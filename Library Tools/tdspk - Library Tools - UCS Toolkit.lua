--@description UCS Toolkit
--@version 1.3
--@author Tadej Supukovic (tdspk)
--@about
--  # UCS Tookit
--  Tool for (re)naming tracks, items, markers, regions and Media Explorer files inside REAPER using the Universal Category System (UCS).
--  This is a development build. Tested on Windows only. Please report bugs and FR at the provided links.
--  # Requirements
--  JS_ReaScriptAPI, SWS Extension, ReaImGui
--@links
--  Website https://www.tdspkaudio.com
--  Forum Thread https://forum.cockos.com/showthread.php?t=286234
--@donation
--  https://ko-fi.com/tdspkaudio
--  https://coindrop.to/tdspkaudio
--@provides
--  data/ucs.csv
--  data/OpenSans-Medium.ttf
--  data/soundly.png
--  [main] .
--  [main] tdspk - Library Tools - Focus UCS Toolkit.lua
-- @changelog
--  1.3 UI support new font API, UI refactoring and improvements
--  1.2.5 require ImGui Version 0.9.3.3 to avoid PushFont errors
--  1.2.4 new button: copy generated UCS names to clipboard, setting to ignore open Media Explorer while renaming
--  1.2.3 refresh Media Explorer after renaming files
--  1.2.2 save FX when closing UCS Toolkit, introduce action to focus UCS toolkit and jump to the search box
--  1.2 show UCS explanations and synonyms as tooltip in search box
--  1.1 fixed typo in title
--  Initial Release (v1.0)

local function InsertState(state)
  if state then
    return "(installed)"
  end
  return "(missing)"
end

-- Common Functions for Launcher and Settings
local function CheckDependencies()
  -- Check if required extensions/packages are installed
  local reapack_exists = reaper.APIExists("ReaPack_AboutRepository")
  local imgui_exists = reaper.APIExists("ImGui_GetVersion")
  local sws_exists = reaper.APIExists("CF_GetSWSVersion")
  local js_exists = reaper.APIExists("JS_ReaScriptAPI_Version")

  if not sws_exists or not reapack_exists then
    local message = "UCS Toolkit requires the following extensions:\n"
    message = message .. "SWS Extension " .. InsertState(sws_exists) .. " - Please install it from https://www.sws-extension.org/\n"
    message = message .. "ReaPack " .. InsertState(reapack_exists) .. " - Please install it from https://reapack.com/\n"
    reaper.ShowMessageBox(message, "UCS Toolkit - Missing Dependencies", 0)
    return false
  end

  if not imgui_exists or not js_exists then
    local message = "UCS Toolkit requires the following packages:\n"
    message = message .. "ReaImGui " .. InsertState(imgui_exists) .. "\n"
    message = message .. "JS ReaScript Api " .. InsertState(js_exists) .. "\n"
    message = message .. "\nDo you want to install them now via ReaPack?"
    if reaper.ShowMessageBox(message, "UCS Toolkit - Missing Packages", 4) == 6 then
      reaper.ReaPack_BrowsePackages("reascript api")
    end
    return false
  end

  return true
end

if not CheckDependencies() then
  goto eof
end

dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

local version = reaper.GetAppVersion()
version = tonumber(version:match("%d.%d"))

if version >= 7.0 then
  reaper.set_action_options(3) -- Terminate and restart the script if it's already running
end

ucs_file = script_path .. "/data/ucs.csv"

local app = {
  dock_id = 0,
  docked = false,
  window_width = 450,
  window_height = 680,
  focused = false
}

local color = {
  red = reaper.ImGui_ColorConvertDouble4ToU32(1, 0, 0, 1),
  blue = reaper.ImGui_ColorConvertDouble4ToU32(0, 0.91, 1, 1),
  gray = reaper.ImGui_ColorConvertDouble4ToU32(0.75, 0.75, 0.75, 1),
  green = reaper.ImGui_ColorConvertDouble4ToU32(0, 1, 0, 0.5),
  yellow = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 0, 0.5),
  purple = reaper.ImGui_ColorConvertDouble4ToU32(0.667, 0, 1, 0.5),
  turquois = reaper.ImGui_ColorConvertDouble4ToU32(0, 1, 0.957, 0.5),
  mainfields = reaper.ImGui_ColorConvertDouble4ToU32(0.2, 0.2, 0.2, 1),
  transparent = reaper.ImGui_ColorConvertDouble4ToU32(0, 0, 0, 0),
  black = reaper.ImGui_ColorConvertDouble4ToU32(0, 0, 0, 1),
}

local style = {
  item_spacing_x = 10,
  item_spacing_y = 10,
  big_btn_height = 50,
  frame_rounding = 2,
  frame_border = 1,
  window_rounding = 12,
}

local ucs = {
  version = 0.0,
  categories = {},
  synonyms = {},
  explanations = {},
  search_data = {},
  cat_ids = {}
}

local combo = {
  idx_cat = {},
  cat_idx = {},
  idx_sub = {},
  sub_idx = {},
  cat_items = "",
  sub_items = ""
}

form = {
  search = "",
  is_search_open = false,
  search_mouse = false,
  search_idx = 1,
  cat_id = "",
  cur_cat = 0,
  cur_sub = 0,
  cat_name = "",
  sub_name = "",
  fx_name = "",
  creator_id = "",
  source_id = "",
  user_cat = "",
  vendor_cat = "",
  user_data = "",
  applied = false,
  search_sc = false,
  search_apply = false,
  clear_fx = false,
  name_sc = false,
  name_focused = false,
  -- Fields for Navigation options
  autorename = false,
  navigate_rename = true,
  navigate_loop = false,
  autofill = false,
  navigated = false,
  lookup = false,
  target = 0,
  navigation_offset = 0
}

local form_config_keys = {
  "fx_name", "creator_id", "source_id", "autoplay", "autorename", "autofill", "navigate_loop", "navigate_rename", "target"
}

data = {
  rename_count = 0,
  directory = "",
  files = {},
  markers = {},
  regions = {},
  selected_markers = {},
  selected_regions = {},
  ticks = 0,
  update = false,
  update_interval = -1,
  nav_marker = 0,
  nav_region = 0,
  state_count = 0,
  tracks = {},
  items = {},
  ready = false,
  ucs_names = {}
}

local ext_section = "tdspk_ucstoolkit"
local version = "1.2" -- TODO: update version

local default_settings = {
  font_size = 12,
  save_state = false,
  delimiter = "_",
  tooltips = true,
  ignore_mx = false
}

local settings = {
}

local wildcards = {
  ["$project"] = reaper.GetProjectName(0),
  ["$author"] = select(2, reaper.GetSetProjectInfo_String(0, "PROJECT_AUTHOR", "", false)),
  ["$track"] = (
    function()
      local track = reaper.GetSelectedTrack(0, 0)

      if track then
        local rv, tname = reaper.GetTrackName(track)
        return tname
      end

      return ""
    end),
  ["$item"] = (
    function()
      local item = reaper.GetSelectedMediaItem(0, 0)

      if item then
        local take = reaper.GetActiveTake(item)
        if take then return reaper.GetTakeName(take) end
      end

      return ""
    end),
  ["$marker"] = (
    function()
      local marker_count = reaper.CountProjectMarkers(0)

      for i = 0, marker_count - 1 do
        local rv, is_rgn, pos, _, name = reaper.EnumProjectMarkers(i)

        local cursor_pos               = reaper.GetCursorPosition()

        if cursor_pos == pos and not is_rgn then
          return name
        end
      end

      return ""
    end),
  ["$region"] = (
    function()
      local marker_count = reaper.CountProjectMarkers(0)

      for i = 0, marker_count - 1 do
        local rv, is_rgn, pos, rgnend, name = reaper.EnumProjectMarkers(i)

        local cursor_pos                    = reaper.GetCursorPosition()

        if is_rgn then
          if cursor_pos >= pos and cursor_pos <= rgnend then
            return name
          end
        end
      end

      return ""
    end)
}

local function ReadUcsData()
  local prev_cat = ""
  local got_version = false
  local i = 0

  -- read UCS values from CSV to categories table
  for line in io.lines(ucs_file) do
    if not got_version then
      ucs.version = string.match(line, "(.*);;;;")
      got_version = true
    else
      local cat, subcat, id, expl, syn = string.match(line, "(.*);(.*);(.*);(.*);(.*)")

      if cat ~= prev_cat then
        combo.cat_items = combo.cat_items .. cat .. "\0"
        combo.idx_cat[i] = cat
        combo.cat_idx[cat] = i
        i = i + 1
      end

      prev_cat = cat

      if not ucs.categories[cat] then
        ucs.categories[cat] = {}
      end

      ucs.categories[cat][subcat] = id
      ucs.cat_ids[id] = true
      table.insert(ucs.synonyms, syn)
      table.insert(ucs.explanations, expl)
      table.insert(ucs.search_data, string.format("%s;%s;%s;%s;%s", id, cat, subcat, expl, syn))
    end
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
    if reaper.HasExtState(ext_section, k) then
      settings[k] = MapExtStateValues(reaper.GetExtState(ext_section, k))
    else
      settings[k] = v
    end
  end
end

local function LoadFormConfig()
  for _, v in ipairs(form_config_keys) do
    if reaper.HasExtState(ext_section, v) then
      form[v] = MapExtStateValues(reaper.GetExtState(ext_section, v))
    end
  end
end

local function Init()
  LoadSettings()
  LoadFormConfig()

  data.os = reaper.GetOS()

  style.font = reaper.ImGui_GetFont(ctx)

  style.logo_soundly = reaper.ImGui_CreateImage(script_path .. "/data/soundly.png")
  reaper.ImGui_Attach(ctx, style.logo_soundly)

  reaper.ImGui_SetNextWindowSize(ctx, app.window_width, app.window_height)

  ReadUcsData()
end

function string.split(input, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(input, "([^" .. sep .. "]+)") do
    table.insert(t, str)
  end
  return t
end

function table.contains(table, value)
  for i, v in ipairs(table) do
    if v == value then return true end
  end

  return false
end

local function clamp(v, min, max)
  if v > max then return max end
  if v < min then return min end
  return v
end

local function FilenameToUCS(filename)
  local words = {}

  for word in string.gmatch(filename, "([^_]+)") do
    table.insert(words, word)
  end

  return words
end

local function ReverseLookup(cat_id)
  if not form.lookup then
    return
  end

  local cat = ""
  local sub = ""
  local found = false

  -- iterate tables and look for id
  for k, v in pairs(ucs.categories) do
    for j, id in pairs(v) do
      if (cat_id == id) then
        cat = k
        sub = j
        found = true
        break
      end
    end
  end

  if found then
    form.cat_name = cat
    form.sub_name = sub
    combo.sub_items = PopulateSubCategories(form.cat_name)
    form.cur_cat = combo.cat_idx[form.cat_name]
    form.cur_sub = combo.sub_idx[form.sub_name]
  end
end

local function PopulateSubCategories(cat_name)
  if not ucs.categories[cat_name] then
    return
  end

  -- iterate categories table with the name and build data
  local result = ""

  local sorted_keys = {}

  for k in pairs(ucs.categories[cat_name]) do
    table.insert(sorted_keys, k)
  end

  table.sort(sorted_keys)
  combo.sub_idx = {}
  combo.idx_sub = {}

  local i = 0

  for k, v in pairs(sorted_keys) do
    result = result .. v .. "\0"
    combo.idx_sub[i] = v
    combo.sub_idx[v] = i
    i = i + 1
  end

  return result
end

local function CreateUCSFilename(d, cat_id, ...)
  local fname = cat_id
  local arg = { ... }

  for i, v in ipairs(arg) do
    if v ~= "" then
      for k, w in pairs(wildcards) do
        if string.find(v, k) then
          v = string.gsub(v, k, wildcards[k])
        end
      end

      fname = fname .. d .. v
    end
  end

  return fname
end

local function Tooltip(ctx, text)
  if settings.tooltips then
    reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x / 2)
    reaper.ImGui_PushFont(ctx, style.font, settings.font_size * 0.8)
    reaper.ImGui_TextColored(ctx, color.gray, "?")
    reaper.ImGui_PopFont(ctx)

    if reaper.ImGui_IsItemHovered(ctx) then
      if reaper.ImGui_BeginTooltip(ctx) then
        reaper.ImGui_Text(ctx, text)
        reaper.ImGui_EndTooltip(ctx)
      end
    end
  end
end

local function SaveSettings()
  for k, v in pairs(default_settings) do
    reaper.SetExtState(ext_section, k, tostring(settings[k]), true)
  end
end

local function SaveFormConfig()
  for _, v in ipairs(form_config_keys) do
    reaper.SetExtState(ext_section, v, tostring(form[v]), true)
  end
end

local function Settings()
  if reaper.ImGui_Button(ctx, "Settings...") then
    reaper.ImGui_OpenPopup(ctx, "Settings")
  end

  local x, y = reaper.ImGui_Viewport_GetCenter(reaper.ImGui_GetWindowViewport(ctx))
  reaper.ImGui_SetNextWindowPos(ctx, x, y, reaper.ImGui_Cond_Appearing(), 0.5, 0.5)

  if reaper.ImGui_BeginPopupModal(ctx, "Settings", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
    rv, settings.font_size = reaper.ImGui_SliderInt(ctx, "Font Size", settings.font_size, 10, 18)

    rv, settings.delimiter = reaper.ImGui_InputText(ctx, "Delimiter", settings.delimiter)
    settings.delimiter = string.sub(settings.delimiter, 1, 1)

    rv, settings.tooltips = reaper.ImGui_Checkbox(ctx, "Display Tooltips", settings.tooltips)

    rv, settings.ignore_mx = reaper.ImGui_Checkbox(ctx, "Ignore Media Explorer when renaming", settings.ignore_mx)

    if reaper.ImGui_Button(ctx, "Save Settings and Close") then
      SaveSettings()
      reaper.ImGui_CloseCurrentPopup(ctx)
    end

    reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)

    if reaper.ImGui_Button(ctx, "Reset") then
      for k, v in pairs(default_settings) do
        settings[k] = v
      end
      SaveSettings()
    end

    reaper.ImGui_EndPopup(ctx)
  end
end

local function WildcardInfo()
  if reaper.ImGui_Button(ctx, "Wildcard Info") then
    reaper.ImGui_OpenPopup(ctx, "Wildcard Info")
  end

  local x, y = reaper.ImGui_Viewport_GetCenter(reaper.ImGui_GetWindowViewport(ctx))
  reaper.ImGui_SetNextWindowPos(ctx, x, y, reaper.ImGui_Cond_Appearing(), 0.5, 0.5)

  if reaper.ImGui_BeginPopupModal(ctx, "Wildcard Info", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
    reaper.ImGui_Text(ctx, "This tool featues a small set of wildcards. These can be used in any field.")
    reaper.ImGui_Text(ctx, "Supported wildcards are:")

    reaper.ImGui_Separator(ctx)

    local info_data = {
      "$project;The filename of the current project",
      "$author;The author of the current project",
      "$track;The name of the selected track",
      "$item;The name of the selected item",
      "$marker;The name of the selected marker",
      "$region;The name of the selected region",
      "$idx;Places as incrementing index",
      "$self;the name of the target to be renamed"
    }

    if reaper.ImGui_BeginTable(ctx, "Wildcard Table", 2) then
      reaper.ImGui_TableNextRow(ctx)
      for _, v in ipairs(info_data) do
        reaper.ImGui_TableNextRow(ctx)
        local wc, desc = string.match(v, "(.*);(.*)")
        reaper.ImGui_TableSetColumnIndex(ctx, 0)
        reaper.ImGui_Text(ctx, wc)
        reaper.ImGui_TableSetColumnIndex(ctx, 1)
        reaper.ImGui_Text(ctx, desc)
      end
      reaper.ImGui_EndTable(ctx)
    end

    if reaper.ImGui_Button(ctx, "Close") then
      reaper.ImGui_CloseCurrentPopup(ctx)
    end

    reaper.ImGui_EndPopup(ctx)
  end
end

local function IsWindowOpen(name)
  local is_open
  local handle

  if name == "Media Explorer" then
    is_open = reaper.GetToggleCommandState(50124) -- Media explorer: Show/hide media explorer
    handle = data.mx_handle
  elseif name == "Region/Marker Manager" then
    is_open = reaper.GetToggleCommandState(40326) -- View: Show region/marker manager window
    handle = data.rm_handle
  end

  if is_open == 0 then
    return false
  else
    local title = reaper.JS_Localize(name, "common")
    if not handle then
      handle = reaper.JS_Window_Find(title, true)
    end
    return true, handle
  end
end

local function ToggleTarget()
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F1(), false) then
    form.target = 0
  elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F2(), false) then
    form.target = 1
  elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F3(), false) then
    form.target = 2
  elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F4(), false) then
    form.target = 3
  end
end

local function OperationMode()
  reaper.ImGui_SeparatorText(ctx, "Renaming\t")
  if data.mx_open and not settings.ignore_mx then
    reaper.ImGui_Text(ctx, "Operating on ")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextColored(ctx, color.red, "Media Explorer Files")
    Tooltip(ctx, "Close the Media Explorer to rename tracks, items, markers and regions.")
  else
    rv, form.target = reaper.ImGui_RadioButtonEx(ctx, "Tracks", form.target, 0)
    reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
    rv, form.target = reaper.ImGui_RadioButtonEx(ctx, "Media Items", form.target, 1)
    reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
    rv, form.target = reaper.ImGui_RadioButtonEx(ctx, "Markers", form.target, 2)
    reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
    rv, form.target = reaper.ImGui_RadioButtonEx(ctx, "Regions", form.target, 3)

    Tooltip(ctx, "You can toggle the renaming target with F1-F4")

    ToggleTarget()

    reaper.ImGui_Text(ctx, "Operating in ")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextColored(ctx, color.blue, "Arrange View")
    Tooltip(ctx, "Open the Media Explorer to rename local files")

    if form.target == 2 or form.target == 3 then
      if data.rm_open then
        reaper.ImGui_Text(ctx, "Renaming selections from ")
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_TextColored(ctx, color.blue, "Marker/Region Manager")
      else
        reaper.ImGui_Text(ctx, "Renaming selections from ")
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_TextColored(ctx, color.blue, "Arrange View")
      end
      Tooltip(ctx, "Toggle the Marker/Region Manager to change the mode")
    end
  end
end

local function CategoryFields()
  local cat_changed, sub_changed, id_changed
  cat_changed, form.cur_cat = reaper.ImGui_Combo(ctx, "Category", form.cur_cat, combo.cat_items)

  if cat_changed or combo.sub_items == "" then
    -- populate subcategories based on selected category
    form.cat_name = combo.idx_cat[form.cur_cat]
    combo.sub_items = PopulateSubCategories(form.cat_name)
  end

  sub_changed, form.cur_sub = reaper.ImGui_Combo(ctx, "Subcategory", form.cur_sub, combo.sub_items)

  if cat_changed or sub_changed or form.cat_id == "" then
    form.sub_name = combo.idx_sub[form.cur_sub]
    form.cat_id = ucs.categories[form.cat_name][form.sub_name]
  end

  id_changed, form.cat_id = reaper.ImGui_InputText(ctx, "CatID", form.cat_id)

  if id_changed and form.cat_id ~= "" then
    form.lookup = true
  end
end

local function CategorySearch()
  local rv

  if (form.applied and not form.name_focused) or form.search_sc then
    reaper.ImGui_SetKeyboardFocusHere(ctx)
    form.applied = false
    form.search_sc = false
  end

  rv, form.search = reaper.ImGui_InputText(ctx, "Search category...", form.search)

  if rv then
    form.search_idx = 1
  end
  if rv and not form.is_search_open then
    form.is_search_open = true
  elseif form.search == "" then
    form.is_search_open = false
    form.search_mouse = false
  end

  if form.is_search_open then
    local words = string.split(form.search, " ")
    local syns = {}
    local findings = {}

    for i = 1, #ucs.search_data do
      local entry = ucs.search_data[i]
      local count = 0
      local minpos

      for i, v in ipairs(words) do
        local pos = string.find(string.lower(entry), string.lower(v))
        if pos then
          count = count + 1

          if i == 1 then
            minpos = pos
          end
        end
      end

      if count == #words then
        findings[i] = minpos
      end
    end

    -- sort the findings table
    local sorted = {}
    for k, v in pairs(findings) do
      table.insert(sorted, { k, v })
    end

    table.sort(sorted, function(a, b) return a[2] < b[2] end)

    -- Sort also by key / alphabetical order

    -- Populate syns with newly sorted table
    for _, v in ipairs(sorted) do
      table.insert(syns, ucs.search_data[v[1]])
    end

    select_next = -1

    if reaper.ImGui_GetMouseWheel(ctx) ~= 0 and not form.search_mouse then
      form.search_mouse = true
    end

    if not form.search_mouse then
      if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_DownArrow(), false) then
        form.search_idx = form.search_idx + 1
        if form.search_idx > #syns then form.search_idx = 1 end
      elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_UpArrow(), false) then
        form.search_idx = form.search_idx - 1
        if form.search_idx < 1 then form.search_idx = #syns end
      elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter(), false) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Tab(), false) then
        select_next = form.search_idx
      end
    else
      local key_pressed = reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_DownArrow(), false) or
          reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_UpArrow(), false)
      if key_pressed then
        form.search_mouse = false
      end
    end

    if reaper.ImGui_BeginListBox(ctx, "Autosearch Categories") then
      for i = 1, #syns do
        local is_selected = form.search_idx == i and not form.search_mouse
        local entry = syns[i]
        local id, cat, subcat, expl, syn = string.match(entry, "(.*);(.*);(.*);(.*);(.*)")

        local selectable = reaper.ImGui_Selectable(ctx, id .. "\n" .. cat .. " / " .. subcat, is_selected)

        if reaper.ImGui_IsItemHovered(ctx) then
          if reaper.ImGui_BeginTooltip(ctx) then
            reaper.ImGui_PushTextWrapPos(ctx, settings.font_size * 35.0)
            reaper.ImGui_Text(ctx, expl)
            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Text(ctx, "Synonyms")
            reaper.ImGui_Text(ctx, syn)
            reaper.ImGui_PopTextWrapPos(ctx)
            reaper.ImGui_EndTooltip(ctx)
          end
        end
        
        if form.search_mouse and reaper.ImGui_IsItemHovered(ctx) then
          form.search_idx = i
        end

        reaper.ImGui_Separator(ctx)

        if is_selected and not form.search_mouse then
          reaper.ImGui_SetScrollHereY(ctx, 1)
        end

        if selectable then
          select_next = i
        end

        if select_next == i then
          form.cat_id = id
          form.search = ""
          form.is_search_open = false
          form.search_idx = 1
          form.search_apply = true
          form.search_mouse = false
          form.lookup = true
        end
      end

      reaper.ImGui_EndListBox(ctx)
    end
  end
end

local function Apply()
  local rv = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl())
      and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter(), false)
  form.applied = rv
  return rv
end

local function SubstituteIdx(filename, index)
  local idx
  if index < 10 then
    idx = 0 .. tostring(index)
  else
    idx = tostring(index)
  end

  -- check if $idx exists
  local idx_wc = string.find(filename, "$idx")

  if idx_wc then
    return string.gsub(filename, "$idx", idx)
  end

  return filename .. " " .. idx
end

local function SubstituteSelf(filename, name)
  local self = string.find(filename, "$self")

  if self then
    -- extract UCS category from name
    local no_cat_name = string.match(name, "[A-Z]+[a-z]+_(.*)")

    if no_cat_name then
      no_cat_name = string.gsub(no_cat_name, "%.(%w+)$", "") -- remove possible file endings
      name = no_cat_name
    end

    return string.gsub(filename, "$self", name)
  end

  return filename
end

local function BigButton(ctx, label, divider, padding, color)
  divider = divider or 1
  padding = padding or 40

  if color then
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), color)
  end

  local width = reaper.ImGui_GetWindowSize(ctx)

  local btn = reaper.ImGui_Button(ctx, label, (width / divider) - padding, style.big_btn_height)

  if color then
    reaper.ImGui_PopStyleColor(ctx)
  end

  return btn
end

local function Rename()
  reaper.Undo_BeginBlock()

  if data.mx_open and not settings.ignore_mx then
    local autoplay = reaper.GetToggleCommandStateEx(32063, 1011) --Autoplay: Toggle on/off

    -- disable autoplay, stop playback
    reaper.JS_Window_OnCommand(data.mx_handle, 1009)  -- Preview: Stop
    reaper.JS_Window_OnCommand(data.mx_handle, 40036) -- Autoplay: Off

    for i, v in ipairs(data.files) do
      local old_file = data.directory .. "/" .. v
      --local _, _, ext = string.match(v, "(.-)([^\\/]-%.?([^%.\\/]*))$")

      -- get extension of a filename
      local ext = string.match(v, "%.(%w+)$")

      local filename = data.ucs_names[i]
      local new_file = data.directory .. "/" .. filename .. "." .. ext

      rv, osbuf = os.rename(old_file, new_file)
    end

    if autoplay == 1 then                               -- Enable autoplay if it was toggled on
      reaper.JS_Window_OnCommand(data.mx_handle, 40035) -- Autoplay: On
    end

    reaper.JS_Window_OnCommand(data.mx_handle, 40018) -- Browser: Refresh

    form.applied = true
  else
    if form.target == 0 then
      for i = 1, #data.tracks do
        local track = data.tracks[i]
        local filename = data.ucs_names[i]

        reaper.GetSetMediaTrackInfo_String(track, "P_NAME", filename, true)
      end
      reaper.Undo_EndBlock2(0, "UCS Toolkit: Renamed " .. #data.tracks .. " tracks", 0)
      form.applied = true
    elseif form.target == 1 then
      for i = 1, #data.items do
        local item = data.items[i]
        local take = reaper.GetActiveTake(item)
        local filename = data.ucs_names[i]

        reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", filename, true)
      end
      reaper.Undo_EndBlock2(0, "UCS Toolkit: Renamed " .. #data.items .. " tracks", 0)
      form.applied = true
    elseif form.target == 2 then
      for i, v in ipairs(data.selected_markers) do
        local idx = v[1]
        local pos = v[2]
        local filename = data.ucs_names[i]

        reaper.SetProjectMarker(idx, false, pos, pos, filename)
        if data.rm_open then reaper.BR_Win32_SetFocus(data.rm_handle) end
      end
      reaper.Undo_EndBlock2(0, "UCS Toolkit: Renamed " .. #data.selected_markers .. " markers", 0)
      form.applied = true
    elseif form.target == 3 then
      for i, v in ipairs(data.selected_regions) do
        local idx = v[1]
        local pos = v[2]
        local rgnend = v[3]
        local filename = data.ucs_names[i]

        reaper.SetProjectMarker(idx, true, pos, rgnend, filename)
        if data.rm_open then reaper.BR_Win32_SetFocus(data.rm_handle) end
      end
      reaper.Undo_EndBlock2(0, "UCS Toolkit: Renamed " .. #data.selected_regions .. " regions", 0)
      form.applied = true
    end
  end
end

-- Only use one button for all targets

local function RenameButton()
  local t
  local label
  local col
  if form.target == 0 then
    t = data.tracks
    label = " Track"
    col = color.green
  elseif form.target == 1 then
    t = data.items
    label = " Item"
    col = color.yellow
  elseif form.target == 2 then
    t = data.selected_markers
    label = " Marker"
    col = color.purple
  elseif form.target == 3 then
    t = data.selected_regions
    label = " Region"
  end

  if data.mx_open and not settings.ignore_mx then
    t = data.files
    label = " File"
    col = color.turquois
  end

  if #t > 1 then label = label .. "s" end -- Append "s" if there are more than one element in table

  if BigButton(ctx, "Rename " .. #t .. label, nil, nil, col) or Apply() then
    Rename()
  end
end

local function CacheMarkers(cacheregions)
  data.markers = {}
  data.regions = {}

  local rv, marker_count, region_count = reaper.CountProjectMarkers(0)

  for i = 0, marker_count + region_count - 1 do
    local rv, isrgn, pos, rgnend, name, idx = reaper.EnumProjectMarkers2(0, i)
    if isrgn and cacheregions then
      local rgn = { [1] = idx, [2] = pos, [3] = rgnend, [4] = name }
      table.insert(data.regions, rgn)
    elseif not isrgn then
      local mrk = { [1] = idx, [2] = pos, [3] = name }
      table.insert(data.markers, mrk)
    end
  end
end

local function CacheSelectedTracks()
  data.tracks = {}
  for i = 0, reaper.CountSelectedTracks(0) do
    local track = reaper.GetSelectedTrack(0, i)
    data.tracks[i + 1] = track
  end
end

local function CacheSelectedItems()
  data.items = {}
  for i = 0, reaper.CountSelectedMediaItems(0) do
    local item = reaper.GetSelectedMediaItem(0, i)
    data.items[i + 1] = item
  end
end

local function CacheFiles()
  data.files = {}

  local file_LV = reaper.JS_Window_FindChildByID(data.mx_handle, 0x3E9)
  local sel_count, sel_indexes = reaper.JS_ListView_ListAllSelItems(file_LV)
  if sel_count == 0 then return data.files end

  -- get path from combobox
  local combo = reaper.JS_Window_FindChildByID(data.mx_handle, 1002)
  local edit = reaper.JS_Window_FindChildByID(combo, 1001)
  local path = reaper.JS_Window_GetTitle(edit, "", 1024)

  data.directory = path

  -- get selected items in 1st column of ListView.
  for ndx in string.gmatch(sel_indexes, '[^,]+') do
    local name = reaper.JS_ListView_GetItemText(file_LV, tonumber(ndx), 0)
    table.insert(data.files, name)
  end
end

local function CacheUCSData()
  data.ucs_names = {}

  local t

  if form.target == 0 then
    t = data.tracks
  elseif form.target == 1 then
    t = data.items
  elseif form.target == 2 then
    t = data.selected_markers
  elseif form.target == 3 then
    t = data.selected_regions
  end

  if data.mx_open and not settings.ignore_mx then
    t = data.files
  end

  for i = 1, #t do
    local target_name

    if data.mx_open and not settings.ignore_mx then
      target_name = t[i]
    else
      if form.target == 0 then
        _, target_name = reaper.GetTrackName(t[i])
      elseif form.target == 1 then
        local take = reaper.GetMediaItemTake(t[i], 0)
        target_name = reaper.GetTakeName(take)
      elseif form.target == 2 then
        target_name = t[i][3]
      elseif form.target == 3 then
        target_name = t[i][4]
      elseif form.target == 4 then
        target_name = t[i]
      end
    end

    local parts = FilenameToUCS(target_name)

    local cat_id, fx_name, creator_id, source_id = table.unpack(parts)
    if #parts == 1 then fx_name = parts[1] end

    -- Autofill needs to happen here, and only for the first selected item!
    if i == 1 then
      if form.autofill and form.navigated then
        if ucs.cat_ids[cat_id] then
          form.cat_id = cat_id
        end

        form.fx_name, form.creator_id, form.source_id = ""

        if fx_name then form.fx_name = fx_name end
        if creator_id then form.creator_id = creator_id end
        if source_id then
          source_id = string.gsub(source_id, "%.(%w+)$", "") -- remove possible file endings
          form.source_id = source_id
        end

        form.lookup = true
        form.navigated = false
      end
    end

    if form.fx_name ~= "" then
      fx_name = form.fx_name
    end

    if form.creator_id ~= "" then
      creator_id = form.creator_id
    end

    if form.source_id ~= "" then
      source_id = form.source_id
    end

    local filename = CreateUCSFilename(settings.delimiter, form.cat_id, form.user_cat, form.vendor_cat,
      fx_name, creator_id, source_id, form.user_data)

    if string.find(filename, "$idx") then
      filename = SubstituteIdx(filename, i)
    end
    filename = SubstituteSelf(filename, target_name)

    data.ucs_names[i] = filename
  end
end

local function GetSelectedMarkers(getregions)
  local selected_markers = {}
  local loop_start, loop_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 10, false)

  local t
  if getregions then t = data.regions else t = data.markers end

  if loop_start < loop_end then
    for i, v in ipairs(t) do
      local mrk
      if getregions then
        local pos = v[2]
        local rgn_end = v[3]
        if pos >= loop_start and rgn_end <= loop_end then
          mrk = { [1] = v[1], [2] = v[2], [3] = v[3], [4] = v[4] }
        end
      else
        local pos = v[2]
        if pos >= loop_start and pos <= loop_end then
          mrk = { [1] = v[1], [2] = v[2], [3] = v[3] }
        end
      end
      table.insert(selected_markers, mrk)
    end
  else -- selected markers and regions for single items
    local cursor_pos = reaper.GetCursorPosition()

    for i, v in ipairs(t) do
      local mrk

      if getregions then
        local pos = v[2]
        local rgn_end = v[3]
        if cursor_pos >= pos and cursor_pos <= rgn_end then
          mrk = { [1] = v[1], [2] = v[2], [3] = v[3], [4] = v[4] }
        end
      else
        local pos = v[2]
        if cursor_pos == pos then
          mrk = { [1] = v[1], [2] = v[2], [3] = v[3] }
        end
      end

      if mrk then
        table.insert(selected_markers, mrk)
        break
      end
    end
  end

  return selected_markers
end

local function CountManagerMarkers(countregions)
  local manager = reaper.JS_Window_FindChildByID(data.rm_handle, 0x42F)
  local sel_count, sel_indexes = reaper.JS_ListView_ListAllSelItems(manager)
  local selected_markers = {}

  if sel_count > 0 then
    local selection = string.split(sel_indexes, ",")

    local ids = {}

    local id_prefix = ""
    if countregions then id_prefix = "R" else id_prefix = "M" end

    for i, v in ipairs(selection) do
      local id = reaper.JS_ListView_GetItemText(manager, tonumber(v), 1)
      id = string.gsub(id, id_prefix, "")
      table.insert(ids, tonumber(id))
    end

    local rv, marker_count, region_count = reaper.CountProjectMarkers(0)

    local t
    if countregions then t = data.regions else t = data.markers end

    for i, v in ipairs(t) do
      local idx = v[1]
      if table.contains(ids, idx) then
        local mrk
        if countregions then
          mrk = { [1] = v[1], [2] = v[2], [3] = v[3], [4] = v[4] }
        else
          mrk = { [1] = v[1], [2] = v[2], [3] = v[3] }
        end
        table.insert(selected_markers, mrk)
      end
    end
  end

  return selected_markers
end

local function CountTargets()
  local filecount = 0

  if data.mx_open and not settings.ignore_mx then
    CacheFiles(data.mx_handle)
    filecount = #data.files
  else
    if form.target == 0 then
      CacheSelectedTracks()
      filecount = #data.tracks
    elseif form.target == 1 then
      CacheSelectedItems()
      filecount = #data.items
    elseif form.target == 2 then
      data.selected_markers = {}

      CacheMarkers(false)

      data.rm_open, data.rm_handle = IsWindowOpen("Region/Marker Manager")
      if data.rm_handle then -- if Region/Marker Manager is open, count there
        data.selected_markers = CountManagerMarkers(false)
        filecount = #data.selected_markers
      else
        -- get selected markers time selection or single items
        data.selected_markers = GetSelectedMarkers(false)
        filecount = #data.selected_markers
      end
    elseif form.target == 3 then
      data.selected_regions = {}

      CacheMarkers(true)

      data.rm_open, data.rm_handle = IsWindowOpen("Region/Marker Manager")
      if data.rm_handle then -- if Region/Marker Manager is open, count there
        data.selected_regions = CountManagerMarkers(true)
        filecount = #data.selected_regions
      else
        -- get selected markers time selection or single items
        data.selected_regions = GetSelectedMarkers(true)
        filecount = #data.selected_regions
      end
    end
  end

  CacheUCSData()

  return filecount
end

local function NameShortcut()
  return reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl())
      and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_N(), false)
end

local function SearchShortcut()
  return reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl())
      and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F(), false)
end

local function NavigateNext()
  return reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt())
      and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_RightArrow(), false)
end

local function NavigatePrevious()
  return reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt())
      and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_LeftArrow(), false)
end

local function GetNearestMarker(isrgn, step)
  local t = {}
  if isrgn then t = data.regions else t = data.markers end

  local cur_pos = reaper.GetCursorPositionEx(0)
  local min = -1
  local nearest_marker

  for i, v in ipairs(t) do
    local distance = v[2] - cur_pos

    if (step > 0 and distance > 0) or (step < 0 and distance < 0) then
      distance = math.abs(v[2] - cur_pos)
      if distance < min or min == -1 then
        min = distance
        nearest_marker = { i, v[2] }
      end
    end
  end

  return nearest_marker
end

local function NavigateMarker(isrgn, step)
  local t = {}
  if isrgn then t = data.regions else t = data.markers end

  local nav_marker
  if isrgn then nav_marker = data.nav_region else nav_marker = data.nav_marker end

  -- markers are cached in their respective order
  -- if no current marker is set (0), take the first one near cursor (default action)

  local pos = reaper.GetCursorPositionEx(0)
  local m = GetNearestMarker(isrgn, step)

  if m and m[2] ~= reaper.GetCursorPositionEx(0) then
    reaper.SetEditCurPos2(0, m[2], true, true)
    nav_marker = m[1]
  else
    if nav_marker == 0 then
      if step > 0 then
        nav_marker = #t
      else
        nav_marker = 1
      end
    else
      nav_marker = clamp(nav_marker + step, 1, #t)
    end

    local mrk = t[nav_marker]

    if mrk then
      reaper.SetEditCurPos2(0, mrk[2], true, true)
      return nav_marker
    end
  end

  return nav_marker
end

local function UpdateLoopPoints()
  if form.target == 1 then
    reaper.Main_OnCommand(41039, 0) --Loop points: Set loop points to items
  elseif form.target == 3 then
    -- load start and end points from current navigated region
    if data.nav_region then
      local start_pos = data.regions[data.nav_region][2]
      local end_pos = data.regions[data.nav_region][3]
      reaper.GetSet_LoopTimeRange2(0, true, true, start_pos, end_pos, false)
    end
  end
end

local function Navigate(next)
  if data.mx_open and not settings.ignore_mx then
    if next then
      reaper.JS_Window_OnCommand(data.mx_handle, 40030) -- Browser: Select next file in directory
    else
      reaper.JS_Window_OnCommand(data.mx_handle, 40029) -- Browser: Select previous file in directory
    end
  else
    if form.target == 0 then
      if next then
        reaper.Main_OnCommand(40285, 0) -- Track: Go to next track
      else
        reaper.Main_OnCommand(40286, 0) -- Track: Go to previous track
      end
    elseif form.target == 1 then
      if next then
        reaper.Main_OnCommand(40417, 0) -- Item navigation: Select and move to next item
      else
        reaper.Main_OnCommand(40416, 0) -- Item navigation: Select and move to previous item
      end
    elseif form.target == 2 then
      if next then
        data.nav_marker = NavigateMarker(false, 1)
      else
        data.nav_marker = NavigateMarker(false, -1)
      end
    elseif form.target == 3 then
      if next then
        data.nav_region = NavigateMarker(true, 1)
      else
        data.nav_region = NavigateMarker(true, -1)
      end
    end
  end

  if form.autorename then Rename() end

  if form.autoplay and not data.mx_open then
    reaper.Main_OnCommand(1016, 0)  -- Transport: Stop
    reaper.Main_OnCommand(40044, 0) -- Transport: Play/stop
  end

  if form.navigate_loop then
    -- If loop area exists, move to next target
    UpdateLoopPoints()
  end

  form.navigated = true
  form.navigation_offset = (next and -1 or 1)
end

local function MainFields()
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), color.mainfields)

  if (form.applied and form.name_focused) or form.search_apply or form.name_sc then
    reaper.ImGui_SetKeyboardFocusHere(ctx)
    form.search_apply = false
    form.applied = false
  end

  local callback
  if form.navigated then
    if not reaper.ImGui_ValidatePtr(form.input_callback, "ImGui_Function*") then
      form.input_callback = reaper.ImGui_CreateFunctionFromEEL([[
        pos = CursorPos;
        CursorPos = pos + navigation_offset;
      ]])
    end
    reaper.ImGui_Function_SetValue(form.input_callback, "navigation_offset", form.navigation_offset)
    form.navigation_offset = 0
    callback = form.input_callback
  end

  rv, form.fx_name = reaper.ImGui_InputText(ctx, "FXName", form.fx_name, reaper.ImGui_InputTextFlags_CallbackAlways(),
    callback)
  form.name_focused = reaper.ImGui_IsItemFocused(ctx)
  Tooltip(ctx, "Brief Description or Title (under 25 characters preferably)")

  rv, form.creator_id = reaper.ImGui_InputText(ctx, "CreatorID", form.creator_id,
    reaper.ImGui_InputTextFlags_CallbackAlways(),
    callback)
  Tooltip(ctx, "Sound Designer, Recordist or Vendor (or abbreviaton for them")

  rv, form.source_id = reaper.ImGui_InputText(ctx, "SourceID", form.source_id,
    reaper.ImGui_InputTextFlags_CallbackAlways(),
    callback)
  Tooltip(ctx, "Project, Show or Library name (or abbreviation representing it")

  reaper.ImGui_PopStyleColor(ctx)

  WildcardInfo()

  reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)

  rv, form.clear_fx = reaper.ImGui_Checkbox(ctx, "Clear FXName on rename", form.clear_fx)
end

local function OptionalFields()
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), color.transparent)
  if reaper.ImGui_CollapsingHeader(ctx, "Optional Fields", nil) then
    rv, form.user_cat = reaper.ImGui_InputText(ctx, "UserCategory", form.user_cat)
    Tooltip(ctx,
      "An optional tail extension of the CatID block that can be used\nas a user defined category, microphone, perspective, etc.")

    rv, form.vendor_cat = reaper.ImGui_InputText(ctx, "VendorCategory", form.vendor_cat)
    Tooltip(ctx,
      "An option head extension to the FXName Block usable by vendors to\ndefine a library specific category. For example, the specific name\nof a gun, vehicle, location, etc.")

    rv, form.user_data = reaper.ImGui_InputText(ctx, "UserData", form.user_data)
    Tooltip(ctx,
      "A user defined space, ofter used for an ID or Number for guaranteeing that the Filename is 100% unique...")
  end
  reaper.ImGui_PopStyleColor(ctx)
end

local function PushMainStyleVars()
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 1, style.item_spacing_y)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_SeparatorTextPadding(), 0, 0)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_SeparatorTextBorderSize(), 1)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), style.frame_rounding)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), style.frame_border)

  return 5
end

local function Navigation()
  reaper.ImGui_SeparatorText(ctx, "Navigation\t")

  if reaper.ImGui_ArrowButton(ctx, "Previous", reaper.ImGui_Dir_Left())
      or NavigatePrevious() then
    Navigate(false)
  end

  reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)

  if reaper.ImGui_ArrowButton(ctx, "Next", reaper.ImGui_Dir_Right())
      or NavigateNext() then
    Navigate(true)
  end

  Tooltip(ctx, "You can also navigate next/previous targets with Alt+Left/Right arrow keys")

  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), color.transparent)
  if reaper.ImGui_CollapsingHeader(ctx, "Navigation Options", nil) then
    if not data.mx_open then
      rv, form.autoplay = reaper.ImGui_Checkbox(ctx, "Autoplay when navigating", form.autoplay)
      reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
    end
    rv, form.autorename = reaper.ImGui_Checkbox(ctx, "Auto-Rename when navigating", form.autorename)
    rv, form.navigate_rename = reaper.ImGui_Checkbox(ctx, "Navigate after Rename", form.navigate_rename)
    if (form.target == 1 or form.target == 3) and not data.mx_open then
      reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
      rv, form.navigate_loop = reaper.ImGui_Checkbox(ctx, "Move loop area to next target", form.navigate_loop)
      Tooltip(ctx, "Moves a set loop area to the next target when navigating inside the UCS Toolkit.")
    end
    rv, form.autofill = reaper.ImGui_Checkbox(ctx, "Auto-Fill when navigating", form.autofill)
    Tooltip(ctx,
      "Auto-fills the form if UCS data exists in the target. This only works when using UCS Toolkit's navigation!\nIf you are working with Markers/Regions, please clear your timeselection for this to work properly!")
  end
  reaper.ImGui_PopStyleColor(ctx)
end

local function Menu()
  if reaper.ImGui_BeginMenuBar(ctx) then
    if reaper.ImGui_BeginMenu(ctx, "Info", true) then
      local info = {
        "UCS Toolkit",
        "UCS Version " .. ucs.version,
        "A tool by Tadej Supukovic"
      }

      for _, v in ipairs(info) do
        reaper.ImGui_MenuItem(ctx, v, "", false, false)
      end

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

      reaper.ImGui_Separator(ctx)
      
      local thanks = {
        "Special thanks to:",
        "Hans Ekevi and Soundly AS",
        "Cockos Inc. for REAPER",
        "cfillion for ReaImGui",
        "The REAPER Community",
        "The Airwiggles Community",
        "Tim Nielsen and the team behind UCS"
      }

      for _, v in ipairs(thanks) do
        reaper.ImGui_MenuItem(ctx, v, "", false, false)
      end

      reaper.ImGui_EndMenu(ctx)
    end

    Settings()

    reaper.ImGui_EndMenuBar(ctx)
  end
end

local function SoundlyLink()
  reaper.ImGui_Text(ctx, "In collaboration with")
  reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
  reaper.ImGui_Image(ctx, style.logo_soundly, 94, 19)
  if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
    reaper.CF_ShellExecute("https://getsoundly.com/")
  end
end

local function Main()
  -- Check if Focus UCS Toolkit script has been called
  if reaper.GetExtState(ext_section, "focus") == "1" then
    form.search_sc = true
    reaper.SetExtState(ext_section, "focus", "0", false)
  end

  data.update = false
  data.ticks = reaper.GetProjectStateChangeCount(0)

  if data.ticks >= data.update_interval then
    data.update = true
  end

  Menu()

  reaper.ImGui_PushFont(ctx, style.font, settings.font_size)

  local style_pushes = PushMainStyleVars()

  CategorySearch()
  CategoryFields()

  reaper.ImGui_Separator(ctx)

  MainFields()

  OptionalFields()

  data.mx_open, data.mx_handle = IsWindowOpen("Media Explorer")

  if data.update then
    data.rename_count = CountTargets()
  end

  if form.lookup then
    ReverseLookup(form.cat_id)
    form.lookup = false
  end

  Navigation()

  OperationMode()

  reaper.ImGui_SeparatorText(ctx, "Preview")

  if data.mx_open and not settings.ignore_mx then
    if data.files then
      reaper.ImGui_LabelText(ctx, "Directory", data.directory)
    end
  end

  if data.rename_count <= 1 then
    reaper.ImGui_LabelText(ctx, "Filename", data.ucs_names[1])
  else
    local filenames = ""

    for i = 1, #data.ucs_names do
      filenames = filenames .. data.ucs_names[i] .. "\0"
    end

    reaper.ImGui_Combo(ctx, "Filenames", 0, filenames)
  end

  reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
  if reaper.ImGui_SmallButton(ctx, "Copy") then
    local clipboard = table.concat(data.ucs_names, "\n")
    reaper.CF_SetClipboard(tostring(clipboard))
  end

  Tooltip(ctx, "Copy the filenames to the clipboard.")

  RenameButton()

  Tooltip(ctx, "Quick Rename targets with Ctrl+Enter")

  form.search_sc = SearchShortcut()
  form.name_sc = NameShortcut()

  if form.applied then
    if form.clear_fx then form.fx_name = "" end
    if form.navigate_rename then
      Navigate(true)
    end
  end

  SoundlyLink()

  reaper.ImGui_PopStyleVar(ctx, style_pushes)
  reaper.ImGui_PopFont(ctx)
end

local function Loop()
  if app.has_undocked then
    reaper.ImGui_SetNextWindowSize(ctx, app.window_width, app.window_height)
  end

  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 10)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowTitleAlign(), 0.5, 0.5)

  local visible, open = reaper.ImGui_Begin(ctx, "tdspk - UCS Toolkit", true, reaper.ImGui_WindowFlags_MenuBar())

  if visible then
    app.focused = reaper.ImGui_IsWindowFocused(ctx)
    Main()
    reaper.ImGui_End(ctx)
  end

  reaper.ImGui_PopStyleVar(ctx, 2)
  if open then
    reaper.defer(Loop)
  else
    SaveFormConfig()
  end
end

-- check if the UCS file exists. If not, don't bother executing
local f_exists = false
local f = io.open(ucs_file, "r")
if f then
  io.close(f)
  f_exists = true
end

if f_exists then
  ctx = reaper.ImGui_CreateContext("tdspk - UCS Tookit")
  Init()
  Loop()
else
  reaper.ShowMessageBox(
    "Could not load 'UCS.csv'.\nPlease check the data folder in the script root for any missing files.",
    "File loading failed", 0)
end

::eof::
