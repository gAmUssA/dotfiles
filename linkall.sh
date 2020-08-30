#!/bin/sh
rm ~/.zshrc
rm -rf ~/.oh-my-zsh/custom
# rm ~/.oh-my-zsh/themes/gamussa_skwp.zsh-theme
# rm ~/.oh-my-zsh/themes/bullet-train.zsh-theme
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
# ln -s ~/projects/dotfiles/zsh_custom ~/.oh-my-zsh/custom
# ln -s ~/projects/dotfiles/gamussa_skwp.zsh-theme ~/.oh-my-zsh/themes/gamussa_skwp.zsh-theme
# ln -s ~/projects/dotfiles/bullet-train.zsh-theme ~/.oh-my-zsh/themes/bullet-train.zsh-theme
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

# ls -lah ~/.zshrc
# ls -lah ~/.oh-my-zsh/custom
# ls -lah ~/.oh-my-zsh/themes/gamussa_skwp.zsh-theme
# ls -lah ~/.oh-my-zsh/themes/bullet-train.zsh-theme
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

rm -r ~/.atom
ln -s ~/Dropbox/Apps/Atom ~/.atom
ls -lah ~/.atom