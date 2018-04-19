# Terminal 256 colors
export TERM="xterm-256color"

# http://mrjoelkemp.com/2013/06/remapping-iterm2-option-keys-for-fish-terminal/
bindkey "\e\[1\;9C" forward-word
bindkey "\e\[1\;9D" backward-word
bindkey "\e\[dw" backward-kill-word

test -e ~/.dircolors && eval `gdircolors -b ~/.dircolors`

# init antigen
source ~/.antigen.zsh

antigen use oh-my-zsh

# slooow
# antigen bundle zsh-users/zsh-autosuggestions

# antigen bundle rupa/z
antigen bundles <<EOBUNDLES
    git
    zsh-users/zsh-syntax-highlighting
    command-not-found

    # The heroku tool helper plugin.
    heroku
    # fzf-z plugin ctrl+G
    andrewferrier/fzf-z
    robbyrussell/oh-my-zsh plugins/sublime
    robbyrussell/oh-my-zsh plugins/z
    robbyrussell/oh-my-zsh plugins/rake
    robbyrussell/oh-my-zsh plugins/rbenv
    robbyrussell/oh-my-zsh plugins/gitignore
    robbyrussell/oh-my-zsh plugins/kubectl
    robbyrussell/oh-my-zsh plugins/docker
    robbyrussell/oh-my-zsh plugins/docker-compose
    robbyrussell/oh-my-zsh plugins/helm

    # command autocorrection with thefuck script
    # robbyrussell/oh-my-zsh plugins/thefuck

    # custom aliases
    $HOME/projects/dotfiles/zsh_custom
EOBUNDLES

# pure prompt
antigen bundle mafredri/zsh-async
antigen bundle sindresorhus/pure

# OS specific plugins
if [[ $CURRENT_OS == 'OS X' ]]; then
    antigen bundle brew
    antigen bundle brew-cask
    antigen bundle gem
    antigen bundle osx
elif [[ $CURRENT_OS == 'Linux' ]]; then
    # None so far...

    if [[ $DISTRO == 'CentOS' ]]; then
        antigen bundle centos
    fi
elif [[ $CURRENT_OS == 'Cygwin' ]]; then
    antigen bundle cygwin
fi

# Tell Antigen that you're done.
antigen apply

export FZF_DEFAULT_OPTS='
  --bind ctrl-f:page-down,ctrl-b:page-up
  --color fg:102,bg:233,hl:65,fg+:15,bg+:234,hl+:108
  --color info:108,prompt:109,spinner:108,pointer:168,marker:168
'

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# tmux
alias tmux="TERM=screen-256color-bce tmux -u"
DISABLE_AUTO_TITLE=true

# Brew
export PATH="/usr/local/bin:$PATH"

# rbenv
export PATH="$HOME/.rbenv/bin:$PATH"
if type "rbenv" > /dev/null; then
  eval "$(rbenv init -)"
fi

# Hazelcast Simulator
export SIMULATOR_HOME=~/hazelcast-simulator
PATH=$SIMULATOR_HOME/bin:$PATH

#thefuck
#eval "$(thefuck --alias)"

# NVM integration
export NVM_LAZY_LOAD=true
antigen bundle lukechilds/zsh-nvm

# tabtab source for jhipster package
# uninstall by removing these lines or running `tabtab uninstall jhipster`
[[ -f /Users/apple/.config/yarn/global/node_modules/tabtab/.completions/jhipster.zsh ]] && . /Users/apple/.config/yarn/global/node_modules/tabtab/.completions/jhipster.zsh

#THIS MUST BE AT THE END OF THE FILE FOR GVM TO WORK!!!
export SDKMAN_DIR="${HOME}/.sdkman" && source "${HOME}/.sdkman/bin/sdkman-init.sh"

# confluent platform
# TEMP - figure out way to switch different versions - oss vs ent, 3.3, 3.4, etc
# symlink
export CONFLUENT_PLATFORM_VERSION=4.1.0
export CONFLUENT_HOME=~/projects/confluent/confluent-oss/$CONFLUENT_PLATFORM_VERSION
export PATH=$CONFLUENT_HOME/bin:$PATH
# GCP completion
source '/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc'
source '/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc'
export PATH=$PATH:~/.fabric8/bin
