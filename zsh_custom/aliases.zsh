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
alias c='pygmentize -O style=tomorrownighteighties -f console256 -g'
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

alias jjs='rlwrap $(/usr/libexec/java_home -v 1.8)/bin/jjs'

alias appleinfo="archey"
alias zshconfig="st ~/.zshrc"
alias ohmyzsh="st ~/.oh-my-zsh"

alias fuck='eval $(thefuck $(fc -ln -1 | tail -n 1)); fc -R'