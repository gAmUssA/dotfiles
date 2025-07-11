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

# Speeds up load time
DISABLE_UPDATE_PROMPT=true

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

# Go development
export GOPATH="${HOME}/.go"
export GOROOT="$BREW_HOME/opt/go/libexec"
export PATH="$PATH:${GOPATH}/bin:${GOROOT}/bin"

test -d "${GOPATH}" || mkdir "${GOPATH}"
test -d "${GOPATH}/src/github.com" || mkdir -p "${GOPATH}/src/github.com"

# ===== ZINIT INITIALIZATION =====
# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# ===== ESSENTIAL PLUGINS (loaded immediately) =====
# Theme - load first for instant prompt
zinit ice depth=1; zinit light romkatv/powerlevel10k

# Core functionality
zinit light "zsh-users/zsh-autosuggestions"
zinit light "zsh-users/zsh-syntax-highlighting"
zinit light "zsh-users/zsh-history-substring-search"

# Auto suggestions config
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_USE_ASYNC=true

# History substring search bindings
bindkey "^[[A" history-substring-search-up
bindkey "^[[B" history-substring-search-down

# ===== LAZY LOADED PLUGINS =====
# Smart cd replacement with frecency algorithm  
# Initialize zoxide but don't let it override zi (keep zi for zinit)
eval "$(zoxide init zsh --no-cmd)"
function z() { __zoxide_z "$@" }
function zz() { __zoxide_zi "$@" }  # Interactive mode for zoxide
alias cd='z'

# Better npm completion
zinit ice wait'1' lucid; zinit light "lukechilds/zsh-better-npm-completion"

# Alias tips
zinit ice wait'1' lucid; zinit light "djui/alias-tips"

# thefuck
zinit ice wait'2' lucid; zinit light "laggardkernel/zsh-thefuck"

# Load custom aliases and functions
source ~/projects/dotfiles/zsh_custom/aliases.zsh

# fzf configuration
export FZF_DEFAULT_OPTS="
  --bind 'ctrl-f:page-down,ctrl-b:page-up,ctrl-o:execute(code {})+abort'
  --color fg:102,bg:233,hl:65,fg+:15,bg+:234,hl+:108
  --color info:108,prompt:109,spinner:108,pointer:168,marker:168
"

FZ_HISTORY_CD_CMD=_zlua
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# ===== LAZY LOADED HEAVY SERVICES =====
# Lazy load GCP SDK
gcp_lazy_load() {
    if [ ! -f "$HOME/.gcp_loaded" ]; then
        echo "Loading GCP SDK..."
        if [ -f "$BREW_HOME/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc" ]; then
            source "$BREW_HOME/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc"
        fi
        if [ -f "$BREW_HOME/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc" ]; then
            source "$BREW_HOME/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc"
        fi
        export USE_GKE_GCLOUD_AUTH_PLUGIN=True
        touch "$HOME/.gcp_loaded"
    fi
}

# Override gcloud command to lazy load
gcloud() {
    unfunction gcloud
    gcp_lazy_load
    command gcloud "$@"
}

# Lazy load SDKMAN
sdk_lazy_load() {
    if [ ! -f "$HOME/.sdkman_loaded" ] && [[ -s "${HOME}/.sdkman/bin/sdkman-init.sh" ]]; then
        echo "Loading SDKMAN..."
        source "${HOME}/.sdkman/bin/sdkman-init.sh"
        touch "$HOME/.sdkman_loaded"
    fi
}

# Override sdk command to lazy load
sdk() {
    unfunction sdk
    sdk_lazy_load
    command sdk "$@"
}

# Lazy load NVM for faster startup
export NVM_DIR="$HOME/.nvm"
nvm() {
    unset -f nvm
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
    [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
    nvm "$@"
}

# Kubernetes functions
function get_cluster_short() {
  echo "$1" | cut -d . -f1
}

function get_namespace_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

KUBE_PS1_BINARY=kubectl
KUBE_PS1_SYMBOL_USE_IMG=true

export PATH="${PATH}:${HOME}/.krew/bin"

# Kubernetes toggle function
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

unalias gm 2>/dev/null || true

# Completion paths
fpath+=~/.zfunc
fpath=($HOME/.zsh/gradle-completion $fpath)

export PATH=~/bin:$PATH

# Initialize completions
autoload -Uz compinit
compinit

# Load additional completion functions
autoload -U +X bashcompinit && bashcompinit

# Additional completion options
setopt complete_in_word
setopt glob_complete



# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu select

# Directory completion
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories
zstyle ':completion:*:cd:*' group-order local-directories path-directories
zstyle ':completion:*:cd:*' accept-exact-dirs true

# Brew completions
if type brew &>/dev/null; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi

# Shell History integration
PATH="${PATH}:/Applications/ShellHistory.app/Contents/Helpers"
__shhist_session="${RANDOM}"

__shhist_prompt() {
    local __exit_code="${?:-1}"
    \history -D -t "%s" -1 | sudo --preserve-env --user ${SUDO_USER:-${LOGNAME}} shhist insert --session ${TERM_SESSION_ID:-${__shhist_session}} --username ${LOGNAME} --hostname $(hostname) --exit-code ${__exit_code} --shell zsh
    return ${__exit_code}
}

precmd_functions=(__shhist_prompt $precmd_functions)

# AWS completion (will be loaded automatically when needed)

# Auto-install completions for CLI tools (smart startup)
if [[ -f ~/projects/dotfiles/install-completions.sh ]]; then
    # Only run completion installer if:
    # 1. It's been more than 7 days since last run, OR
    # 2. No completion check file exists
    local completion_check_file="$HOME/.completion-last-check"
    local should_run=false
    
    if [[ ! -f "$completion_check_file" ]]; then
        should_run=true
    else
        local last_check=$(cat "$completion_check_file" 2>/dev/null || echo 0)
        local current_time=$(date +%s)
        local days_since_check=$(( (current_time - last_check) / 86400 ))
        
        if [[ $days_since_check -gt 7 ]]; then
            should_run=true
        fi
    fi
    
    if $should_run; then
        # Run in background and update check file
        (
            ~/projects/dotfiles/install-completions.sh > /dev/null 2>&1
            echo "$(date +%s)" > "$completion_check_file"
        ) &
    fi
fi

# Windsurf
export PATH="/Users/vikgamov/.codeium/windsurf/bin:$PATH"


# direnv
eval "$(direnv hook zsh)"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Final cleanup: ensure zoxide owns cd command
unalias cd 2>/dev/null || true
unfunction __enhancd::cd 2>/dev/null || true
eval "$(zoxide init zsh --no-cmd)"
function z() { __zoxide_z "$@" }
function zz() { __zoxide_zi "$@" }
alias cd='z'

# end profiling
# zprof
complete -o nospace -C /opt/homebrew/bin/terraform terraform
