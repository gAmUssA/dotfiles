# dotfiles

Configs for the Macs I actually use (DS9, Daystrom, and the laptop). macOS only.
This repo is public. A new machine is rebuilt from here, not copied with
Migration Assistant — the runbook is [SETUP-NEW-MACHINE.md](SETUP-NEW-MACHINE.md).
Rules an agent has to follow while working in here are in [AGENTS.md](AGENTS.md).

Three mechanisms, because three different things store state:

| What | How |
|---|---|
| Text configs (zsh, tmux, herdr, Ghostty, Claude, AeroSpace, Karabiner, …) | symlinks from `linkall.sh` |
| GUI app plists (Bartender, PopClip, iStat, iTerm2, …) | `prefs-backup.sh` / `prefs-restore.sh` |
| macOS itself (Dock, Finder, keyboard, trackpad, …) | `macos-defaults.sh` |

`cfprefsd` rewrites files under `~/Library/Preferences` and replaces symlinks,
which is why the old Mackup setup died. App prefs are snapshots. Mackup is
not part of this machine anymore.

## Install

A fresh machine:

```bash
git clone https://github.com/gAmUssA/dotfiles ~/projects/dotfiles
cd ~/projects/dotfiles
brew bundle
./linkall.sh
```

That is the sketch. The runbook says which steps an agent may run and which
need a person at the keyboard (`sudo`, 1Password, TCC grants, `gh auth`,
Tailscale, accepting a host key). Skipping those leaves a machine that looks
finished while every keybinding is dead.

On a machine that is **already** in use, run `./reconcile-check.sh` first and
resolve what it reports. `linkall.sh` `rm -f`s every path it is about to
relink, then creates the symlink. A config that drifted from a symlink into a
regular file is deleted with no backup and no prompt. Union the two copies.

### Claude Code settings

`claude/settings.json` is symlinked to `~/.claude/settings.json`, so a write
there lands in this public repo. `claude/settings-link-guard.sh` warns at
SessionStart when a tool has replaced the symlink with a regular file.

There is no per-machine, all-projects settings file. Claude Code reads
`settings.local.json` only from a project's `.claude/`, so
`~/.claude/settings.local.json` applies only when `claude` is run in `$HOME`.
A hook moved there silently stops firing everywhere else. Put the command in
the tracked file, portable: `$HOME`-relative, on `PATH`, or a Homebrew opt
path (`/opt/homebrew/opt/<formula>/bin/...`). The only global per-machine
scope is managed settings (`/Library/Application Support/ClaudeCode/`), and
that needs `sudo`.

## What's in here

Daily shell and terminal:

- `.zshrc` + `zsh_custom/` — zinit, lazy-loaded SDKMAN/NVM, one `compinit`, p10k. Non-interactive tools (`ssh host <cmd>`, `herdr --remote`, `mosh-server`) read `.zshenv` only; anything they need on `PATH` goes there.
- `.tmux.conf` — `Ctrl-Space` prefix. `prefix + y` pops a per-directory Claude session named `claude-<md5-of-cwd>`. Windows auto-name to the directory basename; the robot glyph comes from tmux-agentbar, not from `automatic-rename-format`.
- `ghostty/config` — Dracula-ish palette, IosevkaTerm Nerd Font with ligatures on. Linked into Ghostty's macOS Application Support path, which wins over the XDG one.
- `cmux/settings.json` — tmux-style keybindings for [manaflow-ai/cmux](https://github.com/manaflow-ai/cmux).
- `iterm2-icons/` — `.icns` files from [jasonlong/iterm2-icons](https://github.com/jasonlong/iterm2-icons) plus the PNGs the Stop-hook banner uses.
- `claude-dev.sh` — project-scoped tmux launcher: one window for `claude`, one shell, one for tests when a test runner is detected.
- `Brewfile` — the package set `brew bundle` installs. It adds; it does not uninstall.
- `install-completions.sh` — keeps `~/.zfunc` fresh for kubectl, terraform, gh, and friends.

Window management and keys. One owner per modifier family; the table and the
Karabiner traps are in `AGENTS.md`.

- `aerospace/` — float-by-default workspaces. Leader is `f18`, which Karabiner emits on a *tap* of right Command (hold stays Control). Tiling is opt-in per window.
- `karabiner/` — the complex modification that produces that tap, plus the simple mods (`caps_lock` → `f19` for the EN/RU switch, `right_control` → `right_option`).
- `hammerspoon/` — agents menu (every coding agent in herdr or tmux, click to jump), the AeroSpace mode HUD, the window finder, and the Keynote pause below. Keep-awake is Vorssaint's job.
- `sketchybar/` — workspace pill. Hammerspoon reveals it.
- `keyboard-layouts/` + `keyboard-layouts.sh` — the customized Birman EN/RU layouts, with backup, compare, and restore.
- `herdr/config.toml` — terminal workspace manager for agents. Desktop banners inside herdr come from `gAmUssA/herdr-notify`, which `linkall.sh` installs by id. The plugin is not in this repo.

Agents:

- `claude/` — shared status line, Stop hook, secret-blocking PreToolUse hook, and the settings-link guard.
- `junie/` — opt-in Junie lifecycle status in Rex; see [how to enable and verify it](junie/README.md).
- `agents/statusline-install.sh` — points grok, agy, copilot, pi, and opencode at that same status line. Their own configs stay per-machine.
- `op/` — `op://` pointers (`agents.refs`) and the 1Password SSH agent allowlist (`ssh-agent.toml`). No secret values.
- `opencode/`, `pi/`, `copilot/` — the config files safe to share. Generated hook files with absolute paths are not linked; `linkall.sh` re-runs the installers.

Other:

- `clean_projects.sh` — preview or interactively remove project artifacts with Kondo. Also linked at `~/projects/clean_projects.sh` when that path is free.
- `cloud-tabs-to-notes.sh` — snapshot Safari iCloud tabs from a given device into Notes, or `--open` them. Reads `~/Library/Safari/CloudTabs.db` directly.
- `tmux-paste-image.sh` — clipboard image to `/image <path>`. Not bound; Claude Code pastes images itself.
- `ollama-restore.sh` and the `ollama-*-bench.sh` / `agent-bench/` tree — local-model restore and the eval harness. `bench-out/` is gitignored.
- `capture4k.sh`, `obs4k.sh` — capture helpers for this desk, not part of machine setup.

## Keynote presentations

Hammerspoon pauses AeroSpace automatically while Keynote is running and
restores it when Keynote quits. See [behavior and validation](hammerspoon/README.md)
for manual-pause handling and the platform-bound GUI testing procedure.

### App preferences (Bartender, iStat Menus, PopClip, Marked, TaskPaper, Cyberduck, iTerm2)

```bash
./prefs-backup.sh    # after changing settings worth keeping; review diff, commit
./prefs-restore.sh   # on a new machine, after the apps are installed; restart apps
```

Snapshots live in `prefs/` as XML plists. The backup script scans every export
for license/serial/credential key names and refuses to write ones that match.
That scan reads key *names* only, so domains that bury PII in a `<data>` blob
also get a per-domain drop list — see `domain_strip_keys` in `prefs-backup.sh`,
which is what keeps OpenUsage's account email and its ~40 KB of churning usage
snapshots out of the repo. `githooks/pre-commit` is a different check: it
scans staged file content for secret shapes and for live values in the opsync
keychain cache. A clean run of one says nothing about the other.

The modified Birman English/Russian keyboard bundle lives in
[`keyboard-layouts/`](keyboard-layouts/README.md). `prefs-backup.sh` snapshots
it with the portable input-source preferences; `prefs-restore.sh` installs the
matching bundle before importing those preferences. For just the keyboard:

```bash
./keyboard-layouts.sh backup           # capture installed custom mappings
./keyboard-layouts.sh check            # compare installed and tracked bundles
./keyboard-layouts.sh restore --dry-run
./keyboard-layouts.sh restore          # another Mac, after pulling the repo
```

Log out and back in after installation, then verify both input sources and
typing. Fresh installs use the user Library; updating an existing system-wide
installation may require the human-run sudo command documented in the runbook.

iTerm2 is snapshotted the same way rather than through its own "load
preferences from a custom folder" option — that writes on every quit with no
review step, and this repo is public.

PopClip needs two things, not one. Its settings live in `com.pilotmoon.popclip`
(98 keys); the `-setapp` domain holds only the menu-bar position. Its
extensions are `.popclipext` bundles on disk, not plist entries, so they are
rsynced to `popclip/Extensions/` and restored alongside the domain — without
them you get settings pointing at extensions that aren't installed.

### macOS system settings

Dock, Finder, keyboard, hot corners, trackpad, screenshots. These are
`defaults write`s, not symlinks and not plist snapshots.

```bash
./macos-defaults.sh --dry-run   # show current vs intended, change nothing
./macos-defaults.sh             # apply, then restart Dock/Finder/SystemUIServer
```

56 settings across 10 domains, all read off this machine rather than copied
from a generic "awesome macOS defaults" list — if it's not customised here,
it's not in there. Idempotent. Tap-to-click and key-repeat rates need a logout
to take effect.

### Ollama models

`./ollama-restore.sh` pulls the registry models and recreates the local
`-ctx64k` variants used by the OpenCode/Pi agent setup.

### Project cleanup

Install [Kondo](https://github.com/tbillington/kondo) 0.9 or newer with
`brew install kondo` (also declared in the Brewfile). Homebrew upgrades renew
the dependency alongside the other CLI tools.

```bash
~/projects/clean_projects.sh                     # preview ~/projects
~/projects/clean_projects.sh --older 3M          # preview older projects
~/projects/clean_projects.sh --apply             # choose projects interactively
~/projects/clean_projects.sh --exclude ~/projects/keep-this-project
~/projects/clean_projects.sh ~/projects/demo ~/projects/demo/app
```

The tracked script is `clean_projects.sh` in this repo; the old location is a
symlink. `linkall.sh` creates that link when absent and leaves existing files
or different links for reconciliation. The default root is always
`~/projects`, even when called from another directory. Relative paths resolve
from the calling directory. `--apply` requires terminal input and retains
Kondo's project-by-project prompts. There is no unattended delete-all mode.

Kondo identifies projects by their manifests and deletes their known artifact
directories: for example, Node's `node_modules`, Maven's `target`, and Gradle's
`build` and `.gradle`. It does not check whether artifacts are tracked in Git.
Preview first and use `--exclude` for projects that retain those files;
exclusions protect entire projects, not individual artifacts. The wrapper does
not enable symlink traversal and restricts scanning to the root filesystem.

Kondo 0.9 stops descending after recognizing a project. Pass nested Gradle
modules as additional paths, as in the last example, to include their build
outputs. Its deletion diagnostics are forwarded and cause this wrapper to
fail, even when Kondo itself returns success. Sizes in Kondo's summary are
estimates of file content, not a measurement of reclaimed disk blocks.

Shared caches (`~/.gradle`, `~/.npm`, `~/.cache/uv`) are not scanned by default.
Maintain those separately with Gradle's retention settings, `npm cache verify`,
`npm cache npx ls` / `npm cache npx rm <key>`, and `uv cache prune`.

Run the cleanup checks with `bash scripts/run-tests.sh`. The real Kondo
integration checks use temporary fixtures and require Kondo on PATH.

## The agent bits

`claude/statusline.sh` is one status line for Claude Code, grok, agy, copilot,
pi, and opencode. A segment is dropped when its field is absent, so a CLI that
sends less than Claude does not render zeros. What it shows, when the payload
has it: model, directory, git branch with a dirty marker, agent and worktree
badges, context-window percentage (green/yellow/red), lines added/removed,
session duration, plan limits (Claude's `rate_limits`, or agy's tightest
`quota` bucket) with a burn-rate warning, dollar cost only when there is no
plan limit, and Copilot premium requests. Claude's prompt cache gets a second
line. Tests pin the clock with `STATUSLINE_NOW`.

`claude/stop-hook.sh` runs on every Claude Code `Stop` event and raises one
macOS banner via `alerter` (iTerm icon on the left, Claude icon on the right).
It does not write a terminal BEL. tmux-agentbar does that, once per window,
when the aggregate status becomes `waiting` or `done`, and tmux marks that
tab with `window-status-bell-style` (`visual-bell` is off, so the whole bar
does not flash). Inside herdr the hook stays quiet while `gamussa.notify` is
enabled, because that plugin already raises the banner for every agent.

Two things worth knowing if you're copying the banner onto macOS 26 (Tahoe):

1. **`terminal-notifier` is dead on Tahoe.** It uses the deprecated `NSUserNotification` API and errors with "Unable to post a notification."
   Install `alerter` instead (`brew install alerter`).
   It's a Swift rewrite on `UNUserNotificationCenter` and works inside and outside tmux.
2. **Do not pass `--sender`.** macOS validates the bundle identity of the sender process, and any bundle that isn't `com.apple.Terminal` silently hangs.
   I tested both `com.googlecode.iterm2` and `com.mitchellh.ghostty`; both hang.
   Drop the flag and customize the banner's appearance with `--app-icon` instead.

I wrote a long blog post on the notification rabbit holes, with screenshots.
The `.adoc` is in my writing repo.

## The tmux bits

- `prefix + y` opens a floating popup tied to the current directory.
  Session name is `claude-<md5-of-cwd>`, so the same directory always reattaches to the same Claude session.
- Window names stay the directory basename. The robot glyph on a window that is running an agent is drawn by tmux-agentbar's window-status script, which walks the process tree (claude, copilot, aider, codex, gemini, and others).
- `extended-keys always` plus `terminal-features 'xterm*:extkeys'` makes Shift+Enter work inside tmux, so Claude's "newline in prompt" behavior survives the multiplexer.
- Prefix-free pane and workspace chords are Ctrl+Alt, shared with herdr. Alt belongs to the program in the pane. Change a binding in one, change it in the other, then update `tmux-help.md` and `tmux-shortcuts.md`.

## The ligature trap

If ligatures in iTerm2 are not rendering (`->`, `=>`, `!=` stay as separate characters), the font is almost certainly a pre-v3 Nerd Font "Complete" build.
Those strip ligatures as part of the patching process.
Install `font-iosevka-term-nerd-font` (v3+), quit iTerm2 completely, then run `./fix-iterm-ligatures.sh`.
The script rewrites profile fonts in the plist and flips the ligature toggles.

One footgun: the Regular weight of IosevkaTermNF has no `-Regular` suffix in its PostScript name.
It is just `IosevkaTermNF`.
Other weights ship with suffixes — `IosevkaTermNF-Light`, `IosevkaTermNF-ExtraLight` — so Regular is the exception, and if you hard-code `IosevkaTermNF-Regular` anywhere, the profile silently falls back to Menlo.

## Aliases worth stealing

```zsh
alias yolo='claude --dangerously-skip-permissions'
alias cdev='~/projects/dotfiles/claude-dev.sh'
alias reload!='exec zsh'     # beats `. ~/.zshrc` because it avoids re-registering precmd hooks
alias top='htop'             # htop on macOS does not need sudo
```

## What I do not use

- **oh-my-zsh as a framework.** Migrated to zinit for load time.
  A couple of OMZ snippets (`git`, `docker-compose`, `brew`) still come in lazily via `zinit snippet OMZP::*`.
- **Mackup.** cfprefsd on Sonoma and later replaces symlinked plists, so the snapshot scripts above own app prefs. `linkall.sh` does not install or delete `~/.mackup.cfg`.
- **`~/.claude/settings.local.json` as a global config.** See the Claude Code settings section.
- **Terminal.app.** iTerm2 is the daily driver. Ghostty stays installed because a second terminal made the ligature problem diagnosable without restarting iTerm2.
- **Migration Assistant.** A clean install plus the runbook reproduces the environment without the accumulated cruft.

## License

MIT where applicable.
The `iterm2-icons/` `.icns` files are from [jasonlong/iterm2-icons](https://github.com/jasonlong/iterm2-icons) (MIT).
The Claude icon PNG is extracted from the stock Claude.app bundle.
