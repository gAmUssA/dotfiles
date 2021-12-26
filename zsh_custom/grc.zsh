# grc overides for ls
#   Made possible through contributions from generous benefactors like
#   `brew install coreutils`

#if which gls >/dev/null 2>&1;
#then
#  alias ls="gls -F --color"
#  alias l="gls -lAh --color"
#  alias ll="gls -l --color"
#  alias la='gls -A --color'
#fi

# GRC colorizes nifty unix tools all over the place
if which grc >/dev/null 2>&1;
then
#    source ~/projects/grc/grc.zsh
  GRC="$(which grc)"
  alias colourify="$GRC -es"
  alias kubectl='colourify kubectl'
  alias ls='colourify lsd'
  alias docker='colourify docker'
  alias docker-compose='colourify docker-compose'
  alias ps='colourify ps'
fi

