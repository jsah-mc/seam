#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
readonly NIX_FLAGS=(--extra-experimental-features "nix-command flakes")

hostname="${SEAM_NIX_HOST:-}"
system="${SEAM_NIX_SYSTEM:-x86_64-linux}"
user="${SEAM_NIX_USER:-${USER:-joseph}}"
hardware_config="${SEAM_NIX_HARDWARE_CONFIG:-/etc/nixos/hardware-configuration.nix}"
switch_system=1
enable_nvidia="${SEAM_NIX_ENABLE_NVIDIA:-0}"
enable_secure_boot="${SEAM_NIX_ENABLE_SECURE_BOOT:-0}"
enable_nvidia_set=0
enable_secure_boot_set=0
user_set=0
system_set=0
hardware_config_set=0

[[ -n "${SEAM_NIX_ENABLE_NVIDIA:-}" ]] && enable_nvidia_set=1
[[ -n "${SEAM_NIX_ENABLE_SECURE_BOOT:-}" ]] && enable_secure_boot_set=1
[[ -n "${SEAM_NIX_USER:-}" ]] && user_set=1
[[ -n "${SEAM_NIX_SYSTEM:-}" ]] && system_set=1
[[ -n "${SEAM_NIX_HARDWARE_CONFIG:-}" ]] && hardware_config_set=1

log() {
  printf '\033[1;34m[seam]\033[0m %s\n' "$*"
}

die() {
  printf '\033[1;31m[seam]\033[0m %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: setup/nix/install.sh [OPTIONS]

Configure and switch the Seam NixOS system.

Options:
  --hostname NAME          NixOS hostname and flake output name
  --user NAME              Normal user managed by Home Manager
  --system SYSTEM          Nix system, e.g. x86_64-linux
  --hardware-config PATH   Hardware configuration module
  --enable-nvidia          Enable proprietary NVIDIA drivers
  --disable-nvidia         Disable NVIDIA drivers
  --enable-secure-boot     Enable Limine Secure Boot support
  --disable-secure-boot    Disable Secure Boot support
  --no-switch              Check and build only
  -h, --help               Show this help
EOF
}

prompt_hostname() {
  if [[ -n "$hostname" ]]; then
    return
  fi

  if command -v gum >/dev/null 2>&1; then
    hostname="$(gum input --placeholder "hostname" --prompt "Hostname: ")"
  elif [[ -t 0 ]]; then
    printf 'Hostname: '
    read -r hostname
  else
    die "Hostname is required. Pass --hostname NAME or set SEAM_NIX_HOST."
  fi
}

prompt_value() {
  local label="$1"
  local default_value="$2"
  local value

  if command -v gum >/dev/null 2>&1; then
    value="$(gum input --value "$default_value" --prompt "$label: ")"
  elif [[ -t 0 ]]; then
    printf '%s [%s]: ' "$label" "$default_value" >&2
    read -r value
    value="${value:-$default_value}"
  else
    printf '%s' "$default_value"
    return
  fi

  printf '%s' "$value"
}

prompt_bool() {
  local label="$1"
  local default_value="$2"
  local default_answer="No"
  local answer

  case "$default_value" in
  1 | true | yes | on)
    default_answer="Yes"
    ;;
  0 | false | no | off)
    default_answer="No"
    ;;
  *)
    die "Expected boolean default value, got: $default_value"
    ;;
  esac

  if command -v gum >/dev/null 2>&1; then
    if [[ "$default_answer" == "Yes" ]]; then
      gum confirm "$label?" --default=true && printf 1 || printf 0
    else
      gum confirm "$label?" --default=false && printf 1 || printf 0
    fi
    return
  fi

  if [[ ! -t 0 ]]; then
    nix_bool "$default_value" >/dev/null
    case "$(nix_bool "$default_value")" in
    true) printf 1 ;;
    false) printf 0 ;;
    esac
    return
  fi

  while true; do
    if [[ "$default_answer" == "Yes" ]]; then
      printf '%s? [Y/n]: ' "$label" >&2
    else
      printf '%s? [y/N]: ' "$label" >&2
    fi

    read -r answer
    answer="${answer:-$default_answer}"
    case "$answer" in
    y | Y | yes | YES | Yes)
      printf 1
      return
      ;;
    n | N | no | NO | No)
      printf 0
      return
      ;;
    *)
      printf 'Please answer yes or no.\n' >&2
      ;;
    esac
  done
}

prompt_options() {
  if ((user_set == 0)); then
    user="$(prompt_value "User" "$user")"
  fi

  if ((system_set == 0)); then
    system="$(prompt_value "System" "$system")"
  fi

  if ((hardware_config_set == 0)); then
    hardware_config="$(prompt_value "Hardware config" "$hardware_config")"
  fi

  if ((enable_nvidia_set == 0)); then
    enable_nvidia="$(prompt_bool "Enable NVIDIA drivers" "$enable_nvidia")"
  fi

  if ((enable_secure_boot_set == 0)); then
    enable_secure_boot="$(prompt_bool "Enable Secure Boot" "$enable_secure_boot")"
  fi
}

validate_hostname() {
  [[ -n "$hostname" ]] || die "Hostname is required."
  [[ "$hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$|^[a-zA-Z0-9]$ ]] ||
    die "Invalid hostname: $hostname"
}

nix_bool() {
  case "$1" in
  1 | true | yes | on)
    printf true
    ;;
  0 | false | no | off)
    printf false
    ;;
  *)
    die "Expected boolean value, got: $1"
    ;;
  esac
}

nix_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

write_host_config() {
  local host_dir="$SCRIPT_DIR/hosts/$hostname"
  local copied_hardware_config="$host_dir/hardware-configuration.nix"
  local nvidia_enabled
  local secure_boot_enabled
  local seam_root_nix

  [[ "$hardware_config" == /* ]] || hardware_config="$PWD/$hardware_config"
  [[ -r "$hardware_config" ]] || die "Hardware configuration is not readable: $hardware_config"
  nvidia_enabled="$(nix_bool "$enable_nvidia")"
  secure_boot_enabled="$(nix_bool "$enable_secure_boot")"
  seam_root_nix="$(nix_string "$REPO_ROOT")"

  mkdir -p -- "$host_dir"
  cp -- "$hardware_config" "$copied_hardware_config"

  cat >"$host_dir/variables.nix" <<EOF
{
  hostname = "$hostname";
  system = "$system";
  user = "$user";
  seamRoot = $seam_root_nix;
  enableNvidia = $nvidia_enabled;
  enableSecureBoot = $secure_boot_enabled;
  hardwareConfiguration = ./hardware-configuration.nix;
}
EOF
  cat >"$SCRIPT_DIR/seam.local.nix" <<EOF
import ./hosts/$hostname/variables.nix
EOF
  log "Wrote $host_dir/variables.nix"
  log "Copied hardware configuration to $copied_hardware_config"
  log "Wrote $SCRIPT_DIR/seam.local.nix"
}

while (($# > 0)); do
  case "$1" in
  --hostname)
    (($# >= 2)) || die "--hostname requires a value"
    hostname="$2"
    shift
    ;;
  --user)
    (($# >= 2)) || die "--user requires a value"
    user="$2"
    user_set=1
    shift
    ;;
  --system)
    (($# >= 2)) || die "--system requires a value"
    system="$2"
    system_set=1
    shift
    ;;
  --hardware-config)
    (($# >= 2)) || die "--hardware-config requires a path"
    hardware_config="$2"
    hardware_config_set=1
    shift
    ;;
  --enable-nvidia)
    enable_nvidia=1
    enable_nvidia_set=1
    ;;
  --disable-nvidia)
    enable_nvidia=0
    enable_nvidia_set=1
    ;;
  --enable-secure-boot)
    enable_secure_boot=1
    enable_secure_boot_set=1
    ;;
  --disable-secure-boot)
    enable_secure_boot=0
    enable_secure_boot_set=1
    ;;
  --no-switch)
    switch_system=0
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

[[ -r /etc/NIXOS ]] || die "This installer only supports NixOS."
[[ -r "$SCRIPT_DIR/flake.nix" ]] || die "Missing Nix flake: $SCRIPT_DIR/flake.nix"
command -v nix >/dev/null 2>&1 || die "nix was not found."
command -v sudo >/dev/null 2>&1 || die "sudo was not found."
command -v nixos-rebuild >/dev/null 2>&1 || die "nixos-rebuild was not found."

prompt_hostname
prompt_options
validate_hostname
write_host_config

log "Locking dotfiles input to $REPO_ROOT/dots"
nix "${NIX_FLAGS[@]}" flake lock "$SCRIPT_DIR" \
  --override-input dots "path:$REPO_ROOT/dots"

log "Checking NixOS flake in $SCRIPT_DIR"
nix "${NIX_FLAGS[@]}" flake check --no-build "$SCRIPT_DIR"

log "Building NixOS system for $hostname"
nix "${NIX_FLAGS[@]}" build --no-link \
  "$SCRIPT_DIR#nixosConfigurations.$hostname.config.system.build.toplevel"

if ((switch_system == 0)); then
  log "Skipping switch because --no-switch was set."
  exit 0
fi

log "Switching NixOS system for $hostname"
sudo nixos-rebuild switch --flake "$SCRIPT_DIR#$hostname"

log "NixOS installation completed."
