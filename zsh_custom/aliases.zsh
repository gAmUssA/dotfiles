# Easier navigation: .., ..., ...., ....., ~ and -
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ~="cd ~" # `cd` is probably faster to type though
alias -- -="cd -"

# Shortcuts
alias d="cd ~/Documents/Dropbox"
alias dl="cd ~/Downloads"
alias dt="cd ~/Desktop"
alias p="cd ~/projects"
alias g="git"
alias h="history"
alias j="jobs"

alias sys_info='sw_vers'
alias reload!='. ~/.zshrc'
# Count files in subdirs
alias lll='for i in *; do echo "`ls -1aRi "$i" | awk "/^[0-9]+ / { print $1 }" | sort -u | wc -l` $i" ; done | sort -n'
alias grep='grep --color=auto'

# groovyserv
alias gs='groovyclient -Cenv-all'
alias senv='gs ~/senv'

# mongo for citi
alias citimongo='mongod --dbpath /Users/apple/projects/Farata/Citi/mondo/db/data --directoryperdb --smallfiles -v'

# local webserver
alias _w="open http://localhost:8000;python -m SimpleHTTPServer 8000"

# tree aliases
alias tree="eza --tree"
alias tree1="tree -L 1"
alias tree1h="tree -L 1 -h"
alias tree2="tree -L 2"
alias tree2h="tree -L 2 -h"
alias tree3="tree -L 3"
alias tree3h="tree -L 3 -h"

#git
alias g='git'

# mkdir, cd into it (via http://onethingwell.org/post/586977440/mkcd-improved)
function mkcd () {
    mkdir -p "$*"
    cd "$*"
}

# mkdir and touch file there (via https://unix.stackexchange.com/questions/305844/how-to-create-a-file-and-parent-directories-in-one-command#305850)
function mktouch() { 
  mkdir -p $(dirname $1)
  touch $1; 
}

# Based on http://schneems.com/post/41104255619/use-gifs-in-your-pull-request-for-good-not-evil
function convert-video-to-gif() {
  TMPFILE=$(mktemp -t gifvideo)
  echo "TMPFILE is $TMPFILE"
  echo "Converting..."
  ffmpeg -y -i "$1" -pix_fmt rgb24 -f gif "$TMPFILE"
  echo "Optimizing..."
  convert -verbose -layers Optimize "$TMPFILE" "$2"
  rm -f "$TMPFILE"
}

# https://gist.github.com/tlberglund/3714970
function gitwatch(){
        while :
        do
            clear
            git --no-pager log -n "$@" --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%ci) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative --all
            sleep 1
        done
}

# http://junegunn.kr/2015/03/browsing-git-commits-with-fzf/
# fshow - git commit browser (enter for show, ctrl-d for diff)
fshow() {
  local out shas sha q k
  while out=$(
      git log --graph --color=always \
          --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" "$@" |
      fzf --ansi --multi --no-sort --reverse --query="$q" \
          --print-query --expect=ctrl-d); do
    q=$(head -1 <<< "$out")
    k=$(head -2 <<< "$out" | tail -1)
    shas=$(sed '1,2d;s/^[^a-z0-9]*//;/^$/d' <<< "$out" | awk '{print $1}')
    [ -z "$shas" ] && continue
    if [ "$k" = ctrl-d ]; then
      git icdiff --color=always $shas | less -R
    else
      for sha in $shas; do
        git show --color=always $sha | less -R
      done
    fi
  done
}

alias jjs='rlwrap $(/usr/libexec/java_home -v 1.8)/bin/jjs'

alias appleinfo="archey"
alias zshconfig="st ~/.zshrc"
alias ohmyzsh="st ~/.oh-my-zsh"

alias fuck='eval $(thefuck $(fc -ln -1 | tail -n 1)); fc -R'
alias copypath='pwd|pbcopy'
alias ls="ls --color=always"
alias grep="grep --color=always"
alias egrep="egrep --color=always"

# hub alias for pull requests
alias github-pull-request="hub fork;git push -u gAmUssA HEAD;hub pull-request"

# new and awesome stuff
# brew install bat
#alias cat='bat'
#export BAT_THEME="GitHub"
#export BAT_THEME="OneHalfLight"
#export BAT_THEME="Solarized (light)"
export BAT_THEME="base16-256"
alias preview="fzf --preview 'bat --color \"always\" {}'"
alias c='bat'
alias cyml=c -lyaml
#alias c='pygmentize -O style=tomorrownighteighties -f console256 -g'
alias watch='watch '

# brew install prettyping
alias ping='prettyping --nolegend'

#brew install htop
alias top="sudo htop"

#brew install fd
alias du="ncdu --color dark -rr -x --exclude .git --exclude node_modules"

# brew install lsd
alias ls='lsd'

alias ll='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'

