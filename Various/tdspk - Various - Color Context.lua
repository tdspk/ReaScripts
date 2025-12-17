local version = reaper.GetAppVersion()
version = tonumber(version:match("%d.%d"))

if version >= 7.0 then
  reaper.set_action_options(3) -- Terminate and restart the script if it's already running
end

rv, col_string = reaper.BR_Win32_GetPrivateProfileString("reaper", "custcolors", "", reaper.get_ini_file())

-- col_string contains a long string with hex values of colors. divide the string in chunks for 6 and save it to table
col_table = {}
for i = 1, #col_string, 8 do
  table.insert(col_table, col_string:sub(i, i + 7))
end

colors = {

}

local function HexToRgb(hex_color)
  local r = tonumber(hex_color:sub(1, 2), 16) / 255
  local g = tonumber(hex_color:sub(3, 4), 16) / 255
  local b = tonumber(hex_color:sub(5, 6), 16) / 255
  return r, g, b
end

for i = 1, #col_table - 1 do
    local r, g, b = HexToRgb(col_table[i])
    table.insert(colors, reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, 1))
end

-- output color table with reaper.ShowConsoleMsg
for i = 1, #colors do
  reaper.ShowConsoleMsg(("%s\n"):format(colors[i]))
end

local ctx = reaper.ImGui_CreateContext('tdspk - Color Context')

local focus_once = true

local function ColorButton(text, color)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), color)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), color)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), color)
  local btn = reaper.ImGui_Button(ctx, text, 20, 20)
  reaper.ImGui_PopStyleColor(ctx, 3)
  return btn
end

local function Loop()
  if focus_once then
    reaper.ImGui_SetNextWindowFocus(ctx)
    focus_once = false
  end

  local is_focused = reaper.ImGui_IsWindowFocused(ctx)
  local visible, open = reaper.ImGui_Begin(ctx, 'Color Context', true)

  if visible then
    for i = 1, #col_table - 1 do
      local color = colors[i]
      local colstr = tostring(color)
      local btn = ColorButton(("##%d"):format(color, i), color)
      
      if btn then
        cmd = reaper.NamedCommandLookup("_SWS_TRACKCUSTCOL" .. i)
        reaper.Main_OnCommand(cmd, 0)
      end

      if i % 4 ~= 0 then
        reaper.ImGui_SameLine(ctx)
      end
    end
    reaper.ImGui_End(ctx)
  end
  if open then
    reaper.defer(Loop)
  end
end

reaper.defer(Loop)
