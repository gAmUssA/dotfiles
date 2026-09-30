# Setting up a new Mac (DS9, Daystrom & friends)

Step-by-step to bring a fresh macOS machine up to this environment from the
dotfiles repo. Written for the always-on hosts — **DS9** (home-office Mac mini)
and **Daystrom** (Mac Studio, agents and builds) — but works for any new Mac.

Machines are named from Star Trek, and the class of name encodes the class of
hardware: stations and institutions stay put (`DS9`, `Daystrom`), starships
travel (`Voyager`), small craft attach to a parent (the iPad). Pick the name
**before** step 6 — Tailscale derives its node name from the hostname.

The repo's model, so the steps make sense:

- **`linkall.sh`** — symlinks every config file from the repo into `$HOME`
  (`.zshrc`, `.gitconfig`, `.ssh/config`, ghostty, cmux, **herdr**, sesh,
  Claude Code settings, …).
- **`Brewfile`** — every package/app, installed by `brew bundle`.
- **`prefs-restore.sh`** — GUI app preferences (Bartender, PopClip, iStat, …).
- **`macos-defaults.sh`** — 55 system settings (Dock, Finder, keyboard, …).
- **Git submodules** — zsh plugins (kafka-zsh-completions).
- Deliberately **NOT in git**: kube/docker credentials, Apple signing keys
  (see [SETUP-SIGNING-KEYS.md](SETUP-SIGNING-KEYS.md)), Claude Code's
  `settings.local.json`. Those are per-machine on purpose.

---

## If an agent is driving this setup

An agent can do most of the typing but **cannot finish this alone**, and the
failure mode is quiet: the machine looks configured, and nothing keyboard-
related works. Split the work explicitly.

**The agent must stop and hand back for these.** None can be scripted, and
several need a human physically at the machine:

| Gate | Why it is human-only |
|---|---|
| Any `sudo` | No password on the agent's side. Print the command, let the human run it. |
| Apple ID / iCloud sign-in | Interactive, 2FA |
| 1Password sign-in + *Settings → Developer → Use the SSH agent* | Nothing else creates the agent socket that `~/.1password/agent.sock` (linked by `linkall.sh`) points at, and the tracked `.ssh/config` points every host there |
| `gh auth login` | Browser + device code |
| TCC grants (Accessibility, Input Monitoring, Full Disk Access) | macOS refuses programmatic grants by design |
| `sudo tailscale up` | Prints an auth URL to open |
| Ilya Birman layout bundle + the logout after it | Third-party download; sources only appear after a logout |
| Accepting an SSH host key | The fingerprint must be **compared**, not accepted. See the verification ladder. |
| Deciding what user data to copy | Judgment, and irreversible |

**The agent can run unattended:** steps 1–4 (clone, `brew bundle`,
`linkall.sh`, `macos-defaults.sh`, `prefs-restore.sh`), every verification
command in this file, the repo sweep below, and reporting what it found.

**Order matters** — these gate each other, and skipping ahead produces errors
that read like something else entirely:

1. 1Password SSH agent **before** the clone: `.gitmodules` uses SSH, so
   `--recurse-submodules` fails without a key.
2. herdr installed (step 2) **before** `linkall.sh` (step 3): linkall installs
   the notify plugin and needs the binary.
3. TCC grants **before** claiming the desktop environment works.
4. Hostname set **before** `tailscale up`, or the node name is wrong.

**Report honestly.** `brew bundle` partially failing, a cask needing a password,
a TCC grant not yet made — say so with the output. A setup reported as complete
when a keybinding layer is dead costs more than the setup did. Verify with the
commands in each section rather than assuming a command that exited 0 did what
it claimed; `aerospace reload-config --dry-run`, for one, prints errors and
still exits 0.

---

## Reconciling a machine that is already set up

DS9 was configured months ago and the repo has moved since. This is **not** the
fresh-install path: on a machine in use, `linkall.sh` is destructive.

It `rm -f`s all 35 targets before relinking. Anything that drifted from a
symlink into a **regular file** is deleted with no backup and no diff — and
tools do convert them: tmux-assistant-resurrect and Paseo have each done it to
`claude/settings.json`. The local edits in that file are the ones that exist
nowhere else.

### Step 1 — audit before touching anything

```bash
cd ~/projects/dotfiles && git pull --ff-only
./reconcile-check.sh          # read-only; exits 1 if a human decision is needed
```

It reports repo state (behind/ahead/dirty), every expected link as
`OK / REGULAR FILE / WRONG TARGET / missing`, Brewfile gaps, and whether the
herdr notify plugin is installed. A `REGULAR FILE` line is the dangerous case:
that file holds changes the repo has never seen.

This is not hypothetical. Run on the laptop the day it was written, it found
`~/.config/opencode/opencode.json` carrying a `railway` MCP server that existed
in no commit.

### Step 2 — resolve each drift by union, never by choosing a side

For every `REGULAR FILE`, diff it against the repo copy and merge **both**
directions before relinking:

```bash
diff ~/.config/<path> ~/projects/dotfiles/<path>
# fold anything the live file has and the repo lacks INTO the repo, commit it,
# then relink just that one file:
rm -f ~/.config/<path> && ln -s ~/projects/dotfiles/<path> ~/.config/<path>
```

Overwriting the live file loses local work; overwriting the repo copy loses
every other machine's. For `claude/settings.json` specifically, union the hooks
**as a set** — `AGENTS.md` says the same thing, and says it because the rule was
learned twice.

### Step 3 — only now re-run the scripts

```bash
brew bundle --file=Brewfile     # adds; never removes
sh linkall.sh                   # safe once reconcile-check.sh is clean
sh macos-defaults.sh
```

Two cautions specific to an existing machine:

- **`brew bundle` never uninstalls.** Packages dropped from the Brewfile (Moom,
  for one) stay installed until `brew bundle cleanup` is run deliberately.
  Read its dry run before agreeing to it.
- **`prefs-restore.sh` overwrites live app settings** with the repo's snapshot,
  which may be *older* than what this machine has. On a machine in use, run
  `prefs-backup.sh` first and diff, rather than restoring blind. Quit the app
  first either way — a running app rewrites its plist on quit.

### The agent's part

Audit, diff, report, and propose the union — all read-only or repo-local, so all
safe to do unattended. Do **not** run `linkall.sh`, `prefs-restore.sh`, or
`brew bundle cleanup` on a machine in use until a human has signed off on each
drift the audit found. Reporting "reconciled" after deleting a config that
existed only on that machine is the failure this whole section exists to
prevent.

---

## Migrating from an existing Mac — do NOT use Migration Assistant

This repo exists so a new machine can be **rebuilt**, not copied. Migration
Assistant faithfully reproduces years of accumulated cruft; a clean install plus
steps 0–7 gives the same environment with none of it. Measured on the laptop
before the Daystrom build, of 746 GiB used:

| Category | Size | Migrate? |
|---|---|---|
| `/Applications` | 97 G | **No** — reinstall; most of it is the video rig, not this machine's job |
| `/opt/homebrew` | 26 G | **No** — `brew bundle` rebuilds it exactly (step 2) |
| `/Library` + system caches | 80 G | **No** — regenerates |
| Genuine user data | ~540 G | **Only what the new machine will use** — see below |

### If the old machine stays, copy less

A second machine alongside a live one needs far less than a replacement does.
Daystrom runs agents and builds; it does not need the media libraries, the
Downloads pile, or every repo — the laptop is still there, reachable over
Tailscale, and remains the fallback for anything not copied. Start with the
dotfiles repo and the toolchain, add projects when a task actually needs one,
and let `~/Downloads`, `Music`, `Pictures` and archived talks stay put.

Copy over the tailnet rather than a drive:

```bash
rsync -aP ~/Library/Fonts/ daystrom:~/Library/Fonts/     # after brew bundle
rsync -aP ~/projects/<repo> daystrom:~/projects/
```

### Before decommissioning or erasing a machine

Only when the source machine is going away:

**Sweep every repo for work that exists nowhere else.** This found 60+ repos
with unpushed commits, and three with no remote at all:

```bash
cd ~/projects && for r in $(find . -maxdepth 3 -name .git -type d | sed 's|/.git$||'); do
  dirty=$(git -C "$r" status --porcelain 2>/dev/null | wc -l | tr -d " ")
  unpushed=$(git -C "$r" log --branches --not --remotes --oneline 2>/dev/null | wc -l | tr -d " ")
  remote=$(git -C "$r" remote get-url origin 2>/dev/null || echo NO-REMOTE)
  [ "$dirty" != "0" ] || [ "$unpushed" != "0" ] || [ "$remote" = "NO-REMOTE" ] &&
    printf "%-55s dirty=%-5s unpushed=%-5s %s\n" "$r" "$dirty" "$unpushed" "$remote"
done
```

A repo with `NO-REMOTE` is the dangerous case: nothing is backing it up. Push it
somewhere, or copy the directory off, before the disk is erased. If the
machine is staying, this is hygiene rather than a deadline.

Also check what is genuinely per-machine and therefore nowhere in git:
`~/.kube/config`, `~/.docker/config.json`, `~/.appstoreconnect`,
`~/.claude/settings.local.json`, and anything under `~/Downloads` you still want.

### Time Machine local snapshots hide your free space

**Turn Time Machine off before any cleanup or migration:**

```bash
sudo tmutil disable        # re-enable with `sudo tmutil enable` when finished
```

APFS local snapshots pin every block you delete. During the Daystrom prep, ~589
GiB of deletions — a 329 GB runaway clipboard cache, a 97 GB project move, 130
GiB of caches — returned **zero** free space until two hourly snapshots aged
out, at which point it all appeared at once. The cleanup looked broken for an
hour and was not.

The trap inside the trap: `diskutil apfs listSnapshots /` checks the **System**
volume and reports nothing. Your data lives on the Data volume:

```bash
tmutil listlocalsnapshots /                      # the honest answer
diskutil apfs listSnapshots /System/Volumes/Data # ditto, with a Purgeable flag
sudo tmutil deletelocalsnapshots <YYYY-MM-DD-HHMMSS>
```

Related: `du` reports cloned and snapshot-pinned blocks at full size, so a
directory can look enormous while costing almost nothing — and `du` is aliased
in this shell to a tool that rejects `-s`. Use `/usr/bin/du -shx`.

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
then that socket does not exist. The app only creates the real socket inside
its group container; `~/.1password/agent.sock` is a symlink to it that
`linkall.sh` makes — 1Password does not. This is the primary key path on every machine —
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

The notification plugin is **not in this repo** — it lives at
`gAmUssA/herdr-notify`. `linkall.sh` installs it in step 3
(`herdr plugin install gAmUssA/herdr-notify --yes`), but that needs the herdr
binary to already exist, which is why herdr is installed here in step 2 and not
later. It runs server-side, so it fires while you are detached, and
`claude/stop-hook.sh` suppresses its own banner only when the plugin is enabled
— exactly one banner per turn. After step 3, verify:

```bash
herdr plugin list                   # expect gamussa.notify, enabled
```

For plugin development, clone the repo and `herdr plugin link <checkout>`
instead. Edit it there, never a second copy in this repo.

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
sh macos-defaults.sh      # Dock, Finder, keyboard, mouse, hot corners — 64 settings
sh prefs-restore.sh       # Bartender, PopClip, iStat Menus, etc.
```

Some Dock/Finder changes need a logout or `killall Dock Finder` to show.

### Keyboard layout — Ilya Birman Typography (EN + RU)

Both English and Russian typing use the **Ilya Birman Typography** layouts, not
the stock ones. The bundle is third-party, so it is **not** vendored here —
download it, then drop it in the system-wide layout directory:

```bash
# https://ilyabirman.net/projects/typography-layout/ -> download the macOS bundle
sudo cp -R "Ilya Birman Typography Layout.bundle" "/Library/Keyboard Layouts/"
sudo chown -R "$USER:staff" "/Library/Keyboard Layouts/Ilya Birman Typography Layout.bundle"
```

**Log out and back in**, then add both layouts in System Settings → Keyboard →
Text Input → Edit… → `+`:

- `English - Ilya Birman Typography`
- `Russian - Ilya Birman Typography`

`prefs-restore.sh` carries the `com.apple.HIToolbox` domain, which records the
enabled input sources — but it can only enable layouts whose bundle is already
installed, and the change needs a logout to appear. Install the bundle first.

The EN/RU switch is **Caps Lock**, remapped to `f19` ("Select previous input
source") in `karabiner/karabiner.json` — in the profile *and* in every
per-device block. That is why Caps Lock is not available as a modifier for
anything else; see `AGENTS.md`.

---

### Fonts — the Brewfile covers the coding ones, not the slide ones

42 font casks are in the Brewfile, including `font-iosevka-term-nerd-font`,
which is what `ghostty/config` actually sets. `brew bundle` restores all of
them.

It does **not** restore the rest of `~/Library/Fonts` — 1,491 files, 4.3 GB,
none of it symlinked or Homebrew-managed. The display faces used in talks live
there: `FinalFrontierOldStyle`, `Lazer84`, `KOMIKAX`, `ADAM.CG PRO`,
`Font Awesome 5/6`, plus Microsoft's `Aptos` and `calibri` that arrive with
Office.

These are **licensed assets, so they are not vendored here** — this repo is
public, and shipping font binaries is redistribution. Same reasoning as the
Birman layout. Back them up instead, and restore before the first talk:

```bash
# on the old machine
/usr/bin/du -sh ~/Library/Fonts
ditto ~/Library/Fonts /Volumes/<archive>/Fonts-$(date +%F)

# on the new one, after brew bundle has placed the cask fonts
ditto /Volumes/<archive>/Fonts-<date> ~/Library/Fonts
```

`ditto` merges rather than replacing, so it will not disturb what `brew bundle`
already installed. Font Book shows duplicates if both a cask and a hand-copied
version of the same family land — resolve those in Font Book, not by deleting
files, or `brew bundle` will simply put them back.

Worth skipping on the way over: `~/Library/Fonts` also holds X11 leftovers
(`fonts.dir`, `fonts.list`, `fonts.scale`, `encodings.dir`) and a stray `foo`.

---

### Desktop environment — AeroSpace, Karabiner, Hammerspoon

All three are in the Brewfile, but each needs a TCC permission grant that no
script can make for you. Skip these and every keybinding is silently dead:

| App | System Settings → Privacy & Security → | Why |
|---|---|---|
| AeroSpace | **Accessibility** | moving and focusing windows |
| Karabiner-Elements | **Input Monitoring** (both `karabiner_grabber` and `karabiner_observer`) | remapping keys at all |
| Hammerspoon | **Accessibility** | the AeroSpace HUD overlay |

Then launch each once so it registers, and confirm the layer stack works:

```bash
aerospace list-workspaces --all            # AeroSpace is running and has config
osascript -e 'tell application "System Events" to key code 79'
aerospace list-modes --current             # expect "aero" — proves f18 arrives
```

The modifier layers, and why each belongs to exactly one owner, are in
`AGENTS.md`. The short version: **Alt** belongs to the program in the pane,
**Ctrl+Alt** to tmux/herdr, and the **f18 leader** (tap right Command) to
AeroSpace. AeroSpace grabs keys at the OS level before iTerm sees them, so a
stray Ctrl+Alt binding there breaks herdr navigation with every config file
still looking correct.

AeroSpace runs **float-by-default** on purpose — auto-tiling was tried and
rejected. Do not "fix" that. `aerospace/aerospace-help.md` is the cheat sheet
(leader then `/`).

---

## 5. The per-machine bits linkall.sh can't do (don't skip)

These are excluded from git on purpose — set them up by hand on DS9:

**SSH keys come from 1Password, not `ssh-keygen`.** Install the app, sign in,
then enable the agent (Settings → Developer → *Use the SSH agent*) — that
creates the socket in 1Password's group container, and `linkall.sh` links
`~/.1password/agent.sock` (what the tracked `.ssh/config` points every host at)
to it. The first signature pops an approval dialog in 1Password; until someone
clicks it, ssh reports `signing failed ... communication with agent failed`. `linkall.sh` already linked the key list. Verify:

```bash
ls -l ~/.1password/agent.sock                  # socket exists = agent is on
SSH_AUTH_SOCK=~/.1password/agent.sock ssh-add -l   # lists keys from op/ssh-agent.toml
ssh -T git@github.com                          # expect "Hi gAmUssA!"
```

If a key is in the vault but missing from `ssh-add -l`, it is not in
`op/ssh-agent.toml` — add it there and re-check. That file is the allowlist.

**`op` (the CLI) needs two more things than the agent does.** Turn on
*Settings → Developer → Integrate with 1Password CLI*, and give the terminal
(iTerm) **Full Disk Access**. `op` decides whether the integration is on by
reading the app's `settings.json` inside its group container, which macOS's
App Data protection blocks — and `op` reports that as *"No accounts configured"*,
never as a permission error. `op vault list --debug` shows the real
`operation not permitted`. The SSH agent keeps working throughout, which makes
this look like a 1Password problem when it is a TCC one. Found on Daystrom.

Everything else that is genuinely per-machine:

**Apple signing / App Store Connect API keys** live in `~/.appstoreconnect` and
are backed up as 1Password documents — restore steps, and why the local path
matters, are in [SETUP-SIGNING-KEYS.md](SETUP-SIGNING-KEYS.md):

```bash
op item list --tags appstoreconnect      # what's backed up
```

```bash
# Cluster / registry credentials (never in the repo):
#   ~/.kube/config      — copy from wherever your clusters live
#   ~/.docker/config.json — `docker login` as needed

# Claude Code:
claude          # run once, authenticate. Creates per-machine settings.local.json.
```

---

## 6. Always-on herdr host (DS9, Daystrom)

For any machine that stays powered and serves sessions to the others — the Mac
mini (`DS9`) and the Mac Studio (`Daystrom`). Skip this on laptops. Substitute
the machine's own name for `ds9` throughout. See also the network project's
herdr notes.

```bash
# Survive power loss, never sleep (display may sleep):
sudo pmset -a autorestart 1 sleep 0 displaysleep 10
pmset -g | grep -E "autorestart|^ sleep"     # verify

# Tailscale: install from Brewfile already done; now sign in to the tailnet:
sudo tailscale up
# then rename the machine in the Tailscale admin console (Machines → Edit),
# OR set the hostname BEFORE `tailscale up` and it derives automatically.
# Use the machine's own name — DS9/ds9 here, Daystrom/daystrom on the Studio:
sudo scutil --set ComputerName "DS9"
sudo scutil --set LocalHostName  "ds9"
sudo scutil --set HostName       "ds9"

# Enable Remote Login (sshd). GUI equivalent: System Settings → General →
# Sharing → Remote Login. The CLI needs Full Disk Access for Terminal on recent
# macOS; if it errors, use the GUI toggle instead.
sudo systemsetup -setremotelogin on
sudo systemsetup -getremotelogin              # expect "Remote Login: On"

# mosh needs its server half present (Brewfile installs it, just confirm):
which mosh-server || brew install mosh
```

Then authorize the key you log in *with*. Run this **from the laptop**, where
the 1Password agent holds the key — it needs password auth for this one
connection, so do it before turning password auth off:

```bash
op item get "DS9 Mac Mini id_ed25519" --fields "public key" \
  | sed 's/[[:space:]]*$/ DS9-Mac-Mini/' \
  | ssh ds9 'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys'
```

The `sed` tags the line with a comment. `op` returns the key bare, and an
untagged `authorized_keys` is a wall of anonymous base64 you cannot revoke
selectively later. Always append a comment naming the device.

Interactive use — no LaunchAgent needed. Your first `herdr --remote ds9` after a
reboot starts the server. (A LaunchAgent only matters for background/scheduled
agents that must resume without you attaching; skip it for now.)

### Verification ladder

Test one hop at a time — a failure three rungs up is unreadable if the bottom
rungs were never checked. Run these **from the laptop**, against a fresh DS9:

Rung 0 first, once per client: DS9's **host key** — its server identity, which
is unrelated to the key you log in with. Print it on DS9, compare from the
laptop, and only then accept:

```bash
# ON DS9:
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
# FROM THE LAPTOP — must print the same fingerprint:
ssh-keyscan -t ed25519 ds9 2>/dev/null | ssh-keygen -lf -
# match? then connect once and answer yes:
ssh ds9
```

Current DS9 host key: `SHA256:WKhWmCMkSw8uY8a14LDoMzh1OY7tYjnvqga4cxQjDTg`.
Current Daystrom host key: `SHA256:DseJ3XJsaLh7wHms0FvU9qQ1uGBag7xpccqWBc3+S1A`.
It changes only if macOS is reinstalled — a mismatch otherwise is worth stopping
for, not clearing with `ssh-keygen -R ds9`.

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

```bash
# 1. Generate the key straight into 1Password (or use the GUI: New Item → SSH Key):
op item create --category "SSH Key" --title "DS9 iPad Moshi" \
  --vault Private --ssh-generate-key ed25519

# 2. Authorize it on DS9, tagged so it can be revoked by name later:
op item get "DS9 iPad Moshi" --fields "public key" \
  | sed 's/[[:space:]]*$/ DS9-iPad-Moshi/' \
  | ssh ds9 'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys'

# 3. Confirm DS9 now lists both keys, by name:
ssh ds9 'ssh-keygen -lf ~/.ssh/authorized_keys'
```

4. On the iPad: 1Password app → the `DS9 iPad Moshi` item → copy the **private
   key** field → paste into Moshi's key store. This is a GUI step; iOS has no
   agent to broker it. Don't route a private key through a desktop terminal to
   get there.
5. Do **not** add it to `op/ssh-agent.toml` — that file is for Macs, and every
   extra key there is another attempt against sshd's `MaxAuthTries` (default 6).

To revoke that iPad later, remove its one line — the Mac key is untouched:

```bash
ssh ds9 "grep -v ' DS9-iPad-Moshi$' ~/.ssh/authorized_keys > ~/.ssh/ak.new && \
         mv ~/.ssh/ak.new ~/.ssh/authorized_keys && \
         ssh-keygen -lf ~/.ssh/authorized_keys"
```

That matches the comment appended in step 2 — which is exactly why the `sed`
is not optional. Then delete the item in 1Password and remove the key from
Moshi.

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

Then the parts no script can do, in this order:

1. **1Password** — sign in, enable the SSH agent (Settings → Developer).
2. **TCC grants** — Accessibility for AeroSpace and Hammerspoon, Input
   Monitoring for both Karabiner binaries. Nothing keyboard-related works until
   these are set.
3. **Ilya Birman keyboard layout** — install the bundle, then log out so the
   EN/RU sources appear.
4. **Always-on host only** (step 6) — hostname, `tailscale up`, Remote Login,
   `pmset`, then authorize the login key from the laptop.

And if you are migrating rather than starting clean, read the top of this file
first — `sudo tmutil disable`, and sweep for unpushed repos before erasing
anything.
