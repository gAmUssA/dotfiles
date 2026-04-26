-- Caffeine-style display-idle toggle in the menu bar.
-- Click the icon to toggle, or hit ⌃⌥⌘+C.

local M = {}

local ICON_ON  = "☕"
local ICON_OFF = "💤"

local menu = hs.menubar.new()

local function render()
    local on = hs.caffeinate.get("displayIdle")
    menu:setTitle(on and ICON_ON or ICON_OFF)
    menu:setTooltip(on
        and "Caffeine: ON (display will not sleep)"
        or  "Caffeine: off (display can sleep)")
end

local function toggle()
    local on = not hs.caffeinate.get("displayIdle")
    hs.caffeinate.set("displayIdle", on)
    render()
    hs.alert.closeAll()
    hs.alert.show(on and "Caffeine ON" or "Caffeine off", 0.6)
end

menu:setClickCallback(toggle)
render()

hs.hotkey.bind({"ctrl", "alt", "cmd"}, "C", toggle)

return M
