# OPENSPEC:START
# OpenSpec shell completions configuration
# NOTE: compinit is intentionally NOT called here — it runs once later in this
# file, after all fpath additions (zinit plugins, .zfunc, brew site-functions).
# If OpenSpec's installer re-adds `compinit` here, delete it again.
fpath=("$HOME/.zsh/completions" $fpath)
# OPENSPEC:END

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

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

export EDITOR='micro'

# history
export HISTFILE=~/.zsh_history # Where it gets saved
export HISTSIZE=10000
export SAVEHIST=10000
# Note: HISTCONTROL is a bash variable; zsh uses hist_ignore_space / hist_ignore_dups below.
setopt append_history # Don't overwrite, append!
setopt inc_append_history # Write after each command (save entries as soon as entered)
setopt hist_expire_dups_first # Expire duplicate entries first when trimming history.
setopt hist_fcntl_lock # use OS file locking
setopt hist_ignore_all_dups # Delete old recorded entry if new entry is a duplicate.
setopt hist_lex_words # better word splitting, but more CPU heavy
setopt hist_reduce_blanks # Remove superfluous blanks before recording entry.
setopt hist_save_no_dups # Don't write duplicate entries in the history file.
setopt share_history # share history between multiple shells
setopt hist_ignore_space # Don't record an entry starting with a space.
setopt auto_cd # cd by typing directory name if it's not a command
#setopt correct_all # autocorrect commands
setopt auto_list # automatically list choices on ambiguous completion
setopt auto_menu # automatically use menu completion
setopt always_to_end # move cursor to end if word had one match

# Brew
export BREW_HOME=/opt/homebrew
export PATH="$BREW_HOME/bin:$BREW_HOME/sbin:$PATH"

# GNU make
export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"

# (Removed DISABLE_UPDATE_PROMPT — Oh-My-Zsh var, no effect under zinit)

# Base16 Shell
BASE16_SHELL="$HOME/.config/base16-shell/"
[ -n "$PS1" ] && \
    [ -s "$BASE16_SHELL/profile_helper.sh" ] && \
        eval "$("$BASE16_SHELL/profile_helper.sh")"

test -e ~/.dircolors && eval `gdircolors -b ~/.dircolors`

# tmux (let .tmux.conf own default-terminal; no TERM override needed)
alias tmux="tmux -u"

# chruby 
source $BREW_HOME/opt/chruby/share/chruby/chruby.sh
source $BREW_HOME/opt/chruby/share/chruby/auto.sh
RUBIES+=(~/.rbenv/versions/*)

# Go development (Go detects GOROOT automatically since 1.10; don't pin it)
export GOPATH="${HOME}/.go"
export PATH="$PATH:${GOPATH}/bin"

test -d "${GOPATH}" || mkdir -p "${GOPATH}/src/github.com"

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
# Oh-my-zsh plugins (from backup config)
# Note: kubectl, helm, docker, github completions are managed by install-completions.sh
zinit ice wait'1' lucid; zinit snippet OMZP::git
zinit ice wait'1' lucid; zinit snippet OMZP::git-extras
zinit ice wait'1' lucid; zinit snippet OMZP::rake
zinit ice wait'1' lucid; zinit snippet OMZP::gitignore
zinit ice wait'1' lucid; zinit snippet OMZP::docker-compose
zinit ice wait'1' lucid; zinit snippet OMZP::brew
zinit ice wait'1' lucid; zinit snippet OMZP::gem
zinit ice wait'1' lucid; zinit snippet OMZP::gradle

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

# Lazy load SDKMAN for faster startup
export SDKMAN_DIR="$HOME/.sdkman"
_sdk_lazy_load() {
    unset -f sdk java gradle mvn kotlin groovy 2>/dev/null
    unalias gradle 2>/dev/null  # Remove OMZ gradle alias if present
    [[ -s "${SDKMAN_DIR}/bin/sdkman-init.sh" ]] && source "${SDKMAN_DIR}/bin/sdkman-init.sh"
}
sdk() { _sdk_lazy_load; sdk "$@"; }
java() { _sdk_lazy_load; java "$@"; }
unalias gradle 2>/dev/null; gradle() { _sdk_lazy_load; gradle "$@"; }
mvn() { _sdk_lazy_load; mvn "$@"; }
kotlin() { _sdk_lazy_load; kotlin "$@"; }
groovy() { _sdk_lazy_load; groovy "$@"; }

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

# Completion paths — all fpath additions must happen BEFORE compinit
fpath+=~/.zfunc
fpath=($HOME/.zsh/gradle-completion $fpath)

# Brew completions (must be in fpath before compinit, not FPATH after)
fpath=(/opt/homebrew/share/zsh/site-functions $fpath)

export PATH=~/bin:$PATH

# Initialize completions (single authoritative call, after all fpath additions)
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

# Shell History integration
PATH="${PATH}:/Applications/ShellHistory.app/Contents/Helpers"
__shhist_session="${RANDOM}"

__shhist_prompt() {
    local __exit_code="${?:-1}"
    \history -D -t "%s" -1 | shhist insert --session ${TERM_SESSION_ID:-${__shhist_session}} --username ${LOGNAME} --hostname $(hostname) --exit-code ${__exit_code} --shell zsh
    return ${__exit_code}
}

# Guard against double-registration on re-source (e.g., `exec zsh` or `reload!`)
if (( ! ${precmd_functions[(Ie)__shhist_prompt]} )); then
    precmd_functions=(__shhist_prompt $precmd_functions)
fi

# AWS CLI v2 completion (requires bashcompinit, loaded above)
if command -v aws_completer >/dev/null 2>&1; then
    complete -C aws_completer aws
fi

# Auto-install completions for CLI tools (runs at most once per 7 days)
__maybe_install_completions() {
    local installer=~/projects/dotfiles/install-completions.sh
    [[ -f $installer ]] || return 0

    local check_file="$HOME/.completion-last-check"
    local should_run=false

    if [[ ! -f $check_file ]]; then
        should_run=true
    else
        local last_check=$(cat "$check_file" 2>/dev/null || echo 0)
        local days=$(( ( $(date +%s) - last_check ) / 86400 ))
        (( days > 7 )) && should_run=true
    fi

    if $should_run; then
        # Disown so shell exit doesn't wait/HUP the background job
        ( "$installer" >/dev/null 2>&1; date +%s > "$check_file" ) &!
    fi
}
__maybe_install_completions
unset -f __maybe_install_completions

# Windsurf
export PATH="/Users/vikgamov/.codeium/windsurf/bin:$PATH"


# direnv
eval "$(direnv hook zsh)"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# end profiling
# zprof
complete -o nospace -C /opt/homebrew/bin/terraform terraform
export PATH="/Users/vikgamov/projects/kafka/kwack-dist/bin:$PATH"

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# To enable command-not-found
# Add the following lines to ~/.zshrc

HOMEBREW_COMMAND_NOT_FOUND_HANDLER="/opt/homebrew/Library/Homebrew/command-not-found/handler.sh"
if [ -f "$HOMEBREW_COMMAND_NOT_FOUND_HANDLER" ]; then
  source "$HOMEBREW_COMMAND_NOT_FOUND_HANDLER";
fi

. "$HOME/.cargo/env"
# uv
export PATH="/Users/vikgamov/.local/bin:$PATH"
# bun completions
[ -s "/Users/vikgamov/.bun/_bun" ] && source "/Users/vikgamov/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi

# zoxide - MUST be last in .zshrc
export _ZO_DOCTOR=0
eval "$(zoxide init zsh --no-cmd)"
function z() { __zoxide_z "$@" }
function zz() { __zoxide_zi "$@" }
alias cd='z'
