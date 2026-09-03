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

Sign in to GitHub. The dotfiles repo itself is **public**, so cloning it needs
no auth — but `.gitmodules` points at `git@github.com:…` (SSH), so step 1's
`--recurse-submodules` fails without a key. Choose **SSH** at the `gh auth login`
prompt and let it upload a key, which resolves the submodule before you reach it:

```bash
brew install gh
gh auth login          # protocol: SSH — and say yes to generating/uploading a key
```

If you already picked HTTPS, either rerun with SSH or rewrite the submodule URL:

```bash
git config --global url."https://github.com/".insteadOf "git@github.com:"
```

**1Password SSH agent.** The tracked `.ssh/config` points `IdentityAgent` at
`~/.1password/agent.sock` for every host, so install 1Password and turn the SSH
agent on (Settings → Developer → Use the SSH agent) before relying on SSH. Until
then that socket does not exist. This is the primary key path on every machine —
the `ssh-keygen` in step 5 is only for hosts you'd rather key separately.

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

Big list — grab a coffee. This lands the whole toolchain plus **mosh**,
**tailscale**, tmux, sesh, etc.

**herdr is NOT in the Brewfile** — it ships its own installer and lands in
`~/.local/bin`, which is why the tracked `.zshenv` puts that directory on PATH.
Install it separately, or steps 6 and 7 have no binary to run:

```bash
curl -fsSL https://herdr.dev/install.sh | sh
herdr --version
herdr integration install claude   # agent state + native session restore
```

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

### Verification ladder

Test one hop at a time — a failure three rungs up is unreadable if the bottom
rungs were never checked. Run these **from the laptop**, against a fresh DS9:

```bash
tailscale status | grep ds9              # 1. on the tailnet at all
ssh ds9 true && echo "ssh ok"            # 2. sshd + 1Password agent + Remote Login
ssh ds9 'command -v mosh-server'         # 3. .zshenv PATH in a NON-interactive shell
ssh ds9 'command -v herdr'               # 4. same, for ~/.local/bin — gates --remote
mosh ds9 -- true && echo "mosh ok"       # 5. UDP 60000-61000 reachable
herdr --remote ds9 --session scratch     # 6. the real thing
```

Rungs 3 and 4 are the ones that actually bite: `ssh ds9 <cmd>` is a
non-interactive shell that reads `.zshenv` and never `.zshrc`, which is why both
Homebrew and `~/.local/bin` must be on PATH there. If rung 4 fails but an
interactive `ssh ds9` then `herdr` works, `.zshenv` is the file to fix.

---

## 7. Connect from Voyager / phone

The tracked `.ssh/config` has a `ds9` block pinned to its tailnet IP
(`100.124.8.59`), so both paths below work from anywhere on the tailnet:

```bash
# From a laptop — thin local client, bridges the LOCAL clipboard (incl. image paste):
herdr --remote ds9 --session scratch

# From iPhone/iPad: Tailscale app + Blink/Moshi → mosh ds9 → run `herdr`.
```

Pick the path deliberately — they are not interchangeable:

- **`herdr --remote ds9`** runs an SSH bridge (TCP), so it cannot ride mosh, but
  it is the only path that bridges your local desktop clipboard into the session.
- **`mosh ds9` then `herdr`** survives WiFi drops, sleep, and IP changes, and
  gives instant local echo — but herdr runs entirely on DS9 and cannot see the
  laptop's clipboard. Use OSC 52 for copy-out. Mosh keeps no scrollback of its
  own; herdr supplies it, which is exactly why you run herdr inside mosh.

Mosh needs UDP 60000–61000, which hotel/café NAT routinely blocks — connecting
over the tailnet address sidesteps that and survives DS9 changing networks.

### SSH keys, and the iOS exception

On any Mac, keys come from the **1Password SSH agent** — `.ssh/config` points
`IdentityAgent` at its socket and `op/ssh-agent.toml` lists what it offers. Sign
in to 1Password, enable the agent, and DS9 access follows you to a new machine
with nothing to copy.

**iOS has no SSH agent**, so Blink/Moshi cannot pull from 1Password. Copy the
private key out of the 1Password iOS app and paste it into the client's own key
store — the one place a private key legitimately leaves 1Password.

Use a **separate key per iOS device** rather than pasting the Mac's DS9 key:

1. In 1Password, create a new SSH key item, e.g. `DS9 iPad Moshi`.
2. Append its public key to `~/.ssh/authorized_keys` on DS9 (one key per line —
   `authorized_keys` takes any number).
3. Copy its *private* key from the 1Password iOS app, paste into Moshi.
4. Do **not** add it to `op/ssh-agent.toml` — that file is for Macs, and every
   extra key there is another attempt against sshd's `MaxAuthTries` (default 6).

Losing the iPad then costs one line in `authorized_keys`, and the Mac key is
untouched. Full sequence on iOS: Tailscale connected → Moshi with the imported
key → `mosh ds9` → `herdr`.

This is also why `.zshenv` (not `.zshrc`) carries the PATH: `mosh ds9` starts
`mosh-server` through a non-interactive shell that never reads `.zshrc`.

Detach with `ctrl+space q` (the tracked `herdr/config.toml` sets
`prefix = "ctrl+space"` to match tmux — **not** herdr's stock `ctrl+b`);
reattach with the same command. Code lives on DS9; sync between machines is
**git only** — never iCloud/Drive for working trees.

---

## Quick reference — the whole thing on a truly fresh Mac

```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install gh && gh auth login          # pick SSH — the submodule needs a key
mkdir -p ~/projects && git clone --recurse-submodules https://github.com/gAmUssA/dotfiles.git ~/projects/dotfiles
cd ~/projects/dotfiles
brew bundle --file=Brewfile
curl -fsSL https://herdr.dev/install.sh | sh    # herdr is NOT in the Brewfile
sh linkall.sh
sh macos-defaults.sh && sh prefs-restore.sh
exec zsh
```
