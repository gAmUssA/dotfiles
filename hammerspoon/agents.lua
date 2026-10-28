-- Menu bar: every running coding agent (claude, codex, grok, agy, pi, …),
-- whether it lives in a herdr pane or a tmux pane. Click a row to jump to it.
--
-- Replaces claude_sessions.lua, which found agents by grepping `ps` for
-- `claude`. That stopped scaling once several harnesses were in daily use:
-- each one needs its own process-name rule, and node-based CLIs show up as
-- `node`. So discovery now asks the multiplexer instead of guessing:
--
--   * herdr: `herdr agent list` on every live session socket. herdr already
--     detects all supported agents and reports their status and title, so
--     nothing here knows what an agent looks like inside herdr.
--   * tmux: tmux has no agent concept, so this one still reads `ps`, matching
--     AGENT_NAMES against argv[0] (or argv[1] behind node/bun) and walking
--     the ppid chain up to a tmux pane tty. Agents outside both multiplexers
--     are not listed; neither is in use any more.
--
-- Clicking a herdr row runs the herdr-notify plugin's focus.py — the same
-- route a banner click takes — so pane focus and iTerm reveal stay in one
-- place. Clicking a tmux row does switch-client + select-window + select-pane;
-- switch-client is a no-op within the current session, which is why
-- select-window is needed between the other two.
--
-- hs.task gotchas kept from claude_sessions.lua:
--   * a nil callback gets the task garbage-collected before it runs;
--   * output over ~64 KB is silently dropped without a streamCallback, so
--     full `ps` output is filtered with awk before it reaches Lua;
--   * `ps … tty=` pads with trailing spaces.

local M = {}

local REFRESH_S   = 3
local HOME        = os.getenv("HOME")
local HERDR_BIN   = HOME .. "/.local/bin/herdr"
local HERDR_CONF  = HOME .. "/.config/herdr"
local TMUX_BIN    = "/opt/homebrew/bin/tmux"
local MAX_PPID_HOPS = 8

local AGENT_NAMES = {"claude", "codex", "grok", "agy", "pi", "opencode",
                     "copilot", "gemini", "cursor-agent", "aider", "amp"}

local STATUS_ICON = {working = "◐", blocked = "❗", done = "✓", idle = "·"}

local menu = hs.menubar.new()
local cachedItems = {{title = "Loading…", disabled = true}}

------------------------------------------------------------------------------
-- async helpers
------------------------------------------------------------------------------

local function run(bin, args, env, callback)
    local task = hs.task.new(bin, function(code, stdout, stderr)
        callback(code, stdout or "", stderr or "")
    end, args)
    if env then
        local e = task:environment()
        for k, v in pairs(env) do e[k] = v end
        task:setEnvironment(e)
    end
    task:start()
end

local function shell(cmd, callback)
    run("/bin/sh", {"-c", cmd}, nil, function(_, out) callback(out) end)
end

local function basename(p)
    if not p or p == "" or p == "/" then return p or "?" end
    return p:match("([^/]+)/?$") or p
end

------------------------------------------------------------------------------
-- herdr discovery
------------------------------------------------------------------------------

-- Live sockets only: a stopped session leaves its directory behind.
local function herdrSockets()
    local socks = {}
    local function add(path, name)
        local attr = hs.fs.attributes(path)
        if attr and attr.mode == "socket" then
            socks[#socks + 1] = {path = path, session = name}
        end
    end
    add(HERDR_CONF .. "/herdr.sock", "default")
    local ok, iter, dir = pcall(hs.fs.dir, HERDR_CONF .. "/sessions")
    if ok and iter then
        for name in iter, dir do
            if name ~= "." and name ~= ".." then
                add(HERDR_CONF .. "/sessions/" .. name .. "/herdr.sock", name)
            end
        end
    end
    return socks
end

local function focusScript()
    local out = hs.execute("ls -d " .. HERDR_CONF .. "/plugins/*/gamussa.notify*/focus.py 2>/dev/null")
    return out and out:match("[^\n]+")
end

local function focusHerdr(a)
    local script = focusScript()
    if not script then
        hs.alert.show("herdr-notify plugin not installed; can't focus", 1.4)
        return
    end
    run("/usr/bin/python3", {script, "--socket", a.socket, "--terminal", a.terminal,
                             "--herdr-bin", HERDR_BIN}, nil,
        function(code, out, err)
            if code ~= 0 then
                hs.alert.show("herdr focus failed: " .. ((err ~= "" and err) or out):sub(1, 80), 2)
            end
        end)
end

local function listHerdr(callback)
    local socks = herdrSockets()
    local agents, pending, seen = {}, #socks, {}
    if pending == 0 then return callback(agents) end
    for _, s in ipairs(socks) do
        run(HERDR_BIN, {"agent", "list"}, {HERDR_SOCKET_PATH = s.path}, function(_, out)
            local ok, doc = pcall(hs.json.decode, out)
            local list = ok and doc and doc.result and doc.result.agents or {}
            for _, a in ipairs(list) do
                -- One server can answer on more than one socket; dedupe on the
                -- terminal, which is stable for the pane's lifetime.
                if a.terminal_id and not seen[a.terminal_id] then
                    seen[a.terminal_id] = true
                    agents[#agents + 1] = {
                        source = "herdr", kind = a.agent or "agent",
                        status = a.agent_status, cwd = a.foreground_cwd or a.cwd,
                        title = a.terminal_title_stripped,
                        where = ("herdr %s %s"):format(s.session, a.pane_id or "?"),
                        socket = s.path, terminal = a.terminal_id,
                    }
                end
            end
            pending = pending - 1
            if pending == 0 then callback(agents) end
        end)
    end
end

------------------------------------------------------------------------------
-- tmux discovery
------------------------------------------------------------------------------

local AGENT_PS_CMD = ([=[ps -eo pid=,ppid=,tty=,command= | awk -v names='%s' '
BEGIN { n = split(names, a, " "); for (i = 1; i <= n; i++) k[a[i]] = 1 }
{ c = $4; sub(/.*\//, "", c)
  if (c == "node" || c == "bun") { c = $5; sub(/.*\//, "", c); sub(/\.(c|m)?js$/, "", c) }
  if (c in k) print $1, $2, $3, c }']=]):format(table.concat(AGENT_NAMES, " "))
local PROCMAP_CMD = "ps -eo pid=,ppid=,tty="
local PANES_FMT = "#{pane_tty}|#{pane_current_path}|#{session_name}|#{session_id}|#{window_name}|#{window_id}|#{pane_index}|#{pane_id}"
local PANES_CMD = TMUX_BIN .. " list-panes -a -F '" .. PANES_FMT .. "' 2>/dev/null"

local function parseProcMap(out)
    local map = {}
    for line in out:gmatch("[^\n]+") do
        local pid, ppid, tty = line:match("^%s*(%d+)%s+(%d+)%s+(%S+)%s*$")
        if pid then map[pid] = {ppid = ppid, tty = tty:gsub("^/dev/", "")} end
    end
    return map
end

local function parsePanes(out)
    local map = {}
    for line in out:gmatch("[^\n]+") do
        local tty, cwd, sname, sid, wname, wid, pidx, paneId =
            line:match("([^|]+)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
        if tty then
            map[tty:gsub("^/dev/", "")] = {cwd = cwd, session = sname, sessionId = sid,
                windowName = wname, windowId = wid, pane = pidx, paneId = paneId}
        end
    end
    return map
end

local function paneFor(pid, procMap, paneMap)
    local cur = pid
    for _ = 1, MAX_PPID_HOPS do
        local p = procMap[cur]
        if not p then return nil end
        if paneMap[p.tty] then return paneMap[p.tty] end
        if p.ppid == "0" or p.ppid == "1" then return nil end
        cur = p.ppid
    end
end

local function listTmux(callback)
    local procs, procMap, paneMap
    local function finish()
        if not (procs and procMap and paneMap) then return end
        local agents, seen = {}, {}
        for _, p in ipairs(procs) do
            local pane = paneFor(p.pid, procMap, paneMap)
            -- One row per pane: an agent's own subprocesses match too.
            if pane and not seen[pane.paneId] then
                seen[pane.paneId] = true
                agents[#agents + 1] = {
                    source = "tmux", kind = p.kind, cwd = pane.cwd,
                    where = ("tmux %s:%s.%s"):format(pane.session, pane.windowName, pane.pane),
                    pane = pane,
                }
            end
        end
        callback(agents)
    end
    shell(AGENT_PS_CMD, function(out)
        procs = {}
        for line in out:gmatch("[^\n]+") do
            local pid, ppid, _, kind = line:match("^(%d+) (%d+) (%S+) (%S+)$")
            if pid then procs[#procs + 1] = {pid = pid, ppid = ppid, kind = kind} end
        end
        finish()
    end)
    shell(PROCMAP_CMD, function(out) procMap = parseProcMap(out); finish() end)
    shell(PANES_CMD, function(out) paneMap = parsePanes(out); finish() end)
end

local function focusTmux(pane)
    shell(TMUX_BIN .. " list-clients -F '#{client_tty}' 2>/dev/null", function(out)
        local client = out:match("[^\n]+")
        if not client then
            hs.alert.show("tmux has no attached clients", 1.4)
            return
        end
        shell(("%s switch-client -c '%s' -t '%s'; %s select-window -t '%s'; %s select-pane -t '%s'")
            :format(TMUX_BIN, client, pane.sessionId, TMUX_BIN, pane.windowId,
                    TMUX_BIN, pane.paneId), function() end)
        local iterm = hs.application.get("iTerm2")
        if iterm then iterm:activate() end
    end)
end

------------------------------------------------------------------------------
-- render + refresh
------------------------------------------------------------------------------

local function render(agents)
    table.sort(agents, function(a, b)
        if a.source ~= b.source then return a.source < b.source end
        return (a.cwd or "") < (b.cwd or "")
    end)

    local blocked = 0
    for _, a in ipairs(agents) do
        if a.status == "blocked" then blocked = blocked + 1 end
    end
    menu:setTitle(#agents == 0 and "🤖" or ("🤖 " .. #agents .. (blocked > 0 and " ❗" or "")))
    menu:setTooltip(("%d agent%s, %d waiting on you"):format(#agents, #agents == 1 and "" or "s", blocked))

    local items = {}
    if #agents == 0 then
        items[#items + 1] = {title = "No running agents", disabled = true}
    end
    for _, a in ipairs(agents) do
        local icon = STATUS_ICON[a.status] or " "
        local label = ("%s  %s · %s"):format(icon, a.kind, basename(a.cwd))
        if a.title and a.title ~= "" then label = label .. " — " .. a.title end
        items[#items + 1] = {
            title = label,
            tooltip = ("%s  (%s)"):format(a.cwd or "?", a.where),
            fn = function()
                if a.source == "herdr" then focusHerdr(a) else focusTmux(a.pane) end
            end,
        }
    end
    items[#items + 1] = {title = "-"}
    items[#items + 1] = {title = "Refresh", fn = function() M.refresh() end}
    cachedItems = items
end

function M.refresh()
    local herdr, tmux
    local function finish()
        if not (herdr and tmux) then return end
        local all = {}
        for _, a in ipairs(herdr) do all[#all + 1] = a end
        for _, a in ipairs(tmux) do all[#all + 1] = a end
        render(all)
    end
    listHerdr(function(a) herdr = a; finish() end)
    listTmux(function(a) tmux = a; finish() end)
end

-- macOS doesn't redraw an open NSMenu, so return the cache and refresh behind
-- it; the timer keeps the cache at most one tick stale.
menu:setMenu(function()
    M.refresh()
    return cachedItems
end)

M.refresh()
M.menu = menu
M.timer = hs.timer.doEvery(REFRESH_S, function() M.refresh() end)

return M
