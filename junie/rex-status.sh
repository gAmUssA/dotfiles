#!/bin/sh

# Junie captures hook stdout, so status reports must go directly to the pane.
[ -n "${REX_BLOCK:-}" ] || exit 0
exec 2>/dev/null 3>/dev/tty || exit 0

event=${1:-}
case "$event" in
  SessionStart)
    source=$(python3 -c 'import json,sys; print(json.loads(sys.stdin.readline()).get("source", ""))' 2>/dev/null) || exit 0
    [ "$source" = compact ] && exit 0
    report='state=idle:id=junie:app=junie'
    ;;
  UserPromptSubmit|PreToolUse)
    report='state=working:id=junie:app=junie'
    ;;
  PermissionRequest)
    report='state=blocked:kind=permission:id=junie:app=junie'
    ;;
  Stop)
    report='state=done:id=junie:app=junie'
    ;;
  StopFailure)
    report='state=error:id=junie:app=junie'
    ;;
  SessionEnd)
    report='state=clear:id=junie'
    ;;
  *)
    exit 0
    ;;
esac

if [ -n "${TMUX:-}" ]; then
  # tmux only forwards wrapped passthrough sequences when allow-passthrough is on.
  printf '\033Ptmux;\033\033]7501;%s\033\033\\\033\\' "$report" >&3 || :
else
  printf '\033]7501;%s\033\\' "$report" >&3 || :
fi

exit 0