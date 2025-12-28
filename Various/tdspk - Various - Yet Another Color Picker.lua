--@description Yet Another Color Picker
--@version 1.1
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
--  1.1 Add action debug setting, auto-focus on open and hover
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
  version = "1.1",
  ext_section = "tdspk_YACP",
  last_segment = 0,
  mrk_rgn_idx = -1,
  mrk_rgn_pos = -1,
  rgn_end = -1,
  is_region = false,
  is_focused = false,
  hovered_idx = -1,
  post_init = false,
  is_docked = false,
  focus_ticks = 0,
  update_colors = false
}

settings = {

}

default_settings = {
  button_count = 16,
  button_size = 16,
  item_spacing = 2,
  orientation = 3,
  rounded_buttons = false,
  open_at_mousepos = true,
  show_selection_info = false,
  open_at_center = false,
  show_action_info = false,
  autosave_to_sws = false,
  no_close_apply = false
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
  [0] = "Tracks",
  [1] = "Items / Takes",
  [2] = "Markers",
  [3] = "Regions"
}

local default_colors = {
  [1] = {
    [1] = 118,
    [2] = 118,
    [3] = 118
  },
  [2] = {
    [1] = 137,
    [2] = 137,
    [3] = 105
  },
  [3] = {
    [1] = 137,
    [2] = 137,
    [3] = 129
  },
  [4] = {
    [1] = 168,
    [2] = 168,
    [3] = 168
  },
  [5] = {
    [1] = 153,
    [2] = 189,
    [3] = 19
  },
  [6] = {
    [1] = 135,
    [2] = 152,
    [3] = 51
  },
  [7] = {
    [1] = 63,
    [2] = 143,
    [3] = 184
  },
  [8] = {
    [1] = 148,
    [2] = 156,
    [3] = 187
  },
  [9] = {
    [1] = 82,
    [2] = 94,
    [3] = 134
  },
  [10] = {
    [1] = 42,
    [2] = 59,
    [3] = 130
  },
  [11] = {
    [1] = 128,
    [2] = 128,
    [3] = 255
  },
  [12] = {
    [1] = 128,
    [2] = 255,
    [3] = 128
  },
  [13] = {
    [1] = 255,
    [2] = 128,
    [3] = 0
  },
  [14] = {
    [1] = 128,
    [2] = 255,
    [3] = 255
  },
  [15] = {
    [1] = 35,
    [2] = 31,
    [3] = 27
  },
  [16] = {
    [1] = 254,
    [2] = 252,
    [3] = 251
  }
}

local colors = {}

local ctx = reaper.ImGui_CreateContext('tdspk - Yet Another Color Picker')

local function ResetColors()
  for i = 1, 16 do
    local r, g, b = table.unpack(default_colors[i])
    reaper.CF_SetCustomColor(i - 1, reaper.ColorToNative(r, g, b))
  end
end

local function UpdateColors()
  for i = 1, 16 do
    colors[i] = reaper.CF_GetCustomColor(i - 1)
  end
end

local function SaveColors()
  for i = 1, 16 do
    local color = colors[i]
    reaper.CF_SetCustomColor(i - 1, color)
  end
end

local function ResetSettings()
  for k, v in pairs(default_settings) do
    settings[k] = v
  end
end

local function SaveSettings()
  for k, v in pairs(settings) do
    reaper.SetExtState(data.ext_section, k, tostring(v), true)
  end

  if settings.autosave_to_sws then SaveColors() end
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
  elseif window == "ruler" and segment == "marker_lane" then
    data.last_segment = 2 -- marker
  elseif window == "ruler" and segment == "region_lane" then
    data.last_segment = 3 -- region
  end

  -- reset marker / region index
  data.mrk_rgn_idx = -1
  data.mrk_rgn_pos = -1
  data.is_region = false

  -- if the context returns markers or regions, get the index and cache it
  if data.last_segment > 1 then
    local time = reaper.BR_GetMouseCursorContext_Position()
    local marker_idx, region_idx = reaper.GetLastMarkerAndCurRegion(0, time)
    local idx = data.last_segment == 2 and marker_idx or region_idx

    local rv
    rv, data.is_region, data.mrk_rgn_pos, data.rgn_end, _, data.mrk_rgn_idx = reaper.EnumProjectMarkers2(0, idx)
  end
end

local function Init()
  -- Initialize Custom Colors
  local _, col_string = reaper.BR_Win32_GetPrivateProfileString("reaper", "custcolors", "", reaper.get_ini_file())
  local choice = -1

  if col_string == "" then
    choice = reaper.ShowMessageBox(
      "It appears there are no custom colors defined.\nDo you want to open SWS Color Managment?\nOtherwise, the REAPER 7.0 Color Palette will be used.",
      "No Custom Colors", 4)
  end

  if choice == 6 then
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWSCOLORWND"), 0)
    return false
  elseif choice == 7 then
    ResetColors()
  end

  UpdateColors()

  LoadSettings()
  GetMouseCursorContext()
  reaper.ImGui_SetConfigVar(ctx, reaper.ImGui_ConfigVar_HoverDelayNormal(), 1)

  return true
end

local function ColorButton(text, color, idx)
  local r, g, b = reaper.ColorFromNative(color)
  local clr = color
  color = reaper.ImGui_ColorConvertDouble4ToU32(r / 255, g / 255, b / 255, 1)

  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), color)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), color)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), color)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 1))
  local rounded_val = settings.rounded_buttons and 10 or 0
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), rounded_val)

  if data.hovered_idx == idx then
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), 1)
  end

  local btn = reaper.ImGui_Button(ctx, text, settings.button_size, settings.button_size)

  if data.hovered_idx == idx then reaper.ImGui_PopStyleVar(ctx) end

  if reaper.ImGui_IsItemHovered(ctx) then data.hovered_idx = idx end

  if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_DelayNormal() | reaper.ImGui_HoveredFlags_NoSharedDelay()) and reaper.ImGui_BeginTooltip(ctx) then
    reaper.ImGui_Text(ctx, "RMB on item for color picker\nRMB on window for settings")
    reaper.ImGui_EndTooltip(ctx)
  end

  reaper.ImGui_PopStyleVar(ctx)
  reaper.ImGui_PopStyleColor(ctx, 4)

  return btn
end

local function SmallText(text)
  reaper.ImGui_PushFont(ctx, reaper.ImGui_GetFont(ctx), reaper.ImGui_GetFontSize(ctx) * 0.8)
  reaper.ImGui_Text(ctx, text)
  reaper.ImGui_PopFont(ctx)
end

local function Settings()
  reaper.ImGui_SetNextWindowSize(ctx, 250, 0)

  if reaper.ImGui_BeginPopupContextWindow(ctx, "Settings", reaper.ImGui_PopupFlags_NoOpenOverItems() | reaper.ImGui_PopupFlags_MouseButtonRight()) then
    reaper.ImGui_PushFont(ctx, reaper.ImGui_GetFont(ctx), reaper.ImGui_GetFontSize(ctx) * 0.8)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 5, 5)

    if reaper.ImGui_CollapsingHeader(ctx, "Settings", false, reaper.ImGui_TreeNodeFlags_DefaultOpen()) then
      reaper.ImGui_SeparatorText(ctx, "Color Settings")

      if reaper.ImGui_Button(ctx, "Open SWS Color Manager...", 150) then
        local cmd = reaper.NamedCommandLookup("_SWSCOLORWND")
        reaper.Main_OnCommand(cmd, 0)
        data.update_colors = true
      end

      reaper.ImGui_SetItemTooltip(ctx, "Opens the SWS Color Manager.\nUse this if you want to save and load your palettes the SWS way.")

      if reaper.ImGui_Button(ctx, "Assign random colors...", 150) then
        for i = 0, 15 do
          local r, g, b = math.random(0, 255), math.random(0, 255), math.random(0, 255)
          reaper.CF_SetCustomColor(i, reaper.ColorToNative(r, g, b))
        end
        data.update_colors = true
      end

      if reaper.ImGui_Button(ctx, "Reset custom colors", 150) then
        ResetColors()
        data.update_colors = true
      end

      local rv
      rv, settings.autosave_to_sws = reaper.ImGui_Checkbox(ctx, "Autosave colors to SWS Palette", settings.autosave_to_sws)

      reaper.ImGui_SeparatorText(ctx, "UI Settings")

      reaper.ImGui_SetNextItemWidth(ctx, 100)
      rv, settings.orientation = reaper.ImGui_SliderInt(ctx, "Orientation", settings.orientation, 1,
        #orientation_names,
        orientation_names[settings.orientation])

      reaper.ImGui_SetNextItemWidth(ctx, 100)
      rv, settings.button_count = reaper.ImGui_SliderInt(ctx, "Button Count", settings.button_count, 1, 16)

      reaper.ImGui_SetNextItemWidth(ctx, 100)
      rv, settings.button_size = reaper.ImGui_SliderInt(ctx, "Button Size", settings.button_size, 10, 30)

      reaper.ImGui_SetNextItemWidth(ctx, 100)
      rv, settings.item_spacing = reaper.ImGui_SliderInt(ctx, "Button Spacing", settings.item_spacing, 0, 10)

      rv, settings.rounded_buttons = reaper.ImGui_Checkbox(ctx, "Rounded Buttons", settings.rounded_buttons)

      rv, settings.open_at_mousepos = reaper.ImGui_Checkbox(ctx, "Open at mouse cursor position",
        settings.open_at_mousepos)

      rv, settings.open_at_center = reaper.ImGui_Checkbox(ctx, "Open at mouse cursor center", settings
        .open_at_center)

      if reaper.ImGui_Button(ctx, "Reset UI settings", 100) then
        ResetSettings()
      end
    end

    if reaper.ImGui_CollapsingHeader(ctx, "Debug Options", false) then

    rv, settings.show_selection_info = reaper.ImGui_Checkbox(ctx, "Show Selection Info", settings
      .show_selection_info)

    rv, settings.show_action_info = reaper.ImGui_Checkbox(ctx, "Show Action Info", settings.show_action_info)
    rv, settings.no_close_apply = reaper.ImGui_Checkbox(ctx, "Don't close on apply", settings.no_close_apply)

    reaper.ImGui_Separator(ctx)
    end


    if reaper.ImGui_CollapsingHeader(ctx, "Manual", false) then
      reaper.ImGui_Text(ctx, "LMB to apply color")
      reaper.ImGui_Text(ctx, "RMB to open color picker")
      reaper.ImGui_Text(ctx, "Shift + LMB to apply color without closing window")
      reaper.ImGui_Text(ctx, "Alt + LMB to reset color (default color)")
      reaper.ImGui_Text(ctx, "Ctrl + Alt + LMB to apply random colors on selection")
      reaper.ImGui_Text(ctx, "RMB to open settings and info")
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
end

local function Loop()
  if data.update_colors then
    UpdateColors()
    data.update_colors = false
  end

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

  -- Push Styles
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), settings.item_spacing, settings.item_spacing)

  local bg_color = reaper.GetThemeColor("col_main_bg2", 0)
  local r, g, b = reaper.ColorFromNative(bg_color)
  local col = reaper.ImGui_ColorConvertDouble4ToU32(r / 255, g / 255, b / 255, 1)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), col)

  local visible, open = reaper.ImGui_Begin(ctx, "tdspk - YACP", true,
    reaper.ImGui_WindowFlags_NoResize() | reaper.ImGui_WindowFlags_NoFocusOnAppearing() |
    reaper.ImGui_WindowFlags_NoTitleBar())

  if visible then
    data.is_focused = reaper.ImGui_IsWindowFocused(ctx, reaper.ImGui_FocusedFlags_RootAndChildWindows())
    data.is_docked = reaper.ImGui_IsWindowDocked(ctx)

    if reaper.ImGui_IsWindowHovered(ctx) and not data.is_focused then
      data.focus_ticks = 0
    end

    if settings.show_selection_info then
      SmallText(string.format("Coloring: %s", segment_map[data.last_segment]))
    end

    local close_on_apply
    if data.is_docked then
      close_on_apply = false
    else
      close_on_apply = not reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftShift())
    end

    if settings.no_close_apply then close_on_apply = false end

    local apply_random = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl())
    local apply_default = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftAlt())

    local is_disabled
    if data.is_docked then
      is_disabled = false
    else
      is_disabled = not data.is_focused
    end

    reaper.ImGui_BeginDisabled(ctx, is_disabled)

    for i = 1, settings.button_count do
      local color = colors[i]
      local btn = ColorButton(("##%d"):format(i), color, i)

      if btn then
        local clr = color | 0x1000000
        local randomize = false

        if apply_random then
          clr = colors[math.random(1, #colors)]| 0x1000000
        elseif apply_default then
          clr = 1 & ~0x10000000
        end

        if apply_random and apply_default then
          randomize = true
        end

        if data.last_segment == 0 then -- color tracks
          for j = 0, reaper.CountSelectedTracks(0) do
            local tr = reaper.GetSelectedTrack(0, j)
            if tr then
              if randomize then
                clr = colors[math.random(1, #colors)]| 0x1000000
              end
              reaper.SetMediaTrackInfo_Value(tr, "I_CUSTOMCOLOR", clr)
            end
          end
        elseif data.last_segment == 1 then -- color items or takes
          for j = 0, reaper.CountSelectedMediaItems(0) - 1 do
            local item = reaper.GetSelectedMediaItem(0, j)
            local take_count = reaper.CountTakes(item)

            if item then
              if randomize then
                clr = colors[math.random(1, #colors)]| 0x1000000
              end

              if take_count <= 1 then
                reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", clr)
              elseif take_count > 1 then
                local take = reaper.GetActiveTake(item)
                reaper.SetMediaItemTakeInfo_Value(take, "I_CUSTOMCOLOR", clr)
              end
            end
          end
        else
          -- color either markers or regions
          reaper.SetProjectMarker3(0, data.mrk_rgn_idx, data.is_region, data.mrk_rgn_pos, data.rgn_end, "",
            clr)
        end

        reaper.UpdateArrange()

        if close_on_apply then open = false end
      end

      if reaper.ImGui_BeginPopupContextItem(ctx) then
        rv, colors[i] = reaper.ImGui_ColorPicker3(ctx, "Color Picker", colors[i])

        reaper.ImGui_EndPopup(ctx)
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

    Settings()

    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape(), false) then
      open = false
    end

    reaper.ImGui_End(ctx)
  end

  reaper.ImGui_PopStyleVar(ctx, 1)
  reaper.ImGui_PopStyleColor(ctx, 1)

  if open then
    reaper.defer(Loop)
  end

  if data.focus_ticks < 3 then
    local title = reaper.JS_Localize("tdspk - YACP", "common")
    local handle = reaper.JS_Window_Find(title, true)
    if handle then
      reaper.JS_Window_SetFocus(handle)
    end
    data.focus_ticks = data.focus_ticks + 1
  end

  data.post_init = true
end

if Init() then
  reaper.defer(Loop)
end
reaper.atexit(SaveSettings)

::eof::
