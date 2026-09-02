# Setting up a new Mac (DS9 & friends)

Step-by-step to bring a fresh macOS machine up to this environment from the
dotfiles repo. Written for **DS9** (the home-office Mac mini, always-on herdr
host), but works for any new Mac.

The repo's model, so the steps make sense:

- **`linkall.sh`** — symlinks every config file from the repo into `$HOME`
  (`.zshrc`, `.gitconfig`, `.ssh/config`, ghostty, cmux, **herdr**, sesh,
  Claude Code settings, …).
- **`Brewfile`** — every package/app, installed by `brew bundle`.
- **`prefs-restore.sh`** — GUI app preferences (Moom, PopClip, iStat, …).
- **`macos-defaults.sh`** — 55 system settings (Dock, Finder, keyboard, …).
- **Git submodules** — zsh plugins (kafka-zsh-completions).
- Deliberately **NOT in git**: kube/docker credentials, TextExpander serial,
  Claude Code's `settings.local.json`. Those are per-machine on purpose.

---

## 0. Prerequisites (do these first, they gate everything)

```bash
# Xcode command line tools — provides git
xcode-select --install

# Homebrew (Apple Silicon path assumed: /opt/homebrew)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
```

Sign in to GitHub so the private repo and submodules clone cleanly:

```bash
brew install gh
gh auth login          # HTTPS, authenticate in browser
```

---

## 1. Clone the repo to the exact expected path

`linkall.sh` hard-codes `~/projects/dotfiles`. Match it or the symlinks break.

```bash
mkdir -p ~/projects
git clone --recurse-submodules https://github.com/gAmUssA/dotfiles.git ~/projects/dotfiles
cd ~/projects/dotfiles
# if you forgot --recurse-submodules:
git submodule update --init --recursive
```

---

## 2. Install everything from the Brewfile

```bash
brew bundle --file=~/projects/dotfiles/Brewfile
```

Big list — grab a coffee. This lands the whole toolchain plus **herdr**, **mosh**,
**tailscale**, tmux, sesh, etc.

---

## 3. Symlink the config files

```bash
cd ~/projects/dotfiles
sh linkall.sh
```

Safe to re-run — it `rm -f`s each target before re-linking, so no "file exists"
spam and no accidental no-ops. Brings over `.zshrc`, `.gitconfig`, **`.ssh/config`**
(including the `unifi` and `qnap` host blocks), ghostty, cmux, herdr, sesh, and
Claude Code `settings.json`.

Then start a fresh shell (or `exec zsh`) so p10k + plugins load.

---

## 4. System settings + GUI app prefs (optional but nice)

```bash
sh macos-defaults.sh      # Dock, Finder, keyboard, hot corners — 55 settings
sh prefs-restore.sh       # Moom, PopClip, iStat Menus, etc.
```

Some Dock/Finder changes need a logout or `killall Dock Finder` to show.

---

## 5. The per-machine bits linkall.sh can't do (don't skip)

These are excluded from git on purpose — set them up by hand on DS9:

```bash
# Git identity is in the tracked .gitconfig, but SSH keys are not:
#   - either create a new key and add it to GitHub,
ssh-keygen -t ed25519 -C "ds9"
gh ssh-key add ~/.ssh/id_ed25519.pub --title "ds9"
#   - or copy your existing key over from another machine.

# Cluster / registry credentials (never in the repo):
#   ~/.kube/config      — copy from wherever your clusters live
#   ~/.docker/config.json — `docker login` as needed

# Claude Code:
claude          # run once, authenticate. Creates per-machine settings.local.json.

# TextExpander: install, sign in — it has its own cloud sync.
```

---

## 6. DS9-specific: make it an always-on herdr host

Only for the Mac mini. See also the network project's herdr notes.

```bash
# Survive power loss, never sleep (display may sleep):
sudo pmset -a autorestart 1 sleep 0 displaysleep 10
pmset -g | grep -E "autorestart|^ sleep"     # verify

# Tailscale: install from Brewfile already done; now sign in to the tailnet:
sudo tailscale up
# then rename the machine to ds9 in the Tailscale admin console (Machines → Edit),
# OR set the hostname BEFORE `tailscale up` and it derives automatically:
sudo scutil --set ComputerName "DS9"
sudo scutil --set LocalHostName  "ds9"
sudo scutil --set HostName       "ds9"

# Enable Remote Login: System Settings → General → Sharing → Remote Login (on)

# mosh needs its server half present (Brewfile installs it, just confirm):
which mosh-server || brew install mosh
```

Interactive use — no LaunchAgent needed. Your first `herdr --remote ds9` after a
reboot starts the server. (A LaunchAgent only matters for background/scheduled
agents that must resume without you attaching; skip it for now.)

---

## 7. Connect from Voyager / phone

```bash
# From a laptop (SSH alias 'ds9' comes from the tracked .ssh/config; add it if not):
herdr --remote ds9 --session scratch

# From iPhone/iPad: Tailscale app + Blink/Moshi → mosh ds9 → run `herdr`.
```

Detach with `ctrl+b q`; reattach with the same command. Code lives on DS9; sync
between machines is **git only** — never iCloud/Drive for working trees.

---

## Quick reference — the whole thing on a truly fresh Mac

```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install gh && gh auth login
mkdir -p ~/projects && git clone --recurse-submodules https://github.com/gAmUssA/dotfiles.git ~/projects/dotfiles
cd ~/projects/dotfiles
brew bundle --file=Brewfile
sh linkall.sh
sh macos-defaults.sh && sh prefs-restore.sh
exec zsh
```
