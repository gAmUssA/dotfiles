# herdr plugins

## gamussa.notify — moved

The agent-notification plugin that used to live in `herdr-plugins/notify/` is
now its own repository:

**https://github.com/gAmUssA/herdr-notify** — installable from the herdr
marketplace with `herdr plugin install gAmUssA/herdr-notify` (what `linkall.sh`
runs). Its history was carried over with `git subtree split`, so the commits
that are missing from this directory are in that repo, not lost.

It is kept separate because a plugin published for other people should not be
edited in place inside a dotfiles repo: the copy people install and the copy
this machine runs would drift, which is exactly what happened before the split.

Related: `claude/stop-hook.sh` stays quiet inside herdr only while that plugin
is enabled — see the herdr section of `AGENTS.md`.
