# gabe-fz dotfiles

Personal macOS dotfiles managed with [chezmoi](https://www.chezmoi.io/). The
chezmoi source directory lives at `~/dotfiles`; chezmoi renders it into `$HOME`.

## Install

Fast path on a new machine — installs chezmoi, pulls this repo, applies it, and
runs `brew bundle` against the [`Brewfile`](Brewfile). Install
[Homebrew](https://brew.sh/) first.

```
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply gabe-fz
```

**Full setup guide → [SETUP.md](SETUP.md)** — fresh install, migrating from
pre-chezmoi dotfiles, ready-to-paste agent prompts, per-step verification, and
the Ghostty / tmux / Claude Code details.

## Layout

- `dot_zshrc` → `~/.zshrc` — ordered zsh init (env, keymap, completions, modules, prompt)
- `dot_tmux.conf` → `~/.tmux.conf`
- `dot_config/ghostty/config` → `~/.config/ghostty/config`
- `dot_config/zsh/*.zsh` → `~/.config/zsh/*.zsh` — personal modules (aliases, fzf)
- `dot_local/bin/*` → `~/.local/bin/*` — personal scripts
- `Brewfile` + `run_onchange_brew-bundle.sh.tmpl` — package management (the full tool + app list)

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

## Machine-local config & secrets

Two files are intentionally **not** managed by chezmoi and never committed:

- `~/.zshrc.local` — machine-local settings and **secrets**. Sourced by `~/.zshrc`
  if present. Keep tokens/credentials here.
- `~/.zshrc.d/*.zsh` — drop-in directory for **external generators**. `~/.zshrc`
  sources every `*.zsh` here. Safe to be empty.
