# AeroSpace cheat sheet — my config

**Tap right Shift** to enter AERO mode, then press one key. Nothing is held.
The mode exits by itself after each action (`esc` leaves without acting).
Caps Lock is untouched — it still switches EN/RU, instantly.

| Key | Action |
|---|---|
| `h j k l` | focus left / down / up / right |
| `⇧H ⇧J ⇧K ⇧L` | **move** the window |
| `1..9` | switch workspace |
| `tab` | previous workspace (back-and-forth) |
| `⇧1..⇧9` | send window to workspace |
| `f` | fullscreen / restore |
| `space` | float ↔ tile the focused window |
| `[` / `]` | move window to other display |

## Layout & size

| Key | Action |
|---|---|
| `,` | tiles (side by side) |
| `.` | accordion (stacked, one visible) |
| `-` / `=` | shrink / grow focused window |
| `b` | balance all sizes |
| `/` | this cheat sheet |

## Also in AERO mode

| Key | Action |
|---|---|
| `r` | flatten workspace (fix a mangled layout) |
| `f` | toggle floating / tiling |
| `backspace` | close all windows but the focused one |
| `esc` | reload config |


## When something is wrong

- Layout mangled → `;` then `r`
- A window shouldn't tile → `aerospace list-apps` for its bundle id, add an
  `on-window-detected` float rule in `aerospace/aerospace.toml`. `auto-reload-config`
  is on, so saving applies it.
- Everything is wrong → quit AeroSpace from its menu bar icon; windows stay put.

## Rules of the house

- **No Alt bindings.** Alt belongs to the program in the pane (codex).
- **No Ctrl+Alt bindings.** That's tmux and herdr. AeroSpace grabs keys before
  iTerm, so a Ctrl+Alt binding here silently breaks pane navigation.
- Hyper uses all four modifiers, so there is no shift-variant: that's why
  move-to-workspace lives in a mode (`m`) instead of `Hyper+Shift+N`.
- `esc` exits the mode; unbound keys do nothing.

Config: `aerospace/aerospace.toml` · tmux equivalent: `prefix + ?`
