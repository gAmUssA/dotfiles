# profile zsh startup
# zmodload zsh/zprof
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
# Terminal 256 colors
export TERM="xterm-256color"

export EDITOR='micro'

# history
export HISTFILE=~/.zsh_history # Where it gets saved
export HISTSIZE=10000
export SAVEHIST=10000
export HISTCONTROL=ignorespace:ignoredups
setopt append_history # Don't overwrite, append!
setopt INC_APPEND_HISTORY # Write after each command
setopt hist_expire_dups_first # Expire duplicate entries first when trimming history.
setopt hist_fcntl_lock # use OS file locking
setopt hist_ignore_all_dups # Delete old recorded entry if new entry is a duplicate.
setopt hist_lex_words # better word splitting, but more CPU heavy
setopt hist_reduce_blanks # Remove superfluous blanks before recording entry.
setopt hist_save_no_dups # Don't write duplicate entries in the history file.
setopt share_history # share history between multiple shells
setopt HIST_IGNORE_SPACE # Don't record an entry starting with a space.
setopt hist_reduce_blanks # remove superfluous blanks from history items
setopt inc_append_history # save history entries as soon as they are entered
setopt share_history # share history between different instances of the shell
setopt auto_cd # cd by typing directory name if it's not a command
#setopt correct_all # autocorrect commands
setopt auto_list # automatically list choices on ambiguous completion
setopt auto_menu # automatically use menu completion
setopt always_to_end # move cursor to end if word had one match

# Brew
export BREW_HOME=/opt/homebrew
export PATH="$BREW_HOME/bin:$BREW_HOME/sbin:$PATH"

# install zplug
# brew install zplug
export ZPLUG_HOME=$BREW_HOME/opt/zplug
source $ZPLUG_HOME/init.zsh

# Speeds up load time
DISABLE_UPDATE_PROMPT=true

# http://mrjoelkemp.com/2013/06/remapping-iterm2-option-keys-for-fish-terminal/
# bindkey "\e\[1\;9C" forward-word
# bindkey "\e\[1\;9D" backward-word
# bindkey "\e\[dw" backward-kill-word

# Base16 Shell
BASE16_SHELL="$HOME/.config/base16-shell/"
[ -n "$PS1" ] && \
    [ -s "$BASE16_SHELL/profile_helper.sh" ] && \
        eval "$("$BASE16_SHELL/profile_helper.sh")"

test -e ~/.dircolors && eval `gdircolors -b ~/.dircolors`

# tmux
alias tmux="TERM=screen-256color-bce tmux -u"
DISABLE_AUTO_TITLE=true

# chruby 
source $BREW_HOME/opt/chruby/share/chruby/chruby.sh
source $BREW_HOME/opt/chruby/share/chruby/auto.sh
RUBIES+=(~/.rbenv/versions/*)

# rbenv
#export PATH="$HOME/.rbenv/bin:$PATH"
#if type "rbenv" > /dev/null; then
#  eval "$(rbenv init -)"
#fi

#thefuck
# doens't work 🤷
#eval "$(thefuck --alias)"

## GCP completion
source "$BREW_HOME/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc"
source "$BREW_HOME/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc"
export USE_GKE_GCLOUD_AUTH_PLUGIN=True

## Go development
export GOPATH="${HOME}/.go"
# brew --prefix is slow
#export GOROOT="$(brew --prefix golang)/libexec"
export GOROOT="$BREW_HOME/opt/go/libexec"
export PATH="$PATH:${GOPATH}/bin:${GOROOT}/bin"

test -d "${GOPATH}" || mkdir "${GOPATH}"
test -d "${GOPATH}/src/github.com" || mkdir -p "${GOPATH}/src/github.com"
## end Go developement

zplug 'zplug/zplug', hook-build:'zplug --self-manage'

zplug "lib/history", from:oh-my-zsh
# Load completion library for those sweet [tab] squares
zplug "lib/completion", from:oh-my-zsh

#zplug plugins/sudo, from:oh-my-zsh
zplug plugins/git, from:oh-my-zsh
zplug plugins/git-extras, from:oh-my-zsh
zplug plugins/sublime, from:oh-my-zsh
#zplug plugins/z, from:oh-my-zsh
#zplug "agkozak/zsh-z"
zplug plugins/rake, from:oh-my-zsh
#zplug plugins/rbenv, from:oh-my-zsh
zplug plugins/gitignore, from:oh-my-zsh
zplug plugins/kubectl, from:oh-my-zsh, defer:2
zplug plugins/docker, from:oh-my-zsh
zplug plugins/docker-compose, from:oh-my-zsh
zplug plugins/helm, from:oh-my-zsh
zplug plugins/command-not-found, from:oh-my-zsh
zplug plugins/github, from:oh-my-zsh

#     # OS specific plugins
# What OS are we running?
if [[ `uname` == "Darwin" ]]; then
    zplug plugins/brew, from:oh-my-zsh
    zplug plugins/brew-cask, from:oh-my-zsh
    zplug plugins/gem, from:oh-my-zsh
    zplug plugins/macos, from:oh-my-zsh
# TODO: test on rPI
elif [[ $CURRENT_OS == 'Linux' ]]; then
    # None so far...
    if [[ $DISTRO == 'CentOS' ]]; then
        zplug plugins/centos, from:oh-my-zsh
    fi
elif [[ $CURRENT_OS == 'Cygwin' ]]; then
    zplug plugins/cygwin, from:oh-my-zsh
else
    echo 'Unknown OS!'
fi

zplug "zsh-users/zsh-history-substring-search"
if zplug check zsh-users/zsh-history-substring-search; then
  # zmodload zsh/terminfo
  bindkey "^[[A" history-substring-search-up
  bindkey "^[[B" history-substring-search-down
fi

# commented for screencasts
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
#ZSH_AUTOSUGGEST_STRATEGY=(completion)
ZSH_AUTOSUGGEST_USE_ASYNC=true
zplug "zsh-users/zsh-autosuggestions"
if zplug check zsh-users/zsh-autosuggestions; then
   ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(history-substring-search-up history-substring-search-down) # Add history-substring-search-* widgets to list of widgets that clear the autosuggestion
   ZSH_AUTOSUGGEST_CLEAR_WIDGETS=("${(@)ZSH_AUTOSUGGEST_CLEAR_WIDGETS:#(up|down)-line-or-history}") # Remove *-line-or-history widgets from list of widgets that clear the autosuggestion to avoid conflict with history-substring-search-* widgets
fi

zplug b4b4r07/enhancd, use:init.sh
# # zplug check returns true if the given repository exists
if zplug check b4b4r07/enhancd; then
#       # setting if enhancd is available
  export ENHANCD_FILTER=fzf
fi

# k
# Directory listings for zsh with git features.
# https://github.com/supercrabtree/k
# zplug 'supercrabtree/k'

# alias-tips
# Reminds you of aliases you have already.
# https://github.com/djui/alias-tips
zplug 'djui/alias-tips'

export NVM_LAZY_LOAD=true
zplug "lukechilds/zsh-nvm", from:github
zplug "lukechilds/zsh-better-npm-completion", from:github, defer:2

zplug "dabz/kafka-zsh-completions", use:kafka.plugin.zsh

#zplug "changyuheng/fz", defer:1
zplug "skywind3000/z.lua", use:z.lua.plugin.zsh
#zplug "rupa/z", use:z.sh

export FZF_DEFAULT_OPTS="
  --bind 'ctrl-f:page-down,ctrl-b:page-up,ctrl-o:execute(code {})+abort'
  --color fg:102,bg:233,hl:65,fg+:15,bg+:234,hl+:108
  --color info:108,prompt:109,spinner:108,pointer:168,marker:168
"

FZ_HISTORY_CD_CMD=_zlua
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

zplug "zsh-users/zsh-syntax-highlighting"

zplug romkatv/powerlevel10k, as:theme, depth:1
zplug "nnao45/zsh-kubectl-completion"

#zplug plugins/thefuck, from:oh-my-zsh
zplug "laggardkernel/zsh-thefuck", as:plugin, use:"zsh-thefuck.plugin.zsh"

zplug "~/projects/dotfiles/zsh_custom", from:local


if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
fi
zplug load
# zplug load --verbose

function get_cluster_short() {
  echo "$1" | cut -d . -f1
}
function get_namespace_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
  }
KUBE_PS1_BINARY=kubectl
KUBE_PS1_SYMBOL_USE_IMG=true
#KUBE_PS1_NAMESPACE_FUNCTION=get_namespace_upper
#KUBE_PS1_CLUSTER_FUNCTION=get_cluster_short

export PATH="${PATH}:${HOME}/.krew/bin"

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
[[ -s "${HOME}/.sdkman/bin/sdkman-init.sh" ]] && source "${HOME}/.sdkman/bin/sdkman-init.sh"
# end profiling
# zprof

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

source $BREW_HOME/opt/zplug/repos/dabz/kafka-zsh-completions/kafka.plugin.zsh
source $BREW_HOME/etc/grc.zsh

function kube-toggle() {
  if (( ${+POWERLEVEL9K_KUBECONTEXT_SHOW_ON_COMMAND} )); then
    unset POWERLEVEL9K_KUBECONTEXT_SHOW_ON_COMMAND
  else
    POWERLEVEL9K_KUBECONTEXT_SHOW_ON_COMMAND='kubectl|helm|kubens|kubectx|oc|istioctl|kogito|k9s|helmfile'
  fi
  p10k reload
  if zle; then
    zle push-input
    zle accept-line
  fi
}

unalias gm
source ~/.minikube-completion
source ~/.skaffold-completion
source ~/.kind-completion
source ~/.kuma-completion
source ~/.deck-completion
source ~/.confluent-completion
fpath+=~/.zfunc
fpath=($HOME/.zsh/gradle-completion $fpath)

export PATH=~/bin:$PATH

if type brew &>/dev/null
then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"

  autoload -Uz compinit
  compinit
fi

# adding shhist to PATH, so we can use it from Terminal
PATH="${PATH}:/Applications/ShellHistory.app/Contents/Helpers"

# creating an unique session id for each terminal session
__shhist_session="${RANDOM}"

# prompt function to record the history
__shhist_prompt() {
    local __exit_code="${?:-1}"
    \history -D -t "%s" -1 | sudo --preserve-env --user ${SUDO_USER:-${LOGNAME}} shhist insert --session ${TERM_SESSION_ID:-${__shhist_session}} --username ${LOGNAME} --hostname $(hostname) --exit-code ${__exit_code} --shell zsh
    return ${__exit_code}
}

# integrating prompt function in prompt
precmd_functions=(__shhist_prompt $precmd_functions)

#awscli completion 
complete -C '/opt/homebrew/bin/aws_completer' aws
#[[ -s "/Users/vikgamov/.gvm/scripts/gvm" ]] && source "/Users/vikgamov/.gvm/scripts/gvm"
