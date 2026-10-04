# Read by every zsh, including non-interactive SSH exec sessions (which skip
# .zshrc). Keeps Homebrew tools — notably mosh-server for incoming mosh
# connections — on PATH when there's no login shell to run path_helper.
#
# ~/.local/bin is here for the same reason: herdr installs there (curl
# install.sh, not Homebrew), and `herdr --remote <host>` starts the remote
# server over `ssh -T`, which is non-interactive and never reads .zshrc. The
# .zshrc copy of this line only covers interactive shells. `typeset -U path`
# in .zshrc dedupes the overlap.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

# mosh-server refuses to start without a UTF-8 locale; SSH exec sessions have
# none unless the client forwards LANG. Fall back without clobbering a
# client-supplied value.
: "${LANG:=en_US.UTF-8}"
export LANG

# Per-machine OpenCode overrides (e.g. a default model only this machine
# serves, like oMLX on Daystrom). opencode.json is tracked and shared, so a
# machine-specific default would break every other machine; OpenCode merges
# OPENCODE_CONFIG on top of it instead. The file is untracked and optional.
[[ -r ~/.config/opencode/opencode.local.json ]] && export OPENCODE_CONFIG=~/.config/opencode/opencode.local.json
