alias reload="source ~/.zshrc"

# ls -> eza (modern replacement for the abandoned exa)
command -v eza >/dev/null && alias ls='eza'
alias la='ls -a'
alias ll='la -l'

# system helpers
alias lsusb="system_profiler SPUSBDataType"
alias checkspeed='curl -w "%{time_total}\n" -o /dev/null -X POST -s -L https://www.google.com/search\?q\=sample'
alias checkinterfaces='ifconfig | grep -A 2 utun | grep -B 1 10.'
alias fixBindings="mv ~/Library/Preferences/com.apple.symbolichotkeys.plist ~/Desktop/com.apple.symbolichotkeys.plist"

# git
alias githash='git rev-parse HEAD | tr -d "\n" | tee /dev/tty | pbcopy'

# DANGER: deletes Chrome's saved passwords (Login Data)
alias chrome-wipe-passwords-danger="find ~/Library/'Application Support'/Google/Chrome/ -type f -name 'Login Data*' -delete"

function portpid {
  sudo lsof -i tcp:$1
}
