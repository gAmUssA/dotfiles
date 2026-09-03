# Read by every zsh, including non-interactive SSH exec sessions (which skip
# .zshrc). Keeps Homebrew tools — notably mosh-server for incoming mosh
# connections — on PATH when there's no login shell to run path_helper.
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

# mosh-server refuses to start without a UTF-8 locale; SSH exec sessions have
# none unless the client forwards LANG. Fall back without clobbering a
# client-supplied value.
: "${LANG:=en_US.UTF-8}"
export LANG
