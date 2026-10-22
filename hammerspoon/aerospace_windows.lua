-- Fuzzy window picker across every AeroSpace workspace (AERO mode + `w`).
--
-- WHY: with float-by-default and nine workspaces, "where did that window go?"
-- is the common question. alt-tab answers it per app; this answers it by
-- window title too, so "the Kafka tab" or "the PR review" finds the exact
-- window. Idea from the DevOps Toolbox AeroSpace video (`ff`: list-windows
-- piped into fzf), done with hs.chooser instead so no terminal has to open.
--
-- aerospace.toml opens hammerspoon://aerospace-windows; choosing a row runs
-- `aerospace focus --window-id`, which also switches to its workspace.

local M = {}

local AEROSPACE = "/opt/homebrew/bin/aerospace"
local FORMAT = "%{window-id} %{app-name} %{app-bundle-id} %{window-title} %{workspace}"

local chooser

local function windows()
    local out, ok = hs.execute(string.format("%s list-windows --all --json --format '%s'", AEROSPACE, FORMAT))
    if not ok or not out then return nil end
    local list = hs.json.decode(out)
    if type(list) ~= "table" then return nil end

    local rows = {}
    for _, w in ipairs(list) do
        local title = w["window-title"] ~= "" and w["window-title"] or w["app-name"]
        rows[#rows + 1] = {
            text = title,
            subText = string.format("%s · workspace %s", w["app-name"], w["workspace"] or "?"),
            image = w["app-bundle-id"] and hs.image.imageFromAppBundle(w["app-bundle-id"]) or nil,
            id = w["window-id"],
        }
    end
    return rows
end

local function show()
    local rows = windows()
    if not rows then
        hs.alert.show("AeroSpace is not running", 1)
        return
    end
    if not chooser then
        chooser = hs.chooser.new(function(choice)
            if choice then
                hs.execute(string.format("%s focus --window-id %d", AEROSPACE, choice.id))
            end
        end)
        chooser:searchSubText(true) -- match the app name and workspace too
        chooser:placeholderText("Window title, app or workspace")
    end
    chooser:choices(rows)
    chooser:query(nil)
    chooser:show()
end

hs.urlevent.bind("aerospace-windows", function() show() end)

M.show = show
return M
