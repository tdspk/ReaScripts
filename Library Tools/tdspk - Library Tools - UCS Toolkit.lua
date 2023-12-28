--@description UCS Toolkit
--@version 0.1
--@author Tadej Supukovic (tdspk)
--@about
--  # UCS Tookit
--  Tool for (re)naming tracks, items, markers, regions and Media Explorer files inside REAPER using the Universal Category System (UCS).
--  This is a development build. Tested on Windows only. Please report bugs and FR at the provided links.
--  # Requirements
--  JS_ReaScriptAPI, SWS Extension, ReaImGui
--@links
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
    mgs = msg .. "js_ReaScriptAPI: API functions for ReaScripts - please install via ReaPack\n"
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

color = {
  red = reaper.ImGui_ColorConvertDouble4ToU32(1, 0, 0, 1),
  blue = reaper.ImGui_ColorConvertDouble4ToU32(0, 0.91, 1, 1),
  gray = reaper.ImGui_ColorConvertDouble4ToU32(0.75, 0.75, 0.75, 1),
  green = reaper.ImGui_ColorConvertDouble4ToU32(0, 1, 0, 0.5),
  yellow = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 0, 0.5),
  mainfields = reaper.ImGui_ColorConvertDouble4ToU32(0.2, 0.2, 0.2, 1),
  transparent = reaper.ImGui_ColorConvertDouble4ToU32(0, 0, 0, 0)
}

local style = {
  window_width = 450,
  window_height = 760,
  item_spacing_x = 10,
  item_spacing_y = 10,
  big_btn_height = 50,
  frame_rounding = 2,
  frame_border = 1
}

local ucs = {
  version = 0.0,
  categories = {},
  synonyms = {}
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
  search_cat = 1,
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
  applied = false
}

data = {
  target = 0,
  target_self = "",
  rename_count = 0,
  track_count = 0,
  item_count = 0,
  file_count = 0,
  selected_markers = {},
  selected_regions = {},
  ticks = 0,
  update = false
}

local ext_section = "tdspk_ucstoolkit"

default_settings = {
  font_size = 15,
  save_state = false,
  delimiter = "_",
  update_interval = 1,
  tooltips = true
}

settings = {
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
      ucs.version =  string.match(line, "(.*);;;")
      got_version = true
    else
      local cat, subcat, id, syn = string.match(line, "(.*);(.*);(.*);(.*)")
      
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

  style.font = reaper.ImGui_CreateFont("sans-serif", settings.font_size)
  reaper.ImGui_Attach(ctx, style.font)
  
  style.font_info = reaper.ImGui_CreateFont("sans-serif", math.floor(settings.font_size * 0.8))
  reaper.ImGui_Attach(ctx, style.font_info)
  
  style.font_menu = reaper.ImGui_CreateFont("sans-serif", 12)
  reaper.ImGui_Attach(ctx, style.font_menu)
  
  style.window_padding = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding())
  
  reaper.ImGui_SetNextWindowSize(ctx, style.window_width, style.window_height)
  
  form.syn_filter = reaper.ImGui_CreateTextFilter()
  reaper.ImGui_Attach(ctx, form.syn_filter)
  
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

function ParseFilename(filename) 
  local cat_id, fx_name, creator_id, source_id = string.match(filename, "(.*)_(.*)_(.*)_(.*)")
  return cat_id, fx_name, creator_id, source_id
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

-- Code from Edgemeal - adapted! Thank you!
function GetMediaExplorerFiles()
  local files = {}
  
  local file_LV = reaper.JS_Window_FindChildByID(data.mx_handle, 0x3E9) 
  local sel_count, sel_indexes = reaper.JS_ListView_ListAllSelItems(file_LV)
  if sel_count == 0 then return 0, files end

  local index = 0
  -- get path from combobox
  local combo = reaper.JS_Window_FindChildByID(hWnd, 1002)
  local edit = reaper.JS_Window_FindChildByID(combo, 1001)
  local path = reaper.JS_Window_GetTitle(edit, "", 1024)

  files[index] = path
  -- get selected items in 1st column of ListView.
  for ndx in string.gmatch(sel_indexes, '[^,]+') do
    name = reaper.JS_ListView_GetItemText(file_LV, tonumber(ndx), 0)
    index = index + 1
    files[index] = name
  end
  
  return sel_count, files
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
  if reaper.ImGui_Button(ctx, "Settings") then
    reaper.ImGui_OpenPopup(ctx, "Settings")
  end
  
  local x, y = reaper.ImGui_Viewport_GetCenter(reaper.ImGui_GetWindowViewport(ctx))
  reaper.ImGui_SetNextWindowPos(ctx, x, y, reaper.ImGui_Cond_Appearing(), 0.5, 0.5)
  
  reaper.ImGui_PushFont(ctx, style.font)
  
  if reaper.ImGui_BeginPopupModal(ctx, "Settings", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 1, style.item_spacing_x)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), style.frame_border)
  
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
    
    reaper.ImGui_PopStyleVar(ctx)
    reaper.ImGui_PopStyleVar(ctx)
    
    reaper.ImGui_EndPopup(ctx)
  end

  reaper.ImGui_PopFont(ctx)
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

function Licensing()
  if reaper.GetExtState("tdspk_ucs", "license") ~= "1" then
    if BigButton(ctx, "SUPPORT THIS TOOL", nil, nil, color.green) then
      reaper.ImGui_OpenPopup(ctx, "Licensing")
    end
    
    local x, y = reaper.ImGui_Viewport_GetCenter(reaper.ImGui_GetWindowViewport(ctx))
    reaper.ImGui_SetNextWindowPos(ctx, x, y, reaper.ImGui_Cond_Appearing(), 0.5, 0.5)
    
    if reaper.ImGui_BeginPopupModal(ctx, "Licensing", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
      reaper.ImGui_Text(ctx, "This tool is free and open source. And it will always be.")
      reaper.ImGui_Text(ctx, "I am against restrictive licensing.\nHowever, I appreciate your support.")
      reaper.ImGui_Text(ctx, "Purchasing a license will enable you to\nremove the 'SUPPORT THIS TOOL' button.")
      
      rv, buf = reaper.ImGui_InputText(ctx, "License Key", buf)
      
      if reaper.ImGui_Button(ctx, "Activate") then
        
      end
      
      reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
      
      if reaper.ImGui_Button(ctx, "Buy License") then
        reaper.CF_ShellExecute("https://www.tdspkaudio.com")
      end
      
      reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
      
      if reaper.ImGui_Button(ctx, "Close") then
        reaper.ImGui_CloseCurrentPopup(ctx)
      end
      reaper.ImGui_EndPopup(ctx)
    end
  else
    reaper.ImGui_PushFont(ctx, style.font_info)
  
    local email = reaper.GetExtState("tdspk_ucs", "email")
    reaper.ImGui_Text(ctx, "Supported by: " .. email)
    
    reaper.ImGui_PopFont(ctx)
  end
end

function IsWindowOpen(name)
  -- TODO implement mx support for other than windows (for now)
  if not string.find(data.os, "Win") then
    return false
  end
  
  local title = reaper.JS_Localize(name, "common")
  local hWnd = reaper.JS_Window_Find(title, true)
  
  if hWnd then
    return true, hWnd
  else
    return false
  end
end

function ToggleTarget()
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_1(), false) then
    data.target = 0
  elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_2(), false) then
    data.target = 1
  elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_3(), false) then
    data.target = 2
  end
end

function OperationMode() 
  if data.mx_open then
    reaper.ImGui_Text(ctx, "Operating on ")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextColored(ctx, color.red, "Media Explorer Files")
    Tooltip(ctx, "Close the Media Explorer to rename tracks, items, markers and regions.")
  else
    reaper.ImGui_Text(ctx, "Operating in ")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextColored(ctx, color.blue, "Arrange View")
    Tooltip(ctx, "Open the Media Explorer to rename local files")
    
    reaper.ImGui_Text(ctx, "Renaming: ")
    reaper.ImGui_SameLine(ctx)
    
    local has_changed = false
    rv, data.target = reaper.ImGui_RadioButtonEx(ctx, "Tracks", data.target, 0)
    has_changed = has_changed or rv
    reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
    rv, data.target = reaper.ImGui_RadioButtonEx(ctx, "Media Items", data.target, 1)
    has_changed = has_changed or rv
    reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
    rv, data.target = reaper.ImGui_RadioButtonEx(ctx, "Markers/Regions", data.target, 2)
    has_changed = has_changed or rv
    
    Tooltip(ctx, "You can toggle the renaming target with numbers 1-3")
    
    ToggleTarget()
    
    if has_changed then
      reaper.SetExtState(ext_section, "target", tostring(data.target), false)
    end
  end
end

function CategoryFields()
  local cat_changed, sub_changed, id_changed
  cat_changed, form.cur_cat = reaper.ImGui_Combo(ctx, "Category", form.cur_cat, combo.cat_items)
  
  --[[
  if reaper.ImGui_BeginCombo(ctx, "Category", combo.idx_cat[form.cur_cat]) then
    reaper.ImGui_TextFilter_Draw(filter_cat, ctx, "Filter")
    
    for i, v in ipairs(combo.idx_cat) do
      if reaper.ImGui_TextFilter_PassFilter(filter_cat, v) then
        if reaper.ImGui_Selectable(ctx, v) then 
          cat_changed = true
          form.cur_cat = i
        end
      end
    end
    
    reaper.ImGui_EndCombo(ctx)
  end
  ]]--

  if cat_changed or combo.sub_items == "" then
    -- populate subcategories based on selected category
    form.cat_name = combo.idx_cat[form.cur_cat]
    combo.sub_items = PopulateSubCategories(form.cat_name)
  end
  
  sub_changed, form.cur_sub = reaper.ImGui_Combo(ctx, "Subcategory", form.cur_sub, combo.sub_items)
  
  --[[
  if reaper.ImGui_BeginCombo(ctx, "Subcategory", combo.idx_sub[form.cur_sub]) then
    --reaper.ImGui_SetKeyboardFocusHere(ctx)
    reaper.ImGui_TextFilter_Draw(filter_sub, ctx, "Filter")
    
    for i, v in ipairs(combo.idx_sub) do
      if reaper.ImGui_TextFilter_PassFilter(filter_sub, v) then
        if reaper.ImGui_Selectable(ctx, v) then
          sub_changed = true
          form.cur_sub = i
        end
      end
    end
    
    reaper.ImGui_EndCombo(ctx)
  end
  ]]--
  
  if cat_changed or sub_changed or form.cat_id == "" then
    form.sub_name = combo.idx_sub[form.cur_sub]
    form.cat_id = ucs.categories[form.cat_name][form.sub_name]
  end
  
  id_changed, form.cat_id = reaper.ImGui_InputText(ctx, "CatID", form.cat_id)
  
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
  
  if form.applied then 
    reaper.ImGui_SetKeyboardFocusHere(ctx)
    form.applied = false
  end
  
  rv, form.search = reaper.ImGui_InputText(ctx, "Search category...", form.search)
  
  if rv then
    form.search_cat = 1
  end
  if rv and not is_list_open then
    is_list_open = true
  elseif form.search == "" then
    is_list_open = false
  end
  
  if is_list_open then
    --local syn_filter = reaper.ImGui_CreateTextFilter(form.search)
    reaper.ImGui_TextFilter_Set(form.syn_filter, form.search)
    
    -- Filter Synonys manually
    local syns = {}
    for i=1, #ucs.synonyms do
      local entry = ucs.synonyms[i]
      if reaper.ImGui_TextFilter_PassFilter(form.syn_filter, entry) then
        table.insert(syns, entry)
      end
    end
    
    select_next = -1
    
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_DownArrow(), false) then
      form.search_cat = form.search_cat + 1
      if form.search_cat > #syns then form.search_cat = 1 end
    elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_UpArrow(), false) then
      form.search_cat = form.search_cat - 1
      if form.search_cat < 1 then form.search_cat = #syns end
    elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter(), false) then
      select_next = form.search_cat
    end
    
    if reaper.ImGui_BeginListBox(ctx, "Autosearch Categories") then 
      for i=1, #syns do
        local entry = syns[i]
        local id, syn = string.match(entry, "(.*);(.*)")
        
        local selectable = reaper.ImGui_Selectable(ctx, id .. "\n" .. syn, form.search_cat == i);reaper.ImGui_Separator(ctx)
        a_max = reaper.ImGui_GetScrollMaxY(ctx)
        if form.search_cat == i then
          reaper.ImGui_SetScrollHereY(ctx, 1)
        end
        
        if selectable or select_next == i then
          form.cat_id = id
          form.search = ""
          is_list_open = false
          form.search_cat = 1
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

function Apply()
  local rv = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) 
    and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter(), false)
  form.applied = rv
  return rv
end

function SubstituteIdx(index)
  -- check if $idx exists
  local idx = string.find(ucs_filename, "$idx")
  
  if idx then
    return string.gsub(ucs_filename, "$idx", tostring(index))
  end
  
  return ucs_filename .. " " .. tostring(index)
end

function SubstituteSelf(name)
  local self = string.find(ucs_filename, "$self")
  
  if self then
    return string.gsub(ucs_filename, "$self", name)
  end
  
  return ucs_filename
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

function RenameTracks()
  local label = " Track"
  if data.track_count > 1 then label = " Tracks" end
  
  if BigButton(ctx,  "Rename " .. data.track_count .. label, nil, nil, color.green) or Apply() then
    for i = 0, data.track_count - 1 do
      local track = reaper.GetSelectedTrack(0, i)
      local rv, track_name = reaper.GetTrackName(track)
      
      local filename = ucs_filename
      if data.track_count > 1 then filename = SubstituteIdx(i + 1) end
      filename = SubstituteSelf(track_name)
      
      reaper.GetSetMediaTrackInfo_String(track, "P_NAME", filename, true)
    end
  end
end

function RenameMediaItems()
  local label = " Item"
  if data.item_count > 1 then label = " Items" end

  if BigButton(ctx, "Rename " .. data.item_count ..  label, nil, nil, color.yellow) or Apply() then
    for i = 0, data.item_count - 1 do
      local item = reaper.GetSelectedMediaItem(0, i)
      local take = reaper.GetActiveTake(item)
      local take_name = reaper.GetTakeName(take)
      
      local filename = ucs_filename
      if data.item_count > 1 then filename = SubstituteIdx(i + 1) end
      filename = SubstituteSelf(take_name)
      
      reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", filename, true)
    end
  end
end

function RenameMarkers()
  local label = " Marker"
  if #data.selected_markers > 1 then label = " Markers" end

  if BigButton(ctx, "Rename " .. #data.selected_markers .. label, 2, 20) or Apply() then
    for i, v in ipairs(data.selected_markers) do
      local idx = v[1]
      local pos = v[2]
      
      local filename = ucs_filename
      if #data.selected_markers > 1 then filename = SubstituteIdx(i + 1) end
      
      reaper.SetProjectMarker(idx, false, pos, pos, filename)
    end
  end
end

function RenameRegions()
  local label = " Region"
  if #data.selected_regions > 1 then label = " Regions" end
  
  if BigButton(ctx,  "Rename " .. #data.selected_regions .. label, 2, 20) or Apply() then
    for i, v in ipairs(data.selected_regions) do
      local idx = v[1]
      local pos = v[2]
      local rgnend = v[3]
      
      local filename = ucs_filename
      if #data.selected_regions > 1 then filename = SubstituteIdx(i + 1) end
      
      reaper.SetProjectMarker(idx, true, pos, rgnend, filename)
    end
  end
end

function RenameFiles()
  local autoplay = reaper.GetToggleCommandStateEx(32063, 1011) --Autoplay: Toggle on/off
  
  if autoplay == 1 then
    reaper.ImGui_TextColored(ctx, color.red, "Autoplay is enabled! Please ")
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_SmallButton(ctx, "DISABLE") then
      reaper.JS_Window_OnCommand(hWnd, 40036)
    end
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextColored(ctx, color.red, " it to avoid weird behaviour.")
  end
  
  if data.files then
    if reaper.ImGui_Button(ctx, "Rename " .. #data.files .. " File(s)", 0, 40) then
      local dir = data.files[0]
      
      reaper.JS_Window_OnCommand(hWnd, 1009) -- Preview: Stop
      reaper.JS_Window_OnCommand(hWnd, 1009) -- Preview: Stop
      
      for i, v in ipairs(data.files) do
        local old_file = dir .. "/" .. v
        local _, _, ext = string.match(v, "(.-)([^\\/]-%.?([^%.\\/]*))$")
        
        local filename = ucs_filename
        if #data.files > 1 then filename = SubstituteIdx(i) end
        local new_file = dir .. "/" .. filename .. "." .. ext
        rv, osbuf = os.rename(old_file, new_file)
      end
    end
  end
end

function CountTargets()
  if data.mx_open then
    data.file_count, data.files = GetMediaExplorerFiles(hWnd)
    return data.file_count
  else
    if data.target == 0 then
      data.track_count = reaper.CountSelectedTracks(0)
      return data.track_count
    elseif data.target == 1 then
      data.item_count = reaper.CountSelectedMediaItems(0)
      return data.item_count
    elseif data.target == 2 then
      data.selected_markers = {}
      data.selected_regions = {}
      
      data.rm_open, data.rm_handle = IsWindowOpen("Region/Marker Manager", "common")
      if data.rm_handle then -- if Region/Marker Manager is open, count there
        local manager = reaper.JS_Window_FindChildByID(data.rm_handle, 0x42F)
        local sel_count, sel_indexes = reaper.JS_ListView_ListAllSelItems(manager)
        
        if sel_count > 0 then
          local selection = string.split(sel_indexes, ",")
          
          local marker_ids = {}
          local region_ids = {}
          
          for i, v in ipairs(selection) do
            local id = reaper.JS_ListView_GetItemText(manager, tonumber(v), 1)
            if string.find(id, "R") then
              id = string.gsub(id, "R", "")
              table.insert(region_ids, tonumber(id))
            else
              id = string.gsub(id, "M", "")
              table.insert(marker_ids, tonumber(id))
            end
          end
          
          local rv, marker_count, region_count = reaper.CountProjectMarkers(0)
          
          for i=0, marker_count + region_count do
            local rv, isrgn, pos, rgn_end, name, idx = reaper.EnumProjectMarkers(i)
            if isrgn then
              if table.contains(region_ids, idx) then
                local rgn = { [1] = idx, [2] = pos, [3] = rgn_end, [4] = name  }
                table.insert(data.selected_regions, rgn)
              end
            else
              if table.contains(marker_ids, idx) then
                local mrk = { [1] = idx, [2] = pos, [3] = name }
                table.insert(data.selected_markers, mrk)
              end
            end
          end
        end
        
        return sel_count
      else -- otherwise, count time selected items or current cursor position
        local loop_start, loop_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 10, false)
        if loop_start < loop_end then
          local rv, marker_count, region_count = reaper.CountProjectMarkers(0)
          
          for i=0, marker_count + region_count - 1 do
            local rv, isrgn, pos, rgn_end, name, idx = reaper.EnumProjectMarkers(i)
            if isrgn then
              if pos >= loop_start and rgn_end <= loop_end then
                local rgn = { [1] = idx, [2] = pos, [3] = rgn_end, [4] = name  }
                table.insert(data.selected_regions, rgn)
              end
            else
              if pos >= loop_start and pos <= loop_end then
                local mrk = { [1] = idx, [2] = pos, [3] = name }
                table.insert(data.selected_markers, mrk)
              end 
            end
          end
          
          return #data.selected_markers + #data.selected_regions
        else
          local marker_count, region_count = reaper.CountProjectMarkers(0)
          
          for i=0, marker_count + region_count - 1 do
            local rv, isrgn, pos, rgnend, name, idx  = reaper.EnumProjectMarkers(i)
            
            local cursor_pos = reaper.GetCursorPosition()
            
            if cursor_pos == pos then
              if isrgn then
                local rgn = { [1] = idx, [2] = pos, [3] = rgnend, [4] = name  }
                table.insert(data.selected_regions, rgn)
                return 1 -- return 1 counted, 0 markers, 1 region
              else
                local mrk = { [1] = idx, [2] = pos, [3] = name }
                table.insert(data.selected_markers, mrk)
                return 1 -- return 1 counter, 1 marker, 0 regions
              end
            end
          end
        end
      end
    end
  end
  
  return 0
end

function Navigate(next)
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
      reaper.Main_OnCommand(40173, 0) -- Markers: Go to next marker/project end
    else
      reaper.Main_OnCommand(40172, 0) -- Markers: Go to previous marker/project start
    end
  end
end

function MainFields()
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), color.mainfields)
  
  rv, form.fx_name = reaper.ImGui_InputText(ctx, "FXName", form.fx_name)
  Tooltip(ctx, "Brief Description or Title (under 25 characters preferably)")
  
  rv, form.creator_id = reaper.ImGui_InputText(ctx, "CreatorID", form.creator_id)
  Tooltip(ctx, "Sound Designer, Recordist or Vendor (or abbreviaton for them")
  
  rv, form.source_id = reaper.ImGui_InputText(ctx, "SourceID", form.source_id)
  Tooltip(ctx, "Project, Show or Library name (or abbreviation representing it")
  
  reaper.ImGui_PopStyleColor(ctx)
  
  -- Fill from Track feature
    --[[
  track = reaper.GetSelectedTrack(0, 0)
  
  if track then
    reaper.ImGui_BeginDisabled(ctx, false)
  else
    reaper.ImGui_BeginDisabled(ctx, true)
  end
  
  if reaper.ImGui_Button(ctx, "Fill from Track") then
    local rv, track_name = reaper.GetTrackName(track)
    form.cat_id, form.fx_name, form.creator_id, form.source_id = ParseFilename(track_name)
    
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
  reaper.ImGui_EndDisabled(ctx)
  ]]--
  
  --reaper.ImGui_SameLine(ctx, 0, 10)
  
  WildcardInfo()
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

function PushMainStyle()
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 1, style.item_spacing_y)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_SeparatorTextPadding(), 0, 0)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), style.frame_rounding)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), style.frame_border)
  
  return 4
end

function Main()
  -- check if data can update
  data.update = false
  data.ticks = data.ticks + 1
  
  if data.ticks >= settings.update_interval then
    data.update = true
    data.ticks = 0
  end

  reaper.ImGui_PushFont(ctx, style.font)
  local style_pushes = PushMainStyle()
  
  --Licensing()
  
  CategorySearch()
  CategoryFields()
  
  reaper.ImGui_Separator(ctx)
  
  MainFields()
  
  OptionalFields()
  
  reaper.ImGui_SeparatorText(ctx, "Results")
  
  data.mx_open, data.mx_handle = IsWindowOpen("Media Explorer")
  
  if data.mx_open then
    if data.files then
      reaper.ImGui_LabelText(ctx, "Directory", data.files[0])
    end
  end
  
  ucs_filename = CreateUCSFilename(settings.delimiter, form.cat_id, form.user_cat, form.vendor_cat, form.fx_name, form.creator_id, form.source_id, form.user_data)
  
  if data.update then
    data.rename_count = CountTargets()
  end
  
  if data.rename_count <= 1 then
    local filename = string.gsub(ucs_filename, "$idx", 1)
    reaper.ImGui_LabelText(ctx, "Filename", filename)
  else
    local filenames = ""
    local format = ucs_filename .. " $idx" .. "\0"
    
    -- check if $idx exists
    local idx = string.find(ucs_filename, "$idx")
    
    if idx then
      format = ucs_filename .. "\0"
    end
    
    for i=1, data.rename_count do
      local fname = string.gsub(format, "$idx", tostring(i))
      filenames = filenames .. fname
    end
    
     reaper.ImGui_Combo(ctx, "Filenames", 0, filenames)
  end

  reaper.ImGui_Separator(ctx)
  
  OperationMode()
  
  if data.mx_open then
    RenameFiles()
  else 
    -- Render Buttons for Marker/Region Manager and Navigation <>, Arrows
    if reaper.ImGui_ArrowButton(ctx, "Previous", reaper.ImGui_Dir_Left())
      or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_LeftArrow(), false) then
      Navigate(false)
    end
    
    reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
    
    if reaper.ImGui_ArrowButton(ctx, "Next", reaper.ImGui_Dir_Right())
      or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_RightArrow(), false) then
      Navigate(true)
    end
    
    Tooltip(ctx, "You can also navigate next/previous targets with the left and right arrow keys")
    
    if data.target == 2 then
      local btn_text
      reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
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
  
    if data.target == 0 then
      RenameTracks()
    elseif data.target == 1 then
      RenameMediaItems()
    elseif data.target == 2 then
      RenameMarkers()
      reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
      RenameRegions()
    end
    
    Tooltip(ctx, "Quick Rename targets with Ctrl+Enter")
    
    if form.applied then
      Navigate(true)
    end
  end
  
  WebsiteLink()
  
  for i=1, style_pushes do
    reaper.ImGui_PopStyleVar(ctx)
  end
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

function Menu()
  reaper.ImGui_PushFont(ctx, style.font_menu)
  if reaper.ImGui_BeginMenuBar(ctx) then
    if reaper.ImGui_BeginMenu(ctx, "File", true) then
      if reaper.ImGui_MenuItem(ctx, "Save Data") then
        local data = form.fx_name .. ";" .. form.creator_id .. ";" .. form.source_id
        reaper.SetExtState(ext_section, "data", data, false)
      end
      
      Tooltip(ctx, "Save data to local memory")
      
      if reaper.ImGui_MenuItem(ctx, "Load Data") then
        local data = reaper.GetExtState(ext_section, "data")
        form.fx_name, form.creator_id, form.source_id = string.match(data, "(.*);(.*);(.*)")
      end
      
      Tooltip(ctx, "Load data from local memory")
      
      if reaper.ImGui_MenuItem(ctx, "Clear all data") then
        form.fx_name, form.creator_id, form.source_id, form.user_cat, form.vendor_cat, form.user_data = ""
      end
      
      reaper.ImGui_EndMenu(ctx)
    end
    
    if reaper.ImGui_BeginMenu(ctx, "Info", true) then
      local info = {
        "UCS Toolkit",
        "UCS Version " .. ucs.version,
        "A tool by tdspk"
      }
      
      for _, v in ipairs(info) do
        reaper.ImGui_MenuItem(ctx, v, "", false, false)
      end
      
      reaper.ImGui_Separator(ctx)
      
      if reaper.ImGui_BeginMenu(ctx, "Special Thanks to...") then
        local thanks = {
          "Cockos Inc.",
          "cfillion for ReaImGui and the great support",
          "The REAPER Community",
          "Hans Ekevi",
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
      
      if reaper.ImGui_MenuItem(ctx, "GitHub Repository") then
        reaper.CF_ShellExecute("https://github.com/tdspk/ReaScripts")
      end
      
      reaper.ImGui_EndMenu(ctx)
    end
    
    Settings()
    
    reaper.ImGui_Dummy(ctx, style.item_spacing_x * 2, 0)
    
    if reaper.ImGui_BeginMenu(ctx, "Development Build", false) then
      
    end
    
    reaper.ImGui_EndMenuBar(ctx)
    reaper.ImGui_PopFont(ctx)
  end
end

function Loop()
  local visible, open = reaper.ImGui_Begin(ctx, "tdspk - UCS Toolkit - UCS Version " .. ucs.version, true, reaper.ImGui_WindowFlags_MenuBar())
  
  if visible then
    Menu()
    Main()
    reaper.ImGui_End(ctx)
  end
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
  ctx = reaper.ImGui_CreateContext("tdspk UCS Tookit")
  Init()
  Loop()
else
  reaper.ShowMessageBox("Could not load 'UCS.csv'.\nPlease check the data folder in the script root for any missing files.", "File loading failed", 0)
end

::eof::
