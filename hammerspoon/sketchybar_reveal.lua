-- Auto-hide for SketchyBar's workspace pill: show it while the pointer is at
-- the bottom edge, hide it once the pointer leaves.
--
-- WHY here and not in SketchyBar: a hidden bar has no window, so it cannot see
-- the pointer arrive, and SketchyBar has no auto-hide of its own. The bar
-- starts hidden (sketchybar/sketchybarrc); without Hammerspoon it stays hidden
-- and AeroSpace's `1`-`4` still work.
--
-- A 0.1 s poll of the pointer position, not a mouseMoved eventtap: an eventtap
-- sits in the path of every mouse event system-wide, and a stalled callback
-- stalls the pointer. The poll costs a position read per tick.

local M = {}

local SKETCHYBAR = "/opt/homebrew/bin/sketchybar"
local POLL_S     = 0.1
local EDGE_PT    = 2     -- how close to the bottom edge counts as "at the edge"
local KEEP_PT    = 48    -- bar height 30 + y_offset 6 + slack while it is shown
local HIDE_AFTER = 0.4   -- seconds outside before hiding, so a brush past doesn't flicker

-- The bar spans the screen minus `margin` on each side; read it once from the
-- running bar so sketchybarrc stays the only place it is set.
local margin = 480
do
    local out = hs.execute(SKETCHYBAR .. " --query bar 2>/dev/null")
    local ok, bar = pcall(hs.json.decode, out or "")
    if ok and bar and tonumber(bar.margin) then margin = tonumber(bar.margin) end
end

local shown, leftAt = false, nil

local function set(hidden)
    shown = not hidden
    hs.task.new(SKETCHYBAR, function() end, {"--bar", "hidden=" .. (hidden and "on" or "off")}):start()
end

local function tick()
    local pos = hs.mouse.absolutePosition()
    local screen = hs.mouse.getCurrentScreen()
    if not screen then return end
    local f = screen:fullFrame()
    local bottom = f.y + f.h
    local inSpan = pos.x >= f.x + margin and pos.x <= f.x + f.w - margin

    if not shown then
        if inSpan and pos.y >= bottom - EDGE_PT then set(false) end
        return
    end
    if inSpan and pos.y >= bottom - KEEP_PT then
        leftAt = nil
    elseif not leftAt then
        leftAt = hs.timer.secondsSinceEpoch()
    elseif hs.timer.secondsSinceEpoch() - leftAt >= HIDE_AFTER then
        leftAt = nil
        set(true)
    end
end

set(true)
M.timer = hs.timer.doEvery(POLL_S, tick)
return M
