# Island: report commands that ran for a while. Sourced from ~/.zshrc by shell_setup.py.
# Needs an interactive zsh under Wayland with `qs` on PATH; costs nothing per prompt and
# runs `qs ipc` only when a command passed the threshold (seconds, ISLAND_CMD_THRESHOLD).
[[ -o interactive ]] || return 0
[[ -n $WAYLAND_DISPLAY ]] || return 0
(( $+commands[qs] )) || return 0
zmodload zsh/datetime 2>/dev/null || return 0

typeset -g _island_cmd='' _island_start=0
: ${ISLAND_CMD_THRESHOLD:=30}

_island_preexec() {
  _island_cmd=$1
  _island_start=$EPOCHREALTIME
}

_island_precmd() {
  local code=$?
  (( _island_start )) || return 0
  local secs=$(( EPOCHREALTIME - _island_start ))
  local cmd=$_island_cmd
  _island_cmd='' _island_start=0
  (( secs >= ISLAND_CMD_THRESHOLD )) || return 0
  # Interrupted by the user (Ctrl-C, SIGTERM): nothing to report.
  (( code == 130 || code == 143 )) && return 0
  # Interactive programs run for a long time by design.
  case ${${(z)cmd}[1]:t} in
    nvim|vim|vi|nano|ssh|mosh|claude|codex|gemini|less|man|htop|btop|top|tmux|lazygit|watch|tail|journalctl|fzf|yazi|ranger|zellij) return 0 ;;
  esac
  command qs -c caelestia ipc call devcmd done $code ${secs%.*} "${cmd[1,120]}" $$ &>/dev/null &!
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _island_preexec
# Run first, so nothing else can change $? before it is read.
precmd_functions=(_island_precmd ${precmd_functions:#_island_precmd})
