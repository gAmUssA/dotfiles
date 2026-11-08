-- Rex config migrated from tmux, Herdr, Ghostty and iTerm2.
-- Prefix: ctrl+space (from tmux and Herdr).

-- cmd+k clears the terminal (by choice); the session picker moves to shift+cmd+k.
rex.bind("cmd+k", "com.superlogical.terminal.clear")
rex.bind("shift+cmd+k", "session.switch")

-- Pass the prefix through to programs when pressed twice.
rex.bind("ctrl+space>ctrl+space", "pane.send_key", { key = "ctrl+space" })

-- tmux (~/.tmux.conf)
rex.bind("ctrl+space>shift+n", "session.new")
rex.bind("ctrl+space>r", "client.config.reload")
rex.bind("ctrl+space>shift+0", "pane.move", { direction = "down" })
rex.bind("ctrl+space>shift+9", "pane.move", { direction = "up" })
rex.bind("ctrl+space>shift+2", "pane.balance")
rex.bind("ctrl+space>shift+1", "pane.balance")
rex.bind("ctrl+space>ctrl+a", "pane.focus_next")

-- Herdr (~/.config/herdr/config.toml)
rex.bind("ctrl+space>v", "pane.split", { direction = "right" })
rex.bind("ctrl+space>shift+\\", "pane.split", { direction = "right" })
rex.bind("ctrl+space>-", "pane.split", { direction = "down" })
rex.bind("ctrl+space>shift+-", "pane.split", { direction = "down" })
rex.bind("ctrl+space>z", "pane.zoom")
rex.bind("ctrl+space>x", "pane.zoom")
rex.bind("ctrl+space>shift+q", "pane.close")
rex.bind("ctrl+space>h", "pane.focus", { direction = "left" })
rex.bind("ctrl+alt+h", "pane.focus", { direction = "left" })
rex.bind("ctrl+space>j", "pane.focus", { direction = "down" })
rex.bind("ctrl+alt+j", "pane.focus", { direction = "down" })
rex.bind("ctrl+space>k", "pane.focus", { direction = "up" })
rex.bind("ctrl+alt+k", "pane.focus", { direction = "up" })
rex.bind("ctrl+space>l", "pane.focus", { direction = "right" })
rex.bind("ctrl+alt+l", "pane.focus", { direction = "right" })
rex.bind("ctrl+space>p", "client.tab.previous")
rex.bind("ctrl+alt+p", "client.tab.previous")
rex.bind("ctrl+space>n", "client.tab.next")
rex.bind("ctrl+alt+n", "client.tab.next")
rex.bind("ctrl+alt+shift+p", "session.previous")
rex.bind("ctrl+alt+shift+n", "session.next")
rex.bind("ctrl+space>ctrl+h", "pane.resize", { direction = "left" })
rex.bind("ctrl+space>ctrl+j", "pane.resize", { direction = "down" })
rex.bind("ctrl+space>ctrl+u", "pane.resize", { direction = "up" })
rex.bind("ctrl+space>ctrl+l", "pane.resize", { direction = "right" })
rex.bind("ctrl+space>o", "session.switch")
rex.bind("ctrl+space>shift+p", "pane.rename")
rex.bind("ctrl+space>t", "pane.rename")

-- iTerm2 (com.googlecode.iterm2.plist)
rex.bind("shift+cmd+\\", "pane.split", { direction = "right" })
rex.bind("shift+cmd+left", "client.tab.move", { direction = "backward" })
rex.bind("shift+cmd+right", "client.tab.move", { direction = "forward" })
rex.bind("cmd+left", "pane.send_key", { key = "ctrl+a" })
rex.bind("cmd+right", "pane.send_key", { key = "ctrl+e" })

-- Floating "popups", in place of tmux display-popup and Herdr [[keys.command]].
-- Opens a floating pane in the focused pane's directory; it closes when the program exits.
local function pane_cwd(block_id)
  local terminal = "com.superlogical.terminal"
  local r = block_id and rex.block.call(terminal, "pwd", { block_id = block_id })
  if r and r.pwd and r.pwd ~= "" then
    local path = r.pwd:gsub("^file://[^/]*", "")
    return (path:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
  end
  local p = block_id and rex.block.call(terminal, "process", { block_id = block_id })
  if p then
    return (p.foreground and p.foreground.cwd) or (p.child and p.child.cwd) or p.home
  end
end

rex.action{
  name = "popup",
  title = "Open Floating Pane Here",
  description = "Run a command (or a shell) in a floating pane in the focused pane's directory.",
  args = { command = "string?", size = "number?" },
  run = function(ctx, args)
    local size = args.size or 0.8
    local margin = (1 - size) / 2
    local options = { cwd = pane_cwd(ctx.block_id) }
    if args.command and args.command ~= "" then
      options.command = { "/bin/zsh", "-lic", args.command }
    end
    local _, err = rex.session.new_layer{
      session_id = ctx.session_id,
      bounds = { margin, margin, size, size },
      focus = true,
      layout = rex.layout.block{ flavor = "com.superlogical.terminal.shell", options = options },
    }
    if err then error(err) end
  end,
}

rex.bind("ctrl+space>g", "popup", { command = "lazygit", size = 0.9 })
rex.bind("ctrl+space>enter", "popup", {})
rex.bind("ctrl+space>y", "popup", { command = "claude" })
