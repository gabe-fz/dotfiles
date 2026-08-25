# Workstation setup guide

How to rebuild this macOS development environment: a chezmoi-managed dotfiles
base, a Homebrew Brewfile, Ghostty + tmux tuned for Claude Code, Claude Code
itself, and the internal RCG tooling layer (metamux, packs, Nexus tools).

Almost nothing is installed by hand — two files are the source of truth
(`Brewfile` + the `dot_*` dotfiles); everything else installs from them.

---

## For an AI agent running this setup

This guide is written to be executed by an agent end-to-end. Follow these rules:

1. **Detect before you act.** Every step below starts with a *Detect* check. If
   the check shows the step is already satisfied, skip it — all steps are
   idempotent and safe to re-run.
2. **Verify after you act.** Every step ends with a *Verify* command. Run it and
   confirm success before moving on.
3. **Never clobber these — they hold user data and are NOT chezmoi-managed:**
   - `~/.zshrc.local` (secrets/tokens)
   - `~/.zshrc.d/*.zsh` (generated work config — e.g. the vps-setup output)
   - `~/.claude/settings.local.json`, `~/.claude/*.local.*`
   Back them up before any operation that could overwrite, and restore after.
4. **Two common starting states** — check which one you're in first:
   - **Fresh machine** → run Layer 0 → 4 in order.
   - **Pre-chezmoi machine** (dotfiles were hand-copied before the chezmoi
     migration) → do [Layer 0b · Migrate from pre-chezmoi](#layer-0b--migrate-from-pre-chezmoi-dotfiles) first, then continue.
5. **Ask the user before** anything destructive (deleting files, overwriting an
   unmanaged `~/.zshrc`, force operations). Prefer backups over deletes.

> **Personal identifiers.** This repo is one person's dotfiles. `gabe-fz` is a
> GitHub username; paths under `~` are that user's home. Substitute the adopting
> user's own values — see [Making it yours](#making-it-yours).

---

## Prerequisites

- macOS on Apple Silicon (built on macOS 15.x / arm64)
- Corporate VPN access (required for the internal Nexus registry)
- GitHub account with SSH access to the RCG org

**Detect:** `sw_vers; uname -m` (expect macOS / arm64).

---

## Layer 0 — Bootstrap (does ~80% of it)

### 0a. Homebrew

**Detect:** `command -v brew`

If absent:
```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
**Verify:** `brew --version`

### 0b. Migrate from pre-chezmoi dotfiles

Do this **only** if the machine already has hand-copied dotfiles that chezmoi
does not manage yet. Skip on a truly fresh machine.

**Detect:**
```sh
command -v chezmoi && chezmoi managed 2>/dev/null | grep -q '.zshrc' \
  && echo "already chezmoi-managed" \
  || { [ -f ~/.zshrc ] && echo "UNMANAGED dotfiles present — migrate"; }
```

If dotfiles are present but unmanaged:

1. **Back up the existing files** (they may contain hand-added lines the repo
   doesn't have — e.g. inline vps config, personal aliases):
   ```sh
   ts=$(date +%Y%m%d%H%M%S)
   mkdir -p ~/dotfiles-premigration-$ts
   for f in ~/.zshrc ~/.tmux.conf ~/.config/ghostty/config \
            ~/.config/zsh ~/.zshrc.local ~/.zshrc.d; do
     [ -e "$f" ] && cp -R "$f" ~/dotfiles-premigration-$ts/ 2>/dev/null
   done
   ```
2. **Init chezmoi without applying**, then review the diff before writing:
   ```sh
   sh -c "$(curl -fsLS get.chezmoi.io)" -- init gabe-fz   # clones, does NOT apply
   chezmoi diff                                            # review every change
   ```
3. **Reconcile:** anything in the backup that the repo would drop and you want to
   keep goes into `~/.zshrc.local` (secrets/machine-local) or stays as a
   `~/.zshrc.d/*.zsh` drop-in — **not** back into the managed `dot_zshrc`.
4. **Apply:** `chezmoi apply` (see 0c for what this does).

**Verify:** `chezmoi managed | grep .zshrc` returns the file, and
`diff <(cat ~/.zshrc) <(chezmoi cat ~/.zshrc)` is empty.

> chezmoi's default source dir is `~/.local/share/chezmoi`. This repo is
> configured to use `~/dotfiles` instead (via `~/.config/chezmoi/chezmoi.toml`);
> a plain adopter will get the default location unless they set `sourceDir`.

### 0c. Fresh install (or finishing the migration)

**Detect:** `chezmoi managed 2>/dev/null | grep -q .zshrc && echo done`

If not done:
```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply gabe-fz
```
`init --apply <github-user>` resolves to `github.com/<github-user>/dotfiles`.
On first apply, `run_onchange_brew-bundle.sh` runs `brew bundle` against the
[`Brewfile`](Brewfile) (installs every tool + app), and renders the dotfiles:

- `dot_zshrc` → `~/.zshrc` — ordered zsh init (env, keymap, completions, modules, prompt)
- `dot_tmux.conf` → `~/.tmux.conf`
- `dot_config/ghostty/config` → `~/.config/ghostty/config`
- `dot_config/zsh/*.zsh` → `~/.config/zsh/*.zsh` — aliases, fzf
- `dot_local/bin/*` → `~/.local/bin/*` — personal scripts

**Verify:** `brew bundle check --file ~/dotfiles/Brewfile` (or the source dir)
reports "dependencies are satisfied"; `ls ~/.zshrc ~/.tmux.conf ~/.config/ghostty/config`.

### 0d. Machine-local config & secrets (NOT in the repo)

These are never managed by chezmoi. Recreate/preserve them by hand:

- `~/.zshrc.local` — machine-local settings and **secrets/tokens**. Sourced by `~/.zshrc`.
- `~/.zshrc.d/*.zsh` — drop-in dir for **generated** work config. `~/.zshrc`
  sources every `*.zsh` here.

**vps-setup:** if the user runs the vps work-config generator (`~/vps/setup` or
similar), it writes into `~/.zshrc.d/`. Do **not** delete that dir. If it's
missing after a migration, re-run the generator to regenerate it.

**Verify:** `echo ${(j: :)${(f)"$(ls ~/.zshrc.d/*.zsh 2>/dev/null)"}}` and
`test -f ~/.zshrc.local && echo "local present"`.

---

## Layer 1 — Terminal: Ghostty + tmux

Installed by the Brewfile (`cask "ghostty"`, `brew "tmux"`). Configs are tuned so
**Claude Code runs cleanly inside tmux**:

- **Ghostty** (`~/.config/ghostty/config`): `Shift+Enter` → `ESC CR`, so Claude
  Code treats it as *newline*, not *submit* — same inside and outside tmux.
- **tmux** (`~/.tmux.conf`): prefix `C-x`, 1-indexed panes/windows, mouse on,
  `|`/`-` splits, `Alt+arrow` navigation. Claude-critical settings:
  - `extended-keys on` + `terminal-features xterm*:extkeys` — carry
    Shift/Ctrl+Enter through instead of flattening to Enter
  - `escape-time 10` — snappy ESC-prefixed input
  - `set-clipboard on` + `allow-passthrough on` — OSC-52 clipboard + Kitty graphics
  - `pbcopy` piping on copy so selections hit the macOS clipboard

**Verify:** `tmux -f ~/.tmux.conf new-session -d -s _t && tmux kill-session -t _t && echo "tmux config OK"`.

---

## Layer 2 — Claude Code

**Detect:** `command -v claude && claude --version`

Install if absent:
```sh
curl -fsSL https://claude.ai/install.sh | bash    # installs to ~/.local/bin/claude
```

Then reproduce `~/.claude/`:

- **`settings.json`** — model `opus`, `effortLevel: medium`, `theme: auto`, the
  GitHub MCP server, the official Slack plugin, a custom statusline, and the
  **metamux lifecycle hooks** (Layer 3).
- **`statusline.sh`** — custom status line (referenced from `settings.json`).

Seed these from the user's backup, then fix absolute paths.

> ⚠️ The hook commands in `settings.json` use **absolute paths** to the metamux
> checkout (`~/repos/tools/metamux/...`). After copying, rewrite those paths to
> the adopting user's actual home/checkout, or the hooks silently no-op.

**Verify:** `claude --version` succeeds and
`jq -e '.hooks.UserPromptSubmit' ~/.claude/settings.json` returns non-null.

---

## Layer 3 — metamux (multi-session centerpiece)

`metamux` manages tmux sessions/windows/panes as named **workspaces** so you can
run many Claude Code sessions in parallel from one place, with a live Textual
sidebar showing each pane's status (working / needs input / idle).

**Detect:** `command -v metamux && metamux ls`

Install from the internal RCG Nexus (requires `uv`, tmux, VPN):
```sh
uv tool install metamux \
  --index https://nexus-registry.apps.dev1-mgmt-ocp.aws-cup-dev.rccl.com/repository/python-repository/simple/ \
  --allow-insecure-host nexus-registry.apps.dev1-mgmt-ocp.aws-cup-dev.rccl.com
```
`--allow-insecure-host` is required (Nexus TLS cert isn't publicly trusted).

**Wire into Claude Code:** the hooks in `~/.claude/settings.json` call metamux's
`plugins/claude/hook.py` on `UserPromptSubmit`, `Notification`, `Stop`,
`SessionStart`/`SessionEnd`, `SubagentStop`, `PreToolUse(Task)`, `PostToolUse`,
and `PermissionDenied`. Confirm those paths point at the real install.

**Daily driver:** open Ghostty → `metamux attach`.

**Verify:** `metamux ls` runs without error.

> To hack on metamux itself, clone the repo and symlink `bin/metamux` onto PATH
> instead of the Nexus install — see the metamux README.

---

## Layer 4 — Internal RCG tooling

- **npm globals** (install from the RCG registry / Nexus — not by `npm link`):
  `@rcg-enterprise/ai-sdlc`, `@rcg-enterprise/brunch`, `bkman`, plus
  `@mermaid-js/mermaid-cli`, `@usebruno/cli`, `zx`.
- **CLI tools** published to Nexus, installed with `uv tool install` (same
  pattern as metamux): e.g. `leap`, `aws-switch`, `scrolldown`, `selectstar`,
  `harlequin-jt400`.
- **Claude skills & team packs** — the skills under `~/.claude/skills/` (APF
  r1/r2, VPS, pack skills) come from the team **pack** mechanism (cartographer /
  ai-sdlc foundation), not hand-copied. Install the packs and the skills follow.

**Verify:** `npm ls -g --depth=0`, `uv tool list`, `ls ~/.claude/skills | head`.

---

## Making it yours

Adopting this rather than owning it? Change these before `chezmoi apply`:

| Thing | Where | Change to |
|-------|-------|-----------|
| GitHub user in bootstrap | `chezmoi init --apply gabe-fz` | your username (after forking to `github.com/<you>/dotfiles`) |
| dotfiles git remote | `git remote -v` in the source dir | your fork's URL |
| Absolute paths in `~/.claude/settings.json` hooks | metamux hook commands | your `$HOME` / metamux checkout path |
| npm globals linked to a local checkout | `npm ls -g` | install the published package instead of `npm link` |
| Secrets | `~/.zshrc.local` | your own tokens |

The Nexus URL and RCG registry are org-wide — identical for any RCG engineer on
the network.

---

## Day-2 usage (editing this config)

This repo *is* the chezmoi source dir; `dot_*` names map to `~/.*` targets.

```sh
chezmoi diff              # preview changes to $HOME
chezmoi apply             # write them
chezmoi edit ~/.zshrc     # edit a managed file's source
chezmoi re-add            # pull direct $HOME edits back into the source
chezmoi cd                # jump into the source dir
```

Editing the `Brewfile` and running `chezmoi apply` re-runs `brew bundle`
automatically (keyed on the Brewfile's hash).
