# gabe-fz dotfiles

# Install brew

Try below command or visit [brew website](https://brew.sh/) for latest installation script

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

# Clone this repo

```
git clone https://github.com/gabe-fz/dotfiles ~/dotfiles
```

# Install apps and symlink zshrc

```
cd ~/dotfiles
brew bundle
ln -s ~/dotfiles/.zshrc ~/.zshrc
```

# What's included

**CLI Tools:**
- `bat` - cat clone with syntax highlighting
- `exa` - modern ls replacement with colors and icons
- `fd` - fast find alternative
- `fzf` - fuzzy finder for command line
- `git` - version control
- `jq` - JSON processor
- `nnn` - terminal file manager
- `node` - JavaScript runtime
- `zsh` - shell
- `starship` - minimal, fast shell prompt

**Applications:**
- `iterm2` - terminal emulator
- `sensiblesidebuttons` - mouse button configuration utility