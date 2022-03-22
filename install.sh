#!/bin/zsh

# install brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# install brew packages
brew bundle

# run below and install fonts, restart iterm
p10k configure

# symlinks
ln -s ~/dotfiles/.zshrc ~/.zshrc