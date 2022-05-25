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

# Fix fonts
Open iterm, run below command, type 'y', and then restart iterm

```
p10k configure
```