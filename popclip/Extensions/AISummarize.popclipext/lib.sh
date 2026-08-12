# lib.sh — shared plumbing for the two action wrappers. Sourced, never run.
#
# PopClip gives shell-script actions no way to draw a window, and its JavaScript
# environment has no subprocess API — so the result window is a small AppKit
# program we compile on first use and launch detached.

CACHE_DIR="${HOME}/Library/Caches/io.gamov.popclip.extension.ai-summarize"

# Compile a Swift source into a cached binary, rebuilding only when the source
# changes. Prints the binary's path.
#
# Running the sources through `swift` on every invocation would re-parse and
# re-typecheck AppKit and FoundationModels each time, adding seconds to every
# summary. Caching keyed on the source hash means an extension update rebuilds
# automatically and nothing else does.
build_cached() {
    local source="$1"
    local name binary stamp hash scratch
    # Absolute paths throughout: PopClip does not promise the action a login
    # shell's PATH, and a summary failing on a missing `cut` would be baffling.
    name="$(/usr/bin/basename "$source" .swift)"
    binary="${CACHE_DIR}/${name}"
    stamp="${binary}.hash"
    hash="$(/usr/bin/shasum -a 256 "$source" | /usr/bin/cut -d ' ' -f 1)"

    if [[ -x "$binary" && -f "$stamp" && "$(/bin/cat "$stamp")" == "$hash" ]]; then
        printf '%s' "$binary"
        return 0
    fi

    # /usr/bin/swiftc is a shim that exists even with no toolchain behind it, so
    # its presence proves nothing — ask xcode-select whether one is installed.
    if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
        echo "AI Summarize needs the Xcode Command Line Tools. Install them with: xcode-select --install" >&2
        exit 1
    fi

    /bin/mkdir -p "$CACHE_DIR"
    scratch="${binary}.$$"
    if ! /usr/bin/swiftc -O -o "$scratch" "$source" 2>"${CACHE_DIR}/${name}.build.log"; then
        /bin/rm -f "$scratch"
        echo "Could not build the ${name} helper. Details: ${CACHE_DIR}/${name}.build.log" >&2
        exit 1
    fi
    # Move into place only after a successful build, so a failed compile never
    # leaves a half-written binary that later runs skip rebuilding.
    /bin/mv -f "$scratch" "$binary"
    printf '%s' "$hash" >"$stamp"
    printf '%s' "$binary"
}

# Run a summarization engine and print its summary, preserving its exit status
# so PopClip still sees exit code 2 (open settings) and the stderr message.
run_engine() {
    local binary="$1" output status
    set +e
    output="$("$binary")"
    status=$?
    set -e
    [[ $status -eq 0 ]] || exit $status
    printf '%s' "$output"
}

# Show the summary according to the Result setting.
deliver() {
    local title="$1" summary="$2"
    local mode="${POPCLIP_OPTION_OUTPUT:-window}"

    # Stage the summary on the clipboard whichever mode is set. For the two
    # window modes this mirrors what Large Type used to do: dismiss it and ⌘V
    # still works.
    printf '%s' "$summary" | /usr/bin/pbcopy

    local viewer_style
    case "$mode" in
        window) viewer_style=panel ;;
        fullscreen) viewer_style=fullscreen ;;
        *) return 0 ;;  # copy-only
    esac

    local viewer payload
    viewer="$(build_cached "${EXT_DIR}/summary-window.swift")"
    payload="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/ai-summarize.XXXXXX")"
    printf '%s' "$summary" >"$payload"

    # The viewer owns an AppKit run loop and lives until the user closes it, so
    # it must outlive this action — PopClip waits on the action process. Detach
    # it, and unlink the payload as soon as stdin is open on it so nothing is
    # left in the temp directory whether or not the viewer exits cleanly.
    SUMMARY_VIEWER="$viewer" SUMMARY_TITLE="$title" SUMMARY_PAYLOAD="$payload" \
        SUMMARY_STYLE="$viewer_style" \
        /usr/bin/nohup /bin/sh -c \
        'exec <"$SUMMARY_PAYLOAD"; rm -f "$SUMMARY_PAYLOAD"; exec "$SUMMARY_VIEWER" --title "$SUMMARY_TITLE" --style "$SUMMARY_STYLE"' \
        >/dev/null 2>&1 &
    disown 2>/dev/null || true
}
