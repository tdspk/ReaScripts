--@description Yet Another Color Picker
--@version 1.0.1
--@author Tadej Supukovic (tdspk)
--@about
--  # Yet Another Color Picker
--  A simple color picker with no fancy features. It uses the SWS custom color palette.
--  # Requirements
--  JS_ReaScriptAPI, SWS Extension, ReaImGui
--@links
--  Website https://www.tdspkaudio.com
--@donation
--  https://ko-fi.com/tdspkaudio
--  https://coindrop.to/tdspkaudio
--@provides
--  [main] .
-- @changelog
--  1.0.1 Auto-Close window, add modifiers to reset color
--  1.0 Initial Release

local extensions = {
  [1] = {
    name = "ReaPack",
    url = "https://reapack.com/",
    installed = reaper.APIExists("ReaPack_AboutRepository")
  },
  [2] = {
    name = "SWS Extension",
    url = "https://www.sws-extension.org/",
    installed = reaper.APIExists("CF_GetSWSVersion")
  }
}

local packages = {
  [1] = {
    name = "ReaImGui",
    installed = reaper.APIExists("ImGui_GetVersion")
  },
  [2] = {
    name = "JS_ReaScriptAPI",
    installed = reaper.APIExists("JS_ReaScriptAPI_Version")
  }
}

local function CheckDependencies()
  local message
  for i = 1, #extensions do
    if not extensions[i].installed then
      if not message then message = "Yet Another Color Picker requires the following extensions:\n\n" end
      message = message .. extensions[i].name .. " - Please install it from " .. extensions[i].url .. "\n"
    end
  end

  if message then
    reaper.ShowMessageBox(message, "Yet Another Color Picker - Missing Dependencies", 0)
    return false
  end

  local message

  for i = 1, #packages do
    if not packages[i].installed then
      if not message then message = "Yet Another Color Picker requires the following packages:\n\n" end
      message = message .. packages[i].name .. "\n"
    end
  end

  if message then
    if reaper.ShowMessageBox(message, "Yet Another Color Picker - Missing Packages", 4) == 6 then
      reaper.ReaPack_BrowsePackages("reascript api")
    end
    return false
  end

  return true
end

if not CheckDependencies() then
  goto eof
end

local version = reaper.GetAppVersion()
version = tonumber(version:match("%d.%d"))

if version >= 7.31 then
  reaper.set_action_options(1) -- Terminate and restart the script if it's already running
end

data = {
  version = "1.0",
  ext_section = "tdspk_YACP",
  last_segment = 0,
  is_focused = false,
  hovered_idx = -1,
  post_init = false
}

settings = {

}

default_settings = {
  button_size = 16,
  item_spacing = 2,
  orientation = 3,
  open_at_mousepos = true,
  show_selection_info = false,
  open_at_center = false,
  show_action_info = false
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

local segment_map = {
  [0] = "TRACK",
  [1] = "ITEM"
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
    "It appears there are no custom colors defined.\nDo you want to open SWS Color Managment?\nOtherwise, the REAPER 7.0 Color Palette will be used.",
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

local function GetMouseCursorContext()
  -- Get Mouse context to indicate which segment is selected
  local window, segment, details = reaper.BR_GetMouseCursorContext()

  if window == "tcp" and segment == "track" then
    data.last_segment = 0 -- track
  elseif window == "arrange" and segment == "track" and details == "item" then
    data.last_segment = 1 -- item
  end
end

local function Init()
  LoadSettings()
  GetMouseCursorContext()
  reaper.ImGui_SetConfigVar(ctx, reaper.ImGui_ConfigVar_HoverDelayNormal(), 1)
end

local function ColorButton(text, color, idx)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), color)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), color)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), color)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 1))

  if data.hovered_idx == idx then
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), 1)
  end

  local btn = reaper.ImGui_Button(ctx, text, settings.button_size, settings.button_size)

  if data.hovered_idx == idx then reaper.ImGui_PopStyleVar(ctx) end

  if reaper.ImGui_IsItemHovered(ctx) then data.hovered_idx = idx end

  if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_DelayNormal() | reaper.ImGui_HoveredFlags_NoSharedDelay()) and reaper.ImGui_BeginTooltip(ctx) then
    reaper.ImGui_Text(ctx, "Right-click for settings")
    reaper.ImGui_EndTooltip(ctx)
  end

  reaper.ImGui_PopStyleColor(ctx, 4)

  return btn
end

local function SmallText(text)
  reaper.ImGui_PushFont(ctx, reaper.ImGui_GetFont(ctx), reaper.ImGui_GetFontSize(ctx) * 0.8)
  reaper.ImGui_Text(ctx, text)
  reaper.ImGui_PopFont(ctx)
end
local function Loop()
  if not data.is_focused then
    if reaper.JS_Mouse_GetState(1) == 1 or reaper.JS_Mouse_GetState(2) == 2 then
      GetMouseCursorContext()
    end
  end

  reaper.ImGui_SetNextWindowSize(ctx, 0, 0, reaper.ImGui_Cond_Always())

  if settings.open_at_mousepos and not data.post_init then
    local mouse_x, mouse_y = reaper.GetMousePosition()
    local dpi = reaper.ImGui_GetWindowDpiScale(ctx)

    mouse_x = mouse_x / dpi
    mouse_y = mouse_y / dpi

    local pivot = settings.open_at_center and 0.5 or 0

    reaper.ImGui_SetNextWindowPos(ctx, mouse_x, mouse_y, reaper.ImGui_Cond_Once(), pivot, pivot)
  end

  local visible, open = reaper.ImGui_Begin(ctx, "tdspk - YACP", true,
    reaper.ImGui_WindowFlags_NoResize() | reaper.ImGui_WindowFlags_NoFocusOnAppearing() |
    reaper.ImGui_WindowFlags_NoTitleBar())

  data.post_init = true

  if visible then
    data.is_focused = reaper.ImGui_IsWindowFocused(ctx)

    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), settings.item_spacing, settings.item_spacing)

    if settings.show_selection_info then
      SmallText(string.format("Coloring: %s", data.last_segment == 0 and "Tracks" or "Items"))
    end

    local close_on_apply = not reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftShift())
    local apply_random = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl())
    local apply_default = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftAlt())

    reaper.ImGui_BeginDisabled(ctx, not data.is_focused)

    for i = 1, 16 do
      local color = colors[i]
      local btn = ColorButton(("##%d"):format(i), color, i)

      local cmd

      if btn then
        if apply_random then
          cmd = reaper.NamedCommandLookup(("_SWS_%sRANDCOL"):format(segment_map[data.last_segment]))
        elseif apply_default then
          cmd = data.last_segment == 0 and 40359 or 40707 -- set either to track or item default color
        else
          cmd = reaper.NamedCommandLookup(("_SWS_%sCUSTCOL%d"):format(segment_map[data.last_segment], i))
        end
      end

      if cmd then
        reaper.Main_OnCommand(cmd, 0)
        if close_on_apply then open = false end
      end

      if settings.orientation > 0 then
        if i % orientation_mod[settings.orientation] ~= 0 then
          reaper.ImGui_SameLine(ctx)
        end
      end
    end

    reaper.ImGui_EndDisabled(ctx)

    local action_text = ("%sapply\n%scolor"):format(
      not close_on_apply and "multi-" or "",
      apply_random and "random " or apply_default and "default " or ""
    )

    if settings.show_action_info then
      SmallText(action_text)
    end
    
    reaper.ImGui_SetNextWindowSize(ctx, 200, 0)

    if reaper.ImGui_BeginPopupContextWindow(ctx, "Settings") then
      reaper.ImGui_PushFont(ctx, reaper.ImGui_GetFont(ctx), reaper.ImGui_GetFontSize(ctx) * 0.8)
      reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 5, 5)

      if reaper.ImGui_CollapsingHeader(ctx, "Settings", false, reaper.ImGui_TreeNodeFlags_DefaultOpen()) then
        if reaper.ImGui_Button(ctx, "Open SWS Color Manager...") then
          local cmd = reaper.NamedCommandLookup("_SWSCOLORWND")
          reaper.Main_OnCommand(cmd, 0)
        end

        reaper.ImGui_Separator(ctx)

        reaper.ImGui_SetNextItemWidth(ctx, 100)
        rv, settings.orientation = reaper.ImGui_SliderInt(ctx, "Orientation", settings.orientation, 1,
          #orientation_names,
          orientation_names[settings.orientation])

        reaper.ImGui_SetNextItemWidth(ctx, 100)
        rv, settings.button_size = reaper.ImGui_SliderInt(ctx, "Button Size", settings.button_size, 10, 30)

        reaper.ImGui_SetNextItemWidth(ctx, 100)
        rv, settings.item_spacing = reaper.ImGui_SliderInt(ctx, "Button Spacing", settings.item_spacing, 0, 10)

        rv, settings.open_at_mousepos = reaper.ImGui_Checkbox(ctx, "Open at mouse cursor position",
          settings.open_at_mousepos)

        rv, settings.open_at_center = reaper.ImGui_Checkbox(ctx, "Open at mouse cursor center", settings
          .open_at_center)

        reaper.ImGui_SeparatorText(ctx, "Debug")

        rv, settings.show_selection_info = reaper.ImGui_Checkbox(ctx, "Show Selection Info", settings
          .show_selection_info)

        rv, settings.show_action_info = reaper.ImGui_Checkbox(ctx, "Show Action Info", settings.show_action_info)

        reaper.ImGui_Separator(ctx)

        if reaper.ImGui_Button(ctx, "Reset") then
          ResetSettings()
        end
      end

      if reaper.ImGui_CollapsingHeader(ctx, "Manual", false) then
        reaper.ImGui_Text(ctx, "Left-Click to apply color")
        reaper.ImGui_Text(ctx, "Shift-Click to apply color without closing window")
        reaper.ImGui_Text(ctx, "Alt-Shift to reset color (default color)")
        reaper.ImGui_Text(ctx, "Right-Click to open settings and info")
        reaper.ImGui_Text(ctx, "Close with ESC")
      end

      if reaper.ImGui_CollapsingHeader(ctx, "Info", false) then
        local info = {
          "Yet Another Color Picker",
          "Version " .. data.version,
          "A tool by tdspk"
        }

        for i = 1, #info do
          reaper.ImGui_Text(ctx, info[i])
        end

        reaper.ImGui_Separator(ctx)

        if reaper.ImGui_Button(ctx, "Website") then
          reaper.CF_ShellExecute("https://www.tdspkaudio.com")
        end

        if reaper.ImGui_Button(ctx, "Donate") then
          reaper.CF_ShellExecute("https://coindrop.to/tdspkaudio")
        end

        if reaper.ImGui_Button(ctx, "GitHub Repository") then
          reaper.CF_ShellExecute("https://github.com/tdspk/ReaScripts")
        end
      end

      reaper.ImGui_PopStyleVar(ctx, 1)
      reaper.ImGui_PopFont(ctx)

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

Init()

reaper.defer(Loop)
reaper.atexit(SaveSettings)

::eof::
