# AeroSpace — my config

**Tap right Shift** → AERO mode → press one key → it acts and returns you to
normal typing. Nothing is held down. `esc` leaves without doing anything.

**Windows float by default.** Nothing rearranges itself when you open an app —
your windows stay where you put them. **Raycast still does the snapping**
(Center, halves, Reasonable Size); AeroSpace is here for what Raycast cannot do:
workspaces, focus, and throwing a window to the other display. Tiling is opt-in
per window with `space`.

A HUD flashes the name of whatever just ran, so you can learn the keys by using
them. Caps Lock is not involved — it still switches EN/RU, instantly.

## Focus & move

| Key | Action | What should happen |
|---|---|---|
| `←` `↓` `↑` `→` | focus left / down / up / right | The highlight jumps to the next window in that direction. Nothing moves or resizes. |
| `⇧←` `⇧↓` `⇧↑` `⇧→` | move the window | The focused window moves that way. Floating windows shift; tiled ones swap with a neighbour. |
| `d` | send to the other **d**isplay | The window disappears from this screen and appears on the BenQ / built-in. Focus follows it. |

## Workspaces

| Key | Action | What should happen |
|---|---|---|
| `1`–`9` | switch workspace | The screen contents change completely. An empty workspace shows the desktop — that is normal, not a crash. |
| `⇧1`–`⇧9` | send window to workspace | The focused window vanishes from this screen. You stay put; it is waiting on that workspace. |
| `tab` | previous workspace | Flips between the last two workspaces, like alt-tab for workspaces. |

## Layout & size

| Key | Action | What should happen |
|---|---|---|
| `space` | **tile ↔ float** this window | Opts one window into tiling (it snaps into the layout), or back out to float freely. |
| `t` | **t**ile everything here | Pulls every window on this workspace into the layout, splits them evenly, and balances. The one-key way to go from scattered to tiled. |
| `⇧T` | float everything here | Undoes `t` — all windows on this workspace go back to floating where they were. |
| `a` | **a**ccordion | Tiled windows stack; one visible, the rest collapse to slivers. |
| `o` | flip split direction | The tiled windows in the current container swap between side-by-side and stacked. Nothing is added or removed — only the axis changes. |
| `j` then an arrow | **j**oin with that neighbour | The focused window and the neighbour you point at become one group, which then behaves as a single slot in the parent. This is how a column-next-to-a-stack is built. The HUD stays up until you pick a direction; `esc` cancels. |
| `f` | **f**ullscreen | The focused window fills the screen. Press again to restore it. |
| `-` / `=` | shrink / grow | The focused window changes size; neighbours take up the slack. **Stays in AERO mode** so you can press it repeatedly. |
| `b` | balance sizes | All windows in the workspace become equal. Also stays in the mode. |

## Repair & misc

| Key | Action | What should happen |
|---|---|---|
| `x` | spread out | Sends each window here to its own **empty** workspace, keeping the first in place. Occupied workspaces are never touched. |
| `g` | **g**ather | Pulls every window from all other workspaces onto this one. The inverse of `x`. |
| `m` | **m**ove workspace to other display | The whole workspace — every window on it — jumps to the other monitor. |
| `c` | focus other display | Moves focus to the other monitor without moving anything. |
| `r` | reset layout | A mangled workspace flattens back to a plain, even split. |
| `/` | this cheat sheet | Opens in Marked. It live-reloads, so edits show up immediately. |
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

### 3. Focus without the mouse
With two windows open: `⇧, ←` and `⇧, →` move the highlight between them,
`⇧, ↑` / `⇧, ↓` for stacked ones. *Nothing moves or resizes — this only changes
which window is listening to your keyboard.*

### 4. Move a window
`⇧, ⇧←` and `⇧, ⇧→`. Compare with drill 3: plain arrows move your **attention**,
shifted arrows move the **window**. *Use Raycast for exact halves and centring;
this is for coarse placement.*

### 5. Opt one window into tiling
Focus a window and `⇧, space` — it snaps into the layout instead of floating.
Do the same to a second window, then `⇧, t`: those two now share the screen,
and everything else stays floating. `⇧, space` again releases a window.
*Tiling is opt-in here; nothing tiles unless you ask.*

### 6. Send work away and get it back
Focus a window, `⇧, ⇧3` — it vanishes to workspace 3. `⇧, 3` to follow it,
`⇧, tab` to come back. *This is the real workflow: park things by project.*

### 7. Size and rescue
`⇧, -` a few times: the focused window shrinks each press, without leaving the
mode. `esc` to leave. Then `⇧, b` to even up the tiled ones, and `⇧, r` if a
layout ever looks broken. *These three get you out of any visual mess.*

### 8. The other display
`⇧, d` throws the focused window to the other monitor, and again brings it back.
`⇧, c` just moves focus there; `⇧, m` sends the whole workspace across.
*The one thing Raycast's window commands handle less directly.*

### 9. Bulk moves
On a workspace with several windows: `⇧, t` tiles them all at once, `⇧, ⇧T`
floats them back. Then `⇧, x` scatters them one per empty workspace, and
`⇧, g` pulls everything back to where you are. *`x` never writes over a
workspace that is already in use — it only fills empty ones.*

### 10. Nested layouts
Tile three windows (`⇧, t`). Focus the second and `⇧, j` — the HUD waits — then
`→`. The second and third are now a group: `⇧, o` flips just that group between
side-by-side and stacked, leaving the first window alone. That is the classic
"editor on the left, two panes stacked on the right". `⇧, r` undoes all of it.
*`join-with` builds structure; `o` chooses its direction. i3's `split` is not
bound — AeroSpace calls it compatibility-only and it does nothing with the
container normalization this config uses.*

### A first real setup
Once the keys feel automatic, give workspaces fixed jobs — for example herdr on
1, browser on 2, editor on 3. After that, `⇧, 1/2/3` is most of what you ever
press, and everything else is occasional.

---

## When something is wrong

- **Layout mangled** → `⇧, r` (only affects tiled windows)
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
- **Float is the default on purpose.** Auto-tiling everything felt wrong, so
  tiling is opt-in per window. Raycast keeps snapping duty; if you want an app
  to always tile, add a `run = 'layout tiling'` rule in `aerospace.toml`.
- Caps Lock is deliberately untouched: it is the EN/RU switch.

Config: `aerospace/aerospace.toml` · HUD: `hammerspoon/aerospace_hud.lua` ·
tmux equivalent: `prefix + ?`
