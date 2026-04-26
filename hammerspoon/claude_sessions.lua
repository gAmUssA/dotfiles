-- Menu bar: list of running top-level `claude` (Claude Code) sessions.
-- Click a row to focus the terminal tab AND tmux pane that hosts that session.
--
-- Everything off the Lua main thread. Sync shell calls were causing the menu
-- (and tmux) to feel unresponsive during/after clicks; now ps/tmux/osascript
-- all run via `hs.task`, so the click callback returns immediately and the
-- 15s refresh never blocks the UI.
--
-- Routing on click:
--   1. tmux-aware: walk claude's ppid chain until an ancestor's tty matches
--      a tmux pane tty. Needed because pty wrappers (e.g. `thefuck`) sit
--      between the tmux pane shell and claude, so claude's own tty is NOT
--      the pane's tty — but an ancestor's is.
--   2. Direct: claude's tty matches an iTerm session tty (no tmux involved).
--   3. Title fallback: substring match on window titles.
--
-- The tmux command sequence is the non-obvious part: switch-client moves
-- the client onto the target session, but is a no-op if the client is
-- already on that session. So a click within the same session needs
-- select-window between switch-client and select-pane — otherwise pane
-- gets activated in its window but the session keeps showing whichever
-- window was active. select-pane alone does NOT bring the window forward.
--
-- Notes on hs.task gotchas we ran into:
--   * `hs.task.new(_, nil, _)` (nil callback) gets garbage-collected before
--     it runs. Always pass a callback (no-op is fine) to keep the task
--     alive — `fireAndForget` here uses a no-op via `asyncShell`.
--   * Without a streamCallback, hs.task buffers stdout in memory and
--     silently drops the callback if output exceeds ~64 KB. Full
--     `ps -eo command=` is ~85 KB, so we split into three smaller queries
--     (claude rows via awk filter / trim pid-ppid-tty / tmux panes).
--   * `ps -eo … tty=` pads tty to a fixed column width; trailing spaces
--     break a `(%S+)$`-anchored regex. parseProcMap uses `%S+%s*$`.

local M = {}

local REFRESH_S     = 5
local TERMINAL_APPS = {"iTerm2", "Ghostty", "Terminal", "Alacritty", "WezTerm", "kitty"}
local TMUX_BIN      = "/opt/homebrew/bin/tmux"
local OSASCRIPT_BIN = "/usr/bin/osascript"
local MAX_PPID_HOPS = 8

local menu = hs.menubar.new()

-- Items shown when the menu opens. Updated by render() on each refresh; the
-- dynamic setMenu callback below returns this cached list so the menu opens
-- instantly even before the click-triggered refresh completes.
local cachedItems = {{title = "Loading…", disabled = true}}

------------------------------------------------------------------------------
-- async helpers (non-blocking)
------------------------------------------------------------------------------

local function asyncShell(cmd, callback)
    local task = hs.task.new("/bin/sh", function(_, stdout, _)
        if callback then callback(stdout or "") end
    end, {"-c", cmd})
    task:start()
end

local function asyncOsascript(script, callback)
    local task = hs.task.new(OSASCRIPT_BIN, function(_, stdout, _)
        if callback then callback((stdout or ""):gsub("%s+$", "")) end
    end, {"-e", script})
    task:start()
end

-- Fire-and-forget shell. Uses a no-op callback (rather than nil) because
-- hs.task with a nil callback gets garbage-collected before the command runs;
-- the callback closure is what keeps the underlying task alive.
local function fireAndForget(cmd)
    asyncShell(cmd, function() end)
end

------------------------------------------------------------------------------
-- pure parsers (sync, fast)
------------------------------------------------------------------------------

local function basename(p)
    if not p or p == "" or p == "/" then return p or "?" end
    return p:match("([^/]+)/?$") or p
end

local function stripDev(t)
    return (t or ""):gsub("^/dev/", "")
end

-- Parse the trim "pid ppid tty" output into pid → {ppid, tty}.
-- Output is small (~20KB for 1000 procs), well under hs.task's buffer ceiling.
local function parseProcMap(out)
    local map = {}
    for line in out:gmatch("[^\n]+") do
        -- ps `tty=` is padded to a fixed width with trailing spaces; allow them
        local pid, ppid, tty = line:match("^%s*(%d+)%s+(%d+)%s+(%S+)%s*$")
        if pid then
            local cleanTty = (tty == "??" or tty == "?") and nil or tty
            map[pid] = {ppid = ppid, tty = cleanTty}
        end
    end
    return map
end

-- Parse `ps … command= | awk '$5=="claude"'` output (claude rows only).
local function parseClaudeRows(out)
    local procs = {}
    for line in out:gmatch("[^\n]+") do
        local pid, ppid, tty, etime, rest =
            line:match("^%s*(%d+)%s+(%d+)%s+(%S+)%s+(%S+)%s+(.+)$")
        if pid then
            local cleanTty = (tty == "??" or tty == "?") and nil or tty
            table.insert(procs, {
                pid = pid, ppid = ppid, tty = cleanTty,
                etime = etime, cmd = rest,
            })
        end
    end
    return procs
end

local function parsePanes(out)
    local map = {}
    for line in out:gmatch("[^\n]+") do
        local pane_tty, cwd, sname, sid, widx, wname, wid, pidx, panid =
            line:match("([^|]+)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
        if pane_tty then
            map[stripDev(pane_tty)] = {
                paneTty = pane_tty, cwd = cwd,
                session = sname, sessionId = sid,
                window = widx, windowName = wname, windowId = wid,
                pane = pidx, paneId = panid,
            }
        end
    end
    return map
end

-- Walk up ppid chain until an ancestor's tty matches a tmux pane.
local function paneForChain(pid, procMap, paneMap)
    local cur = pid
    for _ = 1, MAX_PPID_HOPS do
        local p = procMap[cur]
        if not p then return nil end
        if p.tty and paneMap[p.tty] then return paneMap[p.tty] end
        if p.ppid == "1" or p.ppid == "0" or not p.ppid then return nil end
        cur = p.ppid
    end
    return nil
end

------------------------------------------------------------------------------
-- focus paths (all async; click handler returns instantly)
------------------------------------------------------------------------------

local function buildITermFocusScript(tty)
    return ([[
tell application "iTerm2"
    activate
    repeat with w in windows
        repeat with t in tabs of w
            repeat with s in sessions of t
                if tty of s ends with "%s" then
                    tell w to select
                    tell t to select
                    tell s to select
                    return "ok"
                end if
            end repeat
        end repeat
    end repeat
    return "miss"
end tell
]]):format(tty)
end

local function focusITermAsync(tty, callback)
    if not tty then if callback then callback(false) end; return end
    asyncOsascript(buildITermFocusScript(tty), function(out)
        if callback then callback(out == "ok") end
    end)
end

local function focusByTitle(cwd)
    if not cwd or cwd == "/" then return false end
    local base = basename(cwd)
    local fullMatch, baseMatch
    for _, appName in ipairs(TERMINAL_APPS) do
        local app = hs.application.get(appName)
        if app then
            for _, win in ipairs(app:allWindows()) do
                local title = win:title() or ""
                if title ~= "" then
                    if title:find(cwd, 1, true) and not fullMatch then
                        fullMatch = {app = app, win = win}
                    elseif title:find(base, 1, true) and not baseMatch then
                        baseMatch = {app = app, win = win}
                    end
                end
            end
        end
    end
    local hit = fullMatch or baseMatch
    if hit then
        hit.app:activate()
        hit.win:focus()
        return true
    end
    return false
end

local function tmuxSwitchAndSelect(pane, clientTty)
    -- switch-client moves the client onto the target session.
    -- select-window brings the target window to the front of that session
    --   (needed when the target is a different window in the same session,
    --   since switch-client to the same session is a no-op).
    -- select-pane finally picks the right pane in that window.
    local cmd = ("%s switch-client -c '%s' -t '%s'; %s select-window -t '%s'; %s select-pane -t '%s'")
        :format(TMUX_BIN, clientTty, pane.sessionId,
                TMUX_BIN, pane.windowId,
                TMUX_BIN, pane.paneId)
    fireAndForget(cmd)
end

local function focusSession(s)
    if s.tmux then
        -- One quick async lookup, then fire-and-forget the rest.
        asyncShell(TMUX_BIN .. " list-clients -F '#{client_tty}' 2>/dev/null",
            function(out)
                local clientTty
                for line in out:gmatch("[^\n]+") do
                    if line:match("%S") then clientTty = line; break end
                end
                if not clientTty then
                    hs.alert.show("tmux has no attached clients", 1.4)
                    return
                end
                tmuxSwitchAndSelect(s.tmux, clientTty)
                if hs.application.get("iTerm2") then
                    focusITermAsync(stripDev(clientTty), function(ok)
                        if not ok and not focusByTitle(s.cwd) then
                            hs.alert.show(("Switched tmux to %s:%s.%s — couldn't find iTerm tab")
                                :format(s.tmux.session, s.tmux.window, s.tmux.pane), 1.4)
                        end
                    end)
                end
            end)
        return
    end

    -- Non-tmux: try iTerm tty match async, then title fallback.
    if hs.application.get("iTerm2") then
        focusITermAsync(s.tty, function(ok)
            if ok then return end
            if focusByTitle(s.cwd) then return end
            for _, appName in ipairs(TERMINAL_APPS) do
                local app = hs.application.get(appName)
                if app then
                    app:activate()
                    hs.alert.show("No tab match for " .. basename(s.cwd or "?")
                        .. ", focused " .. appName, 1.2)
                    return
                end
            end
            hs.alert.show("No terminal app running", 1.2)
        end)
    elseif not focusByTitle(s.cwd) then
        hs.alert.show("No terminal app running", 1.2)
    end
end

------------------------------------------------------------------------------
-- render + refresh (refresh is async, never blocks UI)
------------------------------------------------------------------------------

local function render(sessions)
    if #sessions == 0 then
        menu:setTitle("🤖")
        menu:setTooltip("No active Claude sessions")
    else
        menu:setTitle("🤖 " .. #sessions)
        menu:setTooltip(("%d Claude session%s"):format(#sessions, #sessions == 1 and "" or "s"))
    end

    local items = {}
    if #sessions == 0 then
        table.insert(items, {title = "No active sessions", disabled = true})
    else
        table.insert(items, {title = ("Claude sessions: %d"):format(#sessions), disabled = true})
        for _, s in ipairs(sessions) do
            local context
            if s.tmux then
                -- prefer the (renamable) window name over the numeric index
                local winLabel = (s.tmux.windowName and s.tmux.windowName ~= "")
                    and s.tmux.windowName
                    or  s.tmux.window
                context = ("tmux %s:%s.%s"):format(s.tmux.session, winLabel, s.tmux.pane)
            else
                context = s.tty or "no-tty"
            end
            local proj = s.cwd and basename(s.cwd) or ("pid " .. s.pid)
            local label = ("  %s  · %s  (%s)"):format(proj, s.etime, context)
            table.insert(items, {
                title   = label,
                tooltip = (s.cwd or s.cmd) .. "  pid " .. s.pid,
                fn      = function() focusSession(s) end,
            })
        end
    end
    table.insert(items, {title = "-"})
    table.insert(items, {title = "Refresh", fn = function() M.refresh() end})
    cachedItems = items
end

local PANES_FMT = "#{pane_tty}|#{pane_current_path}|#{session_name}|#{session_id}|#{window_index}|#{window_name}|#{window_id}|#{pane_index}|#{pane_id}"

function M.refresh()
    local procs, procMap, paneMap

    local function maybeFinish()
        if not procs or not procMap or not paneMap then return end
        local sessions = {}
        for _, p in ipairs(procs) do
            local pane = paneForChain(p.pid, procMap, paneMap)
            table.insert(sessions, {
                pid = p.pid, ppid = p.ppid, tty = p.tty,
                etime = p.etime, cmd = p.cmd,
                cwd = pane and pane.cwd or nil,
                tmux = pane,
            })
        end
        render(sessions)
    end

    -- Three async calls (claude rows, full proc map, tmux panes). Each output
    -- is small (well under hs.task's buffer cap). maybeFinish guards against
    -- partial state — only renders when all three have landed.
    asyncShell("ps -eo pid=,ppid=,tty=,etime=,command= | awk '$5==\"claude\"'",
        function(out)
            procs = parseClaudeRows(out)
            maybeFinish()
        end)
    asyncShell("ps -eo pid=,ppid=,tty=", function(out)
        procMap = parseProcMap(out)
        maybeFinish()
    end)
    asyncShell(TMUX_BIN .. " list-panes -a -F '" .. PANES_FMT .. "' 2>/dev/null",
        function(out)
            paneMap = parsePanes(out)
            maybeFinish()
        end)
end

-- Dynamic menu: every click on the icon triggers an async refresh (so the
-- next interaction sees fresh data) and immediately shows the cached items.
-- The cache is also kept warm by the periodic timer below, which is what
-- keeps the icon's title (the count badge) accurate while the menu is closed.
menu:setMenu(function()
    M.refresh()
    return cachedItems
end)

M.refresh()
hs.timer.doEvery(REFRESH_S, function() M.refresh() end)

return M
