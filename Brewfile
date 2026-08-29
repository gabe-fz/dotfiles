# Brewfile — managed by chezmoi. `chezmoi apply` re-runs `brew bundle` whenever
# this file's hash changes (see run_onchange_brew-bundle.sh.tmpl).
# Install Homebrew first (https://brew.sh) on a fresh machine.

# ── Shell & prompt ──────────────────────────────────────────────────
brew "zsh"
brew "starship"          # minimal, fast prompt

# ── Core CLI ────────────────────────────────────────────────────────
brew "bat"               # cat with syntax highlighting
brew "eza"               # modern ls (successor to exa)
brew "fd"                # fast find
brew "fzf"               # fuzzy finder
brew "jq"                # JSON processor
brew "yq"                # YAML processor
brew "nnn"               # terminal file manager
brew "git"
brew "gh"                # GitHub CLI
brew "chezmoi"           # this dotfiles manager
brew "neovim"

# ── Terminal multiplexer (metamux drives this) ──────────────────────
brew "tmux"

# ── Languages & runtimes ────────────────────────────────────────────
brew "node"
brew "uv"                # Python env/tool manager — required by metamux & internal tools
brew "maven"

# ── Cloud / Kubernetes / containers ─────────────────────────────────
brew "awscli"
brew "helm"
brew "kubectx"
brew "kustomize"
brew "minikube"
brew "podman"
brew "k9s"               # Kubernetes TUI

# ── Data / docs / diagrams ──────────────────────────────────────────
brew "mongosh"
brew "pandoc"
brew "d2"                # diagram DSL
brew "marp-cli"          # markdown → slides

# ── Applications (casks) ────────────────────────────────────────────
cask "ghostty"               # terminal emulator
cask "sensiblesidebuttons"   # mouse-button config
cask "visual-studio-code"
cask "intellij-idea"
cask "bruno"                 # API client
cask "mongodb-compass"
cask "offset-explorer"       # Kafka UI
