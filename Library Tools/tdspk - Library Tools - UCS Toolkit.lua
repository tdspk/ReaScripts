--@description UCS Toolkit
--@version 0.2pre4
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
--  [main] .
-- @changelog
--  First beta

local imgui_exists = reaper.APIExists("ImGui_GetVersion")
local sws_exists = reaper.APIExists("CF_GetSWSVersion")
local js_exists = reaper.APIExists("JS_ReaScriptAPI_Version")

if not imgui_exists or not sws_exists or not js_exists then
  local msg = "UCS Toolkit requires the following extensions/packages to work:\n"
  if not sws_exists then
    msg = msg .. "SWS Extension - please visit https://www.sws-extension.org\n"
  end
  if not js_exists then
    msg = msg .. "js_ReaScriptAPI: API functions for ReaScripts - please install via ReaPack\n"
  end
  if not imgui_exists then
    msg = msg .. "ReaImGui: ReaScript binding for Dear ImGui - please install via ReaPack\n"
  end
  
  reaper.ShowMessageBox(msg, "Missing extensions/packages", 0)
  goto eof
end

dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

ucs_file = script_path .. "/data/ucs.csv"

local app = {
  dock_id = 0,
  docked = false,
  window_width = 450,
  window_height = 760,
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
  transparent = reaper.ImGui_ColorConvertDouble4ToU32(0, 0, 0, 0)
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
  raw_data = {}
}

local combo = {
  idx_cat = {},
  cat_idx = {},
  idx_sub = {},
  sub_idx = {},
  cat_items = "",
  sub_items = ""
}

local form = {
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
  autoplay = false,
  clear_fx = false,
  name_sc = false,
  name_focused = false,
  autorename = false
}

data = {
  target = 0,
  target_self = "",
  rename_count = 0,
  directory = "",
  files = {},
  markers = {},
  regions = {},
  selected_markers = {},
  selected_regions = {},
  ticks = 0,
  update = false,
  nav_marker = 0,
  nav_region = 0,
  state_count = 0,
  tracks = {},
  items = {},
  ready = false,
  ucs_names = {}
}

local ext_section = "tdspk_ucstoolkit"
local version = "0.2pre3"

local default_settings = {
  font_size = 16,
  save_state = false,
  delimiter = "_",
  update_interval = 1,
  tooltips = true
}

local settings = {
  changed = false,
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
    
    for i=0, marker_count - 1 do
      local rv, is_rgn, pos, _, name  = reaper.EnumProjectMarkers(i)
      
      local cursor_pos = reaper.GetCursorPosition()
      
      if cursor_pos == pos and not is_rgn then
        return name
      end
    end
    
    return ""
  
  end),
  ["$region"] = (
  function()
    local marker_count = reaper.CountProjectMarkers(0)
    
    for i=0, marker_count - 1 do
      local rv, is_rgn, pos, rgnend, name  = reaper.EnumProjectMarkers(i)
      
      local cursor_pos = reaper.GetCursorPosition()
      
      if is_rgn then
        if cursor_pos >= pos and cursor_pos <= rgnend then
          return name
        end
      end
    end
    
    return ""
  end)
}


function ReadUcsData()
  local prev_cat = ""
  local got_version = false
  local i = 0
  
  -- read UCS values from CSV to categories table
  for line in io.lines(ucs_file) do
    if not got_version then
      ucs.version =  string.match(line, "(.*);;;;")
      got_version = true
    else
      table.insert(ucs.raw_data, line)
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
      table.insert(ucs.synonyms, id .. ";" .. syn)
      table.insert(ucs.explanations, id .. ";" .. expl)
      table.insert(ucs.search_data, string.format("%s;%s, %s, %s, %s", id, cat, subcat, expl, syn))
    end
  end
end

function LoadSettings() 
  for k, v in pairs(default_settings) do
    local ext_value = reaper.GetExtState(ext_section, k)
    
    if ext_value == "" then
      settings[k] = v
    else
      if tonumber(ext_value) then
        ext_value = tonumber(ext_value)
      end
      
      if ext_value == "true" then ext_value = true end
      if ext_value == "false" then ext_value = false end
      
      settings[k] = ext_value
    end
  end
end

function Init()
  LoadSettings()
  
  data.os = reaper.GetOS()
  
  -- init fonts
  local font_res = script_path .. "/data/OpenSans-Medium.ttf"

  style.font = reaper.ImGui_CreateFont(font_res, settings.font_size)
  reaper.ImGui_Attach(ctx, style.font)
  
  style.font_info = reaper.ImGui_CreateFont(font_res, math.floor(settings.font_size * 0.8))
  reaper.ImGui_Attach(ctx, style.font_info)
  
  style.font_menu = reaper.ImGui_CreateFont(font_res, math.floor(settings.font_size * 1.5))
  reaper.ImGui_Attach(ctx, style.font_menu)
  
  reaper.ImGui_SetNextWindowSize(ctx, app.window_width, app.window_height)
  
  ReadUcsData()

  if reaper.HasExtState(ext_section, "target") then data.target = tonumber(reaper.GetExtState(ext_section, "target")) end
end

function string.split(input, sep)
  if sep == nil then
   sep = "%s"
  end
  local t={}
  for str in string.gmatch(input, "([^"..sep.."]+)") do
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

function clamp(v, min, max)
  if v > max then return max end
  if v < min then return min end
  return v
end

function ParseFilename(filename) 
  local words = {}
  
  for word in string.gmatch(filename, "([^_]+)") do
    table.insert(words, word)
  end
  
  return words
end

function ReverseLookup(cat_id)
  local cat = ""
  local sub = ""
  local rv = false
  
  -- iterate tables and look for id
  -- TODO optimize in future?
  for k, v in pairs(ucs.categories) do
    for j, id in pairs(v) do
      if (cat_id == id) then
        cat = k
        sub = j
        rv = true
        break
      end
    end
  end
  
  return rv, cat, sub
end

function PopulateSubCategories(cat_name)
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

function CreateUCSFilename(d, cat_id, ...)
  local fname = cat_id
  local arg = {...}
  
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

function Tooltip(ctx, text)
  if settings.tooltips then
    reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x / 2)
    reaper.ImGui_PushFont(ctx, style.font_info)
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

function SaveSettings()
  for k, v in pairs(default_settings) do
    reaper.SetExtState(ext_section, k, tostring(settings[k]), false)
  end
end

function Settings()
  if SmallButton(ctx, "Settings") then
    reaper.ImGui_OpenPopup(ctx, "Settings")
  end

  --if IconButton("Settings", style.icon_settings) then
  --  reaper.ImGui_OpenPopup(ctx, "Settings")
  --end
  
  local x, y = reaper.ImGui_Viewport_GetCenter(reaper.ImGui_GetWindowViewport(ctx))
  reaper.ImGui_SetNextWindowPos(ctx, x, y, reaper.ImGui_Cond_Appearing(), 0.5, 0.5)
  
  if reaper.ImGui_BeginPopupModal(ctx, "Settings", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then 
    rv, settings.font_size = reaper.ImGui_SliderInt(ctx, "Font Size", settings.font_size, 10, 18)
    settings.changed = rv or settings.changed
    
    if settings.changed then
      reaper.ImGui_Text(ctx, "Restart the script to apply font size change!")
    end
    
    rv, settings.delimiter = reaper.ImGui_InputText(ctx, "Delimiter", settings.delimiter)
    settings.delimiter = string.sub(settings.delimiter, 1, 1)
    
    rv, settings.tooltips = reaper.ImGui_Checkbox(ctx, "Display Tooltips", settings.tooltips)
    
    rv, settings.update_interval = reaper.ImGui_DragInt(ctx, "Poll Interval", settings.update_interval, 1, 1, 30, "%d ticks")
    
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

function WildcardInfo()
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

function Support()
  if SmallButton(ctx, "Support") then
    reaper.ImGui_OpenPopup(ctx, "Support")
  end
  
  --if IconButton("Support", style.icon_support) then
  --  reaper.ImGui_OpenPopup(ctx, "Support")
  --end
  
  local x, y = reaper.ImGui_Viewport_GetCenter(reaper.ImGui_GetWindowViewport(ctx))
  reaper.ImGui_SetNextWindowPos(ctx, x, y, reaper.ImGui_Cond_Appearing(), 0.5, 0.5)
  
  if reaper.ImGui_BeginPopupModal(ctx, "Support", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
    reaper.ImGui_Text(ctx, "This tool is free and open source. And it will always be.")
    reaper.ImGui_Text(ctx, "However, I do appreciate your support via donation.")
    
    if BigButton(ctx, "Donate on Ko-fi", nil, nil, color.green) then
      reaper.CF_ShellExecute("https://ko-fi.com/tdspkaudio")
    end
    
    if BigButton(ctx, "Donate with PayPal and Co.", nil, nil, color.yellow) then
      reaper.CF_ShellExecute("https://coindrop.to/tdspkaudio")
    end
    
    if reaper.ImGui_Button(ctx, "Close") then
      reaper.ImGui_CloseCurrentPopup(ctx)
    end
    reaper.ImGui_EndPopup(ctx)
  end
end

function IsWindowOpen(name)
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

function ToggleTarget()
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F1(), false) then
    data.target = 0
  elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F2(), false) then
    data.target = 1
  elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F3(), false) then
    data.target = 2
  elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F4(), false) then
    data.target = 3
  end
end

function OperationMode()
  reaper.ImGui_SeparatorText(ctx, "Renaming")
  if data.mx_open then
    reaper.ImGui_Text(ctx, "Operating on ")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextColored(ctx, color.red, "Media Explorer Files")
    Tooltip(ctx, "Close the Media Explorer to rename tracks, items, markers and regions.")
  else  
    local has_changed = false
    rv, data.target = reaper.ImGui_RadioButtonEx(ctx, "Tracks", data.target, 0)
    has_changed = has_changed or rv
    reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
    rv, data.target = reaper.ImGui_RadioButtonEx(ctx, "Media Items", data.target, 1)
    has_changed = has_changed or rv
    reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
    rv, data.target = reaper.ImGui_RadioButtonEx(ctx, "Markers", data.target, 2)
    has_changed = has_changed or rv
    reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
    rv, data.target = reaper.ImGui_RadioButtonEx(ctx, "Regions", data.target, 3)
    has_changed = has_changed or rv
    
    Tooltip(ctx, "You can toggle the renaming target with F1-F4")
    
    ToggleTarget()
    
    reaper.ImGui_Text(ctx, "Operating in ")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextColored(ctx, color.blue, "Arrange View")
    Tooltip(ctx, "Open the Media Explorer to rename local files")
    
    if data.target == 2 or data.target == 3 then
      local btn_text
      --reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
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
    else
      reaper.ImGui_Text(ctx, "")
    end
    
    if has_changed then
      reaper.SetExtState(ext_section, "target", tostring(data.target), false)
    end
  end
  --reaper.ImGui_Separator(ctx)
end

function CategoryFields()
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
  
  --CategoryBrowser()
  
  if id_changed and form.cat_id ~= "" then
    -- update categories if Category ID changed manually
    local rv, cname, sname = ReverseLookup(form.cat_id)
    
    if rv then
      form.cat_name = cname
      form.sub_name = sname
      combo.sub_items = PopulateSubCategories(form.cat_name)
      form.cur_cat = combo.cat_idx[form.cat_name]
      form.cur_sub = combo.sub_idx[form.sub_name]
    end
  end
end

function CategorySearch()
  local rv
  
  if (form.applied and not form.name_focused) or form.search_sc then 
    reaper.ImGui_SetKeyboardFocusHere(ctx)
    form.applied = false
    form.search_sc = false
  end
  
  rv, form.search = reaper.ImGui_InputText(ctx, "Search category...", form.search)
  
  Tooltip(ctx, "Search for multiple results by ...")
  
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
    
    for i=1, #ucs.search_data do
      local entry = ucs.search_data[i]
      local count = 0
      
      for _,v in ipairs(words) do
        if string.find(entry, v) then
          count = count + 1
        end
      end
      
      if count == #words then
        table.insert(syns, entry)
      end
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
      for i=1, #syns do
        local is_selected = form.search_idx == i and not form.search_mouse
        local entry = syns[i]
        local id, syn = string.match(entry, "(.*);(.*)")
        
        local selectable = reaper.ImGui_Selectable(ctx, id .. "\n" .. syn, is_selected);reaper.ImGui_Separator(ctx)
      
        if form.search_mouse and reaper.ImGui_IsItemHovered(ctx) then
          form.search_idx = i
        end
        
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
        end
      end
      
      reaper.ImGui_EndListBox(ctx)
    end
    
    -- update categories if Category ID changed manually
    local rv, cname, sname = ReverseLookup(form.cat_id)
    
    if rv then
      form.cat_name = cname
      form.sub_name = sname
      combo.sub_items = PopulateSubCategories(form.cat_name)
      form.cur_cat = combo.cat_idx[form.cat_name]
      form.cur_sub = combo.sub_idx[form.sub_name]
    end
  end
end

function CategoryBrowser()
  if reaper.ImGui_Button(ctx, "Category Browser...") then
    reaper.ImGui_OpenPopup(ctx, "Category Browser")
  end
  local viewport = reaper.ImGui_GetMainViewport(ctx)
  local width, height = reaper.ImGui_Viewport_GetSize(viewport)
  local x, y = reaper.ImGui_Viewport_GetCenter(viewport)
  reaper.ImGui_SetNextWindowPos(ctx, x, y, reaper.ImGui_Cond_Appearing(), 0.5, 0.5)
  
  reaper.ImGui_SetNextWindowSize(ctx, width/2, height/2)
  
  if reaper.ImGui_BeginPopupModal(ctx, "Category Browser", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
    if reaper.ImGui_BeginTable(ctx, "Category Tsable", 5) then
      reaper.ImGui_TableSetupColumn(ctx, "Category")
      reaper.ImGui_TableSetupColumn(ctx, "Subcategory")
      reaper.ImGui_TableSetupColumn(ctx, "CatID")
      reaper.ImGui_TableSetupColumn(ctx, "Explanations")
      reaper.ImGui_TableSetupColumn(ctx, "Synonyms")
      reaper.ImGui_TableHeadersRow(ctx)
      
      for i,v in ipairs(ucs.raw_data) do
        local line = { string.match(v, "(.*);(.*);(.*);(.*);(.*)") }
        reaper.ImGui_TableNextRow(ctx)
        for column=0, 4 do
          reaper.ImGui_TableSetColumnIndex(ctx, column)
          reaper.ImGui_Text(ctx, line[column+1])
        end
      end
      reaper.ImGui_EndTable(ctx)
    end
    if reaper.ImGui_Button(ctx, "Close") then
      reaper.ImGui_CloseCurrentPopup(ctx)
    end
    reaper.ImGui_EndPopup(ctx)
  end
end

function Apply()
  local rv = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) 
    and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter(), false)
  form.applied = rv
  return rv
end

function SubstituteIdx(filename, index)
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

function SubstituteSelf(filename, name)
  local self = string.find(filename, "$self")
  
  --TODO Test self for Files
  
  if self then
    -- extract UCS category from name
    local no_cat_name = string.match(name, "_([^_]+)$")
    if no_cat_name then
      name = no_cat_name
    end
    return string.gsub(filename, "$self", name)
  end
  
  return filename
end

function BigButton(ctx, label, divider, padding, color)
  divider = divider or 1
  padding = padding or 40
  
  if color then
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), color)
  end
  
  local width = reaper.ImGui_GetWindowSize(ctx)
  
  local btn = reaper.ImGui_Button(ctx, label, (width/divider) - padding, style.big_btn_height)
  
  if color then
    reaper.ImGui_PopStyleColor(ctx)
  end
  
  return btn
end

function SmallButton(ctx, label)
  reaper.ImGui_PushFont(ctx, style.font_info)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), color.transparent)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), color.transparent)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), color.transparent)
  
  local btn = reaper.ImGui_Button(ctx, label)
  
  reaper.ImGui_PopStyleColor(ctx, 3)
  reaper.ImGui_PopFont(ctx)
  return btn
end

function Rename()
  reaper.Undo_BeginBlock()
  
  if data.mx_open then
    local autoplay = reaper.GetToggleCommandStateEx(32063, 1011) --Autoplay: Toggle on/off
    
    -- disable autoplay, stop playback
    reaper.JS_Window_OnCommand(data.mx_handle, 40036) -- Autoplay: Off
    reaper.JS_Window_OnCommand(data.mx_handle, 1009) -- Preview: Stop
    reaper.JS_Window_OnCommand(data.mx_handle, 1009) -- Preview: Stop
    
    for i,v in ipairs(data.files) do 
      local old_file = data.directory .. "/" .. v
      local _, _, ext = string.match(v, "(.-)([^\\/]-%.?([^%.\\/]*))$")
      
      local filename = data.ucs_names[i]
      local new_file = data.directory .. "/" .. filename .. "." .. ext
      
      rv, osbuf = os.rename(old_file, new_file)
    end
    
    if autoplay == 1 then -- Enable autoplay if it was toggled on
      reaper.JS_Window_OnCommand(hWnd, 40035) -- Autoplay: On
    end
    
    form.applied = true
  else
    if data.target == 0 then
      for i = 1, #data.tracks do 
        local track = data.tracks[i]
        local filename = data.ucs_names[i]
      
        reaper.GetSetMediaTrackInfo_String(track, "P_NAME", filename, true)
      end
      reaper.Undo_EndBlock2(0, "UCS Toolkit: Renamed " .. #data.tracks .. " tracks", 0)
      form.applied = true
    elseif data.target == 1 then
      for i = 1, #data.items do
        local item = data.items[i]
        local take = reaper.GetActiveTake(item)
        local filename = data.ucs_names[i]
        
        reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", filename, true)
      end
      reaper.Undo_EndBlock2(0, "UCS Toolkit: Renamed " .. #data.items .. " tracks", 0)
      form.applied = true
    elseif data.target == 2 then
      for i, v in ipairs(data.selected_markers) do
        local idx = v[1]
        local pos = v[2]
        local filename = data.ucs_names[i]
        
        reaper.SetProjectMarker(idx, false, pos, pos, filename)
      end
      reaper.Undo_EndBlock2(0, "UCS Toolkit: Renamed " .. #data.selected_markers .. " markers", 0)
      form.applied = true
    elseif data.target == 3 then
      for i, v in ipairs(data.selected_regions) do
        local idx = v[1]
        local pos = v[2]
        local rgnend = v[3]
        local filename = data.ucs_names[i]
        
        reaper.SetProjectMarker(idx, true, pos, rgnend, filename)
      end
      reaper.Undo_EndBlock2(0, "UCS Toolkit: Renamed " .. #data.selected_regions .. " regions", 0)
      form.applied = true
    end
  end
end

-- Only use one button for all targets

function RenameButton()
  local t
  local label
  local col
  if data.target == 0 then
    t = data.tracks
    label = " Track"
    col = color.green
  elseif data.target == 1 then
    t = data.items
    label = " Item"
    col = color.yellow
  elseif data.target == 2 then
    t = data.selected_markers
    label = " Marker"
    col = color.purple
  elseif data.target == 3 then
    t = data.selected_regions
    label = " Region"
  end
  
  if data.mx_open then
    t = data.files
    label = " File"
    col = color.turquois
  end
  
  if #t > 1 then label = label .. "s" end -- Append "s" if there are more than one element in table
  
  if BigButton(ctx, "Rename " .. #t .. label, nil, nil, col) or Apply() then
    Rename()
  end
end

function CacheMarkers(cacheregions)
  data.markers = {}
  data.regions = {}

  local rv, marker_count, region_count = reaper.CountProjectMarkers(0)
  
  for i=0, marker_count + region_count - 1 do
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

function CacheSelectedTracks()
  data.tracks = {}
  for i=0, reaper.CountSelectedTracks(0) do
    local track = reaper.GetSelectedTrack(0, i)
    data.tracks[i+1] = track
  end
end

function CacheSelectedItems()
  data.items = {}
  for i=0, reaper.CountSelectedMediaItems(0) do
    local item = reaper.GetSelectedMediaItem(0, i)
    data.items[i+1] = item
  end
end

function CacheFiles()
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
    name = reaper.JS_ListView_GetItemText(file_LV, tonumber(ndx), 0)
    table.insert(data.files, name)
  end
end

function CacheUCSData()
  data.ucs_names = {}
  
  local t
  
  if data.target == 0 then
    t = data.tracks
  elseif data.target == 1 then
    t = data.items
  elseif data.target == 2 then
    t = data.selected_markers
  elseif data.target == 3 then
    t = data.selected_regions
  end
  
  if data.mx_open then
    t = data.files
  end
  
  for i=1, #t do
    local target_name
    
    if data.mx_open then
      target_name = t[i]
    else 
      if data.target == 0 then
        _, target_name = reaper.GetTrackName(t[i])
      elseif data.target == 1 then
        local take = reaper.GetMediaItemTake(t[i], 0)
        target_name = reaper.GetTakeName(take)
      elseif data.target == 2 then
        target_name = t[i][3]
      elseif data.target == 3 then
        target_name = t[i][4]
      elseif data.target == 4 then
        target_name = t[i]
      end
    end
    
    local parts = ParseFilename(target_name)
    local fx_name = parts[2]
    local creator_id = parts[3]
    local source_id = parts[4]
    
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

function GetSelectedMarkers(getregions)
  local selected_markers = {}
  local loop_start, loop_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 10, false)
  
  local t
  if getregions then t = data.regions else t = data.markers end
  
  if loop_start < loop_end then
    for i,v in ipairs(t) do
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
    
    for i,v in ipairs(t) do
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

function CountManagerMarkers(countregions)
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
    
    for i,v in ipairs(t) do
      local idx = v[1]
      if table.contains(ids, idx) then
        local mrk
        if countregions then
          mrk = { [1] = v[1], [2] = v[2], [3] = v[3], [4] = v[4] }
        else
          mrk =  { [1] = v[1], [2] = v[2], [3] = v[3] }
        end
        table.insert(selected_markers, mrk)
      end
    end
  end
  
  return selected_markers
end

function CountTargets()
  local filecount = 0
  
  if data.mx_open then
    CacheFiles(data.mx_handle)
    filecount = #data.files
  else
    if data.target == 0 then
      CacheSelectedTracks()
      filecount = #data.tracks
    elseif data.target == 1 then
      CacheSelectedItems()
      filecount = #data.items
    elseif data.target == 2 then
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
    elseif data.target == 3 then
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

function NameShortcut()
  return reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) 
    and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_N(), false)
end

function SearchShortcut()
  return reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) 
    and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F(), false)
end

function NavigateNext()
  return reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) 
    and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_RightArrow(), false)
end

function NavigatePrevious()
  return reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) 
    and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_LeftArrow(), false)
end

function GetNearestMarker(isrgn)
  local t = {}
  if isrgn then t = data.regions else t = data.markers end
  
  local cur_pos = reaper.GetCursorPositionEx(0)
  local min = -1
  local nearest_marker
  
  for i,v in ipairs(t) do
    local distance = math.abs(v[2] - cur_pos) 
    if distance < min or min == -1 then
      min = distance
      nearest_marker = {i, v[2]}
    end
  end
  
  return nearest_marker
end

function NavigateMarker(isrgn, step)
  local t = {}
  if isrgn then t = data.regions else t = data.markers end
  
  local nav_marker
  if isrgn then nav_marker = data.nav_region else nav_marker = data.nav_marker end
  
  -- markers are cached in their respective order
  -- if no current marker is set (0), take the first one near cursor (default action)
  
  local m = GetNearestMarker(isrgn)
  
  if m[2] ~= reaper.GetCursorPositionEx(0) then 
    reaper.SetEditCurPos2(0, m[2], true, true)
    nav_marker = m[1]
  else
    nav_marker = clamp(nav_marker + step, 1, #t)
    
    local mrk = t[nav_marker]
    
    if mrk then
      reaper.SetEditCurPos2(0, mrk[2], true, true)
      return nav_marker
    end
  end

  return nav_marker
end

function Navigate(next)
  if data.mx_open then
    if next then
      reaper.JS_Window_OnCommand(data.mx_handle, 40030) -- Browser: Select next file in directory
    else
      reaper.JS_Window_OnCommand(data.mx_handle, 40029) -- Browser: Select previous file in directory
    end
  else
    if data.target == 0 then
      if next then
        reaper.Main_OnCommand(40285, 0) -- Track: Go to next track
      else
        reaper.Main_OnCommand(40286, 0) -- Track: Go to previous track
      end
    elseif data.target == 1 then
      if next then
        reaper.Main_OnCommand(40417, 0) -- Item navigation: Select and move to next item
      else
        reaper.Main_OnCommand(40416, 0) -- Item navigation: Select and move to previous item
      end
    elseif data.target == 2 then
      if next then
        data.nav_marker = NavigateMarker(false, 1)
      else
        data.nav_marker = NavigateMarker(false, -1)
      end
    elseif data.target == 3 then
      if next then
        data.nav_region = NavigateMarker(true, 1)
      else
        data.nav_region = NavigateMarker(true, -1)
      end
    end
  end
  
  if form.autorename then Rename() end
  
  if form.autoplay and not data.mx_open then
    reaper.Main_OnCommand(1016, 0) -- Transport: Stop
    reaper.Main_OnCommand(40044, 0) -- Transport: Play/stop
  end
end

function MainFields()
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), color.mainfields)
  
  if (form.applied and form.name_focused) or form.search_apply or form.name_sc then
    reaper.ImGui_SetKeyboardFocusHere(ctx)
    form.search_apply = false
    form.applied = false
  end
  
  rv, form.fx_name = reaper.ImGui_InputText(ctx, "FXName", form.fx_name)
  form.name_focused = reaper.ImGui_IsItemFocused(ctx)
  Tooltip(ctx, "Brief Description or Title (under 25 characters preferably)")
  
  rv, form.creator_id = reaper.ImGui_InputText(ctx, "CreatorID", form.creator_id)
  Tooltip(ctx, "Sound Designer, Recordist or Vendor (or abbreviaton for them")
  
  rv, form.source_id = reaper.ImGui_InputText(ctx, "SourceID", form.source_id)
  Tooltip(ctx, "Project, Show or Library name (or abbreviation representing it")
  
  reaper.ImGui_PopStyleColor(ctx)
  
  WildcardInfo()
  
  reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
  
  rv, form.clear_fx = reaper.ImGui_Checkbox(ctx, "Clear FXName on rename", form.clear_fx)
end

function OptionalFields()
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), color.transparent)
  if reaper.ImGui_CollapsingHeader(ctx, "Optional Fields", nil) then
    
    rv, form.user_cat = reaper.ImGui_InputText(ctx, "UserCategory", form.user_cat)
    Tooltip(ctx, "An optional tail extension of the CatID block that can be used\nas a user defined category, microphone, perspective, etc.")
    
    rv, form.vendor_cat = reaper.ImGui_InputText(ctx, "VendorCategory", form.vendor_cat)
    Tooltip(ctx, "An option head extension to the FXName Block usable by vendors to\ndefine a library specific category. For example, the specific name\nof a gun, vehicle, location, etc.")
    
    rv, form.user_data = reaper.ImGui_InputText(ctx, "UserData", form.user_data)
    Tooltip(ctx, "A user defined space, ofter used for an ID or Number for guaranteeing that the Filename is 100% unique...")
    
  end
  reaper.ImGui_PopStyleColor(ctx)
end

function AutoFill()
  local state_count= reaper.GetProjectStateChangeCount(0)
  if state_count ~= data.state_count then
    -- Update based on selected target
    local target_name = ""
    
    if data.target == 0 then
      local track = reaper.GetSelectedTrack(0, 0)
      if track then
        _, target_name = reaper.GetTrackName(track)
      end
    elseif data.target == 1 then
      local item = reaper.GetSelectedMediaItem(0, 0)
      if item then
        local take = reaper.GetTake(item, 0)
        target_name = reaper.GetTakeName(take)
      end
    elseif data.target == 2 then
      --target_name = data.selected_markers[1][3]
    elseif data.target == 3 then
      --target_name = data.selected_regions[1][4]
    end
    
    if target_name ~= "" then
      form.cat_id, form.fx_name, form.creator_id, form.source_id = ParseFilename(target_name)
      
      local rv, cname, sname = ReverseLookup(form.cat_id)
      
      if rv then
        form.cat_name = cname
        form.sub_name = sname
        combo.sub_items = PopulateSubCategories(form.cat_name)
        form.cur_cat = combo.cat_idx[form.cat_name]
        form.cur_sub = combo.sub_idx[form.sub_name]
      end
    end
    
    data.state_count = state_count
  end
end

function PushMainStyleVars()
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 1, style.item_spacing_y)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_SeparatorTextPadding(), 0, 0)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), style.frame_rounding)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), style.frame_border)
  
  return 4
end

function Navigation()
  reaper.ImGui_SeparatorText(ctx, "Navigation")
  
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
  
  if not data.mx_open then
    rv, form.autoplay = reaper.ImGui_Checkbox(ctx, "Autoplay when navigating", form.autoplay)
    reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
  end
  rv, form.autorename = reaper.ImGui_Checkbox(ctx, "Auto-Rename when navigating", form.autorename)
end

function Main()
  -- check if data can update
 
  data.update = false
  data.ticks = data.ticks + 1
  
  if data.ticks >= settings.update_interval then
    data.update = true
    data.ticks = 0
  end
  
  reaper.ImGui_PushFont(ctx, style.font_menu)
  reaper.ImGui_Text(ctx, "USC Toolkit")
  reaper.ImGui_PopFont(ctx)
  
  reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
  
  reaper.ImGui_PushFont(ctx, style.font_info)
  reaper.ImGui_Text(ctx, "UCS Version " .. ucs.version)
  
  reaper.ImGui_PopFont(ctx)
  
  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_Dummy(ctx, 70, 0)
  reaper.ImGui_SameLine(ctx)
  
  reaper.ImGui_PushFont(ctx, style.font)
  
  Info()
  reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
  
  Dock()
  reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
  
  Support()
  reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
  
  Settings()
  
  reaper.ImGui_Separator(ctx)
  reaper.ImGui_Dummy(ctx, 0, style.item_spacing_y)
  
  local style_pushes = PushMainStyleVars()
  
  CategorySearch()
  CategoryFields()
  
  reaper.ImGui_Separator(ctx)
  
  MainFields()
  
  OptionalFields()
  
  data.mx_open, data.mx_handle = IsWindowOpen("Media Explorer")
  
  --TODO optimize cache behaviour - ticks vs changed state
  if data.update then
    data.rename_count = CountTargets()
  end

  reaper.ImGui_Separator(ctx)
  
  Navigation()
  
  OperationMode()
  
  reaper.ImGui_SeparatorText(ctx, "Preview")
  
  if data.mx_open then
    if data.files then
      reaper.ImGui_LabelText(ctx, "Directory", data.directory)
    end
  end

  if data.rename_count <= 1 then
    reaper.ImGui_LabelText(ctx, "Filename", data.ucs_names[1])
  else
    local filenames = ""
    
    for i=1, #data.ucs_names do
      filenames = filenames .. data.ucs_names[i] .. "\0"
    end
    
    reaper.ImGui_Combo(ctx, "Filenames", 0, filenames)
  end

  RenameButton()
  
  Tooltip(ctx, "Quick Rename targets with Ctrl+Enter")
  
  form.search_sc = SearchShortcut()
  form.name_sc = NameShortcut()
  
  if form.applied then
    if form.clear_fx then form.fx_name = "" end
    Navigate(true)
  end
  
  WebsiteLink()
  
  reaper.ImGui_PopStyleVar(ctx, style_pushes)
  reaper.ImGui_PopFont(ctx)
end

function WebsiteLink()
  reaper.ImGui_PushFont(ctx, style.font_info)
  
  reaper.ImGui_Text(ctx, "tdspkaudio.com")
  
  if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
    reaper.CF_ShellExecute("https://www.tdspkaudio.com")
  end
  
  reaper.ImGui_PopFont(ctx)
end

function Info()
  if SmallButton(ctx, "Info") then
    reaper.ImGui_OpenPopup(ctx, "Info")
  end
  
  local x, y = reaper.ImGui_Viewport_GetCenter(reaper.ImGui_GetWindowViewport(ctx))
  reaper.ImGui_SetNextWindowPos(ctx, x, y, reaper.ImGui_Cond_Appearing(), 0.5, 0.5)
  reaper.ImGui_SetNextWindowSize(ctx, 300, 0)
  
  if reaper.ImGui_BeginPopupModal(ctx, "Info", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then 
    local info = {
      "UCS Toolkit " .. version,
      "UCS Version " .. ucs.version,
      "A tool by tdspk"
    }
    
    for _, v in ipairs(info) do
      reaper.ImGui_Text(ctx, v)
    end
    
    reaper.ImGui_SeparatorText(ctx, "Special Thanks to:")
    
    local thanks = {
      "Hans Ekevi",
      "Cockos Inc.",
      "cfillion for ReaImGui",
      "The REAPER Community",
      "The Airwiggles Community"
    }
    
    for _, v in ipairs(thanks) do
      reaper.ImGui_Text(ctx, v)
    end
      
    if reaper.ImGui_Button(ctx, "Close") then
      reaper.ImGui_CloseCurrentPopup(ctx)
    end
    
    reaper.ImGui_EndPopup(ctx)
  end
end

function Dock()
  if app.dock_id ~= 0 then
    if SmallButton(ctx, "Undock") then
      app.dock_id = 0
      app.has_undocked = true
    end
  else
    if SmallButton(ctx, "Dock") then
      app.dock_id = -1
    end
  end
end

function Menu()
  reaper.ImGui_PushFont(ctx, style.font_menu)
  if reaper.ImGui_BeginMenuBar(ctx) then
    if reaper.ImGui_BeginMenu(ctx, "Info", true) then
      local info = {
        "UCS Toolkit " .. version,
        "UCS Version " .. ucs.version,
        "A tool by tdspk"
      }
      
      for _, v in ipairs(info) do
        reaper.ImGui_MenuItem(ctx, v, "", false, false)
      end
      
      reaper.ImGui_Separator(ctx)
      
      if reaper.ImGui_BeginMenu(ctx, "Special Thanks to...") then
        local thanks = {
          "Hans Ekevi",
          "Cockos Inc.",
          "cfillion for ReaImGui",
          "The REAPER Community",
          "The Airwiggles Community"
        }
        
        for _, v in ipairs(thanks) do
          reaper.ImGui_MenuItem(ctx, v, "", false, false)
        end
        
        reaper.ImGui_EndMenu(ctx)
      end
      
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

    Support()
    
    reaper.ImGui_EndMenuBar(ctx)
    reaper.ImGui_PopFont(ctx)
  end
end

function Loop()
  reaper.ImGui_SetNextWindowDockID(ctx, app.dock_id)
  
  if app.has_undocked then
    reaper.ImGui_SetNextWindowSize(ctx, app.window_width, app.window_height)
  end

  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 10)
  local visible, open = reaper.ImGui_Begin(ctx, "tdspk - UCS Toolkit", true)
  
  if visible then
    Main()
    
    reaper.ImGui_End(ctx)
  end
  
  reaper.ImGui_PopStyleVar(ctx)
  if open then
    reaper.defer(Loop)
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
  reaper.ShowMessageBox("Could not load 'UCS.csv'.\nPlease check the data folder in the script root for any missing files.", "File loading failed", 0)
end

::eof::
