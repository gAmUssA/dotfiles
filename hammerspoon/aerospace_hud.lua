-- Fullscreen-ish HUD naming the AeroSpace command that just ran.
--
-- WHY: learning a tiling WM is mostly "which key did that?". AeroSpace has no
-- on-screen feedback of its own, so each binding in aerospace/aerospace.toml
-- also fires aerospace-hud.sh, which opens
--   hammerspoon://aerospace-hud?msg=<action>&key=<chord>
-- and this module draws it. Delete the exec-and-forget halves of those bindings
-- once the keys are in your fingers; nothing else depends on this.
--
-- A URL event is used rather than the `hs` CLI so no command-line tool install
-- is required, and `open -g` keeps focus where it is.

local M = {}

local canvas, hideTimer

local function dismiss()
    if hideTimer then hideTimer:stop(); hideTimer = nil end
    if canvas then canvas:delete(); canvas = nil end
end

local function show(msg, key)
    dismiss()
    if not msg or msg == "" then return end

    -- Draw on the screen the pointer is on: with two monitors, the HUD should
    -- appear where you are looking, not always on the main display.
    local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
    local f = screen:fullFrame()
    local w, h = 640, 150

    canvas = hs.canvas.new({
        x = f.x + (f.w - w) / 2,
        y = f.y + (f.h - h) / 2,
        w = w, h = h,
    })

    canvas:appendElements(
        { type = "rectangle", action = "fill",
          fillColor = { red = 0, green = 0, blue = 0, alpha = 0.78 },
          roundedRectRadii = { xRadius = 18, yRadius = 18 } },
        { type = "text", text = msg,
          textSize = 46, textColor = { white = 1, alpha = 1 },
          textAlignment = "center",
          frame = { x = 0, y = key and 26 or 46, w = w, h = 60 } }
    )

    if key and key ~= "" then
        canvas:appendElements({
            type = "text", text = key,
            textSize = 20, textColor = { white = 1, alpha = 0.6 },
            textAlignment = "center",
            frame = { x = 0, y = 92, w = w, h = 32 },
        })
    end

    canvas:level(hs.canvas.windowLevels.overlay)
    canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
    canvas:show(0.08)

    hideTimer = hs.timer.doAfter(1.1, function()
        if canvas then canvas:hide(0.25) end
        hs.timer.doAfter(0.3, dismiss)
    end)
end

-- hammerspoon://aerospace-hud?msg=Focus%20left&key=Hyper%2Bh
hs.urlevent.bind("aerospace-hud", function(_, params)
    show(params.msg, params.key)
end)

M.show = show
return M
