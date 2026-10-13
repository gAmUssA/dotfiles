/** @jsxImportSource @opentui/solid */
/**
 * Status line under the OpenCode (v2) prompt, rendered by the shared agent
 * script (claude/statusline.sh). OpenCode has no "status line command"
 * setting, only TUI slots, so this builds the Claude-shaped JSON the script
 * reads, runs it off the render path, and paints the output. A slot is OpenTUI
 * text, not a terminal, so the script's ANSI SGR colors become spans here.
 *
 * Linked as ~/.config/opencode/plugins/dotfiles-statusline/ by
 * agents/statusline-install.sh; v2 auto-loads a plugin directory's tui entry.
 */
import { createSignal, For } from "solid-js"
import { spawn } from "node:child_process"
import { readFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

const SCRIPT = join(homedir(), ".claude", "statusline.sh")
const POLL_MS = 1000 // cheap: reruns the script only when the payload changes
const REFRESH_MS = 30_000 // the elapsed-time segment moves while idle

const SGR: Record<number, string> = { 31: "red", 32: "green", 33: "yellow", 34: "blue", 35: "magenta", 36: "cyan" }
type Span = { text: string; fg?: string; bold?: boolean; dim?: boolean }

function parseAnsi(line: string): Span[] {
  const spans: Span[] = []
  let cur: Omit<Span, "text"> = {}
  for (const part of line.split(/(\x1b\[[0-9;]*m)/)) {
    const m = part.match(/^\x1b\[([0-9;]*)m$/)
    if (!m) {
      if (part) spans.push({ text: part, ...cur })
      continue
    }
    for (const code of (m[1] || "0").split(";").map(Number)) {
      if (code === 0) cur = {}
      else if (code === 1) cur = { ...cur, bold: true }
      else if (code === 2) cur = { ...cur, dim: true }
      else if (SGR[code]) cur = { ...cur, fg: SGR[code] }
    }
  }
  return spans
}

function run(payload: string, cwd: string): Promise<string[] | undefined> {
  return new Promise((resolve) => {
    const child = spawn(SCRIPT, [], { cwd, stdio: ["pipe", "pipe", "ignore"] })
    let out = ""
    const timer = setTimeout(() => child.kill(), 10_000)
    child.stdout.on("data", (b) => (out += b))
    child.on("error", () => resolve(undefined))
    child.on("close", (code) => {
      clearTimeout(timer)
      resolve(code === 0 ? out.replace(/\n+$/, "").split("\n") : undefined)
    })
    child.stdin.end(payload)
  })
}

const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : undefined)

// The v2 plugin API names the model but not its context window. Look it up
// where OpenCode itself gets it: the user's provider config (local models),
// then its models.dev cache (hosted ones). Read once per model.
const windows = new Map<string, number | undefined>()
function contextWindow(providerID: string, modelID: string): number | undefined {
  const key = `${providerID}/${modelID}`
  if (windows.has(key)) return windows.get(key)
  let found: number | undefined
  for (const [file, pick] of [
    [join(homedir(), ".config", "opencode", "opencode.json"), (j: any) => j?.provider?.[providerID]?.models?.[modelID]],
    [join(homedir(), ".cache", "opencode", "models.json"), (j: any) => j?.[providerID]?.models?.[modelID]],
  ] as const) {
    try {
      found = num(pick(JSON.parse(readFileSync(file, "utf8")))?.limit?.context)
    } catch {
      found = undefined // missing or unreadable: try the next source
    }
    if (found) break
  }
  windows.set(key, found)
  return found
}

// biome-ignore lint: the v2 plugin context ships no public types yet
function setup(context: any) {
  const startedAt = Date.now()
  const [lines, setLines] = createSignal<string[]>([])
  let sessionID: string | undefined
  let last = ""
  let lastRun = 0
  let running = false

  function directory(): string {
    return context.location?.directory ?? context.data.location.default()?.directory ?? process.cwd()
  }

  function payload(): string {
    const dir = directory()
    const route = context.ui.router.current()
    const sid: string | undefined = route?.type === "session" ? route.sessionID : sessionID
    const msgs: any[] = sid ? context.data.session.message.list(sid) ?? [] : []
    const asst = [...msgs].reverse().find((m) => m?.type === "assistant" && m.tokens)
    // The prompt's selection, else the model the session last ran on.
    const sel = context.ui.model.current() ?? asst?.model
    const providerID: string | undefined = sel?.providerID
    const modelID: string | undefined = sel?.modelID ?? sel?.id
    const t = asst?.tokens
    const used = t
      ? (num(t.input) ?? 0) + (num(t.output) ?? 0) + (num(t.cache?.read) ?? 0) + (num(t.cache?.write) ?? 0)
      : undefined
    const window = providerID && modelID ? contextWindow(providerID, modelID) : undefined
    return JSON.stringify({
      session_id: sid,
      cwd: dir,
      model: modelID ? { id: modelID, display_name: modelID } : undefined,
      workspace: { current_dir: dir },
      cost: {
        total_duration_ms: Math.floor((Date.now() - startedAt) / REFRESH_MS) * REFRESH_MS,
        total_cost_usd: sid ? num(context.data.session.cost(sid)) : undefined,
      },
      context_window: window && used !== undefined
        ? { context_window_size: window, used_percentage: Math.round((used / window) * 100) }
        : undefined,
    })
  }

  async function tick() {
    if (running) return
    let p: string
    try {
      p = payload()
    } catch {
      return // data not ready yet
    }
    if (p === last && Date.now() - lastRun < REFRESH_MS) return
    running = true
    last = p
    lastRun = Date.now()
    const out = await run(p, directory())
    running = false
    if (out) setLines(out)
  }

  const timer = setInterval(() => void tick(), POLL_MS)
  void tick()

  function Line(props: { sessionID?: string }) {
    if (props.sessionID) sessionID = props.sessionID
    return (
      <box flexDirection="column" paddingLeft={1} paddingRight={1}>
        <For each={lines()}>
          {(line) => (
            <text>
              <For each={parseAnsi(line)}>
                {(s) => (
                  <span style={{ fg: s.dim ? "#808080" : s.fg, bold: s.bold }}>{s.text}</span>
                )}
              </For>
            </text>
          )}
        </For>
      </box>
    )
  }

  // One full-width row at the bottom of every screen (home and sessions).
  context.ui.slot({ append: "app", render: (props: any) => <Line sessionID={props?.sessionID} /> })

  return () => clearInterval(timer)
}

export default { id: "dotfiles.statusline", setup }
