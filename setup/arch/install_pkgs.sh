#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

noninteractive=0
dry_run=0
aur_helper=""

readonly -a metapackages=(
  "illogical-impulse-fonts-themes"
  "illogical-impulse-kde"
  "illogical-impulse-hyprland"
  "illogical-impulse-microtex-git"
  "illogical-impulse-quickshell-git"
  "seam-cli"
)

usage() {
  cat <<'EOF'
Usage: setup/arch/install_pkgs.sh [OPTIONS]

Build and install Seam's local Arch metapackages.

Options:
  --dry-run          Show what would be built without changing the system
  --noconfirm        Disable package-manager confirmation prompts
  --helper NAME      Use a specific AUR helper (yay or paru)
  -h, --help         Show this help
EOF
}

log() {
  printf '\033[1;34m[seam]\033[0m %s\n' "$*"
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

die() {
  printf '\033[1;31m[seam]\033[0m %s\n' "$*" >&2
  exit 1
}

on_error() {
  local exit_code=$?
  printf '\033[1;31m[seam]\033[0m Failed near line %s (exit %s).\n' "$1" "$exit_code" >&2
  exit "$exit_code"
}
trap 'on_error $LINENO' ERR

while (($# > 0)); do
  case "$1" in
  --dry-run)
    dry_run=1
    ;;
  --noconfirm)
    noninteractive=1
    ;;
  --helper)
    (($# >= 2)) || die "--helper requires yay or paru"
    aur_helper="$2"
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    die "Unknown option: $1"
    ;;
  esac
  shift
done

[[ -r /etc/arch-release ]] || die "This installer only supports Arch Linux and Arch-based distributions."
((EUID != 0)) || die "Run this script as a regular user, not root; makepkg refuses to build as root."

for command_name in bash makepkg pacman sudo; do
  command -v "$command_name" >/dev/null 2>&1 || die "Missing required command: $command_name"
done

find_aur_helper() {
  local candidate
  if [[ -n "$aur_helper" ]]; then
    command -v "$aur_helper" >/dev/null 2>&1 || die "Requested AUR helper is not installed: $aur_helper"
    return
  fi

  for candidate in yay paru; do
    if command -v "$candidate" >/dev/null 2>&1; then
      aur_helper="$candidate"
      return
    fi
  done
  die "Install yay or paru before running this installer."
}

install_local_pkgbuild() (
  local package_dir="$1"
  local -a confirm_args=()
  local -a package_files=()
  local -a dependency_list=()

  [[ -f "$package_dir/PKGBUILD" ]] || die "PKGBUILD not found: $package_dir/PKGBUILD"
  cd -- "$package_dir"

  # PKGBUILDs are executable build recipes. Source the trusted local recipe so
  # AUR dependencies can be installed before makepkg asks pacman for the rest.
  # shellcheck disable=SC1091
  source ./PKGBUILD
  if declare -p depends >/dev/null 2>&1; then
    dependency_list+=("${depends[@]}")
  fi
  if declare -p makedepends >/dev/null 2>&1; then
    dependency_list+=("${makedepends[@]}")
  fi

  if ((noninteractive)); then
    confirm_args+=(--noconfirm)
  fi

  log "Preparing ${pkgname:-${package_dir##*/}}"
  if ((dry_run)); then
    printf '  cd %q\n' "$package_dir"
    if ((${#dependency_list[@]} > 0)); then
      printf '  %q -S --needed --asdeps ' "$aur_helper"
      printf '%q ' "${confirm_args[@]}" "${dependency_list[@]}"
      printf '\n'
    fi
    printf '  makepkg -Afs '
    printf '%q ' "${confirm_args[@]}"
    printf '\n'
    printf '  sudo pacman -U --needed '
    printf '%q ' "${confirm_args[@]}"
    printf '<packages from makepkg --packagelist>\n'
    return
  fi

  if ((${#dependency_list[@]} > 0)); then
    run_with_spinner \
      "Installing dependencies for ${pkgname:-${package_dir##*/}}..." \
      "$aur_helper" -S --needed --asdeps "${confirm_args[@]}" "${dependency_list[@]}"
  fi

  # Build first, then install only the files reported by makepkg. This avoids
  # accidentally installing stale *.pkg.tar.zst files from earlier builds.
  run_with_spinner \
    "Building ${pkgname:-${package_dir##*/}} with makepkg..." \
    makepkg -Afs "${confirm_args[@]}"
  mapfile -t package_files < <(makepkg --packagelist)
  ((${#package_files[@]} > 0)) || die "makepkg did not report an output package for $package_dir"
  run_with_spinner \
    "Installing ${pkgname:-${package_dir##*/}}..." \
    sudo pacman -U --needed "${confirm_args[@]}" "${package_files[@]}"
)

find_aur_helper
log "Repository: $REPO_ROOT"
log "AUR helper: $aur_helper"

for package_name in "${metapackages[@]}"; do
  install_local_pkgbuild "$SCRIPT_DIR/$package_name"
done

if ((dry_run)); then
  log "Dry run complete; no packages were changed."
else
  log "All Seam metapackages were installed successfully."
fi
