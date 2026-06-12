#!/bin/sh
# rm -f everywhere: quiet on a fresh machine (no "No such file" spam) and
# guarantees the following ln -s can't silently no-op against a leftover file.
rm -f ~/.zshrc
rm -f ~/.gitconfig
rm -f ~/.gitignore
rm -f ~/.jshintrc
rm -f ~/.inputrc
rm -f ~/.tigrc
rm -f ~/.ssh/config
rm -f ~/.dircolors
rm -f ~/.mackup.cfg
rm -f ~/.tmux.conf
rm -f ~/.vimrc
rm -f ~/.p10k.zsh

ln -s ~/projects/dotfiles/.zshrc ~/.zshrc
ln -s ~/projects/dotfiles/.gitconfig ~/.gitconfig
ln -s ~/projects/dotfiles/.gitignore ~/.gitignore
ln -s ~/projects/dotfiles/.jshintrc ~/.jshintrc
ln -s ~/projects/dotfiles/.inputrc ~/.inputrc
ln -s ~/projects/dotfiles/.tigrc ~/.tigrc
ln -s ~/projects/dotfiles/.vimrc ~/.vimrc
ln -s ~/projects/dotfiles/.ssh/config ~/.ssh/config
ln -s ~/projects/dotfiles/.dircolors ~/.dircolors
ln -s ~/projects/dotfiles/.mackup.cfg ~/.mackup.cfg
ln -s ~/projects/dotfiles/.tmux.conf ~/.tmux.conf
ln -s ~/projects/dotfiles/.p10k.zsh ~/.p10k.zsh

# Ghostty terminal config
# On macOS, Ghostty loads ~/Library/Application Support/com.mitchellh.ghostty/config
# AFTER the XDG path, so the macOS-native one wins on conflicts. Put the symlink there
# and drop the XDG one to avoid split-brain config.
GHOSTTY_MACOS_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
mkdir -p "$GHOSTTY_MACOS_DIR"
rm -f "$GHOSTTY_MACOS_DIR/config"
ln -s ~/projects/dotfiles/ghostty/config "$GHOSTTY_MACOS_DIR/config"
rm -rf ~/.config/ghostty

# cmux terminal config
mkdir -p ~/.config/cmux
rm -f ~/.config/cmux/settings.json
ln -s ~/projects/dotfiles/cmux/settings.json ~/.config/cmux/settings.json

# sesh — tmux session manager config
mkdir -p ~/.config/sesh
rm -f ~/.config/sesh/sesh.toml
ln -s ~/projects/dotfiles/sesh/sesh.toml ~/.config/sesh/sesh.toml

# Claude Code config (settings + custom statusline + stop hook script)
# Skips settings.local.json — that's meant to stay per-machine.
mkdir -p ~/.claude
rm -f ~/.claude/settings.json ~/.claude/statusline.sh ~/.claude/stop-hook.sh ~/.claude/block-secrets.py
ln -s ~/projects/dotfiles/claude/settings.json ~/.claude/settings.json
ln -s ~/projects/dotfiles/claude/statusline.sh ~/.claude/statusline.sh
ln -s ~/projects/dotfiles/claude/stop-hook.sh ~/.claude/stop-hook.sh
ln -s ~/projects/dotfiles/claude/block-secrets.py ~/.claude/block-secrets.py

# Local AI coding agents — Ollama provider configs only. Machine state
# (opencode node_modules/bun.lock, pi auth.json/sessions/settings.json) is
# deliberately NOT versioned, so symlink the single config file in each.
mkdir -p ~/.config/opencode ~/.pi/agent ~/.agents/skills
rm -f ~/.config/opencode/opencode.json ~/.pi/agent/models.json
ln -s ~/projects/dotfiles/opencode/opencode.json ~/.config/opencode/opencode.json
ln -s ~/projects/dotfiles/pi/models.json ~/.pi/agent/models.json
# Shared agent skill (SKILL.md open standard) in the universal ~/.agents/skills
# location — discovered by OpenCode, Pi, AND Claude Code alike. Pi has no MCP,
# so web search is a skill (CLI tool + SKILL.md) rather than an MCP server.
rm -rf ~/.agents/skills/tavily-search
ln -s ~/projects/dotfiles/agents/skills/tavily-search ~/.agents/skills/tavily-search

# micro editor — file-level symlinks (NOT the whole dir: micro keeps machine
# state in ~/.config/micro/backups and buffers alongside the config).
mkdir -p ~/.config/micro
rm -f ~/.config/micro/settings.json ~/.config/micro/bindings.json
ln -s ~/projects/dotfiles/micro/settings.json ~/.config/micro/settings.json
ln -s ~/projects/dotfiles/micro/bindings.json ~/.config/micro/bindings.json

# Karabiner-Elements — whole-directory symlink (the approach Karabiner's sync
# docs support; file-level symlinks are risky because the GUI rewrites
# karabiner.json on every change). automatic_backups/ inside is gitignored.
# Restart the user server after linking so it picks up the new path.
if [ -d ~/.config/karabiner ] && [ ! -L ~/.config/karabiner ]; then
  mv ~/.config/karabiner ~/.config/karabiner.pre-symlink-backup
fi
rm -f ~/.config/karabiner
ln -s ~/projects/dotfiles/karabiner ~/.config/karabiner
launchctl kickstart -k "gui/$(id -u)/org.pqrs.service.agent.karabiner_console_user_server" 2>/dev/null

# Hammerspoon — entry point + caffeine + ollama menubar modules.
# File-level symlinks so anything else in ~/.hammerspoon (Spoons/, scratch
# files, Hammerspoon's own state) is left alone.
mkdir -p ~/.hammerspoon
rm -f ~/.hammerspoon/init.lua ~/.hammerspoon/caffeine.lua ~/.hammerspoon/ollama.lua ~/.hammerspoon/claude_sessions.lua
ln -s ~/projects/dotfiles/hammerspoon/init.lua ~/.hammerspoon/init.lua
ln -s ~/projects/dotfiles/hammerspoon/caffeine.lua ~/.hammerspoon/caffeine.lua
ln -s ~/projects/dotfiles/hammerspoon/ollama.lua ~/.hammerspoon/ollama.lua
ln -s ~/projects/dotfiles/hammerspoon/claude_sessions.lua ~/.hammerspoon/claude_sessions.lua

ls -lah ~/.zshrc
ls -lah ~/.gitconfig
ls -lah ~/.gitignore
ls -lah ~/.jshintrc
ls -lah ~/.inputrc
ls -lah ~/.tigrc
ls -lah ~/.vimrc
ls -lah ~/.ssh/config
ls -lah ~/.dircolors
ls -lah ~/.mackup.cfg
ls -lah ~/.tmux.conf
ls -lah ~/.p10k.zsh
ls -lah "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
ls -lah ~/.config/cmux/settings.json
ls -lah ~/.claude/settings.json ~/.claude/statusline.sh ~/.claude/stop-hook.sh
ls -lah ~/.hammerspoon/init.lua ~/.hammerspoon/caffeine.lua ~/.hammerspoon/ollama.lua ~/.hammerspoon/claude_sessions.lua
ls -lah ~/.config/opencode/opencode.json ~/.pi/agent/models.json ~/.agents/skills/tavily-search

# thefuck — installed via pipx pinned to python@3.11 (the brew formula has a
# stale openssl@1.1 dep, and thefuck 3.32 imports `distutils` which Python
# 3.12+ removed). Idempotent: re-runs only if not already installed.
if command -v pipx >/dev/null 2>&1; then
  if ! pipx list 2>/dev/null | grep -q "package thefuck"; then
    if [ -x /opt/homebrew/bin/python3.11 ]; then
      pipx install --python /opt/homebrew/bin/python3.11 thefuck
    else
      echo "skip: thefuck install — install python@3.11 first (brew install python@3.11)"
    fi
  fi
fi
