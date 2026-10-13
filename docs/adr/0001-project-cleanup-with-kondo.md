# 0001: Use Kondo for project artifact cleanup

## Status

Accepted

## Date

2026-10-13

## Context

The old projects-folder script ran Maven and Gradle clean commands for every
manifest, assumed each Gradle module had a wrapper, and hid failures. It did
not cover Node dependencies. Directory names alone cannot distinguish source,
exports, and build artifacts across this collection of projects.

## Decision

Track `clean_projects.sh` in dotfiles and link its old location. Delegate
project recognition and deletion to Kondo, declared in the Brewfile, instead
of maintaining our own deletion rules or executing every project's build.
Require Kondo 0.9's dry-run support. Default to preview; explicit `--apply`
uses interactive prompts. Keep shared-cache maintenance separate.

## Consequences

One helper covers multiple build ecosystems without installing their build
dependencies to clean them. The wrapper validates paths, supports exclusions,
and fails when Kondo reports diagnostics. Kondo's artifact rules remain an
external dependency: Git-tracked artifacts need project exclusions, and
nested modules need explicit paths while Kondo stops at a recognized root.
