# grc overides for ls
#   Made possible through contributions from generous benefactors like
#   `brew install coreutils`

if which gls >/dev/null 2>&1;
then
  alias ls="gls -F --color"
  alias l="gls -lAh --color"
  alias ll="gls -l --color"
  alias la='gls -A --color'
fi

# GRC colorizes nifty unix tools all over the place
if which gls >/dev/null 2>&1;
then
  source `brew --prefix`/etc/grc.bashrc
fi