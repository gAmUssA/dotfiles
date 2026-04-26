-- ~/.hammerspoon/init.lua → dotfiles/hammerspoon/init.lua
-- Entry point. Loads modules, keeps the WiFi watcher, and logs any module
-- errors to /tmp/hammerspoon.log so we can debug from outside Hammerspoon.

hs.allowAppleScript(true)  -- enable osascript probes from the shell

local LOG_PATH = "/tmp/hammerspoon.log"
local function logLine(msg)
    local f = io.open(LOG_PATH, "a")
    if f then
        f:write(os.date("%Y-%m-%d %H:%M:%S"), "  ", tostring(msg), "\n")
        f:close()
    end
    print(msg)  -- also lands in Hammerspoon Console
end

-- Truncate log on each load so we always see only this run.
local f = io.open(LOG_PATH, "w"); if f then f:close() end
logLine("=== init.lua starting ===")

-- Live-reload on any .lua change. Watch both ~/.hammerspoon and the dotfiles
-- source dir (FSEvents reports changes against the real path, not the symlink).
local function reloadOnLua(files)
    for _, f in ipairs(files) do
        if f:sub(-4) == ".lua" then
            hs.reload()
            return
        end
    end
end

local watchedDirs = {
    hs.configdir,
    os.getenv("HOME") .. "/projects/dotfiles/hammerspoon",
}
configWatchers = {}
for _, dir in ipairs(watchedDirs) do
    local w = hs.pathwatcher.new(dir, reloadOnLua)
    w:start()
    table.insert(configWatchers, w)
end
logLine("path watchers up: " .. #configWatchers)

-- WiFi connect/disconnect notifications
local wifiWatcher = hs.wifi.watcher.new(function()
    local net = hs.wifi.currentNetwork()
    if net == nil then
        hs.notify.show("WiFi disconnected", "", "")
    else
        hs.notify.show("Connected to WiFi", "", net)
    end
end)
wifiWatcher:start()
logLine("wifi watcher up")

-- Load modules with isolation so one failure doesn't kill the others.
local function safeRequire(name)
    local ok, err = pcall(require, name)
    if ok then
        logLine("loaded: " .. name)
    else
        logLine("FAILED " .. name .. ": " .. tostring(err))
    end
end

safeRequire("caffeine")
safeRequire("ollama")
safeRequire("claude_sessions")

logLine("=== init.lua done ===")
hs.alert.show("Hammerspoon config loaded", 0.6)
