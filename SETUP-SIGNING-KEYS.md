# Apple signing keys & App Store Connect API keys

Where the Apple signing secrets live, how they got into 1Password, and how to
restore them on a new Mac. Companion to [SETUP-NEW-MACHINE.md](SETUP-NEW-MACHINE.md).

Nothing here is a secret: item titles and key IDs only. The keys themselves are
1Password **Documents**, tagged `appstoreconnect`, in the `Private` vault.

---

## What these files are (and are not)

| File                 | What it is                                                                       | Used by                                              |
|----------------------|----------------------------------------------------------------------------------|------------------------------------------------------|
| `AuthKey_<KEYID>.p8` | PKCS#8 ECDSA private key. Signs the JWT for App Store Connect API auth.          | `xcrun altool`, `notarytool`, `xcodebuild`, fastlane |
| `DeveloperID.p12`    | PKCS#12 bundle — Developer ID cert **plus** its private key. Password-protected. | codesign / notarization                              |

They are **not** SSH keys. Do not put them in 1Password's *SSH Key* category and
do not list them in `op/ssh-agent.toml` — the SSH agent has no business serving
them, and the category will mangle the bytes. Documents keep them intact.

**Apple lets you download a `.p8` exactly once.** Lose it and the only path is
revoke + regenerate in App Store Connect. That is the whole reason for the
1Password copy.

---

## Local layout — the path is load-bearing

```
~/.appstoreconnect/private_keys/     # 700
├── AuthKey_<KEYID>.p8               # 600, one per API key (4 as of 2026-09-03)
└── DeveloperID.p12                  # 600
```

### Getting the `<KEYID>`s

Key IDs are deliberately **not** written down in this repo — it is public, and
they are permanent identifiers you cannot rotate (see *Why no IDs here* below).
Derive them instead:

```bash
# from the local keys:
ls ~/.appstoreconnect/private_keys/AuthKey_*.p8 | sed 's|.*/AuthKey_||; s|\.p8$||'

# or from 1Password, when the local copies are gone (no download, just titles):
op item list --tags appstoreconnect --format json \
  | jq -r '.[] | select(.title | startswith("ASC API Key ")) | .title | sub("^ASC API Key "; "")'
```

The Key ID is also the `kid` in any JWT you sign, and Apple shows it in App
Store Connect → Users and Access → Integrations.

Apple's tools **discover keys by convention**, searching `./private_keys`,
`~/private_keys`, `~/.private_keys`, and `~/.appstoreconnect/private_keys` for
`AuthKey_<KEYID>.p8`. So 1Password is the durable backup and this directory is a
working cache — back up, don't move. Deleting the local copies breaks builds.

This directory is deliberately **not** symlinked into the dotfiles repo by
`linkall.sh`: the repo is public, and these are live private keys.

---

## Back up to 1Password (already done, kept for reference)

```bash
cd ~/.appstoreconnect/private_keys
for f in AuthKey_*.p8; do
  kid="${f#AuthKey_}"; kid="${kid%.p8}"
  op document create "$f" --title "ASC API Key $kid" --vault Private --tags appstoreconnect
done
op document create DeveloperID.p12 --title "Developer ID cert (p12)" \
  --vault Private --tags appstoreconnect
```

`op document create` reads the file directly, so no key bytes pass through shell
history or terminal scrollback. Never `cat` a `.p8`.

### Verify the backup, or it isn't one

```bash
tmp=$(mktemp -d) && cd "$tmp"
for f in ~/.appstoreconnect/private_keys/AuthKey_*.p8; do
  kid=$(basename "$f" .p8); kid="${kid#AuthKey_}"
  op document get "ASC API Key $kid" --output "AuthKey_$kid.p8"
done
op document get "Developer ID cert (p12)" --output DeveloperID.p12
for f in *.p8 *.p12; do
  a=$(shasum -a 256 "$f" | cut -d' ' -f1)
  b=$(shasum -a 256 ~/.appstoreconnect/private_keys/"$f" | cut -d' ' -f1)
  [ "$a" = "$b" ] && echo "OK   $f" || echo "FAIL $f"
done
cd - && rm -rf "$tmp"     # do not leave private keys in a temp dir
```

All five verified OK on 2026-09-03.

---

## Restore on a new Mac

Nothing is hardcoded — this pulls whatever `appstoreconnect`-tagged keys exist:

```bash
mkdir -p ~/.appstoreconnect/private_keys && cd ~/.appstoreconnect/private_keys
op item list --tags appstoreconnect --format json \
  | jq -r '.[] | select(.title | startswith("ASC API Key ")) | .title' \
  | while read -r title; do
      op document get "$title" --output "AuthKey_${title##* }.p8"
    done
op document get "Developer ID cert (p12)" --output DeveloperID.p12
chmod 700 ~/.appstoreconnect/private_keys
chmod 600 ~/.appstoreconnect/private_keys/*
ls -l                                    # expect 4 .p8 + 1 .p12, all 600
```

List what's there without downloading anything:

```bash
op item list --tags appstoreconnect
```

---

## TODO: record the Issuer ID (do this next time you're in App Store Connect)

**A `.p8` is useless without its Issuer ID.** Every API call needs both the Key
ID (in the filename) and the Issuer ID — a UUID that is *not* derivable from the
key file and is not stored anywhere on disk. As of 2026-09-03 it is recorded
nowhere, which makes these backups incomplete.

Get it from **App Store Connect → Users and Access → Integrations → App Store
Connect API** (shown once at the top of the keys list), then:

```bash
op item edit "ASC API Key <KEYID>" \
  "issuer id[text]=<UUID>" "key id[text]=<KEYID>"
```

**The Issuer ID goes in 1Password, never in this file.** It is not a credential
— auth needs Issuer ID *and* Key ID *and* the `.p8`, and only the `.p8` is
secret — but it is permanent. A leaked `.p8` you revoke in five minutes; an
Issuer ID can never be changed. It belongs beside the key it pairs with.

While you're there, also record **what each key is for**. There are four, and
nothing on disk or in the key bytes says which team or app each serves. Put the
purpose in the 1Password item title so `op item list` is self-describing:

```bash
op item edit "ASC API Key <KEYID>" --title "ASC API Key <KEYID> — <what it's for>"
```

Any key you no longer recognize is worth revoking outright — four
indistinguishable secrets is worse than two labeled ones.

### Why no IDs here

This repo is **public**. Key IDs and the Issuer ID are not secrets, but they are
permanent identifiers that cannot be rotated, and writing them here buys nothing
that 1Password does not already give you. `githooks/pre-commit` will not catch
them either — correctly, since they are not secrets. So: derive Key IDs with the
one-liners above, keep the Issuer ID in 1Password.

What *is* fine to keep in this repo: DS9's **host key fingerprint** (it is the
public half, and committing it is what lets you detect a MITM on first connect,
exactly as SSHFP DNS records do) and its **tailnet IP** (CGNAT, routable only
inside the tailnet, and consistent with the LAN IPs already in `.ssh/config`).

The `.p12` needs its **export password** stored in its 1Password item too, or
the file is inert. Verify the bundle is valid (prompts for the password):

```bash
openssl pkcs12 -info -in ~/.appstoreconnect/private_keys/DeveloperID.p12 -noout
```

Not yet confirmed — `file` reports it as generic `data`, which is expected for
PKCS#12 but proves nothing about validity.

---

## Rotating / revoking

1. App Store Connect → Users and Access → Integrations → revoke the key.
2. Generate a replacement, download the `.p8` (**one chance**).
3. `op document create` it, per the block above.
4. Delete the old 1Password document and the local `.p8`.
5. Update any CI secrets referencing the old Key ID.
