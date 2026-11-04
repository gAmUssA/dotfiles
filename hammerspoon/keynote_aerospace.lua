-- Keynote fullscreen can immediately disappear while AeroSpace manages windows.
-- Pause for Keynote's whole lifetime, before its presentation windows appear.
-- https://github.com/nikitabobko/AeroSpace/issues/804
local M = {}
local AEROSPACE = "/opt/homebrew/bin/aerospace"
-- Creator Studio uses com.apple.Keynote; the standalone app uses iWork.Keynote.
local KEYNOTE_IDS = {"com.apple.Keynote", "com.apple.iWork.Keynote"}

local function keynoteRunning()
    for _, id in ipairs(KEYNOTE_IDS) do
        if #hs.application.applicationsForBundleID(id) > 0 then return true end
    end
    return false
end

-- run is the process boundary: (enable argument, fail-if-noop) -> exit, output.
-- Only a successful off transition gives us permission to restore on quit.
function M.newController(run, report)
    local controller = { ownsPause = false }

    function controller:pause()
        if self.ownsPause then return end
        local code, output = run("off", true)
        if code == 0 then
            self.ownsPause = true
        elseif code ~= 2 then -- AeroSpace's --fail-if-noop exit: already off
            report("pause", output)
        end
    end

    function controller:resume()
        if not self.ownsPause then return end
        local code, output = run("on", false)
        if code == 0 then
            self.ownsPause = false
        else
            report("resume", output)
        end
    end

    return controller
end

function M.start()
    local function run(value, failIfNoop)
        local output, ok, _, code = hs.execute(AEROSPACE .. " enable " .. value
            .. (failIfNoop and " --fail-if-noop" or "") .. " 2>&1")
        return ok and 0 or code, output
    end
    local function report(action, output)
        print("Keynote: cannot " .. action .. " AeroSpace: " .. tostring(output))
        hs.alert.show("Cannot " .. action .. " AeroSpace. Check Hammerspoon Console.", 4)
    end
    local controller = M.newController(run, report)
    M.controller = controller

    local function reconcile()
        local wasOwned = controller.ownsPause
        if keynoteRunning() then
            controller:pause()
        else
            controller:resume()
        end
        if wasOwned ~= controller.ownsPause then
            hs.alert.show(controller.ownsPause
                and "Keynote open — AeroSpace paused"
                or "Keynote closed — AeroSpace resumed", 2)
        end
    end

    M.watcher = hs.application.watcher.new(function(name, event, app)
        local bundleID = app and app:bundleID()
        if bundleID == KEYNOTE_IDS[1] or bundleID == KEYNOTE_IDS[2] or name == "Keynote" then
            if event == hs.application.watcher.launched
                or event == hs.application.watcher.terminated
                or event == hs.application.watcher.activated then
                reconcile()
            end
        elseif name == "AeroSpace" and event == hs.application.watcher.launched then
            -- Ownership belonged to the old process, never the new one.
            controller.ownsPause = false
            reconcile()
        end
    end):start()

    -- Reconcile on reload as well as launch. No persisted ownership can go stale.
    -- Shutdown callbacks run synchronously, before Lua is torn down on reload.
    local previousShutdown = hs.shutdownCallback
    hs.shutdownCallback = function()
        controller:resume()
        if previousShutdown then previousShutdown() end
    end
    reconcile()
end

-- Plain Lua loads only the controller for process-boundary tests.
if hs then M.start() end
return M
