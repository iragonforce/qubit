export TERM=xterm-256color
export BASH_SILENCE_DEPRECATION_WARNING=1
force_color_prompt=yes

__bash_git_prompt_segment() {
  local branch dirty
  branch=$(git symbolic-ref --short HEAD 2>/dev/null \
    || git describe --tags --exact-match HEAD 2>/dev/null \
    || git rev-parse --short HEAD 2>/dev/null) || return 0
  dirty=''
  [[ -n $(git status --porcelain 2>/dev/null) ]] && dirty='*'
  printf ' git:(%s%s)' "$branch" "$dirty"
}

__bash_set_prompt() {
  local last_status=$?
  local arrow_color='0;32'
  local user_color='0;33'
  local host_color='0;34'
  local git_segment

  (( last_status != 0 )) && arrow_color='0;31'
  if (( EUID == 0 )); then
    user_color='0;31'
    host_color='0;33'
  fi

  git_segment=$(__bash_git_prompt_segment)
  PS1="\\[\\e[${arrow_color}m\\]➜\\[\\e[0m\\] \\[\e[${user_color}m\\]\\u\\[\\e[0m\\]@\\[\\e[${host_color}m\\]\\h\\[\\e[0m\\]"
  if [[ -n "$git_segment" ]]; then
    PS1+="\\[\\e[0;31m\\]${git_segment}\\[\\e[0m\\]"
  fi
  PS1+=" \\[\\e[0;97m\\]\\w\\[\\e[0m\\] "
}

PROMPT_COMMAND=__bash_set_prompt
__bash_set_prompt

if [[ $- == *i* ]]; then
  if [ -f /opt/homebrew/etc/profile.d/bash_completion.sh ]; then
    . /opt/homebrew/etc/profile.d/bash_completion.sh
  elif [ -f /usr/local/etc/bash_completion ]; then
    . /usr/local/etc/bash_completion
  fi

  if command -v fastfetch >/dev/null 2>&1; then
    fastfetch
  fi

  # Bash is the clean Unix-learning environment. Keep user configuration and
  # plugins out of both editors; zsh owns the personal Neovim setup.
  vim() {
    /usr/bin/vim -u NONE -U NONE -N --noplugin "$@"
  }

  nvim() {
    /opt/homebrew/bin/nvim -u NONE --noplugin "$@"
  }
fi

. "$HOME/.local/bin/env"

[ -f "$HOME/.config/shell/capture.sh" ] && . "$HOME/.config/shell/capture.sh"
