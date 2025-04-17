--@description Media Explorer - Query
--@version 0.1pre1
--@author Tadej Supukovic (tdspk)
--@about
--  # Media Explorer - Query
--  A small script to save search queries in the Media Explorer on a per-project basis. 
--  # Requirements
--  JS_ReaScriptAPI, SWS Extension, ReaImGui
--@links
--  Website https://www.tdspkaudio.com
--  Forum Thread 
--@donation
--  https://ko-fi.com/tdspkaudio
--  https://coindrop.to/tdspkaudio
--@provides
--  json/json.lua
--  [main] .
-- @changelog
--  

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]
json = dofile(script_path .. "/json/json.lua") -- import json library

local version = reaper.GetAppVersion()
version = tonumber(version:match("%d.%d+"))

if version >= 7.03 then
  reaper.set_action_options(3) -- Terminate and restart the script if it's already running
end

-- TODO add settings table

local ext_section = "tdspk_MXQuery"

ui = {
  window_flags = reaper.ImGui_WindowFlags_NoDocking() | reaper.ImGui_WindowFlags_NoTitleBar(),
  pinned_flags = reaper.ImGui_WindowFlags_NoMove() | reaper.ImGui_WindowFlags_NoResize() |
      reaper.ImGui_WindowFlags_NoBackground(),
  hidden_flags = reaper.ImGui_WindowFlags_NoMove() | reaper.ImGui_WindowFlags_NoBackground(),

  pinned = false,
  pinned_pos = { x = 0, y = 0 },
  hidden = false,
  color = {
    black = reaper.ImGui_ColorConvertDouble4ToU32(0, 0, 0, 1),
    white = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 1),
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
  tabs = {},
  selected_tab = -1
}

function Print(txt)
  reaper.ClearConsole()
  reaper.ShowConsoleMsg(txt)
end

function SaveTabs()
  local tabs = json.encode(data.tabs)
  reaper.SetProjExtState(0, ext_section, "tabs", tabs)
end

function LoadTabs()
  local rv, tabs = reaper.GetProjExtState(0, ext_section, "tabs")
  if rv > 0 then
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

  local parent = reaper.JS_Window_GetParent(handle)
  reaper.JS_Window_SetFocus(parent)

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

  -- if ui.pinned then
  --   rv, ui.mx_x, ui.mx_y = reaper.JS_Window_GetRect(data.mx_handle)
  --   -- set pinned position relative to media explorer position
  --   local x = ui.mx_x + ui.pinned_pos.x
  --   local y = ui.mx_y + ui.pinned_pos.y
  --   reaper.ImGui_SetNextWindowPos(ctx, x, y)
  -- end

  reaper.ImGui_SetNextWindowSize(ctx, 0, 0)
  local visible, open = reaper.ImGui_Begin(ctx, 'Media Explorer Tabs', false,
    ui.window_flags | (ui.hidden and ui.hidden_flags or 0) | (ui.pinned and ui.pinned_flags or 0))
  if visible then
    if IsMxOpen() then
      for idx, tab in ipairs(data.tabs) do
        local color = idx == data.selected_tab and ui.color.green or ui.color.white

        -- reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), color)
        -- reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), color)
        -- reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), color)

        local btn = reaper.ImGui_Button(ctx, string.format("%s##%d", tab.term, idx))

        if btn then
          if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then
            -- remove table entry
            table.remove(data.tabs, idx)
          else
            data.selected_tab = idx
            -- Perform Search
            Search(data.tabs[idx].path, data.tabs[idx].term)
          end
        end

        -- reaper.ImGui_PopStyleColor(ctx, 3)

        reaper.ImGui_SameLine(ctx)
      end

      if reaper.ImGui_Button(ctx, "+") then
        local term = reaper.JS_Window_GetTitle(data.mx_search)
        if string.len(term) > 0 then
          local path = reaper.JS_Window_GetTitle(data.mx_path)
          table.insert(data.tabs, { term = term, path = path })
          data.selected_tab = #data.tabs
        end
      end

      reaper.ImGui_SameLine(ctx, 0, 50)

      if reaper.ImGui_BeginPopupContextWindow(ctx) then
        if reaper.ImGui_MenuItem(ctx, "Pinned", "", ui.pinned) then
          ui.pinned = not ui.pinned
          -- rv, ui.mx_x, ui.mx_y = reaper.JS_Window_GetRect(data.mx_handle)
          -- -- local viewport = reaper.ImGui_GetWindowViewport(ctx)
          -- -- local vx, vy = reaper.ImGui_GetViewportPos(viewport)
          -- local x, y = reaper.ImGui_GetWindowPos(ctx)
          -- ui.pinned_pos.x = x - ui.mx_x
          -- ui.pinned_pos.y = y - ui.mx_y
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

LoadTabs()
Loop()

local function AtExit()
  SaveTabs()
end

reaper.atexit(AtExit)




-- -- get path content
-- path = reaper.JS_Window_GetTitle(edit)

-- local combo = reaper.JS_Window_FindChildByID(handle, 0x3F7)
-- count = reaper.JS_WindowMessage_Send(combo, "CB_GETCOUNT", 0, 0, 0, 0)
-- a = reaper.JS_WindowMessage_Send(combo, "CB_GETLBTEXT", 0, 0, 0, 0)

-- local edit = reaper.JS_Window_FindChildByID(combo, 0x3E9)

-- search = reaper.JS_Window_GetTitle(edit)

-- text = "koll"
-- chars = {}

-- for i = 1, string.len(text) do
--   local char = string.byte(string.sub(text, i, i))
--   table.insert(chars, char)
-- end

-- reaper.JS_Window_SetFocus(edit)

-- for i=1, #chars do
--   -- reaper.JS_WindowMessage_Send(edit, "WM_CHAR", chars[i], 0, 0, 0)
-- end

-- -- todo press enter
