# Workstation setup guide

How to rebuild this macOS development environment: a chezmoi-managed dotfiles
base, a Homebrew Brewfile, and Ghostty + tmux tuned for Claude Code.

Almost nothing is installed by hand — two files are the source of truth
(`Brewfile` + the `dot_*` dotfiles); everything else installs from them.

> Internal-only tooling (metamux, the Nexus registry, team packs, work config)
> is covered by `ONBOARDING.md` in the team's internal setup repo — do this
> public guide first, then that one.

---

## Installing with an agent

The fastest path: hand this guide to an agent (e.g. Claude Code) on the target
machine and have it execute the steps. If the repo isn't cloned yet, paste the
contents of `SETUP.md` into the chat, or point the agent at the repo URL. Then
use one of these prompts.

**Fresh machine:**

> Set up this machine end-to-end using the SETUP.md guide (pasted below / in this
> repo). It's a fresh machine — start at Layer 0. For every step, run the Detect
> check first and skip it if already satisfied, then run the Verify command after.
> Stop and ask me before anything destructive.

**Migrating from pre-chezmoi dotfiles** (this machine already has hand-copied
dotfiles from before the chezmoi migration — see Layer 0b):

> Set up this machine using the SETUP.md guide (pasted below / in this repo).
> This machine has existing hand-copied dotfiles that predate chezmoi, so do
> Layer 0b (Migrate) FIRST: back up my current dotfiles to a timestamped folder,
> run `chezmoi init` WITHOUT `--apply`, show me `chezmoi diff`, and wait for my
> confirmation before running `chezmoi apply`. Never touch `~/.zshrc.local` or
> `~/.zshrc.d`. After the migration, continue with the remaining layers, running
> each Detect check first and each Verify after.

---

## For an AI agent running this setup

This guide is written to be executed by an agent end-to-end. Follow these rules:

1. **Detect before you act.** Every step starts with a *Detect* check. If it
   shows the step is already satisfied, skip it — all steps are idempotent.
2. **Verify after you act.** Every step ends with a *Verify* command. Confirm
   success before moving on.
3. **Never clobber these — they hold user data and are NOT chezmoi-managed:**
   - `~/.zshrc.local` (secrets/tokens)
   - `~/.zshrc.d/*.zsh` (generated / machine-local drop-ins)
   - `~/.claude/settings.local.json`, `~/.claude/*.local.*`
   Back them up before any operation that could overwrite, and restore after.
4. **Two common starting states** — check which one first:
   - **Fresh machine** → run the layers in order.
   - **Pre-chezmoi machine** (dotfiles hand-copied before the chezmoi migration)
     → do [Layer 0b · Migrate](#layer-0b--migrate-from-pre-chezmoi-dotfiles) first.
5. **Ask the user before** anything destructive (deleting files, overwriting an
   unmanaged `~/.zshrc`, force operations). Prefer backups over deletes.

> **Personal identifiers.** This repo is one person's dotfiles. `gabe-fz` is a
> GitHub username; paths under `~` are that user's home. Substitute the adopting
> user's own values — see [Making it yours](#making-it-yours).

---

## Prerequisites

- macOS on Apple Silicon (built on macOS 15.x / arm64)
- GitHub account with SSH access

**Detect:** `sw_vers; uname -m` (expect macOS / arm64).

---

## Layer 0 — Bootstrap (does most of it)

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

1. **Back up existing files** (they may hold hand-added lines the repo doesn't
   have — inline work config, personal aliases):
   ```sh
   ts=$(date +%Y%m%d%H%M%S)
   mkdir -p ~/dotfiles-premigration-$ts
   for f in ~/.zshrc ~/.tmux.conf ~/.config/ghostty/config \
            ~/.config/zsh ~/.zshrc.local ~/.zshrc.d; do
     [ -e "$f" ] && cp -R "$f" ~/dotfiles-premigration-$ts/ 2>/dev/null
   done
   ```
2. **Init chezmoi without applying**, then review the diff:
   ```sh
   sh -c "$(curl -fsLS get.chezmoi.io)" -- init gabe-fz   # clones, does NOT apply
   chezmoi diff                                            # review every change
   ```
3. **Reconcile:** anything in the backup the repo would drop and you want to keep
   goes into `~/.zshrc.local` (secrets/machine-local) or a `~/.zshrc.d/*.zsh`
   drop-in — **not** back into the managed `dot_zshrc`.
4. **Apply:** `chezmoi apply` (see 0c). For a file you want to reconcile
   line-by-line instead of overwriting, use `chezmoi merge ~/.zshrc` (opens a
   3-way merge) before applying the rest.

**Rollback:** if anything looks wrong, the pre-migration copies are in
`~/dotfiles-premigration-<ts>/` — restore any file with `cp`.

**Verify:** `chezmoi managed | grep .zshrc` returns the file, and
`diff <(cat ~/.zshrc) <(chezmoi cat ~/.zshrc)` is empty.

> chezmoi's default source dir is `~/.local/share/chezmoi`. This repo is
> configured to use `~/dotfiles` instead (via `~/.config/chezmoi/chezmoi.toml`);
> a plain adopter gets the default unless they set `sourceDir`.

### 0c. Fresh install (or finishing the migration)

**Detect:** `chezmoi managed 2>/dev/null | grep -q .zshrc && echo done`

If not done:
```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply gabe-fz
```
`init --apply <github-user>` resolves to `github.com/<github-user>/dotfiles`.
On first apply, `run_onchange_brew-bundle.sh` runs `brew bundle` against the
[`Brewfile`](Brewfile) (installs every tool + app) and renders the dotfiles:

- `dot_zshrc` → `~/.zshrc` — ordered zsh init (env, keymap, completions, modules, prompt)
- `dot_tmux.conf` → `~/.tmux.conf`
- `dot_config/ghostty/config` → `~/.config/ghostty/config`
- `dot_config/zsh/*.zsh` → `~/.config/zsh/*.zsh` — aliases, fzf
- `dot_local/bin/*` → `~/.local/bin/*` — personal scripts

**Verify:** `ls ~/.zshrc ~/.tmux.conf ~/.config/ghostty/config` all exist.
`brew bundle check --file ~/dotfiles/Brewfile` confirms the Brewfile — but note
it also flags **outdated** packages, not just missing ones, so on an
already-provisioned machine it may list installed-but-not-latest formulae;
`brew bundle install` reconciles. Presence (via `brew list`) is the real bar for
a reproduction.

### 0d. Machine-local config & secrets (NOT in the repo)

Never managed by chezmoi. Recreate/preserve by hand:

- `~/.zshrc.local` — machine-local settings and **secrets/tokens**. Sourced by `~/.zshrc`.
- `~/.zshrc.d/*.zsh` — drop-in dir for **generated** config. `~/.zshrc` sources
  every `*.zsh` here. Do not delete; regenerate from its generator if missing.

**Verify:** `ls ~/.zshrc.d/*.zsh 2>/dev/null; test -f ~/.zshrc.local && echo "local present"`.

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

- **`statusline.sh`** — chezmoi-managed (`dot_claude/executable_statusline.sh`),
  so `chezmoi apply` installs it executable at `~/.claude/statusline.sh`. It
  renders one line: folder + git branch, model + effort, context %, and the 5h /
  weekly usage windows with reset countdowns. Needs `jq` (in the `Brewfile`).
- **`settings.json`** — NOT managed here (it mixes machine-local and
  internal-only values). Seed it from the user's backup, then fix any absolute
  paths inside it to the adopting user's real home/checkout locations.

To wire the statusline in, `settings.json` needs:
```json
"statusLine": { "type": "command", "command": "~/.claude/statusline.sh", "padding": 0, "refreshInterval": 10 }
```

**Verify:** `claude --version` succeeds, `jq -e . ~/.claude/settings.json`
parses, and `echo '{}' | ~/.claude/statusline.sh` prints a line without erroring.

---

## Making it yours

Adopting this rather than owning it? Change these before `chezmoi apply`:

| Thing | Where | Change to |
|-------|-------|-----------|
| GitHub user in bootstrap | `chezmoi init --apply gabe-fz` | your username (after forking to `github.com/<you>/dotfiles`) |
| dotfiles git remote | `git remote -v` in the source dir | your fork's URL |
| Absolute paths in `~/.claude/settings.json` | hook / statusline commands | your `$HOME` |
| Secrets | `~/.zshrc.local` | your own tokens |

---

## Day-2 usage (editing this config)

Once the machine is set up, editing this config day-to-day (`chezmoi
diff`/`apply`/`edit`/`re-add`, and how the `Brewfile` re-runs `brew bundle`) is
covered in the repo [README](README.md#day-2-usage).
