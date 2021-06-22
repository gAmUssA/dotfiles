# https://unix.stackexchange.com/a/10065
# if stdout is a terminal
if test -t 1; then
    # see if it supports colors
    ncolors=$(tput colors)
    if test -n "$ncolors" && test $ncolors -ge 8; then
        bold="$(tput bold)"
        underline="$(tput smul)"
        standout="$(tput smso)"
        normal="$(tput sgr0)"
        black="$(tput setaf 0)"
        red="$(tput setaf 1)"
        green="$(tput setaf 2)"
        yellow="$(tput setaf 3)"
        blue="$(tput setaf 4)"
        magenta="$(tput setaf 5)"
        cyan="$(tput setaf 6)"
        white="$(tput setaf 7)"
    fi
fi

kubectl get pods "$@" \
        | sed "s/Running/${green}Running${normal}/g" \
        | sed "s/Pending/${yellow}Pending${normal}/g" \
        | sed "s/Completed/${blue}Completed${normal}/g" \
        | sed "s/Error/${red}Error${normal}/g" \
        | sed "s/CrashLoopBackOff/${red}CrashLoopBackOff${normal}/g"