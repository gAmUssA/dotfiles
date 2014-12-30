#!/bin/sh
rm ~/.zshrc
rm -rf ~/.oh-my-zsh/custom
rm ~/.oh-my-zsh/themes/gamussa_skwp.zsh-theme

ln -s ~/projects/gamussa-dotfiles/.zshrc ~/.zshrc
ln -s ~/projects/gamussa-dotfiles/zsh_custom ~/.oh-my-zsh/custom
ln -s ~/projects/gamussa-dotfiles/gamussa_skwp.zsh-theme ~/.oh-my-zsh/themes/gamussa_skwp.zsh-theme

ls -lah ~/.zshrc
ls -lah ~/.oh-my-zsh/custom
ls -lah ~/.oh-my-zsh/themes/gamussa_skwp.zsh-theme