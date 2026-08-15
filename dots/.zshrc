# Seam shared Zsh configuration.
# This file is deployed on Arch by setup/arch/install.sh and linked on NixOS by Home Manager.

export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

path=(
  "$HOME/.local/bin"
  "$HOME/.cargo/bin"
  "$HOME/.nix-profile/bin"
  $path
)

autoload -Uz compinit
if [[ -n "${XDG_CACHE_HOME:-}" ]]; then
  compinit -d "$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION"
else
  compinit
fi

setopt autocd
setopt auto_pushd
setopt hist_ignore_all_dups
setopt hist_reduce_blanks
setopt inc_append_history
setopt share_history

HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
HISTSIZE=10000
SAVEHIST=10000
mkdir -p -- "${HISTFILE:h}" "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"

alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'
alias rebuild='sudo nixos-rebuild switch --flake ~/seam/setup/nix'

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi
