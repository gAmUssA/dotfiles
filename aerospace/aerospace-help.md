# AeroSpace — my config

**Tap right Shift** → AERO mode → press one key → it acts and returns you to
normal typing. Nothing is held down. `esc` leaves without doing anything.

A HUD flashes the name of whatever just ran, so you can learn the keys by using
them. Caps Lock is not involved — it still switches EN/RU, instantly.

## Focus & move

| Key | Action | What should happen |
|---|---|---|
| `h` `j` `k` `l` | focus left / down / up / right | The highlight jumps to the neighbouring window. Nothing moves or resizes. |
| `⇧H` `⇧J` `⇧K` `⇧L` | move the window | The focused window swaps places with its neighbour; the others reflow to fill. |
| `[` / `]` | send to the other display | The window disappears from this screen and appears on the BenQ / built-in. Focus follows it. |

## Workspaces

| Key | Action | What should happen |
|---|---|---|
| `1`–`9` | switch workspace | The screen contents change completely. An empty workspace shows the desktop — that is normal, not a crash. |
| `⇧1`–`⇧9` | send window to workspace | The focused window vanishes from this screen. You stay put; it is waiting on that workspace. |
| `tab` | previous workspace | Flips between the last two workspaces, like alt-tab for workspaces. |

## Layout & size

| Key | Action | What should happen |
|---|---|---|
| `,` | tiles | Windows split the screen side by side, all visible at once. |
| `.` | accordion | Windows stack; one is visible and the rest collapse to slivers at the edge. |
| `f` | fullscreen | The focused window fills the screen. Press again to restore it. |
| `space` | float ↔ tile | The window pops out of the layout (drag/resize it freely), or snaps back in. |
| `-` / `=` | shrink / grow | The focused window changes size; neighbours take up the slack. **Stays in AERO mode** so you can press it repeatedly. |
| `b` | balance sizes | All windows in the workspace become equal. Also stays in the mode. |

## Repair & misc

| Key | Action | What should happen |
|---|---|---|
| `r` | reset layout | A mangled workspace flattens back to a plain, even split. |
| `⌫` | close all but focused | Every other window in this workspace closes. Destructive — there is no undo. |
| `/` | this cheat sheet | Opens in Marked 3. Marked live-reloads, so edits show up immediately. |
| `esc` | leave AERO mode | Nothing happens to your windows. |

---

# Tutorial

Ten minutes, in order. Each drill builds on the last. Every step below starts
with **tap right Shift**, which is written `⇧,` — so "`⇧, 2`" means tap right
Shift, then press `2`.

### 1. Get in and out
Tap right Shift. The HUD shows **AERO**. Press `esc` — nothing happens to your
windows. Do it twice. *You now know how to back out of a mistake.*

### 2. Workspaces
`⇧, 1` then `⇧, 2` then `⇧, 3`. Empty workspaces show the bare desktop; that is
expected. `⇧, tab` flips back to the previous one. *This is the key you will use
most.*

### 3. Collect some windows
Open two apps. On workspace 1, `⇧, ,` (that is the comma) to force **tiles** —
now both share the screen. Then `⇧, .` for accordion and back to `⇧, ,`. *You
have just seen the two layouts that matter.*

### 4. Focus without the mouse
With two tiled windows: `⇧, h` and `⇧, l` move the highlight left and right;
`⇧, j` / `⇧, k` for down and up. *Same letters as tmux and herdr panes — that is
deliberate.*

### 5. Rearrange
`⇧, ⇧H` and `⇧, ⇧L` — the window itself swaps sides. Compare with drill 4:
lowercase moves your **attention**, uppercase moves the **window**. *This
replaces Moom's halves: two tiled windows already are halves.*

### 6. Send work away and get it back
Focus a window, `⇧, ⇧3` — it vanishes to workspace 3. `⇧, 3` to follow it,
`⇧, tab` to come back. *This is the real workflow: park things by project.*

### 7. Size and rescue
`⇧, -` a few times: the window shrinks each press, without leaving the mode.
`esc` to leave. Then `⇧, b` to even everything out, and `⇧, r` if a layout ever
looks broken. *These three get you out of any visual mess.*

### 8. Floating
`⇧, space` on a window — it lifts out of the tiling and you can drag it. `⇧,
space` again puts it back. *Use it for anything you want to place by hand.*

### A first real setup
Once the keys feel automatic, give workspaces fixed jobs — for example herdr on
1, browser on 2, editor on 3. After that, `⇧, 1/2/3` is most of what you ever
press, and everything else is occasional.

---

## When something is wrong

- **Layout mangled** → `⇧, r`
- **A window tiles that should float** → `aerospace list-apps` to get its bundle
  id, then add an `on-window-detected` rule in `aerospace/aerospace.toml`.
  `auto-reload-config` is on, so saving is enough — no reload command needed.
- **A key does nothing** → you may not be in AERO mode. Tap right Shift first;
  the HUD confirms it. Unbound keys inside the mode do nothing at all.
- **Everything is wrong** → quit AeroSpace from its menu bar icon. Your windows
  stay exactly where they are.

## Rules of the house

- **No Alt bindings.** Alt belongs to the program in the pane (codex, editors).
- **No Ctrl+Alt bindings.** That is tmux and herdr. AeroSpace takes keys before
  iTerm sees them, so a Ctrl+Alt binding here silently breaks pane navigation.
- The leader exists so nothing is held **and** Shift stays free for the move
  variants. A four-modifier Hyper was tried first and dropped for both reasons.
- Caps Lock is deliberately untouched: it is the EN/RU switch.

Config: `aerospace/aerospace.toml` · HUD: `hammerspoon/aerospace_hud.lua` ·
tmux equivalent: `prefix + ?`
