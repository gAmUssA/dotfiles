# Keynote and AeroSpace

`keynote_aerospace.lua` pauses AeroSpace while Keynote is running, including
editing and time spent in other apps. Quit Keynote with Command-Q to restore
AeroSpace. Closing its document window alone does not quit Keynote.
Both Keynote Creator Studio (`com.apple.Keynote`) and standalone Keynote
(`com.apple.iWork.Keynote`) are recognized.

This avoids [AeroSpace #804](https://github.com/nikitabobko/AeroSpace/issues/804),
which can hide a Keynote slideshow as soon as it starts. A floating-window rule
does not avoid the bug. Launch/quit detection avoids relying on a fullscreen
event that may arrive after AeroSpace has already interfered.

The module restores AeroSpace only when its own pause command succeeded.
An existing manual pause is preserved. Normal Hammerspoon reloads and quits
restore an owned pause; loading again pauses for an already-running Keynote.
If Hammerspoon crashes or is force-quit while it owns the pause, restore manually
with `aerospace enable on`. Errors appear in Hammerspoon Console and an alert.

## Validation

Run `bash tests/test_keynote_aerospace.sh` from the repository root for the
controller's process-boundary tests (Lua, installed through the Brewfile).
The Hammerspoon app watcher, shutdown callback and real slideshow are covered
by the platform-bound testing carve-out: they need a macOS GUI session with
Hammerspoon Accessibility access. Validate those as follows:

1. With AeroSpace enabled, open Keynote. Expect the pause alert and AeroSpace's
   menu to show it is disabled. Start a fullscreen slideshow; it must stay up.
2. Switch apps while Keynote remains open. AeroSpace must remain paused.
3. Reload Hammerspoon with Keynote open. AeroSpace must end paused. Quit Keynote;
   expect the resume alert and working AeroSpace workspace shortcuts.
4. Run `aerospace enable off` before opening Keynote. Quit Keynote; AeroSpace must
   remain disabled. Restore it with `aerospace enable on` after this check.

`linkall.sh` installs the module's symlink on new machines. On an existing
machine, create only the missing `~/.hammerspoon/keynote_aerospace.lua` symlink
to this module, then reload Hammerspoon; a full relink is unnecessary.
