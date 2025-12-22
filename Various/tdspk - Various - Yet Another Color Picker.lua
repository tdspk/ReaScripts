-- TODO Spawn at mouse center

local version = reaper.GetAppVersion()
version = tonumber(version:match("%d.%d"))

-- local _, _, section_id, cmd_id = reaper.get_action_context()
-- local _, info = reaper.GetActionShortcutDesc(section_id, cmd_id, 0)

-- reaper.ShowConsoleMsg(info)

if version >= 7.0 then
  reaper.set_action_options(1) -- Terminate and restart the script if it's already running
end

data = {
  ext_section = "tdspk_YACP",
  update = false,
  last_segment = 0,
  last_clicked = 0,
  is_focused = false
}

settings = {

}

default_settings = {
  button_size = 15,
  item_spacing = 2,
  window_padding = 0,
  orientation = 3,
  close_on_click = false,
  open_at_mousepos = true,
  show_selection_info = false
}

local orientation_names = {
  [1] = "1x16",
  [2] = "2x8",
  [3] = "4x4",
  [4] = "8x2",
  [5] = "16x1"
}

local orientation_mod = {
  [1] = 1,
  [2] = 2,
  [3] = 4,
  [4] = 8,
  [5] = 16
}

local function HexToRgb(hex_color)
  local r = tonumber(hex_color:sub(1, 2), 16) / 255
  local g = tonumber(hex_color:sub(3, 4), 16) / 255
  local b = tonumber(hex_color:sub(5, 6), 16) / 255
  return r, g, b
end

-- Initialize Custom Colors

local _, col_string = reaper.BR_Win32_GetPrivateProfileString("reaper", "custcolors", "", reaper.get_ini_file())

col_table = {}
colors = {}

local choice = -1

if col_string == "" then
  choice = reaper.ShowMessageBox(
  "It appears there are no custom colors defined.\nDo you want to open SWS Color Managment?\nOtherwise, the tdspk Color Palette will be used.",
    "No Custom Colors", 4)
end

if choice == 6 then
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWSCOLORWND"), 0)
  goto eof
elseif choice == 7 then
  col_string =
  "767676006989890081898900A8A8A80013BD990033988700B88F3F00BB9C9400865E5200823B2A00FF80800080FF80000080FF00FFFF80001B1F2300FBFCFE00FE"
  reaper.BR_Win32_WritePrivateProfileString("reaper", "custcolors", col_string, reaper.get_ini_file())
end

-- col_string contains a long string with hex values of colors. Divide the string in chunks by 6 and save it to table
for i = 1, #col_string, 8 do
  table.insert(col_table, col_string:sub(i, i + 7))
end

for i = 1, 16 do
  local r, g, b = HexToRgb(col_table[i])
  table.insert(colors, reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, 1))
end


local ctx = reaper.ImGui_CreateContext('tdspk - Yet Another Color Picker')

local focus_once = true

local function ResetSettings()
  for k, v in pairs(default_settings) do
    settings[k] = v
  end
end

local function ColorButton(text, color)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), color)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), color)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), color)

  local btn = reaper.ImGui_Button(ctx, text, settings.button_size, settings.button_size)
  reaper.ImGui_PopStyleColor(ctx, 3)
  return btn
end

local function GetMouseCursorContext()
  local window, segment, details = reaper.BR_GetMouseCursorContext()

  if window == "tcp" and segment == "track" then
    data.last_segment = 0 -- track
  elseif window == "arrange" and segment == "track" and details == "item" then
    data.last_segment = 1 -- item
  end
end

local function Loop()
  if not data.is_focused then
    if reaper.JS_Mouse_GetState(1) == 1 or reaper.JS_Mouse_GetState(2) == 2 then
      GetMouseCursorContext()
    end
  end

  reaper.ImGui_SetNextWindowSize(ctx, 0, 0, reaper.ImGui_Cond_Always())
  local width, height = reaper.ImGui_GetWindowSize(ctx)

  if settings.open_at_mousepos then
    local mouse_x, mouse_y = reaper.GetMousePosition()
    local dpi = reaper.ImGui_GetWindowDpiScale(ctx)
    mouse_x = mouse_x * dpi
    mouse_y = mouse_y * dpi


    reaper.ImGui_SetNextWindowPos(ctx, mouse_x, mouse_y, reaper.ImGui_Cond_Once())
  end

  data.is_focused = reaper.ImGui_IsWindowFocused(ctx)

  local visible, open = reaper.ImGui_Begin(ctx, "tdspk - YACP", true,
    reaper.ImGui_WindowFlags_NoResize() | reaper.ImGui_WindowFlags_NoFocusOnAppearing() |
    reaper.ImGui_WindowFlags_NoTitleBar())

  if visible then
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), settings.item_spacing, settings.item_spacing)

    if settings.show_selection_info then
      reaper.ImGui_Text(ctx, string.format("Coloring: %s", data.last_segment == 0 and "Tracks" or "Items"))
    end

    for i = 1, 16 do
      local color = colors[i]
      local colstr = tostring(color)
      local btn = ColorButton(("##%d"):format(i), color)

      if btn then
        local cmd
        if data.last_segment == 0 then
          cmd = reaper.NamedCommandLookup("_SWS_TRACKCUSTCOL" .. i)
        elseif data.last_segment == 1 then
          cmd = reaper.NamedCommandLookup("_SWS_ITEMCUSTCOL" .. i)
        end
        reaper.Main_OnCommand(cmd, 0)
        if settings.close_on_click then open = false end
      end

      if settings.orientation > 0 then
        if i % orientation_mod[settings.orientation] ~= 0 then
          reaper.ImGui_SameLine(ctx)
        end
      end
    end

    if reaper.ImGui_BeginPopupContextWindow(ctx, "Settings") then
      reaper.ImGui_Text(ctx, "Settings")

      if reaper.ImGui_Button(ctx, "Manage Colors...") then
        local cmd = reaper.NamedCommandLookup("_SWSCOLORWND")
        reaper.Main_OnCommand(cmd, 0)
      end

      reaper.ImGui_SetNextItemWidth(ctx, 100)
      rv, settings.orientation = reaper.ImGui_SliderInt(ctx, "Orientation", settings.orientation, 1,
        #orientation_names,
        orientation_names[settings.orientation])

      reaper.ImGui_SetNextItemWidth(ctx, 100)
      rv, settings.button_size = reaper.ImGui_SliderInt(ctx, "Button Size", settings.button_size, 10, 30)

      reaper.ImGui_SetNextItemWidth(ctx, 100)
      rv, settings.item_spacing = reaper.ImGui_SliderInt(ctx, "Button Spacing", settings.item_spacing, 0, 10)

      rv, settings.close_on_click = reaper.ImGui_Checkbox(ctx, "Close Window on Click", settings.close_on_click)

      rv, settings.open_at_mousepos = reaper.ImGui_Checkbox(ctx, "Open at Mouse Position", settings.open_at_mousepos)

      rv, settings.show_selection_info = reaper.ImGui_Checkbox(ctx, "Show Selection Info", settings.show_selection_info)

      if reaper.ImGui_Button(ctx, "Reset") then
        ResetSettings()
      end
      reaper.ImGui_EndPopup(ctx)
    end

    reaper.ImGui_PopStyleVar(ctx, 1)

    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape(), false) then
      open = false
    end

    reaper.ImGui_End(ctx)
  end
  if open then
    reaper.defer(Loop)
  end
end

local function SaveSettings()
  for k, v in pairs(settings) do
    reaper.SetExtState(data.ext_section, k, tostring(v), true)
  end
end

local function MapExtStateValues(ext_value)
  if tonumber(ext_value) then
    ext_value = tonumber(ext_value)
  end

  if ext_value == "true" then ext_value = true end
  if ext_value == "false" then ext_value = false end
  if ext_value == "nil" then ext_value = nil end

  return ext_value
end

local function LoadSettings()
  for k, v in pairs(default_settings) do
    if reaper.HasExtState(data.ext_section, k) then
      settings[k] = MapExtStateValues(reaper.GetExtState(data.ext_section, k))
    else
      settings[k] = v
    end
  end
end

LoadSettings()

-- Get Mouse context to indicate which segment is selected
GetMouseCursorContext()

reaper.defer(Loop)
reaper.atexit(SaveSettings)

::eof::
