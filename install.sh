#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly ARCH_INSTALLER="$SCRIPT_DIR/setup/arch/install_pkgs.sh"
readonly DOTS_DIR="$SCRIPT_DIR/dots"
readonly WALLPAPER_REPOSITORY="https://github.com/orangci/walls.git"
readonly WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
readonly PYTHON_REQUIREMENTS="$SCRIPT_DIR/sdata/uv/requirements.txt"
readonly INSTALL_LOCK="${XDG_RUNTIME_DIR:-/tmp}/seam-installer-${UID}.lock"
readonly SEAM_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/seam"
readonly INSTALL_LOG_DIR="$SEAM_STATE_DIR/install-logs"
readonly MINIMUM_FREE_KIB=1048576

aur_helper=""
sudo_keepalive_pid=""
temporary_dir=""
current_stage="startup"
install_started_at=$SECONDS
install_journal=""
last_backup_dir=""

readonly -a desktop_packages=(
  bc
  cava
  cliphist
  cmake
  coreutils
  curl
  dolphin
  go-yq
  hypridle
  jq
  ripgrep
  rsync
  tela-circle-icon-theme-standard
  wget
  xdg-user-dirs
  zen-browser-bin
  vesktop
)

usage() {
  cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Bootstrap and install Seam on Arch Linux.

Options:
  --helper NAME         Use yay or paru instead of auto-detecting one
EOF
}

log() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 39 --bold "[seam] $*"
  else
    printf '\033[1;34m[seam]\033[0m %s\n' "$*"
  fi
}

warn() {
  printf '\033[1;33m[seam]\033[0m %s\n' "$*" >&2
}

journal() {
  [[ -n "$install_journal" ]] || return 0
  printf '%(%Y-%m-%dT%H:%M:%S%z)T\t%s\n' -1 "$*" >>"$install_journal"
}

die() {
  printf '\033[1;31m[seam]\033[0m %s\n' "$*" >&2
  journal "ABORT stage=$current_stage reason=$*"
  exit 1
}

on_interrupt() {
  warn "Installation cancelled."
  journal "CANCELLED stage=$current_stage"
  exit 130
}

cleanup() {
  if [[ -n "$sudo_keepalive_pid" ]]; then
    kill "$sudo_keepalive_pid" 2>/dev/null || true
    wait "$sudo_keepalive_pid" 2>/dev/null || true
  fi
  if [[ -n "$temporary_dir" && -d "$temporary_dir" ]]; then
    rm -rf -- "$temporary_dir"
  fi
  journal "cleanup complete"
}

on_error() {
  local exit_code=$?
  local line_number="$1"
  local failed_command="$2"
  printf '\033[1;31m[seam]\033[0m Installation failed during %s at line %s (exit %s).\n' \
    "$current_stage" "$line_number" "$exit_code" >&2
  printf '  Command: %s\n' "$failed_command" >&2
  [[ -z "$install_journal" ]] || printf '  Journal: %s\n' "$install_journal" >&2
  journal "FAILED stage=$current_stage line=$line_number exit=$exit_code command=$failed_command"
  exit "$exit_code"
}

run_stage() {
  local stage_started_at=$SECONDS
  current_stage="$1"
  shift
  journal "START $current_stage"
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 81 --bold "${current_stage}"
  else
    log "${current_stage}"
  fi
  "$@"
  journal "DONE $current_stage duration=$((SECONDS - stage_started_at))s"
  log "Finished $current_stage in $((SECONDS - stage_started_at))s"
}

run_with_spinner() {
  local title="$1"
  shift

  if command -v gum >/dev/null 2>&1; then
    gum spin \
      --spinner dot \
      --show-output \
      --title "$title" \
      -- "$@"
  else
    log "$title"
    "$@"
  fi
}

show_logo() {
  if [[ -t 1 && "${TERM:-dumb}" != "dumb" ]]; then
    clear || true
  fi
  echo
  cat -- "$SCRIPT_DIR/logo.txt"
  echo
}

trap cleanup EXIT
trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR
trap on_interrupt INT TERM

show_logo

while (($# > 0)); do
  case "$1" in
  --helper)
    (($# >= 2)) || die "--helper requires yay or paru"
    aur_helper="$2"
    shift
    ;;
  *)
    usage >&2
    die "Unknown option: $1"
    ;;
  esac
  shift
done

[[ -r /etc/arch-release ]] || die "This installer only supports Arch Linux and Arch-based distributions."
((EUID != 0)) || die "Run this installer as a regular user, not root."
command -v pacman >/dev/null 2>&1 || die "pacman was not found."
command -v sudo >/dev/null 2>&1 || die "sudo was not found."
[[ -x "$ARCH_INSTALLER" ]] || die "Arch package installer is missing or not executable: $ARCH_INSTALLER"
[[ -d "$DOTS_DIR" ]] || die "Dotfiles directory is missing: $DOTS_DIR"
[[ -r "$PYTHON_REQUIREMENTS" ]] || die "Python requirements are missing: $PYTHON_REQUIREMENTS"
[[ -r "$SCRIPT_DIR/logo.txt" ]] || die "Installer logo is missing: $SCRIPT_DIR/logo.txt"

preflight_checks() {
  local available_kib

  [[ -n "${HOME:-}" && "$HOME" == /* ]] || die "HOME must be set to an absolute path."
  [[ "$SEAM_VIRTUAL_ENV" == /* ]] || die "The Seam virtual environment path must be absolute."
  [[ "$WALLPAPER_DIR" == /* ]] || die "The wallpaper destination must be absolute."
  [[ -w "$HOME" ]] || die "Home directory is not writable: $HOME"

  available_kib="$(df -Pk -- "$HOME" | awk 'NR == 2 { print $4 }')"
  [[ "$available_kib" =~ ^[0-9]+$ ]] || die "Could not determine available disk space."
  ((available_kib >= MINIMUM_FREE_KIB)) ||
    die "At least 1 GiB of free space is required in $HOME."

  mkdir -p -- "$INSTALL_LOG_DIR"
  install_journal="$INSTALL_LOG_DIR/$(date +%Y%m%d-%H%M%S)-$$.log"
  : >"$install_journal"
  chmod 600 -- "$install_journal"
  journal "Seam installer started repo=$SCRIPT_DIR user=${USER:-$UID}"
  journal "free_space_kib=$available_kib"
}

preflight_checks

command -v flock >/dev/null 2>&1 || die "flock was not found (provided by util-linux)."
exec {installer_lock_fd}>"$INSTALL_LOCK"
flock -n "$installer_lock_fd" || die "Another Seam installer is already running."
[[ ! -e /var/lib/pacman/db.lck ]] ||
  die "pacman is already running (or left /var/lib/pacman/db.lck behind)."

start_sudo_keepalive() {
  log "Requesting administrator privileges..."
  sudo -v || die "Could not obtain administrator privileges."
  (
    while true; do
      sleep 45
      sudo -n true 2>/dev/null || exit
    done
  ) &
  sudo_keepalive_pid=$!
}

ensure_sudo_session() {
  sudo -n true 2>/dev/null || sudo -v || die "Administrator session expired and could not be renewed."
}

install_repository_packages() {
  local -a packages=(base-devel git gum rsync uv)
  local -a missing=()
  mapfile -t missing < <(pacman -T "${packages[@]}" 2>/dev/null || true)
  if ((${#missing[@]} == 0)); then
    log "Bootstrap packages are already installed."
    return 0
  fi
  log "Bootstrap packages: ${missing[*]}"
  ensure_sudo_session
  run_with_spinner \
    "Installing bootstrap packages (${#missing[@]})..." \
    sudo pacman -S --needed --noconfirm "${missing[@]}"
}

verify_bootstrap_commands() {
  local command_name
  for command_name in git gum makepkg rsync uv; do
    command -v "$command_name" >/dev/null 2>&1 ||
      die "Bootstrap package installation did not provide: $command_name"
  done
}

detect_aur_helper() {
  local candidate
  if [[ -n "$aur_helper" ]]; then
    [[ "$aur_helper" == "yay" || "$aur_helper" == "paru" ]] || die "Unsupported AUR helper: $aur_helper"
    if [[ "$aur_helper" == "paru" ]] && ! command -v paru >/dev/null 2>&1; then
      die "Requested AUR helper is not installed: paru"
    fi
    return
  fi

  for candidate in yay paru; do
    if command -v "$candidate" >/dev/null 2>&1; then
      aur_helper="$candidate"
      return
    fi
  done

  aur_helper="yay"
}

bootstrap_yay() {
  command -v yay >/dev/null 2>&1 && return
  temporary_dir="$(mktemp -d -t seam-installer.XXXXXXXX)"
  log "No AUR helper found; bootstrapping yay-bin..."
  run_with_spinner \
    "Downloading yay-bin..." \
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$temporary_dir/yay-bin"
  (
    cd -- "$temporary_dir/yay-bin"
    run_with_spinner \
      "Building and installing yay-bin..." \
      makepkg -si --needed --noconfirm
  )
  command -v yay >/dev/null 2>&1 || die "yay bootstrap completed but the command is unavailable."
}

install_desktop_packages() {
  local -a missing=()
  mapfile -t missing < <(pacman -T "${desktop_packages[@]}" 2>/dev/null || true)
  ((${#missing[@]} > 0)) || {
    log "Supplemental desktop packages are already installed."
    return
  }
  log "Supplemental packages (${#missing[@]}): ${missing[*]}"
  run_with_spinner \
    "Installing desktop packages (${#missing[@]}) with $aur_helper..." \
    "$aur_helper" -S --needed --noconfirm "${missing[@]}"
}

install_metapackages() {
  gum style --foreground 81 --bold "Building Seam metapackages"
  "$ARCH_INSTALLER" --helper "$aur_helper" --noconfirm
}

install_wallpapers() {
  local current_origin=""
  local first_entry=""

  mkdir -p -- "$(dirname -- "$WALLPAPER_DIR")"
  if [[ -d "$WALLPAPER_DIR" ]]; then
    first_entry="$(find "$WALLPAPER_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null || true)"
  fi
  if [[ ! -e "$WALLPAPER_DIR" || (-d "$WALLPAPER_DIR" && -z "$first_entry") ]]; then
    gum spin \
      --spinner dot \
      --title "Downloading wallpapers..." \
      -- git clone --depth 1 "$WALLPAPER_REPOSITORY" "$WALLPAPER_DIR"
    log "Wallpapers installed to $WALLPAPER_DIR"
    return
  fi

  if [[ -d "$WALLPAPER_DIR/.git" ]]; then
    current_origin="$(git -C "$WALLPAPER_DIR" remote get-url origin 2>/dev/null || true)"
  fi
  if [[ "$current_origin" == "https://github.com/orangci/walls" ||
    "$current_origin" == "https://github.com/orangci/walls.git" ||
    "$current_origin" == "git@github.com:orangci/walls.git" ]]; then
    if [[ -n "$(git -C "$WALLPAPER_DIR" status --porcelain --untracked-files=no)" ]]; then
      warn "Wallpaper repository has local changes; leaving it untouched."
      journal "SKIP wallpapers reason=dirty_repository"
      return 0
    fi
    gum spin \
      --spinner dot \
      --title "Updating wallpapers..." \
      -- git -C "$WALLPAPER_DIR" pull --ff-only
    log "Wallpapers are up to date in $WALLPAPER_DIR"
    return
  fi

  die "$WALLPAPER_DIR already exists and is not the orangci/walls repository; refusing to overwrite it."
}

collect_dotfile_targets() {
  local source_root entry
  shopt -s nullglob dotglob
  for source_root in "$DOTS_DIR"/*; do
    if [[ -d "$source_root" && ("${source_root##*/}" == ".config" || "${source_root##*/}" == ".local") ]]; then
      for entry in "$source_root"/*; do
        printf '%s\0' "${entry#"$DOTS_DIR"/}"
      done
    else
      printf '%s\0' "${source_root#"$DOTS_DIR"/}"
    fi
  done
  shopt -u nullglob dotglob
}

backup_existing_dotfiles() {
  local backup_dir="$1"
  shift
  local relative_path target
  local -a backup_sources=()

  mkdir -p -- "$backup_dir"
  for relative_path in "$@"; do
    target="$HOME/$relative_path"
    [[ -e "$target" || -L "$target" ]] || continue
    # The /./ marker makes rsync retain the path relative to HOME.
    backup_sources+=("$HOME/./$relative_path")
  done

  ((${#backup_sources[@]} > 0)) || return 0
  gum spin \
    --spinner dot \
    --show-output \
    --title "Backing up existing dotfiles..." \
    -- rsync -aR -- "${backup_sources[@]}" "$backup_dir/"

  printf '%s\n' "$@" >"$backup_dir/.seam-backup-manifest"
  printf 'Restore this backup with:\n  rsync -a -- %q/ %q/\n' "$backup_dir" "$HOME" \
    >"$backup_dir/RESTORE.txt"
}

deploy_dotfiles() {
  local -a existing_targets=()
  local relative_path
  local backup_dir=""

  while IFS= read -r -d '' relative_path; do
    [[ -n "$relative_path" ]] || continue
    if [[ -e "$HOME/$relative_path" || -L "$HOME/$relative_path" ]]; then
      existing_targets+=("$relative_path")
    fi
  done < <(collect_dotfile_targets)

  gum style \
    --border rounded \
    --border-foreground 39 \
    --padding "0 2" \
    --margin "1 0" \
    --bold \
    "Installing Seam dotfiles" \
    "Source: $DOTS_DIR" \
    "Destination: $HOME"

  if ((${#existing_targets[@]} > 0)); then
    gum style --foreground 214 "Found ${#existing_targets[@]} existing config targets."
    if gum confirm --default=yes "Back up your existing config files before continuing?"; then
      backup_dir="$HOME/.local/state/seam/backups/$(date +%Y%m%d-%H%M%S)"
      backup_existing_dotfiles "$backup_dir" "${existing_targets[@]}"
      last_backup_dir="$backup_dir"
      log "Backup saved to $backup_dir"
      log "Restore instructions: $backup_dir/RESTORE.txt"
    else
      gum style --foreground 214 "Continuing without a backup. Existing matching files may be overwritten."
    fi
  fi

  gum spin \
    --spinner dot \
    --title "Copying dotfiles with rsync..." \
    -- rsync -a --exclude='.git/' -- "$DOTS_DIR/" "$HOME/"
  log "Dotfiles installed."
}

verify_installation() {
  local command_name
  local -a required_commands=(git gum jq qs rsync uv yq)
  local -a missing_commands=()

  for command_name in "${required_commands[@]}"; do
    command -v "$command_name" >/dev/null 2>&1 || missing_commands+=("$command_name")
  done

  ((${#missing_commands[@]} == 0)) ||
    die "Post-install verification failed; missing commands: ${missing_commands[*]}"
  [[ -r "$HOME/.config/quickshell/seam/shell.qml" ]] ||
    die "Post-install verification failed; Seam's shell.qml was not deployed."
  [[ -x "$SEAM_VIRTUAL_ENV/bin/python" ]] ||
    die "Post-install verification failed; Python environment is incomplete."

  uv pip check --python "$SEAM_VIRTUAL_ENV/bin/python"
  journal "verification passed"
  log "Post-install verification passed."
}

run_stage "Administrator access" start_sudo_keepalive
run_stage "Bootstrap packages" install_repository_packages
verify_bootstrap_commands
current_stage="AUR helper detection"
detect_aur_helper
if [[ "$aur_helper" == "yay" ]]; then
  run_stage "AUR helper bootstrap" bootstrap_yay
fi

log "Using AUR helper: $aur_helper"
run_stage "Desktop packages" install_desktop_packages
run_stage "Seam metapackages" install_metapackages
run_stage "Wallpapers" install_wallpapers
run_stage "Dotfiles" deploy_dotfiles
run_stage "Verification" verify_installation

command -v xdg-user-dirs-update >/dev/null 2>&1 && xdg-user-dirs-update
elapsed_seconds=$((SECONDS - install_started_at))
journal "SUCCESS duration=${elapsed_seconds}s backup=${last_backup_dir:-none}"
gum style \
  --border rounded \
  --border-foreground 42 \
  --padding "0 2" \
  --margin "1 0" \
  --bold \
  "Seam installation completed successfully" \
  "Elapsed: $((elapsed_seconds / 60))m $((elapsed_seconds % 60))s" \
  "Install journal: $install_journal" \
  "Backup: ${last_backup_dir:-not requested}"
