-- Hold either Command key alone for 0.4 seconds while Ghostty is foreground.
-- The popup remains open until Neovim handles Escape, q, or Enter.
local types = hs.eventtap.event.types
local log_file = hs.configdir .. "/nvim-motions-hold.log"
local serial, pending = 0, nil

local function log(message)
  local record = os.date("%Y-%m-%d %H:%M:%S ") .. message
  local file, err = io.open(log_file, "a")
  if file then
    file:write(record, "\n")
    file:close()
  else
    hs.printf("[nvim-motions] Unable to write log %s: %s", log_file, tostring(err))
  end
  hs.printf("[nvim-motions] %s", message)
end

local function cancel()
  serial = serial + 1
  if pending then
    pending:stop()
    pending = nil
  end
end

if _G.nvimMotionsHoldTap then
  _G.nvimMotionsHoldTap:stop()
end

_G.nvimMotionsHoldTap = hs.eventtap.new({
  types.flagsChanged, types.keyDown, types.leftMouseDown, types.rightMouseDown,
}, function(event)
  if event:getType() == types.flagsChanged then
    local code = event:getKeyCode()
    local flags = event:getFlags()
    local only_command = flags.cmd and not flags.alt and not flags.ctrl and not flags.shift
    if (code == 55 or code == 54) and only_command then
      cancel()
      local expected = serial
      log("Command down; hold started (keycode=" .. tostring(code) .. ")")
      pending = hs.timer.doAfter(0.4, function()
        if expected ~= serial then return end
        pending = nil
        local mods = hs.eventtap.checkKeyboardModifiers()
        if not (mods.cmd and not mods.alt and not mods.ctrl and not mods.shift) then
          log("Hold ignored: Command no longer held alone")
          return
        end
        local app = hs.application.frontmostApplication()
        local bundle = app and app:bundleID() or ""
        if not bundle:lower():find("ghostty", 1, true) then
          log("Hold ignored: frontmost app is " .. bundle)
          return
        end

        local home = os.getenv("HOME") or hs.configdir:match("^(.*)/%.hammerspoon$")
        local script = home .. "/.local/bin/nvim-motions-trigger"
        log("Command held 0.4 seconds; starting " .. script)
        local task = hs.task.new(script, function(code, stdout, stderr)
          log("Trigger exit=" .. tostring(code)
            .. " stdout=" .. tostring(stdout or ""):gsub("\n", " ")
            .. " stderr=" .. tostring(stderr or ""):gsub("\n", " "))
          _G.nvimMotionsHoldTask = nil
        end, {})
        if not task then
          log("ERROR: hs.task.new() failed")
          return
        end
        _G.nvimMotionsHoldTask = task
        if not task:start() then
          log("ERROR: task:start() failed")
          _G.nvimMotionsHoldTask = nil
        end
      end)
    else
      if pending then log("Command hold cancelled by modifier transition") end
      cancel()
    end
  else
    if pending then log("Command hold cancelled by key or mouse input") end
    cancel()
  end
  return false
end)

_G.nvimMotionsHoldTap:start()
log("Listener installed; enabled=" .. tostring(_G.nvimMotionsHoldTap:isEnabled())
  .. " secure_input=" .. tostring(hs.eventtap.isSecureInputEnabled()))
