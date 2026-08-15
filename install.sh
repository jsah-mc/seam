#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly ARCH_INSTALLER="$SCRIPT_DIR/setup/arch/install.sh"
readonly NIX_INSTALLER="$SCRIPT_DIR/setup/nix/install.sh"

wallpaper_repository="https://github.com/orangci/walls.git"
wallpaper_dir="$HOME/Pictures/Wallpapers"

usage() {
  cat <<'EOF'
Arch options are forwarded to setup/arch/install.sh.
NixOS options are forwarded to setup/nix/install.sh.
EOF
}

log() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 39 --bold "[seam] $*"
  else
    printf '\033[1;34m[seam]\033[0m %s\n' "$*"
  fi
}

die() {
  printf '\033[1;31m[seam]\033[0m %s\n' "$*" >&2
  exit 1
}

run_with_spinner() {
  local title="$1"
  shift

  if command -v gum >/dev/null 2>&1; then
    gum spin --spinner dot --show-output --title "$title" -- "$@"
  else
    log "$title"
    "$@"
  fi
}

install_wallpapers() {
  local current_origin=""
  local first_entry=""

  [[ -n "${HOME:-}" && "$HOME" == /* ]] || die "HOME must be set to an absolute path."
  [[ "$wallpaper_dir" == /* ]] || die "Wallpaper destination must be absolute: $wallpaper_dir"
  command -v git >/dev/null 2>&1 || die "git is required for wallpaper setup."

  mkdir -p -- "$(dirname -- "$wallpaper_dir")"
  if [[ -d "$wallpaper_dir" ]]; then
    first_entry="$(find "$wallpaper_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null || true)"
  fi

  if [[ ! -e "$wallpaper_dir" || (-d "$wallpaper_dir" && -z "$first_entry") ]]; then
    run_with_spinner "Downloading wallpapers..." \
      git clone --depth 1 "$wallpaper_repository" "$wallpaper_dir"
    log "Wallpapers installed to $wallpaper_dir"
    return
  fi

  if [[ -d "$wallpaper_dir/.git" ]]; then
    current_origin="$(git -C "$wallpaper_dir" remote get-url origin 2>/dev/null || true)"
  fi

  if [[ "$current_origin" == "$wallpaper_repository" ||
    "$current_origin" == "https://github.com/orangci/walls" ||
    "$current_origin" == "https://github.com/orangci/walls.git" ||
    "$current_origin" == "git@github.com:orangci/walls.git" ]]; then
    if [[ -n "$(git -C "$wallpaper_dir" status --porcelain --untracked-files=no)" ]]; then
      log "Wallpaper repository has local changes; leaving it untouched."
      return
    fi
    run_with_spinner "Updating wallpapers..." git -C "$wallpaper_dir" pull --ff-only
    log "Wallpapers are up to date in $wallpaper_dir"
    return
  fi

  die "$wallpaper_dir already exists and is not the configured wallpaper repository."
}

show_logo() {
  if [[ -r "$SCRIPT_DIR/logo.txt" ]]; then
    [[ ! -t 1 || "${TERM:-dumb}" == "dumb" ]] || clear || true
    echo
    cat -- "$SCRIPT_DIR/logo.txt"
    echo
  fi
}

skip_wallpapers=0
forward_args=()

while (($# > 0)); do
  case "$1" in
  -h | --help)
    usage
    exit 0
    ;;
  *)
    forward_args+=("$1")
    ;;
  esac
  shift
done

show_logo

if [[ -r /etc/NIXOS ]]; then
  [[ -x "$NIX_INSTALLER" ]] || die "NixOS installer is missing or not executable: $NIX_INSTALLER"
  "$NIX_INSTALLER" "${forward_args[@]}"
elif [[ -r /etc/arch-release ]]; then
  [[ -x "$ARCH_INSTALLER" ]] || die "Arch installer is missing or not executable: $ARCH_INSTALLER"
  "$ARCH_INSTALLER" "${forward_args[@]}"
else
  die "Unsupported distro. Expected NixOS or Arch Linux."
fi

if ((skip_wallpapers == 0)); then
  install_wallpapers
fi
