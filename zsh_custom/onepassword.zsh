# 1Password-backed secrets, without a Touch ID popup in every terminal.
#
# THE PROBLEM
# The 1Password desktop-app CLI integration keys its authorization to
# `tty` + process start time, with a 10-minute inactivity window and a 12-hour
# hard ceiling. That means every new window, tab, and tmux pane is a fresh tty
# and therefore a fresh biometric prompt — and there is no setting to widen the
# scope or extend the lifetime. Calling `op read` from .zshrc.local made every
# single shell pay that prompt, plus ~6 sequential op round-trips, even though
# almost no shell ever touches a secret.
#   https://www.1password.dev/cli/app-integration-security/
#
# THE SHAPE OF THE FIX
# 1Password stays the source of truth. The login keychain is a derived cache:
#   opsync    resolve every op:// ref in one `op inject` call (ONE prompt) and
#             stash the resolved values in the login keychain.
#   opload    hydrate the current shell from that cache. Runs automatically at
#             shell start — ~20ms, no network, no prompt.
#   opx       escape hatch: run one command with values pulled fresh from
#             1Password, bypassing the cache entirely.
#
# Re-run `opsync` when you rotate a key or add a ref. Nothing else needs doing.
#
# TRADE-OFF, STATED PLAINLY: cached values live in the macOS login keychain
# (encrypted at rest, readable by local processes while you are logged in)
# rather than behind a per-use biometric gate. That is strictly better than the
# plaintext exports this replaced, and weaker than a Touch ID tap per read. If
# you want the gate back for a specific tool, launch it with `opx`.

export OP_AGENTS_REFS="${OP_AGENTS_REFS:-$HOME/.config/op/agents.refs}"
export OP_KEYCHAIN_SERVICE="${OP_KEYCHAIN_SERVICE:-dotfiles-agent-secrets}"

# Names of the vars this module manages, derived from the refs file so the file
# stays the single source of truth.
_op_var_names() {
  [[ -r $OP_AGENTS_REFS ]] || return 1
  sed -nE 's|^([A-Za-z_][A-Za-z0-9_]*)=op://.*$|\1|p' "$OP_AGENTS_REFS"
}

# Resolve all refs against 1Password and cache them in the login keychain.
# Costs exactly one biometric prompt regardless of how many refs there are.
opsync() {
  if ! command -v op >/dev/null 2>&1; then
    print -u2 "opsync: 1Password CLI not found (brew install 1password-cli)"
    return 1
  fi
  if [[ ! -r $OP_AGENTS_REFS ]]; then
    print -u2 "opsync: no reference file at $OP_AGENTS_REFS"
    return 1
  fi

  # dotenv refs -> op inject template, so one op call resolves everything.
  #   FOO=op://v/i/f   ->   FOO={{ op://v/i/f }}
  # `sed -n ... p` emits ONLY assignment lines. That is load-bearing: op inject
  # also resolves bare `op://...` strings found in plain prose, so passing the
  # comment block through would make it try to resolve the examples in it.
  local resolved
  if ! resolved=$(sed -nE 's|^([A-Za-z_][A-Za-z0-9_]*)=(op://.+)$|\1={{ \2 }}|p' \
                    "$OP_AGENTS_REFS" | op inject 2>&1); then
    print -u2 "opsync: op inject failed — nothing was cached. op said:"
    print -u2 "$resolved"
    return 1
  fi

  # base64 so newlines survive the keychain round-trip intact: `security -w`
  # switches to hex output for values containing non-printable bytes, and
  # base64 keeps it unambiguously printable in both directions.
  local blob
  blob=$(printf '# synced %s\n%s\n' "$(date +%s)" "$resolved" | base64)

  if ! security add-generic-password -U \
         -a "$USER" -s "$OP_KEYCHAIN_SERVICE" \
         -w "$blob" -T /usr/bin/security 2>/dev/null; then
    print -u2 "opsync: failed writing to the login keychain"
    return 1
  fi

  local n
  n=$(_op_var_names | wc -l | tr -d ' ')
  print "opsync: cached $n secrets to keychain service '$OP_KEYCHAIN_SERVICE'"
  opload
}

# Load cached secrets into the current shell. Silent and non-fatal by design —
# this runs at shell start, and printing here would trip p10k's instant prompt.
opload() {
  local blob
  blob=$(security find-generic-password -w -s "$OP_KEYCHAIN_SERVICE" -a "$USER" 2>/dev/null) || return 1
  blob=$(print -r -- "$blob" | base64 -d 2>/dev/null) || return 1
  [[ -n $blob ]] || return 1

  local line key
  while IFS= read -r line; do
    [[ -z $line || $line == '#'* ]] && continue
    key=${line%%=*}
    # Valid identifier check that does not depend on EXTENDED_GLOB being set:
    # strip every legal character and require nothing to be left over.
    [[ -n $key && -z ${key//[A-Za-z0-9_]/} ]] || continue
    export "$key=${line#*=}"
  done <<< "$blob"
}

# Run a command with secrets resolved fresh from 1Password, ignoring the cache.
# Costs one biometric prompt per invocation (per tty, within the 10-min window).
# --no-masking: op's output masking buffers and rewrites stdout, which mangles
# full-screen TUIs like Claude Code.
opx() {
  if (( $# == 0 )); then
    print -u2 "usage: opx <command> [args...]"
    return 2
  fi
  op run --no-masking --env-file="$OP_AGENTS_REFS" -- "$@"
}

# Which managed vars are actually set in this shell, and how stale is the cache.
opstatus() {
  # Note the two-step read: piping security into base64 would report base64's
  # exit status, so a missing keychain item would decode to empty and look
  # present. Check security's own status, then require a non-empty blob.
  local blob synced age
  blob=$(security find-generic-password -w -s "$OP_KEYCHAIN_SERVICE" -a "$USER" 2>/dev/null) \
    && blob=$(print -r -- "$blob" | base64 -d 2>/dev/null)
  if [[ -n $blob ]]; then
    synced=${${(M)${(f)blob}:#\# synced *}##\# synced }
    if [[ -n $synced ]]; then
      age=$(( ($(date +%s) - synced) / 86400 ))
      print "cache: $OP_KEYCHAIN_SERVICE — synced ${age}d ago ($(date -r "$synced" '+%Y-%m-%d %H:%M'))"
    else
      print "cache: $OP_KEYCHAIN_SERVICE — present, no sync timestamp"
    fi
  else
    print "cache: absent — run 'opsync' to populate it"
  fi

  local v val
  for v in ${(f)"$(_op_var_names)"}; do
    val=${(P)v}
    if [[ -n $val ]]; then
      print "  ✓ $v  (${#val} chars, ...${val: -4})"
    else
      print "  ✗ $v  (unset)"
    fi
  done
}

# Drop the keychain cache. Does not touch 1Password.
opclear() {
  if security delete-generic-password -s "$OP_KEYCHAIN_SERVICE" -a "$USER" >/dev/null 2>&1; then
    print "opclear: removed keychain item '$OP_KEYCHAIN_SERVICE'"
  else
    print "opclear: no keychain item '$OP_KEYCHAIN_SERVICE' to remove"
  fi
  local v
  for v in ${(f)"$(_op_var_names)"}; do unset "$v"; done
}

# Hydrate this shell. Must stay silent — see opload.
opload
