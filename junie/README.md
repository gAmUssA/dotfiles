# Junie status in Rex

`rex-status.sh` reports Junie's lifecycle through Rex's OSC 7501 Program Status
Protocol. It creates a separate `id=junie` record, so ending a Junie session
clears only that record and not other programs' status.

## Enable

Start Junie with this repository's hook configuration:

```sh
junie --config-location "$HOME/projects/dotfiles/junie/rex-hooks.json"
```

Junie merges hooks from the explicitly supplied configuration with its user and
extension hooks. This repository does not edit `~/.junie/config.json` or enable
the adapter globally. The configured script path assumes this checkout is at
`~/projects/dotfiles`; adjust the command strings in `rex-hooks.json` if it is
elsewhere.

In Rex, enable **Settings → Notifications → Program Activity → Show activity in
tabs**. Send Junie a prompt to see its status change. To verify the reported
state directly, find its block with `rex block ls -A`, then run
`rex block call -b <junie-block-id> program_status`.

## Status mapping

| Junie event | Rex status |
| --- | --- |
| `SessionStart` (`startup`, `resume`, `clear`) | `idle` |
| `SessionStart` (`compact`) | No report, preserving the current turn state |
| `UserPromptSubmit`, `PreToolUse` | `working` |
| `PermissionRequest` | `blocked`, kind `permission` |
| `Stop` | `done` |
| `StopFailure` | `error` |
| `SessionEnd` | Clear the `junie` record |

Reports are sent only when `REX_BLOCK` is present and `/dev/tty` is writable.
They go to `/dev/tty`, never hook stdout, and carry no prompt, tool input, or
other private payload text. Outside Rex, or without a controlling terminal, the
hook is a silent no-op. Hook failures are also best-effort and do not block
Junie.

Junie's hooks do not include a permission-result event, so `blocked` can remain
visible until another prompt/tool/completion event updates it. `Stop` is not
emitted for chat-type tasks, and hook coverage differs across interactive and
batch hosts. This adapter does not report every internal state transition.

## tmux

When Junie runs inside tmux in a Rex pane, the reporter wraps OSC 7501 in tmux's
passthrough sequence. Enable forwarding in tmux:

```tmux
set -g allow-passthrough on
```

This setting only takes effect for reports emitted after it is enabled. Without
passthrough, tmux may consume the status sequence before Rex receives it.