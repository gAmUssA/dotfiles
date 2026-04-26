# dotfiles

These are the configs I run on my Mac every day: zsh, tmux, iTerm2, Ghostty, and an opinionated Claude Code setup. macOS only.

## What's in here

- `.zshrc` + `zsh_custom/` — zinit plugin manager, lazy-loaded SDKMAN/NVM, a single authoritative `compinit`, and the p10k prompt.
- `.tmux.conf` — `Ctrl-Space` prefix, visual bell wired to Claude Code's Stop hook, and `prefix + y` to pop up a per-directory Claude session.
- `claude/` — `settings.json`, a custom status line, and the Stop-hook shell script that fires a macOS banner when a turn finishes.
- `hammerspoon/` — Lua menu-bar modules: caffeine toggle (☕/💤), Ollama loaded-model status (🦙), and a Claude-session router (🤖) that lists every running `claude` process and click-jumps to its terminal tab + tmux pane (handles the `thefuck` pty wrapper via ppid-walk; uses iTerm2 AppleScript for tab focus and `tmux switch-client`/`select-window`/`select-pane` for the pane). Init writes a debug trace to `/tmp/hammerspoon.log`.
- `ghostty/config` — Dracula-ish palette, IosevkaTerm Nerd Font with ligatures on.
- `cmux/settings.json` — tmux-style keybindings for [manaflow-ai/cmux](https://github.com/manaflow-ai/cmux).
- `iterm2-icons/` — custom `.icns` files from [jasonlong/iterm2-icons](https://github.com/jasonlong/iterm2-icons) plus extracted PNGs that the Stop-hook banner uses.
- `fix-iterm-ligatures.sh` — rewrites iTerm2 profiles from ligature-stripping Nerd Font "Complete" builds to v3+ `IosevkaTermNF`.
- `claude-dev.sh` — project-scoped tmux launcher: one window for `claude`, one shell, one for tests when a test runner is detected.
- `tmux-paste-image.sh` — clipboard image to `/image <path>` helper.
  Not currently bound (Claude Code handles clipboard paste natively), but kept in case that changes.
- `Brewfile` — everything above, plus my usual CLI kit.
- `install-completions.sh` — background job that keeps `~/.zfunc` fresh for kubectl, terraform, gh, and friends.

## Install

```bash
git clone https://github.com/gAmUssA/dotfiles ~/projects/dotfiles
cd ~/projects/dotfiles
brew bundle
./linkall.sh
```

`linkall.sh` removes the target symlinks first, then re-creates them.
If you already have config at any of those paths, back it up before running — it will not ask.

Claude Code settings live at `claude/settings.json`, symlinked to `~/.claude/settings.json`.
The per-machine file `~/.claude/settings.local.json` stays local and is gitignored.

## The Claude Code bits

I wrote a long blog post on why and how this is wired up, including every macOS 26 notification rabbit hole I fell into on the way.
If you want the full story with screenshots, grab the `.adoc` from my writing repo.

Short version of what lives in `claude/`:

**`statusline.sh`** — one line at the bottom of the Claude TUI showing model, project dir, git branch with a dirty marker, context window percentage (color-coded green/yellow/red), lines added/removed, and turn time.

**`stop-hook.sh`** — runs on every `Stop` event.
Two signals fire:

1. A terminal BEL written straight to `/dev/tty` so tmux's `visual-bell` flashes the status bar.
2. A macOS banner via `alerter`, with the iTerm icon on the left and the Claude icon on the right.

Two things worth knowing if you're copying this hook onto macOS 26 (Tahoe):

1. **`terminal-notifier` is dead on Tahoe.** It uses the deprecated `NSUserNotification` API and errors with "Unable to post a notification."
   Install `alerter` instead (`brew install alerter`).
   It's a Swift rewrite on `UNUserNotificationCenter` and works inside and outside tmux.
2. **Do not pass `--sender`.** macOS validates the bundle identity of the sender process, and any bundle that isn't `com.apple.Terminal` silently hangs.
   I tested both `com.googlecode.iterm2` and `com.mitchellh.ghostty`; both hang.
   Drop the flag and customize the banner's appearance with `--app-icon` instead.

## The tmux bits

- `prefix + y` opens a floating popup tied to the current directory.
  Session name is `claude-<md5-of-cwd>`, so the same directory always reattaches to the same Claude session.
- `automatic-rename-format` injects a small robot glyph at the start of the window name when the pane is running Claude.
  The match is `[0-9]*.[0-9]*` against `pane_current_command`, which is how Claude's version string shows up in the process title.
- `extended-keys always` plus `terminal-features 'xterm*:extkeys'` makes Shift+Enter work inside tmux, so Claude's "newline in prompt" behavior survives the multiplexer.

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
- **Dropbox-based Mackup.** Switched to iCloud.
  Mackup has not seen a real release in a while, but it still moves app prefs around fine.
- **Terminal.app.** iTerm2 is my daily driver.
  I installed Ghostty out of curiosity, then kept it around because having a second terminal on hand made it easier to diagnose ligature rendering without reinstalling fonts or restarting iTerm2.

## License

MIT where applicable.
The `iterm2-icons/` `.icns` files are from [jasonlong/iterm2-icons](https://github.com/jasonlong/iterm2-icons) (MIT).
The Claude icon PNG is extracted from the stock Claude.app bundle.
