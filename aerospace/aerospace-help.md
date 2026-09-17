# AeroSpace cheat sheet — my config

**Hyper = hold Caps Lock** (⌘⌥⌃⇧). *Tapping* Caps still switches EN/RU.

| Key | Action |
|---|---|
| `Hyper + h j k l` | focus left / down / up / right |
| `Hyper + ← ↓ ↑ →` | **move** the window (letters move focus, arrows move windows) |
| `Hyper + 1..9` | switch workspace |
| `Hyper + Tab` | previous workspace (back-and-forth) |
| `Hyper + m` then `1..9` | send window to workspace |
| `Hyper + f` | fullscreen / restore |
| `Hyper + space` | float ↔ tile the focused window |
| `Hyper + [` / `]` | move window to other display |

## Layout & size

| Key | Action |
|---|---|
| `Hyper + ,` | tiles (side by side) |
| `Hyper + .` | accordion (stacked, one visible) |
| `Hyper + -` / `Hyper + =` | shrink / grow focused window |
| `Hyper + b` | balance all sizes |
| `Hyper + /` | this cheat sheet |

## Service mode — `Hyper + ;` then

| Key | Action |
|---|---|
| `r` | flatten workspace (fix a mangled layout) |
| `f` | toggle floating / tiling |
| `backspace` | close all windows but the focused one |
| `esc` | reload config |

## Move mode — `Hyper + m` then

`1`–`9` send window to that workspace · `h j k l` join with neighbour · `esc` cancel

## When something is wrong

- Layout mangled → `Hyper + ;` then `r`
- A window shouldn't tile → `aerospace list-apps` for its bundle id, add an
  `on-window-detected` float rule in `aerospace/aerospace.toml`. `auto-reload-config`
  is on, so saving applies it.
- Everything is wrong → quit AeroSpace from its menu bar icon; windows stay put.

## Rules of the house

- **No Alt bindings.** Alt belongs to the program in the pane (codex).
- **No Ctrl+Alt bindings.** That's tmux and herdr. AeroSpace grabs keys before
  iTerm, so a Ctrl+Alt binding here silently breaks pane navigation.
- Hyper uses all four modifiers, so there is no shift-variant: that's why
  move-to-workspace lives in a mode (`Hyper + m`) instead of `Hyper+Shift+N`.
- `Hyper + ?` and `Hyper + /` are the same key — Shift is already in Hyper.

Config: `aerospace/aerospace.toml` · tmux equivalent: `prefix + ?`
