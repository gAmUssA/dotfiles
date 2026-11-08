# Changelog

## 2026-11-06

- The README, `AGENTS.md`, and Claude's auto-mode notes now match the
  machine: `~/.claude/settings.local.json` is not a global settings file,
  Mackup stays retired, and the Stop hook does not ring the tmux bell
  (tmux-agentbar does). `linkall.sh` no longer deletes `~/.mackup.cfg`.

## 2026-11-04

- Pause AeroSpace automatically while Keynote or Keynote Creator Studio is
  running, preventing fullscreen slideshows from disappearing. Restore an
  automation-owned pause when Keynote quits; preserve existing manual pauses.
