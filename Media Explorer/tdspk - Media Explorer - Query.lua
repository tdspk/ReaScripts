local version = reaper.GetAppVersion()
version = tonumber(version:match("%d.%d+"))

if version >= 7.03 then
  reaper.set_action_options(3) -- Terminate and restart the script if it's already running
end

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
  tabs = {
    { idx = 1, term = "koll",  path = "C:\\Users\\Tadej\\Desktop" },
    { idx = 2, term = "peaks", path = "C:\\Users\\Tadej\\Videos" },
  },
  selected_tab = -1
}

function Print(txt)
  reaper.ClearConsole()
  reaper.ShowConsoleMsg(txt)
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

  if ui.pinned then
    rv, ui.mx_x, ui.mx_y = reaper.JS_Window_GetRect(data.mx_handle)
    -- set pinned position relative to media explorer position
    local x = ui.mx_x - ui.pinned_pos.x
    local y = ui.mx_y - ui.pinned_pos.y
    reaper.ImGui_SetNextWindowPos(ctx, x, y)
  end

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

        if reaper.ImGui_Button(ctx, string.format("%s##%d", tab.term, idx)) then
          data.selected_tab = idx

          -- Perform Search
          Search(data.tabs[idx].path, data.tabs[idx].term)
        end

        -- reaper.ImGui_PopStyleColor(ctx, 3)

        reaper.ImGui_SameLine(ctx)
      end

      if reaper.ImGui_Button(ctx, "+") then
        table.insert(data.tabs, { term = "New Tab", path = "" })
        data.selected_tab = #data.tabs
      end

      reaper.ImGui_SameLine(ctx, 0, 50)

      if reaper.ImGui_BeginPopupContextWindow(ctx) then
        if reaper.ImGui_MenuItem(ctx, "Pinned", "", ui.pinned) then
          ui.pinned = not ui.pinned
          -- local viewport = reaper.ImGui_GetWindowViewport(ctx)
          -- local vx, vy = reaper.ImGui_GetViewportPos(viewport)
          ui.pinned_pos.x, ui.pinned_pos.y = reaper.ImGui_GetWindowPos(ctx)
        end

        reaper.ImGui_EndPopup(ctx)
      end
    end

    reaper.ImGui_End(ctx)
  end
  if open then
    reaper.defer(Loop)
  end
end

Loop()






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
