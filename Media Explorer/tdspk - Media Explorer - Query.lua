--@description Media Explorer - Query
--@version 0.4
--@author Tadej Supukovic (tdspk)
--@about
--  # Media Explorer - Query
--  A small script to save search queries in the Media Explorer on a per-project basis.
--  # Requirements
--  JS_ReaScriptAPI, SWS Extension, ReaImGui
--@links
--  Website https://www.tdspkaudio.com
--@donation
--  https://ko-fi.com/tdspkaudio
--  https://coindrop.to/tdspkaudio
--@provides
--  json/json.lua
--  [main] .
-- @changelog
--  TBA

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]
json = dofile(script_path .. "/json/json.lua") -- import json library

local version = reaper.GetAppVersion()
version = tonumber(version:match("%d.%d+"))

if version >= 7.03 then
  reaper.set_action_options(3) -- Terminate and restart the script if it's already running
end

local ext_section = "tdspk_MXQuery"
local script_version = "0.3"

settings = {
  pinned = false
}

ui = {
  window_flags = reaper.ImGui_WindowFlags_NoDocking() | reaper.ImGui_WindowFlags_NoTitleBar() | reaper.ImGui_WindowFlags_TopMost(),
  pinned_flags = reaper.ImGui_WindowFlags_NoMove() | reaper.ImGui_WindowFlags_NoResize() |
      reaper.ImGui_WindowFlags_NoBackground(),
  hidden_flags = reaper.ImGui_WindowFlags_NoMove() | reaper.ImGui_WindowFlags_NoBackground(),
  pinned_pos = { x = 0, y = 0 },
  hidden = false,
  color = {
    black = reaper.ImGui_ColorConvertDouble4ToU32(0, 0, 0, 1),
    white = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 1),
    green = reaper.ImGui_ColorConvertDouble4ToU32(0, 1, 0, 1),
    red = reaper.ImGui_ColorConvertDouble4ToU32(1, 0, 0, 1),
    blue = reaper.ImGui_ColorConvertDouble4ToU32(0, 0, 1, 1),
    yellow = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 0, 1),
  },
  color_palette = {
    green = reaper.ImGui_ColorConvertDouble4ToU32(0, 1, 0, 1),
    red = reaper.ImGui_ColorConvertDouble4ToU32(1, 0, 0, 1),
    blue = reaper.ImGui_ColorConvertDouble4ToU32(0, 0, 1, 1),
    yellow = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 0, 1),
  }
}

data = {
  update_handles = true,
  mx_handle = nil,
  mx_path = nil,
  mx_search = nil,
  -- tab structure:
  --- idx
  --- term
  --- path
  --- color
  tabs = {},
  selected_tab = -1
}

local function GetComplementaryColor(r, g, b)
  local luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
  if luminance > 0.6 then
    return reaper.ImGui_ColorConvertDouble4ToU32(0, 0, 0, 1)
  else
    return reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 1)
  end
end

function Print(txt)
  reaper.ClearConsole()
  reaper.ShowConsoleMsg(txt)
end

function Save()
  local tabs = json.encode(data.tabs)
  reaper.SetProjExtState(0, ext_section, "tabs", tabs)

  local settings = json.encode(settings)
  reaper.SetProjExtState(0, ext_section, "settings", settings)
end

function SavePreset(slot)
  local tabs = json.encode(data.tabs)
  reaper.SetExtState(ext_section, ("preset_%d"):format(slot), tabs, true)
end

function Load()
  local rv, tabs = reaper.GetProjExtState(0, ext_section, "tabs")
  if rv > 0 then
    data.tabs = json.decode(tabs)
  end

  local rv, sett = reaper.GetProjExtState(0, ext_section, "settings")
  if rv > 0 then
    settings = json.decode(sett)
  end
end

function LoadPreset(slot)
  local tabs = reaper.GetExtState(ext_section, ("preset_%d"):format(slot))
  if tabs then
    data.tabs = json.decode(tabs)
  end
end

function IsMxOpen()
  local is_open = reaper.GetToggleCommandState(50124) -- Media explorer: Show/hide media explorer

  return is_open == 1 and true or false
end

function UpdateHandles()
  local title = reaper.JS_Localize("Media Explorer", "common")
  data.mx_handle = reaper.JS_Window_Find(title, true)

  local combo = reaper.JS_Window_FindChildByID(data.mx_handle, 0x3EA) -- get path comboBoxHwnd
  data.mx_path = reaper.JS_Window_FindChildByID(combo, 0x3E9)

  local combo = reaper.JS_Window_FindChildByID(data.mx_handle, 0x3F7) -- get search comboBoxHwnd
  data.mx_search = reaper.JS_Window_FindChildByID(combo, 0x3E9)

  -- data.mx_toolbar = reaper.JS_Window_FindChild(data.mx_handle, "Media Explorer toolbar", true)

  data.update_handles = false
end

function TypeChars(handle, text)
  local chars = {}
  for i = 1, string.len(text) do
    local char = string.byte(string.sub(text, i, i))
    table.insert(chars, char)
  end

  reaper.JS_Window_SetFocus(handle)

  for i = 1, #chars do
    reaper.JS_WindowMessage_Send(handle, "WM_CHAR", chars[i], 0, 0, 0)
  end

  -- local parent = reaper.JS_Window_GetParent(handle)
  -- reaper.JS_Window_SetFocus(parent)

  reaper.JS_WindowMessage_Send(handle, "WM_KEYDOWN", 0x0D, 0, 0, 0)
end

function Search(path, term)
  reaper.JS_Window_SetFocus(data.mx_path)
  TypeChars(data.mx_path, path)

  reaper.JS_Window_SetFocus(data.mx_search)
  TypeChars(data.mx_search, term)
end

ctx = reaper.ImGui_CreateContext("tdspk - Media Explorer Tabs")

function Loop()
  if IsMxOpen() then
    if data.update_handles then UpdateHandles() end
    ui.hidden = false

    -- TODO handle windows / mac os
  else
    ui.hidden = true
    data.update_handles = true
  end

  local dpi = reaper.ImGui_GetWindowDpiScale(ctx)

  -- if settings.pinned then
  --   rv, ui.mx_x, ui.mx_y = reaper.JS_Window_GetRect(data.mx_handle)
  --   -- set pinned position relative to media explorer position
  --   local x = ui.mx_x + ui.pinned_pos.x
  --   local y = ui.mx_y + ui.pinned_pos.y
  --   reaper.ImGui_SetNextWindowPos(ctx, x, y)
  -- end

  reaper.ImGui_SetNextWindowSize(ctx, 0, 0)
  local visible, open = reaper.ImGui_Begin(ctx, 'Media Explorer Tabs', false,
    ui.window_flags | (ui.hidden and ui.hidden_flags or 0) | (settings.pinned and ui.pinned_flags or 0))
  if visible then
    if IsMxOpen() then
      local btnctx = false
      for idx, tab in ipairs(data.tabs) do
        local doremove = false
        
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), tab.color)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), tab.color)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), tab.color)

        -- convert tab color to rgb
        local r, g, b = reaper.ImGui_ColorConvertU32ToDouble4(tab.color)
        local text_color = GetComplementaryColor(r, g, b)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), text_color)

        local btn = reaper.ImGui_Button(ctx, string.format("%s##%d", tab.term, idx))
        reaper.ImGui_PopStyleColor(ctx, 4)

        if btn then
          if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then
            doremove = true
          else
            data.selected_tab = idx
            -- Perform Search
            Search(data.tabs[idx].path, data.tabs[idx].term)
          end
        end

        -- right click context menu
        if reaper.ImGui_BeginPopupContextItem(ctx, nil) then
          btnctx = true

          local counter = 0
          for k, v in pairs(ui.color_palette) do
            if reaper.ImGui_ColorButton(ctx, ("##%s"):format(k), v, reaper.ImGui_ColorEditFlags_NoTooltip(), 20, 20) then
              data.tabs[idx].color = v
            end
            counter = counter + 1

            -- do a SameLine until 5 elements have been drawn
            if counter % 5 ~= 0 then reaper.ImGui_SameLine(ctx) end
          end

          if reaper.ImGui_MenuItem(ctx, "Remove", "Alt+Click") then
            doremove = true
          end
          reaper.ImGui_EndPopup(ctx)
        end

        if doremove then
          table.remove(data.tabs, idx)
        end

        reaper.ImGui_SameLine(ctx)
      end

      if reaper.ImGui_Button(ctx, "+") then
        local term = reaper.JS_Window_GetTitle(data.mx_search)
        if string.len(term) > 0 then
          local path = reaper.JS_Window_GetTitle(data.mx_path)
          table.insert(data.tabs, { term = term, path = path, color = ui.color_palette.default })
          data.selected_tab = #data.tabs
        end
      end

      reaper.ImGui_SameLine(ctx, 0, 50)

      if not btnctx and reaper.ImGui_BeginPopupContextWindow(ctx) then
        if reaper.ImGui_MenuItem(ctx, "Pinned", "", settings.pinned) then
          settings.pinned = not settings.pinned
          -- rv, ui.mx_x, ui.mx_y = reaper.JS_Window_GetRect(data.mx_handle)
          -- -- local viewport = reaper.ImGui_GetWindowViewport(ctx)
          -- -- local vx, vy = reaper.ImGui_GetViewportPos(viewport)
          -- local x, y = reaper.ImGui_GetWindowPos(ctx)
          -- ui.pinned_pos.x = x - ui.mx_x
          -- ui.pinned_pos.y = y - ui.mx_y
        end

        reaper.ImGui_Separator(ctx)

        if reaper.ImGui_BeginMenu(ctx, "Save") then
          for i=1, 3 do
            if reaper.ImGui_MenuItem(ctx, ("Preset %d"):format(i)) then
              SavePreset(i)
            end
          end

          reaper.ImGui_EndMenu(ctx)
        end

        if reaper.ImGui_BeginMenu(ctx, "Load") then
          for i=1, 3 do
            if reaper.ImGui_MenuItem(ctx, ("Preset %d"):format(i)) then
              LoadPreset(i)
            end
          end

          reaper.ImGui_EndMenu(ctx)
        end
        

        if reaper.ImGui_BeginMenu(ctx, "Info") then
          reaper.ImGui_MenuItem(ctx, ("Media Explorer Query - Version %s"):format(script_version))
          reaper.ImGui_MenuItem(ctx, "A tool by tdspk")

          reaper.ImGui_Separator(ctx)

          if reaper.ImGui_MenuItem(ctx, "Website") then
            reaper.CF_ShellExecute("https://www.tdspkaudio.com")
          end

          if reaper.ImGui_MenuItem(ctx, "Donate") then
            reaper.CF_ShellExecute("https://coindrop.to/tdspkaudio")
          end

          if reaper.ImGui_MenuItem(ctx, "GitHub Repository") then
            reaper.CF_ShellExecute("https://github.com/tdspk/ReaScripts")
          end

          reaper.ImGui_EndMenu(ctx)
        end

        reaper.ImGui_EndPopup(ctx)
      end
    end

    -- local ret, pt, time, wparamlow, wparamhigh =false reaper.JS_WindowMessage_Peek(data.mx_search, "WM_TITLE")
    -- reaper.ShowConsoleMsg(tostring(ret) .. " " .. tostring(pt))

    reaper.ImGui_End(ctx)
  end
  if open then
    reaper.defer(Loop)
  end
end

ui.color_palette.default = reaper.ImGui_GetStyleColor(ctx, reaper.ImGui_Col_Button()),

Load()
Loop()

local function AtExit()
  Save()
end

reaper.atexit(AtExit)
