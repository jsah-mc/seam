#!/usr/bin/env bash

# Hosted bootstrap entry point:
#   bash <(curl -fsSL https://jsah-mc.github.io/seam/auto-install.sh)
#   bash <(curl -fsSL https://jsah-mc.github.io/seam/auto-install.sh) --helper paru

set -Eeuo pipefail

readonly SEAM_REPOSITORY="https://github.com/jsah-mc/seam.git"
readonly SEAM_REF="${SEAM_REF:-main}"

checkout_dir=""
current_stage="bootstrap"

log() {
  printf '\033[1;34m[seam bootstrap]\033[0m %s\n' "$*"
}

die() {
  printf '\033[1;31m[seam bootstrap]\033[0m %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "$checkout_dir" && -d "$checkout_dir" ]]; then
    rm -rf -- "$checkout_dir"
  fi
}

on_error() {
  local exit_code=$?
  local line_number="$1"
  local failed_command="$2"
  printf '\033[1;31m[seam bootstrap]\033[0m Failed during %s at line %s (exit %s).\n' \
    "$current_stage" "$line_number" "$exit_code" >&2
  printf '  Command: %s\n' "$failed_command" >&2
  exit "$exit_code"
}

on_interrupt() {
  printf '\n'
  die "Installation cancelled."
}

trap cleanup EXIT
trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR
trap on_interrupt INT TERM

[[ -r /etc/arch-release ]] || die "This bootstrapper supports Arch Linux and Arch-based distributions only."
(( EUID != 0 )) || die "Run this command as a regular user, not root."
command -v pacman >/dev/null 2>&1 || die "pacman was not found."
command -v sudo >/dev/null 2>&1 || die "sudo was not found."
command -v mktemp >/dev/null 2>&1 || die "mktemp was not found."
[[ ! -e /var/lib/pacman/db.lck ]] || die "pacman is already running or its database lock is stale."

# The full installer intentionally accepts only --helper. Validate here too so
# a typo is rejected before sudo or network access is requested.
if (( $# > 0 )); then
  [[ $# -eq 2 && "$1" == "--helper" ]] || \
    die "Usage: auto-install.sh [--helper yay|paru]"
  [[ "$2" == "yay" || "$2" == "paru" ]] || \
    die "--helper must be yay or paru."
fi

if ! command -v git >/dev/null 2>&1; then
  current_stage="Git installation"
  log "Git is required; installing it with pacman..."
  sudo -v || die "Could not obtain administrator privileges."
  sudo pacman -S --needed --noconfirm git
fi

current_stage="repository download"
checkout_dir="$(mktemp -d -t seam-bootstrap.XXXXXXXX)"
[[ -d "$checkout_dir" && "${checkout_dir##*/}" == seam-bootstrap.* ]] || \
  die "Could not create a safe temporary checkout directory."

log "Downloading Seam ($SEAM_REF)..."
GIT_TERMINAL_PROMPT=0 git clone \
  --depth 1 \
  --single-branch \
  --branch "$SEAM_REF" \
  "$SEAM_REPOSITORY" \
  "$checkout_dir/repository"

readonly installer="$checkout_dir/repository/install.sh"
[[ -f "$installer" ]] || die "The downloaded repository does not contain install.sh."
[[ -x "$installer" ]] || chmod u+x -- "$installer"

current_stage="Seam installation"
log "Repository downloaded. Starting the full installer..."
"$installer" "$@"

current_stage="complete"
log "Seam installation finished successfully."
