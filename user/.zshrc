if [[ -n "${GHOSTTY_RESOURCES_DIR:-}" && -r "${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration" ]]; then
  source "${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration"
fi

# Keep local tools ahead of system tools without assuming Homebrew exists.
export PATH="$HOME/bin:/opt/homebrew/bin:$PATH"
alias bup="brew update && brew upgrade && brew cleanup --prune=all"
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(
    git
    colored-man-pages
    command-not-found
    extract
    safe-paste
    web-search
    npm
    yarn
    kubectl
    docker
    pipenv
    pip
    python
)

source "$ZSH/oh-my-zsh.sh"

# Keep interactive history in the regular zsh history file.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt append_history
setopt inc_append_history
setopt share_history
setopt hist_ignore_dups

# Load installed custom plugins after Oh My Zsh. Syntax highlighting must be
# loaded last so it can see aliases and functions defined by every plugin.
if [ -f "$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    ZSH_AUTOSUGGEST_USE_ASYNC=true
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#808080"
    ZSH_AUTOSUGGEST_HISTORY_IGNORE='?(#c51,)'
    source "$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
    bindkey '^[[C' autosuggest-accept
    bindkey '^F' autosuggest-accept
fi

if [ -f "$ZSH_CUSTOM/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh" ]; then
    source "$ZSH_CUSTOM/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh"
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
    bindkey -M vicmd 'k' history-substring-search-up
    bindkey -M vicmd 'j' history-substring-search-down
fi

if [ -f "$ZSH_CUSTOM/plugins/you-should-use/you-should-use.plugin.zsh" ]; then
    source "$ZSH_CUSTOM/plugins/you-should-use/you-should-use.plugin.zsh"
fi

if [ -f "$ZSH_CUSTOM/plugins/zsh-z/zsh-z.plugin.zsh" ]; then
    source "$ZSH_CUSTOM/plugins/zsh-z/zsh-z.plugin.zsh"
fi

if [ -f "$ZSH_CUSTOM/plugins/autoenv/autoenv.plugin.zsh" ]; then
    source "$ZSH_CUSTOM/plugins/autoenv/autoenv.plugin.zsh"
fi


setopt PROMPT_SUBST

__prompt_git_segment() {
    local branch dirty
    branch=$(command git symbolic-ref --short HEAD 2>/dev/null \
        || command git describe --tags --exact-match HEAD 2>/dev/null \
        || command git rev-parse --short HEAD 2>/dev/null) || return 0
    dirty=''
    [[ -n "$(command git status --porcelain 2>/dev/null)" ]] && dirty='*'
    print -r -- " git:(${branch}${dirty})"
}

if (( EUID == 0 )); then
    PROMPT='%(?:%F{green}➜%f:%F{red}➜%f) %F{red}%n%f@%F{yellow}%m%f%F{red}$( __prompt_git_segment )%f %F{15}%~%f '
else
    PROMPT='%(?:%F{yellow}➜%f:%F{red}➜%f) %F{yellow}%n%f@%F{63}%m%f%F{red}$( __prompt_git_segment )%f %F{15}%~%f '
fi

zmodload zsh/datetime
autoload -Uz add-zsh-hook

export HOMEBREW_NO_ENV_HINTS=1
# tmux sets TERM=tmux-256color; preserve terminal capability detection.
export COLORTERM=truecolor
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export ANIFETCH_VIDEO="$HOME/Downloads/youtube/Cool Arch Linux plymouth theme [BqEbionheNY].webm"
unset NO_COLOR
export EDITOR="$(whence -p nvim 2>/dev/null)"
export VISUAL="$EDITOR"

alias vim='nvim'
alias vi='nvim'

alias ls='gls --color=auto'
alias py=python3
alias sbcl='/opt/homebrew/bin/rlwrap -H ~/.sbcl_history /opt/homebrew/bin/sbcl'
[ -f /opt/homebrew/etc/profile.d/autojump.sh ] && . /opt/homebrew/etc/profile.d/autojump.sh
export PATH=/opt/homebrew/opt/swift/bin:$PATH
export CC=clang

# Use the shared tmux session layout after shell setup.
if [[ -o interactive ]]; then
  _clipboard_key_noop() { return 0 }
  zle -N _clipboard_key_noop
  for _clipboard_keymap in emacs viins vicmd; do
    bindkey -M "$_clipboard_keymap" $'\e[25~' _clipboard_key_noop
    bindkey -M "$_clipboard_keymap" $'\e[26~' _clipboard_key_noop
    bindkey -M "$_clipboard_keymap" $'\e[1;2P' _clipboard_key_noop
    bindkey -M "$_clipboard_keymap" $'\e[1;2Q' _clipboard_key_noop
    bindkey -M "$_clipboard_keymap" $'\e[77101~' _clipboard_key_noop
  done
  unset _clipboard_keymap
fi
if [[ -n ${SSH_TTY:-} && ${TERM:-dumb} == dumb ]]; then
  export TERM=xterm-256color
fi

# Bare tmux attaches to the managed session.
# All tmux commands with arguments remain native.
tmux() {
  if (( $# == 0 )); then
    if [[ -n ${TMUX:-} ]]; then
      command tmux display-message 'Already inside tmux: #{session_name}'
    else
      "$HOME/.config/tmux/session" start
    fi
  else
    command tmux "$@"
  fi
}

if [[ -o interactive && -z ${TMUX:-} && -t 0 && -t 1 && ${TERM:-} != dumb ]]; then
  "$HOME/.config/tmux/session" start
  if [[ -n ${SSH_TTY:-} ]]; then
    builtin exit
  fi
fi

# Ghostty's prompt cursor integration does not run inside tmux panes.
if [[ -o interactive && -n ${TMUX:-} ]]; then
  autoload -Uz add-zle-hook-widget
  _homelab_tmux_cursor_bar() { print -n -- $'\e[6 q' }
  add-zle-hook-widget line-init _homelab_tmux_cursor_bar
fi

[ -f "$HOME/.config/shell/capture.sh" ] && . "$HOME/.config/shell/capture.sh"

[[ -r "$HOME/.config/bws/helpers.zsh" ]] && source "$HOME/.config/bws/helpers.zsh"

export PATH="$HOME/.local/bin:$PATH"

# Enable ANSI colours in watch
alias watch='watch --color'


# Atuin interactive command history
if (( $+commands[atuin] )); then
    eval "$(atuin init zsh )"
fi

# Atuin Up Arrow keybindings
if zle -l atuin-up-search >/dev/null 2>&1; then
    for keymap in emacs viins; do
        bindkey -M "$keymap" '^[[A' atuin-up-search
        bindkey -M "$keymap" '^[OA' atuin-up-search
    done
fi

# Deduplicate PATH, preserving first occurrence.
typeset -U path

# zsh-syntax-highlighting must be loaded last
if [ -f "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    # Ghostty palette: black/white base with bright ANSI accents.
    ZSH_HIGHLIGHT_STYLES[command]='fg=#00ff00,bold'
    ZSH_HIGHLIGHT_STYLES[builtin]='fg=#00ff00,bold'
    ZSH_HIGHLIGHT_STYLES[function]='fg=#00ff00,bold'
    ZSH_HIGHLIGHT_STYLES[alias]='fg=#00ff00,bold'
    ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#ff0000,bold'
    ZSH_HIGHLIGHT_STYLES[path]='fg=#ffffff'
    ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#ffff00'
    ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#ffff00'
fi
