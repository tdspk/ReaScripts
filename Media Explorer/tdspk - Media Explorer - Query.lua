local title = reaper.JS_Localize("Media Explorer", "common")
if not handle then
  handle = reaper.JS_Window_Find(title, true)
end

local combo = reaper.JS_Window_FindChildByID(handle, 0x3EA)
local edit = reaper.JS_Window_FindChildByID(combo, 0x3E9)

-- get path content
path = reaper.JS_Window_GetTitle(edit)

local combo = reaper.JS_Window_FindChildByID(handle, 0x3F7)
count = reaper.JS_WindowMessage_Send(combo, "CB_GETCOUNT", 0, 0, 0, 0)
a = reaper.JS_WindowMessage_Send(combo, "CB_GETLBTEXT", 0, 0, 0, 0)

local edit = reaper.JS_Window_FindChildByID(combo, 0x3E9)

search = reaper.JS_Window_GetTitle(edit)

text = "koll"
chars = {}

for i = 1, string.len(text) do
  local char = string.byte(string.sub(text, i, i))
  table.insert(chars, char)
end

reaper.JS_Window_SetFocus(edit)

for i=1, #chars do
  -- reaper.JS_WindowMessage_Send(edit, "WM_CHAR", chars[i], 0, 0, 0)
end

-- todo press enter
