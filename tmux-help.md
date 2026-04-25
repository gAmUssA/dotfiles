# tmux cheat sheet — my config

**Prefix:** `Ctrl-Space`   ·   **Reload config:** `prefix + r`

## Panes (inside one window)
| Key | Action |
|---|---|
| `Alt + ← → ↑ ↓` *(no prefix)* | jump between panes |
| `prefix + x` | zoom / unzoom (toggle fullscreen) |
| `prefix + \|` | split horizontally |
| `prefix + _` | split vertically |
| `prefix + Ctrl-h/j/l/u` | resize left/down/right/up (10 cells) |
| `prefix + *` | resize pane to 80 cols |
| `prefix + q` | flash pane numbers — press N to jump |
| `prefix + =` | toggle pane sync (type in all panes at once) |
| `prefix + Ctrl-A` | cycle through panes |
| `prefix + t` / `prefix + T` | rename pane / toggle pane-title bar |

## Windows (tabs)
| Key | Action |
|---|---|
| `Shift + Alt + ← / →` *(no prefix)* | prev / next window |
| `prefix + 1..9` | jump directly to window N |
| `prefix + n` / `prefix + p` | next / previous window |
| `prefix + w` | interactive window picker |
| `prefix + f` | find a window by text content |
| `prefix + ,` | rename current window |
| `prefix + &` | kill current window |

## Sessions
| Key | Action |
|---|---|
| `Shift + Alt + ↑ / ↓` *(no prefix)* | prev / next session |
| `prefix + s` | native session picker |
| `prefix + o` | **sessionx** popup (fuzzy, with preview) |
| `prefix + y` | per-dir **Claude** popup (spawns/reattaches) |
| `prefix + N` | new session |
| `prefix + $` | rename session |
| `prefix + d` | detach (session keeps running) |

## Popups
| Key | Action |
|---|---|
| `prefix + g` | **lazygit** in popup (scoped to pane cwd) |
| `prefix + Enter` | ephemeral **shell** peek (scoped to pane cwd) |
| `prefix + y` | Claude per-dir popup |
| `prefix + o` | sessionx fuzzy picker |

## Copy / scroll / clear
| Key | Action |
|---|---|
| `prefix + [` | enter copy mode (vi keys, `q` to exit) |
| Mouse wheel | scroll history |
| `prefix + ]` | paste |
| `Ctrl-Alt-k` *(no prefix)* | clear pane AND history |

## Layouts
| Key | Action |
|---|---|
| `prefix + @` | even-horizontal |
| `prefix + !` | even-vertical |
| `prefix + l` / `prefix + L` | next / prev layout *(remapped from "last window")* |
| `prefix + )` / `prefix + (` | swap pane down / up *(remapped from sessions)* |

## Tab bar reading guide
- ` ·` gray → agent idle
- ` ✶` yellow → agent thinking (spinner animates)
- ` ⏸` red → agent waiting for your input
- ` ✓` green → agent turn finished
- No robot = no agent detected in that window
- `*` = current window  ·  `-` = last  ·  `Z` = zoomed  ·  `!` = bell (attention)

## Shell aliases & commands
| Command | What it does |
|---|---|
| `s` | fuzzy session picker (sesh + fzf) — works inside and outside tmux |
| `cdev [dir]` | spawn project tmux session (claude + shell + tests windows) |
| `yolo` | `claude --dangerously-skip-permissions` |
| `z <dir>` | zoxide jump |

## Gotchas worth remembering
- **Right Option** key in iTerm2 must be set to **"Esc+"** (not Normal) for Shift+Alt+arrow to fire.
- `prefix + l` is **next layout**, NOT "last window" — use `prefix + p` to bounce back.
- `prefix + (` / `prefix + )` swap **panes**, not sessions — Shift+Alt+↑/↓ for sessions.
- Powerline chevrons require IosevkaTermNF or another Nerd Font.
