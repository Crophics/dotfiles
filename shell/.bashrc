#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
[ -r /home/ryoku/.config/byobu/prompt ] && . /home/ryoku/.config/byobu/prompt   #byobu-prompt#
