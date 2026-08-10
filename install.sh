#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly ARCH_INSTALLER="$SCRIPT_DIR/setup/arch/install_pkgs.sh"
readonly DOTS_DIR="$SCRIPT_DIR/dots"
readonly WALLPAPER_REPOSITORY="https://github.com/orangci/walls.git"
readonly WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
readonly PYTHON_REQUIREMENTS="$SCRIPT_DIR/sdata/uv/requirements.txt"
readonly SEAM_VIRTUAL_ENV="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/.venv"

aur_helper=""
sudo_keepalive_pid=""
temporary_dir=""

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

die() {
  printf '\033[1;31m[seam]\033[0m %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "$sudo_keepalive_pid" ]]; then
    kill "$sudo_keepalive_pid" 2>/dev/null || true
    wait "$sudo_keepalive_pid" 2>/dev/null || true
  fi
  if [[ -n "$temporary_dir" && -d "$temporary_dir" ]]; then
    rm -rf -- "$temporary_dir"
  fi
}

on_error() {
  local exit_code=$?
  printf '\033[1;31m[seam]\033[0m Installation failed near line %s (exit %s).\n' "$1" "$exit_code" >&2
  exit "$exit_code"
}

trap cleanup EXIT
trap 'on_error $LINENO' ERR
trap 'exit 130' INT TERM

while (( $# > 0 )); do
  case "$1" in
    --helper)
      (( $# >= 2 )) || die "--helper requires yay or paru"
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
(( EUID != 0 )) || die "Run this installer as a regular user, not root."
command -v pacman >/dev/null 2>&1 || die "pacman was not found."
command -v sudo >/dev/null 2>&1 || die "sudo was not found."
[[ -x "$ARCH_INSTALLER" ]] || die "Arch package installer is missing or not executable: $ARCH_INSTALLER"
[[ -d "$DOTS_DIR" ]] || die "Dotfiles directory is missing: $DOTS_DIR"

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

install_repository_packages() {
  local -a packages=(base-devel git gum rsync uv)
  local -a missing=()
  mapfile -t missing < <(pacman -T "${packages[@]}" 2>/dev/null || true)
  if (( ${#missing[@]} == 0 )); then
    log "Bootstrap packages are already installed."
    return 0
  fi
  log "Bootstrap packages: ${missing[*]}"
  sudo pacman -S --needed "${missing[@]}"
}

detect_aur_helper() {
  local candidate
  if [[ -n "$aur_helper" ]]; then
    [[ "$aur_helper" == "yay" || "$aur_helper" == "paru" ]] || die "Unsupported AUR helper: $aur_helper"
    command -v "$aur_helper" >/dev/null 2>&1 || die "Requested AUR helper is not installed: $aur_helper"
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
  git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$temporary_dir/yay-bin"
  (
    cd -- "$temporary_dir/yay-bin"
    makepkg -si
  )
}

install_desktop_packages() {
  local -a missing=()
  mapfile -t missing < <(pacman -T "${desktop_packages[@]}" 2>/dev/null || true)
  (( ${#missing[@]} > 0 )) || {
    log "Supplemental desktop packages are already installed."
    return
  }
  log "Supplemental packages (${#missing[@]}): ${missing[*]}"
  gum style --foreground 214 "The package manager may ask for confirmation."
  "$aur_helper" -S --needed "${missing[@]}"
}

install_metapackages() {
  gum style --foreground 81 --bold "Building Seam metapackages"
  "$ARCH_INSTALLER" --helper "$aur_helper"
}

install_python_packages() {
  [[ -f "$PYTHON_REQUIREMENTS" ]] || die "Python requirements are missing: $PYTHON_REQUIREMENTS"

  mkdir -p -- "$(dirname -- "$SEAM_VIRTUAL_ENV")"
  export UV_NO_MODIFY_PATH=1
  export SEAM_VIRTUAL_ENV

  gum spin \
    --spinner dot \
    --show-output \
    --title "Creating Seam's Python 3.12 environment..." \
    -- uv venv \
      --allow-existing \
      --prompt Seam \
      --python 3.12 \
      "$SEAM_VIRTUAL_ENV"

  gum spin \
    --spinner dot \
    --show-output \
    --title "Installing Seam's Python packages..." \
    -- uv pip install \
      --python "$SEAM_VIRTUAL_ENV/bin/python" \
      --requirements "$PYTHON_REQUIREMENTS"

  log "Python environment ready at $SEAM_VIRTUAL_ENV"
}

install_wallpapers() {
  local current_origin=""

  mkdir -p -- "$(dirname -- "$WALLPAPER_DIR")"
  if [[ ! -e "$WALLPAPER_DIR" ]]; then
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
    if [[ -d "$source_root" && ( "${source_root##*/}" == ".config" || "${source_root##*/}" == ".local" ) ]]; then
      for entry in "$source_root"/*; do
        printf '%s\n' "${entry#"$DOTS_DIR"/}"
      done
    else
      printf '%s\n' "${source_root#"$DOTS_DIR"/}"
    fi
  done
  shopt -u nullglob dotglob
}

backup_existing_dotfiles() {
  local backup_dir="$1"
  shift
  local relative_path target

  mkdir -p -- "$backup_dir"
  for relative_path in "$@"; do
    target="$HOME/$relative_path"
    [[ -e "$target" || -L "$target" ]] || continue
    # The /./ marker makes rsync retain the path relative to HOME.
    gum spin \
      --spinner dot \
      --title "Backing up $relative_path..." \
      -- rsync -aR -- "$HOME/./$relative_path" "$backup_dir/"
  done
}

deploy_dotfiles() {
  local -a existing_targets=()
  local relative_path
  local backup_dir=""

  while IFS= read -r relative_path; do
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

  if (( ${#existing_targets[@]} > 0 )); then
    gum style --foreground 214 "Found ${#existing_targets[@]} existing config targets."
    if gum confirm --default=yes "Back up your existing config files before continuing?"; then
      backup_dir="$HOME/.local/state/seam/backups/$(date +%Y%m%d-%H%M%S)"
      backup_existing_dotfiles "$backup_dir" "${existing_targets[@]}"
      log "Backup saved to $backup_dir"
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

start_sudo_keepalive
install_repository_packages
detect_aur_helper
[[ "$aur_helper" != "yay" ]] || bootstrap_yay

log "Using AUR helper: $aur_helper"
install_desktop_packages
install_metapackages
install_python_packages
install_wallpapers
deploy_dotfiles

command -v xdg-user-dirs-update >/dev/null 2>&1 && xdg-user-dirs-update
log "Seam installation completed successfully."
