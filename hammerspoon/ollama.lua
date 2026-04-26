-- Ollama menu bar: shows the currently loaded model, click to swap or unload.
-- Talks to the local Ollama HTTP API at http://localhost:11434.

local OLLAMA_HOST = "http://localhost:11434"
local REFRESH_S   = 10
local KEEP_ALIVE  = "10m"

local M = {}
local menu = hs.menubar.new()

local state = {
    online    = false,
    loaded    = {},  -- list of {name=, size=}
    available = {},  -- list of {name=, size=}
}

local function fmtBytes(n)
    if not n or n == 0 then return "" end
    local gb = n / (1024^3)
    if gb >= 1 then return string.format("%.1fG", gb) end
    return string.format("%.0fM", n / (1024^2))
end

local function shortName(name)
    if not name then return "?" end
    if #name <= 16 then return name end
    return name:sub(1, 15) .. "…"
end

local function jdec(body)
    local ok, decoded = pcall(hs.json.decode, body or "")
    if ok then return decoded end
    return nil
end

local function isLoaded(name)
    for _, l in ipairs(state.loaded) do
        if l.name == name then return true end
    end
    return false
end

local function render()
    if not state.online then
        menu:setTitle("🦙 ⚠")
        menu:setTooltip("Ollama unreachable at " .. OLLAMA_HOST)
    elseif #state.loaded == 0 then
        menu:setTitle("🦙 ·")
        menu:setTooltip("Ollama: idle")
    else
        local first = state.loaded[1].name
        local extra = #state.loaded > 1 and ("+" .. (#state.loaded - 1)) or ""
        menu:setTitle("🦙 " .. shortName(first) .. extra)
        menu:setTooltip(("Ollama: %d model%s loaded")
            :format(#state.loaded, #state.loaded == 1 and "" or "s"))
    end

    local items = {}
    if not state.online then
        table.insert(items, {title = "Ollama unreachable", disabled = true})
        table.insert(items, {title = "-"})
        table.insert(items, {title = "Refresh", fn = function() M.refresh() end})
        menu:setMenu(items)
        return
    end

    if #state.loaded == 0 then
        table.insert(items, {title = "No model loaded", disabled = true})
    else
        table.insert(items, {title = "Loaded:", disabled = true})
        for _, m in ipairs(state.loaded) do
            local size = fmtBytes(m.size)
            local label = "  " .. m.name .. (size ~= "" and ("  " .. size) or "")
            table.insert(items, {title = label, disabled = true})
        end
    end
    table.insert(items, {title = "-"})

    if #state.available > 0 then
        table.insert(items, {title = "Switch to:", disabled = true})
        for _, m in ipairs(state.available) do
            local mark = isLoaded(m.name) and "✓ " or "  "
            local size = fmtBytes(m.size)
            local label = mark .. m.name .. (size ~= "" and ("  " .. size) or "")
            table.insert(items, {
                title = label,
                fn    = function() M.load(m.name) end,
            })
        end
        table.insert(items, {title = "-"})
    end

    table.insert(items, {
        title    = "Unload all",
        fn       = function() M.unloadAll() end,
        disabled = #state.loaded == 0,
    })
    table.insert(items, {title = "Refresh", fn = function() M.refresh() end})
    menu:setMenu(items)
end

local function fetchPS(cb)
    hs.http.asyncGet(OLLAMA_HOST .. "/api/ps", nil, function(status, body)
        if status ~= 200 then return cb(false) end
        local data = jdec(body)
        state.loaded = {}
        if data and data.models then
            for _, m in ipairs(data.models) do
                table.insert(state.loaded, {name = m.name, size = m.size})
            end
        end
        cb(true)
    end)
end

local function fetchTags(cb)
    hs.http.asyncGet(OLLAMA_HOST .. "/api/tags", nil, function(status, body)
        if status ~= 200 then return cb(false) end
        local data = jdec(body)
        state.available = {}
        if data and data.models then
            for _, m in ipairs(data.models) do
                table.insert(state.available, {name = m.name, size = m.size})
            end
            table.sort(state.available, function(a, b) return a.name < b.name end)
        end
        cb(true)
    end)
end

function M.refresh()
    fetchPS(function(ok)
        state.online = ok
        if ok then
            fetchTags(function() render() end)
        else
            render()
        end
    end)
end

function M.load(name)
    hs.alert.show("Loading " .. name .. "…", 0.8)
    local body = hs.json.encode({
        model      = name,
        keep_alive = KEEP_ALIVE,
        prompt     = "",
    })
    hs.http.asyncPost(OLLAMA_HOST .. "/api/generate", body,
        {["Content-Type"] = "application/json"},
        function(status)
            if status == 200 then
                hs.alert.show(name .. " ready", 0.8)
            else
                hs.alert.show("Load failed (" .. tostring(status) .. ")", 1.2)
            end
            M.refresh()
        end)
end

function M.unloadAll()
    if #state.loaded == 0 then return end
    local names = {}
    for _, m in ipairs(state.loaded) do table.insert(names, m.name) end
    local pending = #names
    for _, name in ipairs(names) do
        local body = hs.json.encode({model = name, keep_alive = 0, prompt = ""})
        hs.http.asyncPost(OLLAMA_HOST .. "/api/generate", body,
            {["Content-Type"] = "application/json"},
            function()
                pending = pending - 1
                if pending == 0 then
                    hs.alert.show("Ollama: unloaded all", 0.8)
                    M.refresh()
                end
            end)
    end
end

M.refresh()
hs.timer.doEvery(REFRESH_S, function() M.refresh() end)

return M
