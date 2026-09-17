# Agent notifications

A [Herdr](https://herdr.dev) plugin: one macOS banner when an agent finishes or
needs input, and a click takes you to the exact pane — even from a detached
session.

## Install

```sh
brew install vjeantet/tap/alerter jq   # banner + JSON tooling
herdr plugin install gAmUssA/herdr-notify
```

Requires macOS, iTerm2, Python 3.8+ and Herdr 0.9.0+. The first click asks for
**Automation** permission to control iTerm. Turn off Herdr's own toasts
(`[ui.toast] delivery = "off"`) or you will get two banners per event while a
client is attached.

Overrides: `HERDR_NOTIFY_ALERTER` (path to alerter), `HERDR_NOTIFY_ICON`
(banner icon).

## How it works


`notify.sh` emits one banner for each `done` or `blocked` event. Banners replace
earlier banners from the same socket/pane; separate sessions never share a group.
Requires `alerter`, `jq`, Python 3.8+, and iTerm with macOS Automation permission.

On a content click, `focus.py`:

1. Finds the captured terminal ID on the **originating socket**. This follows a
   pane moved to another workspace, works after the agent exits, and rejects a
   closed/replaced terminal.
2. Calls the public `pane.focus` API, which selects the workspace, tab, and pane
   and redirects attached clients. In Herdr 0.9.0, `agent.focus` omits that client
   navigation step in `src/server/headless/client_views.rs`.
3. Resolves local client processes using exact arguments and their inherited
   Herdr routing environment, then selects the matching iTerm window/tab/split
   by TTY. Remote clients and CLI commands are excluded. Process credentials
   are never retained or logged.
4. If no matching iTerm session exists, opens a window attached to that exact
   socket, waits for the client, and reapplies pane focus.

The socket focus API applies to all attached clients of that server. The desktop
window routing is local macOS/iTerm only; it does not route across SSH machines.
Routing failures are logged when debug is enabled and never reported as success.

The linked plugin reads these scripts on each event; no server restart is needed.
Already displayed banners retain the old callback until they expire.

Run regression checks:

```sh
python3 -B -m unittest discover -v
shellcheck notify.sh
```

For a manual check, run from a Herdr pane (this selects that pane and its iTerm
window, using the same handler as a banner click):

```sh
./notify.sh --focus-test
```

Enable server-side debugging with a `debug` marker in the plugin state directory
(`~/.local/state/herdr/plugins/gamussa.notify` by default). Inspect `notify.log`
there for the confirmed workspace/tab/pane and host TTY, or a routing failure.
