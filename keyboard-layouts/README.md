# Customized Birman keyboard layouts

This is the installed English/Russian bundle from the source Mac, including
its local modifications. It is based on
[Ilya Birman's Typography Layout](https://ilyabirman.net/typography-layout/)
and was edited with [Ukelele](https://software.sil.org/ukelele/). Preserve the
original names, identifiers, attribution and resources when changing it.

The snapshot includes both `.keylayout` source files, their icons,
localization, and bundle metadata. Git stores their file contents; the exporter
omits `.DS_Store` and AppleDouble files and does not copy the original ACLs or
extended attributes. Layout XML is copied without
normalization: macOS uses legacy control-character references that ordinary
XML validators may reject.

From the dotfiles root, after installing a layout change:

```bash
./keyboard-layouts.sh backup
./keyboard-layouts.sh check
git diff -- keyboard-layouts prefs/com.apple.HIToolbox.plist
```

`backup` finds the installed bundle in the user or system Keyboard Layouts
folder. If both contain a copy, reconcile them and choose the intended source
with `--source BUNDLE`. Ukelele may edit a working copy rather than an installed
bundle; install that copy first, or explicitly supply its path. Review layout
outputs before committing: custom macros can contain private text.

Backup validates each layout's header ID/name and the bundle's TIS source IDs
against the enabled, selected and current HIToolbox sources before replacing
either snapshot. Both EN/RU layouts must be enabled and one must be selected.
If those identifiers changed, install and enable the edited layouts, select one,
then export again; a stale preferences file is rejected without changing the
saved pair. Other enabled input sources and non-keyboard methods are preserved.

The standard-library validator `scripts/validate_keyboard_sources.py` requires
Python 3.9+ and runs through `uv` (already in the Brewfile), without downloading
Python or third-party packages:

```bash
uv run --no-project --no-python-downloads --no-cache scripts/validate_keyboard_sources.py \
  "keyboard-layouts/Ilya Birman Typography Layout.bundle" prefs/com.apple.HIToolbox.plist
```

`prefs-backup.sh` runs the same backup helper, keeping the bundle and the
allowlisted `com.apple.HIToolbox` input-source preferences together.

On another Mac, after pulling the repo:

```bash
./keyboard-layouts.sh restore --dry-run
./keyboard-layouts.sh restore
./prefs-restore.sh
```

Restore updates an existing user/system installation at its current location.
With no existing installation, it uses `~/Library/Keyboard Layouts` and needs
no administrator access. It copies the bundle rather than symlinking it.
A differing existing bundle is moved into a local `.birman-backup.*` directory
before replacement; these backups are not shared through Git. Unrelated
keyboard bundles remain in place. `--destination DIR` selects another existing
directory or a new directory whose parent already exists.

If the existing installation is system-wide and needs updating, run
`sudo ./keyboard-layouts.sh restore --system` yourself. Do not install a second
copy in the user folder with the same layout IDs.

`prefs-restore.sh` installs the bundle before importing input sources. Log out
and back in, then verify both layouts in System Settings → Keyboard → Text
Input → Edit. If necessary, add English/Russian - Ilya Birman Typography there.
Only the human can complete the logout and confirm real keyboard behavior.

Run `bash tests/test_keyboard_layouts.sh` on macOS for fixture-based backup,
restore, privacy filtering, and failure checks. Verify the real exported
bundle with `./keyboard-layouts.sh check` on its source machine.
