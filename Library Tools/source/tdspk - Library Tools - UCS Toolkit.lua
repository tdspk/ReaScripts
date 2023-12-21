dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]
ucs_file = script_path .. "../data/UCS.csv"

color = {
  red = reaper.ImGui_ColorConvertDouble4ToU32(1, 0, 0, 1),
  blue = reaper.ImGui_ColorConvertDouble4ToU32(0, 0.91, 1, 1),
  gray = reaper.ImGui_ColorConvertDouble4ToU32(0.75, 0.75, 0.75, 1),
}

-- variables for UCS data storage
-- TODO refactor in meaningful table

-- ucs data
-- 

local ucs = {
  categories = {},
  synonyms = {}
}

combo = {
  idx_cat = {},
  cat_idx = {},
  idx_sub = {},
  sub_idx = {},
  cat_items = "",
  sub_items = ""
}

form = {
  search = "",
  cat_id = "",
  cur_cat = 1,
  cur_sub = 1,
  cat_name = "",
  sub_name = "",
  fx_name = "",
  creator_id = "",
  source_id = "",
  user_cat = "",
  vendor_cat = "",
  user_data = "",
}

local ext_section = "tdspk_ucs"

data = {
  delimiter = "_",
  target = 0,
  target_self = "",
  selected_markers = {},
  selected_regions = {}
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

local prev_cat = ""
selected_cat = 1

local function ReadUcsData()
  local i = 1
  
  -- read UCS values from CSV to categories table
  for line in io.lines(ucs_file) do
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

function Init()
  font = reaper.ImGui_CreateFont("sans-serif", 15)
  reaper.ImGui_Attach(ctx, font)
  
  font_info = reaper.ImGui_CreateFont("sans-serif", 12)
  reaper.ImGui_Attach(ctx, font_info)
  
  reaper.ImGui_SetNextWindowSize(ctx, 500, 800)
  
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

local function ParseFilename(filename) 
  local cat_id, fx_name, creator_id, source_id = string.match(filename, "(.*)_(.*)_(.*)_(.*)")
  return cat_id, fx_name, creator_id, source_id
end

local function ReverseLookup(cat_id)
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

local function PopulateSubCategories(cat_name)
  if not ucs.categories[cat_name] then
    return
  end
  
  -- iterate categories table with the name and build data
  local result = ""
  
  sorted_keys = {}
  
  for k in pairs(ucs.categories[cat_name]) do
    table.insert(sorted_keys, k)
  end
  
  table.sort(sorted_keys)
  combo.sub_idx = {}
  combo.idx_sub = {}
  
  local i = 1
  
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
  arg = {...}
  
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
function GetMediaExplorerFiles(hWnd)
  local files = {}
  
  local file_LV = reaper.JS_Window_FindChildByID(hWnd, 0x3E9) 
  local sel_count, sel_indexes = reaper.JS_ListView_ListAllSelItems(file_LV)
  if sel_count == 0 then return end

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
  
  return files
end

local function Tooltip(ctx, text)
  reaper.ImGui_SameLine(ctx, 0, 10)
  reaper.ImGui_PushFont(ctx, font_info)
  reaper.ImGui_TextColored(ctx, color.gray, "?")
  reaper.ImGui_PopFont(ctx)
  
  if reaper.ImGui_IsItemHovered(ctx) then
    if reaper.ImGui_BeginTooltip(ctx) then
      reaper.ImGui_Text(ctx, text)
      reaper.ImGui_EndTooltip(ctx)
    end
  end
end

function Licensing()
  local width, height = reaper.ImGui_GetWindowSize(ctx)
  
  if reaper.GetExtState("tdspk_ucs", "license") ~= "1" then
    if reaper.ImGui_Button(ctx, "SUPPORT THIS TOOL", width, 30) then
      reaper.ImGui_OpenPopup(ctx, "Licensing")
    end
    
    local x, y = reaper.ImGui_Viewport_GetCenter(reaper.ImGui_GetMainViewport(ctx))
    reaper.ImGui_SetNextWindowPos(ctx, x, y, reaper.ImGui_Cond_Appearing(), 0.5, 0.5)
    
    if reaper.ImGui_BeginPopupModal(ctx, "Licensing", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
      reaper.ImGui_Text(ctx, "This tool is free and open source. And it will always be.")
      reaper.ImGui_Text(ctx, "I am against restrictive licensing.\nHowever, I appreciate your support.")
      reaper.ImGui_Text(ctx, "Purchasing a license will enable you to\nremove the 'SUPPORT THIS TOOL' button.")
      
      rv, buf = reaper.ImGui_InputText(ctx, "License Key", buf)
      
      if reaper.ImGui_Button(ctx, "Activate") then
          abc = reaper.ExecProcess(
                    "curl -s https://api.gumroad.com/v2/licenses/verify -d \"product_id=xj9IrqQHNS06kNyKPGMvBQ==\" -d \"license_key=" ..
                        buf .. "\"  -X POST", 0)
          success = string.match(abc, "\"success\":(.*),")
          if (success == "true") then end
      end
      
      reaper.ImGui_SameLine(ctx, 0, 10)
      
      if reaper.ImGui_Button(ctx, "Buy License") then
        reaper.CF_ShellExecute("https://www.tdspkaudio.com")
      end
      
      reaper.ImGui_SameLine(ctx, 0, 10)
      
      if reaper.ImGui_Button(ctx, "Close") then
        reaper.ImGui_CloseCurrentPopup(ctx)
      end
      reaper.ImGui_EndPopup(ctx)
    end
  else
    reaper.ImGui_PushFont(ctx, font_info)
  
    local email = reaper.GetExtState("tdspk_ucs", "email")
    reaper.ImGui_Text(ctx, "Supported by: " .. email)
    
    reaper.ImGui_PopFont(ctx)
  end
end

local function IsWindowOpen(name)
  local title = reaper.JS_Localize("Media Explorer", "common")
  local hWnd = reaper.JS_Window_Find(title, true)
  
  if hWnd then
    return true, hWnd
  else
    return false
  end
end

local function OperationMode() 
  if mx_open then
    reaper.ImGui_Text(ctx, "Operating on ")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextColored(ctx, color.red, "Media Explorer Files")
  else
    reaper.ImGui_Text(ctx, "Operating in ")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextColored(ctx, color.blue, "Arrange View")
    
    reaper.ImGui_Text(ctx, "Renaming: ")
    reaper.ImGui_SameLine(ctx)
    
    local has_changed = false
    rv, data.target = reaper.ImGui_RadioButtonEx(ctx, "Tracks", data.target, 0)
    has_changed = has_changed or rv
    reaper.ImGui_SameLine(ctx)
    rv, data.target = reaper.ImGui_RadioButtonEx(ctx, "Media Items", data.target, 1)
    has_changed = has_changed or rv
    reaper.ImGui_SameLine(ctx)
    rv, data.target = reaper.ImGui_RadioButtonEx(ctx, "Markers/Regions", data.target, 2)
    has_changed = has_changed or rv
    
    if has_changed then
      reaper.SetExtState(ext_section, "target", tostring(data.target), false)
    end
  end
end

local function CategoryFields()
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

  if cat_changed or combo.sub_items == "" then
    -- populate subcategories based on selected category
    form.cat_name = combo.idx_cat[form.cur_cat]
    combo.sub_items = PopulateSubCategories(form.cat_name)
    --form.cur_sub = 1
  end
  
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
  
  if cat_changed or sub_changed or form.cat_id == "" then
    form.sub_name = combo.idx_sub[form.cur_sub]
    form.cat_id = ucs.categories[form.cat_name][form.sub_name]
  end
end

local function CategorySearch()
  rv, form.search = reaper.ImGui_InputText(ctx, "Search category...", form.search)
  if rv then
    selected_cat = 1
  end
  if rv and not is_list_open then
    is_list_open = true
  elseif form.search == "" then
    is_list_open = false
  end
  
  if is_list_open then
    local syn_filter = reaper.ImGui_CreateTextFilter(form.search)
    
    -- Filter Synonys manually
    local syns = {}
    for i=1, #ucs.synonyms do
      local entry = ucs.synonyms[i]
      if reaper.ImGui_TextFilter_PassFilter(syn_filter, entry) then
        table.insert(syns, entry)
      end
    end
    
    select_next = -1
    
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_DownArrow(), false) then
      selected_cat = selected_cat + 1
      if selected_cat > #syns then selected_cat = 1 end
    elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_UpArrow(), false) then
      selected_cat = selected_cat - 1
      if selected_cat < 1 then selected_cat = #syns end
    elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter(), false) then
      select_next = selected_cat
    end
    
    if reaper.ImGui_BeginListBox(ctx, "Autosearch Categories") then 
      for i=1, #syns do
        local entry = syns[i]
        local id, syn = string.match(entry, "(.*);(.*)")
        
        selectable = reaper.ImGui_Selectable(ctx, id .. "\n" .. syn, selected_cat == i);reaper.ImGui_Separator(ctx)
        a_max = reaper.ImGui_GetScrollMaxY(ctx)
        if selected_cat == i then
          reaper.ImGui_SetScrollHereY(ctx, 1)
        end
        
        if selectable or select_next == i then
          form.cat_id = id
          form.search = ""
          is_list_open = false
          selected_cat = 1
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

local function Apply()
  return reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter(), false)
end

local function SubstituteIdx(index)
 -- check if $idx exists
  local idx = string.find(ucs_filename, "$idx")
  
  if idx then
    return string.gsub(ucs_filename, "$idx", tostring(index))
  end
  
  return ucs_filename .. " " .. tostring(index)
end

local function RenameTracks(track_count) 
  if track_count == 1 then
    local track = reaper.GetSelectedTrack(0, 0)
    local rv, track_name = reaper.GetTrackName(track)
    data.target_self = track_name
  else
    data.target_self = ""
  end
  
  if reaper.ImGui_Button(ctx, "Rename " .. track_count ..  " Track(s)", 0, 40) or Apply() then
    for i = 0, track_count - 1 do
      local track = reaper.GetSelectedTrack(0, i)
      
      local filename = ucs_filename
      if track_count > 1 then filename = SubstituteIdx(i + 1) end
      
      reaper.GetSetMediaTrackInfo_String(track, "P_NAME", filename, true)
    end
  end
end

local function RenameMediaItems(item_count)
  if item_count == 1 then
    local item = reaper.GetSelectedMediaItem(0, 0)
    local take = reaper.GetActiveTake(item)
    local take_name = reaper.GetTakeName(take)
    data.target_self = take_name
  else
    data.target_self = ""
  end
  
  if reaper.ImGui_Button(ctx, "Rename " .. item_count ..  " Item(s)", 0, 40) or Apply() then
    for i = 0, item_count - 1 do
      local item = reaper.GetSelectedMediaItem(0, i)
      local take = reaper.GetActiveTake(item)
      local take_name = reaper.GetTakeName(take)
      
      local filename = ucs_filename
      if item_count > 1 then filename = SubstituteIdx(i + 1) end
      
      reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", filename, true)
    end
  end
end

local function RenameMarkers(marker_count)
  if reaper.ImGui_Button(ctx, "Rename " .. marker_count .. " Markers(s)", 0, 40) or Apply() then
    for i, v in ipairs(data.selected_markers) do
      local idx = v[1]
      local pos = v[2]
      
      local filename = ucs_filename
      if #data.selected_markers > 1 then filename = SubstituteIdx(i + 1) end
      
      reaper.SetProjectMarker(idx, false, pos, pos, filename)
    end
  end
end

local function RenameRegions(region_count)
  if reaper.ImGui_Button(ctx, "Rename " .. region_count .. " Regions(s)", 0, 40) or Apply() then
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

local function RenameFiles()
  autoplay = reaper.GetToggleCommandStateEx(32063, 1011) --Autoplay: Toggle on/off
  if autoplay == 1 then
    reaper.ImGui_TextColored(ctx, color.red, "Autoplay is enabled! Please ")
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_SmallButton(ctx, "DISABLE") then
      reaper.JS_Window_OnCommand(hWnd, 40036)
    end
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextColored(ctx, color.red, " it to avoid weird behaviour.")
  end
  
  if files then
    if reaper.ImGui_Button(ctx, "Rename " .. #files .. " File(s)", 0, 40) then
      local dir = files[0]
      
      reaper.JS_Window_OnCommand(hWnd, 1009) -- Preview: Stop
      reaper.JS_Window_OnCommand(hWnd, 1009) -- Preview: Stop
      
      for i, v in ipairs(files) do
        local old_file = dir .. "/" .. v
        local _, _, ext = string.match(v, "(.-)([^\\/]-%.?([^%.\\/]*))$")
        
        local filename = string.gsub(ucs_filename, "$idx", tostring(i))
        local new_file = dir .. "/" .. filename .. "." .. ext
        rv, osbuf = os.rename(old_file, new_file)
      end
    end
  end
end

local function CountTargets()
  if data.target == 0 then
    return reaper.CountSelectedTracks(0)
  elseif data.target == 1 then
    return reaper.CountSelectedMediaItems(0)
  elseif data.target == 2 then
    data.selected_markers = {}
    data.selected_regions = {}
  
    local title = reaper.JS_Localize("Region/Marker Manager", "common")
    local hWnd = reaper.JS_Window_Find(title, true)
    
    if hWnd then -- if Region/Marker Manager is open, count there
      local manager = reaper.JS_Window_FindChildByID(hWnd, 0x42F)
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
              return 1, 0, 1 -- return 1 counted, 0 markers, 1 region
            else
              local mrk = { [1] = idx, [2] = pos, [3] = name }
              table.insert(data.selected_markers, mrk)
              return 1, 1, 0 -- return 1 counter, 1 marker, 0 regions
            end
          end
        end
      end
    end
  end
  
  return 0
end

local function RenderWindow()
  reaper.ImGui_PushFont(ctx, font)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 1, 10)
  
  --Licensing()
  
  reaper.ImGui_SeparatorText(ctx, "Mandatory Fields")
  
  CategorySearch()
  CategoryFields()
  
  reaper.ImGui_Separator(ctx)
  
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), 
  reaper.ImGui_ColorConvertDouble4ToU32(0.2, 0.2, 0.2, 1))
  
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
  
  if reaper.ImGui_Button(ctx, "Save Data") then
    local data = form.fx_name .. ";" .. form.creator_id .. ";" .. form.source_id
    reaper.SetExtState("tdspk_ucs", "data", data, false)
  end
  
  reaper.ImGui_SameLine(ctx, 0, 10)
  
  if reaper.ImGui_Button(ctx, "Load Data") then
    local data = reaper.GetExtState("tdspk_ucs", "data")
    form.fx_name, form.creator_id, form.source_id = string.match(data, "(.*);(.*);(.*)")
  end
  
  reaper.ImGui_SeparatorText(ctx, "Optional")
  
  rv, form.user_cat = reaper.ImGui_InputText(ctx, "UserCategory", form.user_cat)
  Tooltip(ctx, "An optional tail extension of the CatID block that can be used\nas a user defined category, microphone, perspective, etc.")
  
  rv, form.vendor_cat = reaper.ImGui_InputText(ctx, "VendorCategory", form.vendor_cat)
  Tooltip(ctx, "An option head extension to the FXName Block usable by vendors to\ndefine a library specific category. For example, the specific name\nof a gun, vehicle, location, etc.")
  
  rv, form.user_data = reaper.ImGui_InputText(ctx, "UserData", form.user_data)
  Tooltip(ctx, "A user defined space, ofter used for an ID or Number for guaranteeing that the Filename is 100% unique...")
  
  reaper.ImGui_SeparatorText(ctx, "Results")
  
  -- pre-calculate file names
  -- check selected tracks, items, regions for wildcard
  -- pre cache new filename(s)
  
  if mx_open then
    files = GetMediaExplorerFiles(hWnd)
    if files then
      reaper.ImGui_LabelText(ctx, "Directory", files[0])
    end
  end
  
  ucs_filename = CreateUCSFilename(data.delimiter, form.cat_id, form.user_cat, form.vendor_cat, form.fx_name, form.creator_id, form.source_id, form.user_data)
  
  local rename_count, marker_count, region_count = CountTargets()
  
  if rename_count <= 1 then
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
    
    for i=1, rename_count do
      local fname = string.gsub(format, "$idx", tostring(i))
      filenames = filenames .. fname
    end
    
    reaper.ImGui_Combo(ctx, "Filenames", 0, filenames)
  end
  
  reaper.ImGui_Separator(ctx)
  
  mx_open, hWnd = IsWindowOpen("Media Explorer")
  OperationMode()
  
  if mx_open then
    RenameFiles()
  else
    if data.target == 0 then
      RenameTracks(rename_count)
    elseif data.target == 1 then
      RenameMediaItems(rename_count)
    elseif data.target == 2 then
      -- Render Buttons for Marker/Region Manager and Navigation <>, Arrows
      if reaper.ImGui_ArrowButton(ctx, "Previous Marker", reaper.ImGui_Dir_Left()) 
        or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_LeftArrow(), false) then
        reaper.Main_OnCommand(40172, 0) -- Markers: Go to previous marker/project start
      end
      
      reaper.ImGui_SameLine(ctx, 0, 10)
      
      if reaper.ImGui_ArrowButton(ctx, "Next Marker", reaper.ImGui_Dir_Right())
        or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_RightArrow(), false) then
        reaper.Main_OnCommand(40173, 0) -- Markers: Go to next marker/project end
      end
    
      RenameMarkers(#data.selected_markers)
      reaper.ImGui_SameLine(ctx, 0, 10)
      RenameRegions(#data.selected_regions)
    end
  end
    
  if reaper.ImGui_Button(ctx, "Clear all data", 0, 40) and track then
    form.fx_name, form.creator_id, form.source_id, form.user_cat, form.vendor_cat, form.user_data = ""
  end
  
  reaper.ImGui_PushFont(ctx, font_info)
  reaper.ImGui_Text(ctx, "tdspkaudio.com")
  reaper.ImGui_PopFont(ctx)
  
  reaper.ImGui_PopStyleVar(ctx)
  reaper.ImGui_PopFont(ctx)
end

local function Loop()
  local visible, open = reaper.ImGui_Begin(ctx, 'tdspk - UCS Toolkit', true)
  if visible then
    RenderWindow()
    reaper.ImGui_End(ctx)
  end
  if open then
    reaper.defer(Loop)
  end
end

ctx = reaper.ImGui_CreateContext("tdspk UCS Tookit")
Init()
Loop()
