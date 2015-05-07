# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# http://mrjoelkemp.com/2013/06/remapping-iterm2-option-keys-for-fish-terminal/
bindkey "\e\[1\;9C" forward-word
bindkey "\e\[1\;9D" backward-word
bindkey "\e\[dw" backward-kill-word

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
#ZSH_THEME="robbyrussell"
ZSH_THEME="gamussa_skwp"

# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Set to this to use case-sensitive completion
# CASE_SENSITIVE="true"

# Comment this out to disable weekly auto-update checks
# DISABLE_AUTO_UPDATE="true"

# Uncomment following line if you want to disable colors in ls
# DISABLE_LS_COLORS="true"

# Uncomment following line if you want to disable autosetting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
COMPLETION_WAITING_DOTS="true"

HISTCONTROL=ignoredups:ignorespace

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(ant battery bower brew compleat encode64 Forklift gem git-extras gitfast glassfish gradle grails grunt heroku jsontools marked2 mercurial mvn node npm osx rake rbenv sublime svn web-search xcode z)

source $ZSH/oh-my-zsh.sh

# Customize to your needs...
#export NODE_PATH=/usr/local/lib/node
#AWESTRUCT_BIN=/Users/apple/projects/awestruct
#AVATAR_HOME=//Users/apple/projects/glassfish-4.0-release/glassfish
SENCHA_CMD_VERSION=4.0.4.84
DART_SDK=/Developer/dart/dart-sdk/
SENCHA_CMD_HOME=/Developer/Sencha/Cmd/$SENCHA_CMD_VERSION
export PATH=$DART_SDK/bin:/usr/local/bin:/opt/local/bin:/opt/local/sbin:/bin:/usr/sbin:/sbin:/usr/X11/bin:/opt/local/bin:/usr/local/git/bin:/usr/local/sbin:/usr/bin:$SENCHA_CMD_HOME:/usr/local/share/npm/bin:$JAVA_HOME/bin
export NODE_PATH=`brew --prefix node`
export NODE_PATH=$NODE_PATH:/usr/local/share/npm/lib/node_modules
export PATH=$PATH:$NODE_PATH/bin
export PATH="$HOME/.rbenv/bin:$PATH"
export SIMULATOR_HOME=~/hazelcast-simulator
PATH=$SIMULATOR_HOME/bin:$PATH
#export PATH="$AVATAR_HOME/bin:$PATH"

PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"
MANPATH="/usr/local/opt/coreutils/libexec/gnuman:$MANPATH"
test -e ~/.dircolors && eval `gdircolors -b ~/.dircolors`
alias ls="ls --color=always"
alias grep="grep --color=always"
alias egrep="egrep --color=always"

# Terminal 256 colors
export TERM="xterm-256color"

export EDITOR="subl -w"

#xmlcatalog

export XML_CATALOG_FILES="`brew --prefix`/etc/xml/catalog"
export HOMEBREW_CASK_OPTS="--appdir=/Applications"

export JRUBY_OPTS="-Xcompat.version=RUBY1_9 -Xcompile.mode=OFF -J-XX:+TieredCompilation -J-XX:TieredStopAtLevel=1 -J-Xverify:none -Xcext.enabled=true"

. `brew --prefix`/etc/profile.d/z.sh
eval "$(fasd --init auto)"

setjdk17

if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi

function gi() { curl -L -s https://www.gitignore.io/api/$@ ;}

source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

#THIS MUST BE AT THE END OF THE FILE FOR GVM TO WORK!!!
[[ -s "$HOME/.gvm/bin/gvm-init.sh" ]] && source "$HOME/.gvm/bin/gvm-init.sh"