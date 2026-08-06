# gabe-fz dotfiles

Personal macOS dotfiles managed with [chezmoi](https://www.chezmoi.io/). The
chezmoi source directory lives at `~/dotfiles`; chezmoi renders it into `$HOME`.

## Install (new machine)

One line — installs chezmoi, pulls this repo, and applies it:

```
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply gabe-fz
```

On first `apply`, the `run_onchange_brew-bundle.sh` script runs `brew bundle`
against the `Brewfile`, installing every CLI tool and cask below. (Install
[Homebrew](https://brew.sh/) first if it isn't already present.)

## Day-2 usage

This repo *is* the chezmoi source directory, so edit files under `~/dotfiles`
(the `dot_*` names map to `~/.*` targets) and apply.

```
chezmoi diff              # preview what would change in $HOME
chezmoi apply             # write the changes into $HOME
chezmoi edit ~/.zshrc     # edit the source of a managed file
chezmoi re-add            # pull edits you made directly in $HOME back into the source
chezmoi cd                # jump into ~/dotfiles (the source dir)
```

After editing the `Brewfile`, `chezmoi apply` re-runs `brew bundle` automatically
(the script is keyed on the Brewfile's hash).

## Layout

- `dot_zshrc` → `~/.zshrc` — ordered zsh init (env, keymap, completions, modules, prompt)
- `dot_tmux.conf` → `~/.tmux.conf`
- `dot_config/zsh/*.zsh` → `~/.config/zsh/*.zsh` — personal modules (aliases, fzf)
- `Brewfile` + `run_onchange_brew-bundle.sh.tmpl` — package management

## Machine-local config & secrets

Two files are intentionally **not** managed by chezmoi and never committed:

- `~/.zshrc.local` — machine-local settings and **secrets**. Sourced by `~/.zshrc`
  if present. Keep tokens/credentials here.
- `~/.zshrc.d/*.zsh` — drop-in directory for **external generators** (e.g. the
  vps-setup work-config generator). `~/.zshrc` sources every `*.zsh` here. Safe
  to be empty.

## What's included

**CLI tools:**
- `bat` - cat clone with syntax highlighting
- `chezmoi` - dotfiles manager
- `eza` - modern ls replacement (successor to the abandoned `exa`)
- `fd` - fast find alternative
- `fzf` - fuzzy finder for the command line
- `git` - version control
- `jq` - JSON processor
- `nnn` - terminal file manager
- `node` - JavaScript runtime
- `starship` - minimal, fast shell prompt
- `tmux` - terminal multiplexer
- `zsh` - shell

**Applications:**
- `ghostty` - terminal emulator
- `sensiblesidebuttons` - mouse button configuration utility
