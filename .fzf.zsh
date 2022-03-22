# Setup fzf
# ---------
# if [[ ! "$PATH" == */usr/local/opt/fzf/bin* ]]; then
#   export PATH="${PATH:+${PATH}:}/usr/local/opt/fzf/bin"
if [[ ! "$PATH" == */opt/homebrew/opt/fzf/bin* ]]; then
  export PATH="${PATH:+${PATH}:}/opt/homebrew/opt/fzf/bin"
fi

# Auto-completion
# ---------------
# [[ $- == *i* ]] && source "/usr/local/opt/fzf/shell/completion.zsh" 2> /dev/null
[[ $- == *i* ]] && source "/opt/homebrew/opt/fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
# source "/usr/local/opt/fzf/shell/key-bindings.zsh"
source "/opt/homebrew/opt/fzf/shell/key-bindings.zsh"

# Custom Opts

# Use ~~ as the trigger sequence instead of the default **
export FZF_COMPLETION_TRIGGER='``'

# Options to fzf command
fzf_preview_opts="--preview 'bat --style=numbers --color=always --line-range :150 {}'"
export FZF_DEFAULT_OPTS="--height 40% --layout reverse --border --multi --inline-info"
export FZF_COMPLETION_OPTS="$FZF_DEFAULT_OPTS $fzf_preview_opts"

# Use fd (https://github.com/sharkdp/fd) instead of the default find
# command for listing path candidates.80
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  fd --hidden --follow --exclude ".git" . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type d --hidden --follow --exclude ".git" . "$1"
}

# custom aliases
# . prefix = use fzf
# - postfix = use directory
# ~ postfix = use home directory
# p postfix = preview

# fd
alias fd-='fd --type d --hidden --follow --exclude ".git" .'
alias fd~="fd- ~"

# fzf
alias fzfp="fzf $FZF_COMPLETION_OPTS"
alias fzf-="fd- | fzf"
alias fzf~="fd~ | fzf"

# fzf mixes
alias .code='code $(fzfp)'
alias .code-='code $(fzfp)'
alias .code~='code $(fzfp)'
alias .cd='cd $(fzf-)'
alias .cd-='.cd'
alias .cd~='cd $(fzf~)'