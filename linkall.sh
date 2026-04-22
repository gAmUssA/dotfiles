#!/bin/sh
rm ~/.zshrc
rm -rf ~/.oh-my-zsh/custom
rm ~/.gitconfig
rm ~/.gitignore
rm ~/.jshintrc
rm ~/.inputrc
rm ~/.tigrc
rm ~/.ssh/config
rm ~/.dircolors
rm ~/.mackup.cfg
rm ~/.antigen.zsh
rm ~/.tmux.conf
rm ~/.vimrc
rm ~/.p10k.zsh

ln -s ~/projects/dotfiles/antigen.zsh ~/.antigen.zsh
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
ln -s ~/projects/dotfiles/.deck.yaml ~/.deck.yaml

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

# Claude Code config (settings + custom statusline + stop hook script)
# Skips settings.local.json — that's meant to stay per-machine.
mkdir -p ~/.claude
rm -f ~/.claude/settings.json ~/.claude/statusline.sh ~/.claude/stop-hook.sh
ln -s ~/projects/dotfiles/claude/settings.json ~/.claude/settings.json
ln -s ~/projects/dotfiles/claude/statusline.sh ~/.claude/statusline.sh
ln -s ~/projects/dotfiles/claude/stop-hook.sh ~/.claude/stop-hook.sh

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
ls -lah ~/.antigen.zsh
ls -lah ~/.tmux.conf
ls -lah ~/.p10k.zsh
ls -lah ~/.deck.yaml
ls -lah "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
ls -lah ~/.config/cmux/settings.json
ls -lah ~/.claude/settings.json ~/.claude/statusline.sh ~/.claude/stop-hook.sh
