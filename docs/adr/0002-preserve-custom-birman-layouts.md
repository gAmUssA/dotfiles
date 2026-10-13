# 0002: Preserve the installed customized Birman layouts

## Status

Accepted

## Date

2026-10-13

## Context

The source Mac uses modified English and Russian Birman layouts. Downloading
a stock bundle on another Mac loses those modifications. The runbook and
preference exporter referred to a HIToolbox snapshot that was also absent.

## Decision

Keep the actual installed bundle as personal configuration in
`keyboard-layouts/`, preserving all resource bytes and layout IDs. This is a
snapshot of customized keyboard configuration, not a vendored application or
library dependency. Back it up together with only the portable HIToolbox
selection fields. Restore the matching bundle before importing those fields.

## Consequences

Git carries the custom mappings and their selection state to other Macs.
Copies, rather than symlinks, isolate installed edits until an explicit backup.
Existing differing bundles are preserved locally before replacement. Fresh
installs use the user layout directory; existing system installs may need a
human-run sudo command. Logout and actual typing verification remain human
steps. New upstream layout releases never silently replace these customizations.
