#!/bin/bash
#==============================================================#
# Environment
export EDITOR="vi"
export PAGER="less"
#--------------------------------------------------------------#
# if bash is used, set shopt and prompt
if [ -n "$BASH_VERSION" ]; then
  shopt -s nocaseglob # case-insensitive globbing
  shopt -s cdspell    # auto-correct typos in cd
  set -o pipefail     # pipe fail when component fail
  shopt -s histappend # append to history rather than overwrite
  for option in autocd globstar; do
    shopt -s "$option" 2>/dev/null
  done
  export PS1="\[\033]0;\w\007\]\[\]\n\[\e[1;36m\][\D{%m-%d %T}] \[\e[1;31m\]\u\[\e[1;33m\]@\H\[\e[1;32m\]:\w \n\[\e[1;35m\]\$ \[\e[0m\]"
fi
#--------------------------------------------------------------#
# Bash settings
export MANPAGER="less -X"
export HISTSIZE=65535
export HISTFILESIZE=$HISTSIZE
export HISTCONTROL=ignoredups
export HISTIGNORE="l:ls:cd:cd -:pwd:exit:date:* --help"
#--------------------------------------------------------------#
# Path dedupe
if [ -n "$PATH" ]; then
	old_PATH=$PATH:
	PATH=
	while [ -n "$old_PATH" ]; do
		x=${old_PATH%%:*}
		case $PATH: in
		*:"$x":*) ;;
		*) PATH=$PATH:$x ;;
		esac
		old_PATH=${old_PATH#*:}
	done
	PATH=${PATH#:}
	unset old_PATH x
fi

# /etc/profile sources this file with the user's login shell; the shebang is ignored.
# Keep common environment above, and skip bash-only aliases/functions for sh/dash.
if [ -z "${BASH_VERSION:-}" ]; then
  return 0 2>/dev/null || exit 0
fi

#--------------------------------------------------------------#
# aliases & functions
alias c="clear"
alias p="pig"
alias pp="psql"
alias q="exit"
alias j="jobs"
alias k="kubectl"
alias h="history"
alias m="mcli"
alias mc="mcli"
alias d="docker"
alias dc="docker compose"
alias x="codex --dangerously-bypass-approvals-and-sandbox"
alias xx="IS_SANDBOX=1 claude --dangerously-skip-permissions"
alias oc="opencode"
alias gc='git checkout'
alias gst="git status"
alias gci="git commit"
alias gpm='git push origin main'
function v() {
	if [ $# -eq 0 ]; then
		vi .
	else
		vi "$@"
	fi
}
alias hg="history | grep --color=auto "
alias py="python3"
alias cl="clear"
alias clc="clear"
alias rf="rm -rf"
alias ax="chmod a+x"
alias sd="sudo su - dba"
alias sa="sudo su - root"
alias sp="sudo su - postgres"
alias adm="sudo su - admin"
alias vl="sudo cat /var/log/messages"
alias ntps="sudo chronyc -a makestep"
alias node-mt="curl -sL localhost:9100/metrics | grep -v '#' | grep node_"
alias vec-mt="curl -sL localhost:9598/metrics | grep -v '#' | grep vector_"
#--------------------------------------------------------------#
# ls corlor
command ls --color >/dev/null 2>&1 && colorflag="--color" || colorflag="-G"
[ "${TERM}" != "dumb" ] && export LS_COLORS='no=00:fi=00:di=01;34:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:\ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:'
alias sl=ls
alias ll="ls -lh ${colorflag}"
alias l="ls -lh ${colorflag}"
alias la="ls -lha ${colorflag}"
alias lsa="ls -a ${colorflag}"
alias ls="command ls ${colorflag}"
alias lsd="ls -lh ${colorflag} | grep --color=never '^d'" # List only directories
alias ~="cd ~"
alias ..="cd .."
alias cd..="cd .."
alias ...="cd ../.."
alias cd...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias grep="grep --color=auto"
alias fgrep="fgrep --color=auto"
alias egrep="egrep --color=auto"
alias now='date +"DATE: %Y-%m-%d  TIME: %H:%M:%S  EPOCH: %s"'
alias today='date +"%Y%m%d "'
alias suod='sudo '
alias map="xargs -n1"
#--------------------------------------------------------------#
# utils
function tz() {
	if [ $# -gt 0 ]; then
		local t="${1%/}"
		tar -zcf "$t.tar.gz" -- "$@"
	else
		gzip
	fi
}
function tx() {
	if [ $# -gt 0 ]; then
		tar -xf "$@"
	else
		tar -x -
	fi
}
function zz() {
	if [ $# -gt 0 ]; then
		local t="${1%/}"
		local l="${2:-3}"
		l="${l#-}"

		if [ -d "$t" ]; then
			tar -cf - -- "$t" | zstd -f -T0 "-$l" -o "$t.tar.zst"
		elif [ -f "$t" ]; then
			zstd -f -T0 "-$l" -- "$t"
		else
			echo "zz: $t: not found" >&2
			return 1
		fi
	else
		zstd -f -T0
	fi
}
function zx() {
	if [ $# -gt 0 ]; then
		case "$1" in
			*.tar.zst|*.tzst) zstd -dc -- "$1" | tar -xf - "${@:2}" ;;
			*) zstd -df -- "$@" ;;
		esac
	else
		zstd -dc
	fi
}
#--------------------------------------------------------------#
# log & color util
#--------------------------------------------------------------#
if [[ -t 1 ]]; then
	__CN='\033[0m';    __CK='\033[0;30m'; __CR='\033[0;31m'; __CG='\033[0;32m'
	__CY='\033[0;33m'; __CB='\033[0;34m'; __CM='\033[0;35m'; __CC='\033[0;36m'; __CW='\033[0;37m'
else
	__CN=''; __CK=''; __CR=''; __CG=''; __CY=''; __CB=''; __CM=''; __CC=''; __CW=''
fi
function log_info()  { printf "[${__CG} OK ${__CN}] ${__CG}$*${__CN}\n"; }
function log_warn()  { printf "[${__CY}WARN${__CN}] ${__CY}$*${__CN}\n"; }
function log_error() { printf "[${__CR}FAIL${__CN}] ${__CR}$*${__CN}\n"; }
function log_debug() { printf "[${__CB}HINT${__CN}] ${__CB}$*${__CN}\n"; }
function log_input() { printf "[${__CM} IN ${__CN}] ${__CM}$*\n=> ${__CN}"; }
function log_hint()  { printf "${__CB}$*${__CN}"; }
#--------------------------------------------------------------#
# systemctl
alias s="systemctl"
alias st="sudo systemctl status "
alias sr="sudo systemctl restart  "
alias ssdr="sudo systemctl daemon-reload"

_pigsty_unit_completion() {
  local cur
  cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=( $(compgen -W "$(systemctl list-units --no-legend --no-pager 2>/dev/null | awk '{print $1}')" -- "$cur") )
}
complete -F _pigsty_unit_completion s st sr ju
#--------------------------------------------------------------#
# journalctl
alias je="journalctl -xe"
alias ju="journalctl -u"
