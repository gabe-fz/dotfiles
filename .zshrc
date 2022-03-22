dotfiles_home="$HOME/dotfiles" # dotfiles home
p10k_config_file="$dotfiles_home/.p10k.zsh"
fzf_config_files="$dotfiles_home/.fzf.zsh"


######### ZSH #########
#######################

autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
alias reload="source ~/.zshrc"

######### OTHER ZSH CONFIGS #########
#####################################

[ -f $p10k_config_file ] && source $p10k_config_file

[ -f $fzf_config_files ] && source $fzf_config_files


######### ISSUES #########
########################
alias fixchromepws="find ~/Library/'Application Support'/Google/Chrome/ -type f -name 'Login Data*' -delete"
alias fixBindings="mv ~/Library/Preferences/com.apple.symbolichotkeys.plist ~/Desktop/com.apple.symbolichotkeys.plist"
alias checkspeed='curl -w "%{time_total}\n" -o /dev/null -X POST -s -L https://www.google.com/search\?q\=sample'

######### TMUX #########
##########################

alias mux="tmuxinator"
alias muxkill="tmux kill-server"

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

######### BUILD TOOLS #########
###############################

alias mvns="mvn -Dmaven.test.skip=true"   
alias g="./gradlew"
alias gcb="./gradlew clean build"
alias gcp="./gradlew clean publishToMavenLocal"
alias gcbs="./gradlew clean build -x test"
alias gcps="./gradlew clean publishToMavenLocal -x test"

######### GIT #########
##########################

alias gitignorerm="git rm --cached \`git ls-files -i --exclude-from=.gitignore\`"
alias gituncommit="git reset HEAD^"
alias gitbranchpurgels="git fetch --prune && git branch -r | cut -c 10- | grep -v develop | grep -v master | grep -v release"
alias gitbranchpurgecommit="git fetch --prune && git branch -r | cut -c 10- | grep -v develop | grep -v master | grep -v release | xargs git push origin --delete"

######### SDKMAN #########
##########################

alias gradle5="sdk use gradle 5.6"
alias gradle6="sdk use gradle 6.8"
alias gradle7="sdk use gradle 7.2"
alias java8="sdk use java 8.0.242-zulu"
alias java11="sdk use java 11.0.2-open"
alias java17="sdk use java 17.0.1-open"