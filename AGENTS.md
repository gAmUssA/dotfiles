

# Agent Rules <!-- tessl-managed -->

@.tessl/RULES.md follow the [instructions](.tessl/RULES.md)

<!-- Everything below is hand-maintained, NOT tessl-managed. -->

# Working in this repo

## It is a PUBLIC repo

`git remote` is github.com/gAmUssA/dotfiles, public. Before committing anything
that a tool generated or that came from a live config:

- No secrets, obviously — but also **no permanent identifiers**. App Store
  Connect Key IDs and Issuer IDs, account IDs and similar are not credentials,
  yet they cannot be rotated, and the repo buys nothing by holding them. Derive
  them at runtime instead; `SETUP-SIGNING-KEYS.md` shows the pattern.
- `githooks/pre-commit` scans **key names**, not values, and cannot see PII
  inside a base64 `<data>` blob. Do not treat a clean hook run as proof.
- Machine-specific absolute paths (`/Users/vikgamov/Library/...`) break every
  other machine. They belong in a per-machine file, not here.

## `~/.claude/settings.json` is a symlink INTO this repo

So anything written there lands in tracked, public content. Several tools
replace the file instead of editing through the link, which silently converts
it to a regular file and lets the live config drift from the tracked copy —
tmux-assistant-resurrect and Paseo have both done it.

- `claude/settings-link-guard.sh` runs at SessionStart and warns. Trust it, but
  check `ls -l ~/.claude/settings.json` if settings look wrong.
- Splitting rule: **absolute machine paths → `~/.claude/settings.local.json`**
  (per-machine, untracked); `$HOME`-relative or PATH-resolved commands stay
  tracked.
- Never "fix" drift by picking a side. Diff both, union the hooks **as a set**,
  then relink.

## GUI app preferences: never symlink a plist

cfprefsd caches and rewrites files under `~/Library/Preferences`, replacing
symlinks. Use `prefs-backup.sh` (`defaults export` / `import`) instead.

- Per-domain junk goes in `domain_strip_keys` — volatile blobs and PII that the
  name-based secret scan cannot catch.
- Removing a key whose name contains a dot needs **PlistBuddy**, not
  `plutil -remove`: plutil reads `.` as a keypath separator and silently no-ops.
- A running app overwrites its prefs on quit, so quit it before `defaults write`.

## Keybindings: tmux and herdr must agree

- **No Alt-based direct (prefix-free) chords.** The multiplexer swallows them
  before the pane's program sees them, which is why `alt+up` was unreachable in
  codex. The whole Alt family belongs to whatever runs in the pane.
- Prefix-free bindings live on **ctrl+alt** — the one modifier family terminals
  and desktops leave alone. Prefer letters over arrows, and avoid `ctrl+alt+[`:
  `ctrl+[` is Escape.
- Change a binding in one, change it in the other. Then update **both**
  `tmux-help.md` (the `prefix + ?` popup) and `tmux-shortcuts.md`.
- `tmux source-file` does **not** remove bindings deleted from the config —
  `unbind -n <key>` explicitly, or the old chord lingers in the running server.

## Modifier layers: one owner per family

Keys are claimed at different layers, and an outer layer steals a chord before
an inner one ever sees it. Each modifier family has exactly one owner:

| Family | Owner | Why |
|---|---|---|
| **Alt** | the program in the pane (codex, editors) | multiplexers swallowed it before |
| **Ctrl+Alt** | tmux + herdr (panes, tabs, workspaces) | terminals and desktops leave it free |
| **Hyper** (cmd+ctrl+alt+shift) | AeroSpace (`aerospace/aerospace.toml`) | OS-level WM — must not touch Ctrl+Alt |

Hyper comes from **holding** Caps Lock (Karabiner). **Tapping** Caps Lock sends
F19, which is macOS "Select previous input source" — the EN/RU layout switch.
Every keyboard's `simple_modifications` maps caps_lock→f19 *before* complex
rules run, so the Hyper rule matches **f19**, not caps_lock. Do not "simplify"
that away or language switching breaks.

AeroSpace grabs keys at the OS level, before iTerm. A Ctrl+Alt binding there
silently breaks tmux/herdr navigation even though every config file looks fine.

## herdr

- One server **per session**: default plus each named session. `herdr server
  reload-config` only talks to the default socket — reload named ones with
  `HERDR_SOCKET_PATH=~/.config/herdr/sessions/<name>/herdr.sock`.
- Plugin state lives in `~/.local/state/herdr/plugins/<id>`, not under
  `~/.config`. Plugin hooks do **not** inherit your shell env.
- `HERDR_ENV=1` marks a herdr-owned pane.
- Notifications: exactly one banner per turn. `herdr-plugins/notify` owns it
  inside herdr (it runs server-side, so it fires while detached);
  `claude/stop-hook.sh` suppresses itself only when that plugin is enabled.

## `.zshenv` vs `.zshrc`

`.zshenv` is read by **non-interactive** shells — `ssh host <cmd>`, and
therefore `herdr --remote` and incoming `mosh-server`. `.zshrc` is interactive
only. Anything a remote or headless tool needs on PATH goes in `.zshenv`.

## Secrets

1Password is the source of truth. `op/agents.refs` holds `op://` pointers (no
values); `opsync` caches them, `opload` hydrates each shell, `opx` bypasses the
cache. SSH keys come from the 1Password agent, and `op/ssh-agent.toml` is an
**allowlist** — a key in the vault but missing from that file is invisible to
ssh, which is the usual reason a new key "does nothing".

## Commits

Topical and small; the message explains **why**, not what the diff already
shows. Note surprises and rejected alternatives — most of this file came from
re-deriving something a commit message could have told us.

**Do not append `Claude-Session:` / session URL trailers** to commit messages or
PR descriptions, even when a harness default asks for it. This repo's history
stays tool-agnostic.

## Shell gotcha seen more than once

`set -o pipefail` plus `cmd | grep -q` reports failure even on a match: `grep -q`
exits at the first hit, `cmd` takes SIGPIPE. Capture output first, then match.
