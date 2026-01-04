data = {
  ext_section = "tdspk_ContextualActions",
  update = false
}

local contexts = { "track", "arrange", "item" }

local function SaveSettings(inputs)
  local commands = {}
  for cmd in string.gmatch(inputs, "([^,]+)") do
    table.insert(commands, cmd)
  end

  for i, k in ipairs(contexts) do
    local cmd = commands[i]
    if not cmd then cmd = "" end
    reaper.SetExtState(data.ext_section, k, cmd, true)
  end
end

local function LoadSettings()
  local result = ""
  for _, k in ipairs(contexts) do
    local cmd = reaper.GetExtState(data.ext_section, k)
    result = result .. cmd .. ","
  end

  return result
end

local settings = LoadSettings()
reaper.ShowActionList(0)
local rv, inputs = reaper.GetUserInputs("tdspk - Contextual Actions - Settings", 3,
  "Track Action,Arrange Action,Item Action", settings)
if rv then SaveSettings(inputs) end
