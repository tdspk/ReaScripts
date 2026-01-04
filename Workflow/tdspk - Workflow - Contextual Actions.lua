local ext_section = "tdspk_ContextualActions"

contexts = { "track", "arrange", "item" }

actions = {

}

local function LoadSettings()
  for _, k in ipairs(contexts) do
    local cmd = reaper.GetExtState(ext_section, k)
    actions[k] = cmd
  end
end

local function ExecuteCommands(context)
  local v = actions[context]
  local cmd
  if tonumber(v) then
    cmd = v
  else
    cmd = reaper.NamedCommandLookup(v)
  end

  if cmd then
    reaper.Main_OnCommand(cmd, 0)
  end
end

LoadSettings()

local window, segment, details = reaper.BR_GetMouseCursorContext()

if window == "tcp" and segment == "track" then
  ExecuteCommands("track")
elseif window == "arrange" then
  if segment == "empty" or (segment == "track" and details == "empty") then
    ExecuteCommands("arrange")
  elseif window == "arrange" and segment == "track" and details == "item" then
    ExecuteCommands("item")
  end
end
