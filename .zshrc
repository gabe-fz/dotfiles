dotfiles_home="$HOME/dotfiles" # dotfiles home
fzf_config_files="$dotfiles_home/.fzf.zsh"

######### ZSH #########
#######################

autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
alias reload="source ~/.zshrc"

######### OTHER ZSH CONFIGS #########
#####################################

eval "$(starship init zsh)"

[ -f $fzf_config_files ] && source $fzf_config_files

######### VS CODE #######
#########################
[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path zsh)"

######### ISSUES #######
########################
alias fixchromepws="find ~/Library/'Application Support'/Google/Chrome/ -type f -name 'Login Data*' -delete"
alias fixBindings="mv ~/Library/Preferences/com.apple.symbolichotkeys.plist ~/Desktop/com.apple.symbolichotkeys.plist"
alias checkspeed='curl -w "%{time_total}\n" -o /dev/null -X POST -s -L https://www.google.com/search\?q\=sample'
alias checkinterfaces='ifconfig | grep -A 2 utun | grep -B 1 10.'

######### SYSTEN #########
##########################

alias ls='exa'
alias la='ls -a'
alias ll='la -l'

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vi'
else
  export EDITOR='vi'
fi

alias lsusb="system_profiler SPUSBDataType"

function portpid {
  sudo lsof -i tcp:$1
}

######### VPS EXTENSION #########
#################################

[ -f /Users/gabrielfernandez@rccl.com/vps/setup/dotfiles/.zshrc ] && source /Users/gabrielfernandez@rccl.com/vps/setup/dotfiles/.zshrc
