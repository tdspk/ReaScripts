dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]
--ucs_file = script_path .. "../data/UCS.csv"

ctx = reaper.ImGui_CreateContext("tdspk UCS Tookit")
local font = reaper.ImGui_CreateFont("sans-serif", 15)
reaper.ImGui_Attach(ctx, font)

local font_info = reaper.ImGui_CreateFont("sans-serif", 12)
reaper.ImGui_Attach(ctx, font_info)

target = 0 -- 0 Tracks, 1 Items, 2 Regions

windows = {}

colors = {
  red = reaper.ImGui_ColorConvertDouble4ToU32(1, 0, 0, 1),
  blue = reaper.ImGui_ColorConvertDouble4ToU32(0, 0.91, 1, 1)
}

local categories = {}
local synonyms = {}

local idx_cat = {}
local cat_idx = {}

local idx_sub = {}
local sub_idx = {}

cat_items = ""
sub_items = ""
cat_id = ""
delimiter = "_"

local cur_cat = 1
local cur_sub = 1

wildcards = {
  ["$project"] = reaper.GetProjectName(0),
  ["$author"] = select(2, reaper.GetSetProjectInfo_String(0, "PROJECT_AUTHOR", "", false))
}

filter_cat = reaper.ImGui_CreateTextFilter()
reaper.ImGui_Attach(ctx, filter_cat)
filter_sub = reaper.ImGui_CreateTextFilter()
reaper.ImGui_Attach(ctx, filter_sub)

local i = 1
local prev_cat = ""
selected_cat = 1

-- read UCS values from CSV to categories table
for line in io.lines(ucs_file) do
  local cat, subcat, id, syn = string.match(line, "(.*);(.*);(.*);(.*)")
  if cat ~= prev_cat then
    cat_items = cat_items .. cat .. "\0"
    idx_cat[i] = cat
    cat_idx[cat] = i
    i = i + 1
  end
  prev_cat = cat
  
  if not categories[cat] then
    categories[cat] = {}
  end
  
  categories[cat][subcat] = id
  table.insert(synonyms, id .. ";" .. syn)
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
  for k, v in pairs(categories) do
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
  if not categories[cat_name] then
    return
  end
  
  -- iterate categories table with the name and build data
  local result = ""
  
  sorted_keys = {}
  
  for k in pairs(categories[cat_name]) do
    table.insert(sorted_keys, k)
  end
  
  table.sort(sorted_keys)
  sub_idx = {}
  
  local i = 1
  
  for k, v in pairs(sorted_keys) do
    result = result .. v .. "\0"
    idx_sub[i] = v
    sub_idx[v] = i
    i = i + 1
  end
  
  return result
end

local function CreateUCSFilename(d, cat_id, ...)
  fname = cat_id
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
    reaper.ImGui_TextColored(ctx, colors.red, "Media Explorer Files")
  else
    reaper.ImGui_Text(ctx, "Operating in ")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextColored(ctx, colors.blue, "Arrange View")
    
    --[[
    reaper.ImGui_Text(ctx, "Renaming: ")
    reaper.ImGui_SameLine(ctx)
    rv, target = reaper.ImGui_RadioButtonEx(ctx, "Tracks", target, 0)
    reaper.ImGui_SameLine(ctx)
    rv, target = reaper.ImGui_RadioButtonEx(ctx, "Media Items", target, 1)
    reaper.ImGui_SameLine(ctx)
    rv, target = reaper.ImGui_RadioButtonEx(ctx, "Regions", target, 2)
    ]]--
  end
end

local function CategoryFields()
  if reaper.ImGui_BeginCombo(ctx, "Category", idx_cat[cur_cat]) then
    reaper.ImGui_TextFilter_Draw(filter_cat, ctx, "Filter")
    
    for i, v in ipairs(idx_cat) do
      if reaper.ImGui_TextFilter_PassFilter(filter_cat, v) then
        if reaper.ImGui_Selectable(ctx, v) then 
          cat_changed = true
          cur_cat = i
        end
      end
    end
    
    reaper.ImGui_EndCombo(ctx)
  end

  if cat_changed or sub_items == "" then
    -- populate subcategories based on selected category
    cat_name = idx_cat[cur_cat]
    sub_items = PopulateSubCategories(cat_name)
    --cur_sub = 1
  end
  
  if reaper.ImGui_BeginCombo(ctx, "Subcategory", idx_sub[cur_sub]) then
    --reaper.ImGui_SetKeyboardFocusHere(ctx)
    reaper.ImGui_TextFilter_Draw(filter_sub, ctx, "Filter")
    
    for i, v in ipairs(idx_sub) do
      if reaper.ImGui_TextFilter_PassFilter(filter_sub, v) then
        if reaper.ImGui_Selectable(ctx, v) then
          sub_changed = true
          cur_sub = i
        end
      end
    end
    
    reaper.ImGui_EndCombo(ctx)
  end
  
  if cat_changed or sub_changed or cat_id == "" then
    sub_name = idx_sub[cur_sub]
    cat_id = categories[cat_name][sub_name]
  end
end

local function CategorySearch()
  rv, search = reaper.ImGui_InputText(ctx, "Search category...", search)
  if rv then
    selected_cat = 1
  end
  if rv and not is_list_open then
    is_list_open = true
  elseif search == "" then
    is_list_open = false
  end
  
  if is_list_open then
    local syn_filter = reaper.ImGui_CreateTextFilter(search)
    
    -- Filter Synonys manually
    local syns = {}
    for i=1, #synonyms do
      local entry = synonyms[i]
      if reaper.ImGui_TextFilter_PassFilter(syn_filter, entry) then
        table.insert(syns, entry)
      end
    end
    
    select_next = -1
    
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_DownArrow(), false) then
      selected_cat = selected_cat + 1
    elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_UpArrow(), false) then
      selected_cat = selected_cat - 1
    elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter(), false) then
      select_next = selected_cat
    end
    
    if reaper.ImGui_BeginListBox(ctx, "Autosearch Categories") then 
      for i=1, #syns do
        local entry = syns[i]
        local id, syn = string.match(entry, "(.*);(.*)")
        
        selectable = reaper.ImGui_Selectable(ctx, id .. "\n" .. syn, selected_cat == i);reaper.ImGui_Separator(ctx)
        if selectable or select_next == i then
          cat_id = id
          search = ""
          is_list_open = false
          selected_cat = 1
        end
      end
    
      reaper.ImGui_EndListBox(ctx)
    end
    
    -- update categories if Category ID changed manually
    local rv, cname, sname = ReverseLookup(cat_id)
    
    if rv then
      cat_name = cname
      sub_name = sname
      sub_items = PopulateSubCategories(cat_name)
      cur_cat = cat_idx[cat_name]
      cur_sub = sub_idx[sub_name]
    end
  end
end

local function Rename()
  if mx_open then
    autoplay = reaper.GetToggleCommandStateEx(32063, 1011) --Autoplay: Toggle on/off
    if autoplay == 1 then
      reaper.ImGui_TextColored(ctx, colors.red, "Autoplay is enabled! Please ")
      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_SmallButton(ctx, "DISABLE") then
        reaper.JS_Window_OnCommand(hWnd, 40036)
      end
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_TextColored(ctx, colors.red, " it to avoid weird behaviour.")
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
  else
    track_count = reaper.CountSelectedTracks(0)
    
    if reaper.ImGui_Button(ctx, "Rename " .. track_count ..  " Track(s)", 0, 40) and track then
      for i = 0, track_count - 1 do
        track = reaper.GetSelectedTrack(0, i)
        local filename = string.gsub(ucs_filename, "$idx", tostring(i))
        reaper.GetSetMediaTrackInfo_String(track, "P_NAME", filename, true)
      end
    end
    
    reaper.ImGui_SameLine(ctx, 0, 10)
    
    item_count = reaper.CountSelectedMediaItems(0)
    if reaper.ImGui_Button(ctx, "Rename " .. item_count ..  " Item(s)", 0, 40) then
      for i = 0, item_count - 1 do
        item = reaper.GetSelectedMediaItem(0, i)
        take = reaper.GetActiveTake(item)
        local filename = string.gsub(ucs_filename, "$idx", tostring(i))
        reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", filename, true)
      end
    end
    
    reaper.ImGui_SameLine(ctx, 0, 10)
    
    -- find out if region/marker manager is open
    local title = reaper.JS_Localize("Region/Marker Manager", "common")
    local hWnd = reaper.JS_Window_Find(title, true)
    
    if hWnd then
      local manager = reaper.JS_Window_FindChildByID(hWnd, 0x42F)
      sel_count, sel_indexes = reaper.JS_ListView_ListAllSelItems(manager)
      
      sel_regions = string.split(sel_indexes, ",")
      
      if reaper.ImGui_Button(ctx, "Rename " .. #sel_regions .. " Region(s)", 0, 40) then
        -- get region IDs from selection, cache in table
        regions = {}
        for i, v in ipairs(sel_regions) do
          local r_id = reaper.JS_ListView_GetItemText(manager, tonumber(v), 1)
          r_id = string.gsub(r_id, "R", "")
          table.insert(regions, tonumber(r_id))
        end
      
        local rv, _, region_count = reaper.CountProjectMarkers(0)
        
        for i, v in ipairs(regions) do
          for i=0, region_count - 1 do
            local rv, isrgn, pos, rgn_end, _, idx = reaper.EnumProjectMarkers(i)
            if idx == v then
              local filename = string.gsub(ucs_filename, "$idx", tostring(i))
              reaper.SetProjectMarker2(0, idx, true, pos, rgn_end, filename)
              break;
            end
          end
        end
      end
    else
      -- rename regions in time selection
      local loop_start, loop_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 10, false)
      local rv, _, region_count = reaper.CountProjectMarkers(0)
      
      local regions = {}
      
      for i=0, region_count - 1 do
        local rv, isrgn, pos, rgn_end, _, idx = reaper.EnumProjectMarkers(i)
        if isrgn then
          if pos >= loop_start and rgn_end <= loop_end then
            local rgn = { [1] = idx, [2] = pos, [3] = rgn_end }
            table.insert(regions, rgn)
          end
        end
      end
      
      if reaper.ImGui_Button(ctx, "Rename " .. #regions .. " Region(s)", 0, 40) then
        for i, v in ipairs(regions) do
          local filename = string.gsub(ucs_filename, "$idx", tostring(i))
          reaper.SetProjectMarker2(0, v[1], true, v[2], v[3], filename)
        end
      end
    end
    
  end
end

local function RenderWindow()
  reaper.ImGui_PushFont(ctx, font)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 1, 10)
  
  --Licensing()
  mx_open, hWnd = IsWindowOpen("Media Explorer")
  OperationMode()
  
  reaper.ImGui_SeparatorText(ctx, "Mandatory Fields")
  
  CategoryFields()
  
  CategorySearch()
  
  reaper.ImGui_Separator(ctx)
  
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), 
  reaper.ImGui_ColorConvertDouble4ToU32(0.2, 0.2, 0.2, 1))
  
  id_changed, cat_id = reaper.ImGui_InputText(ctx, "CatID", cat_id)
  
  if id_changed and cat_id ~= "" then
    -- update categories if Category ID changed manually
    local rv, cname, sname = ReverseLookup(cat_id)
    
    if rv then
      cat_name = cname
      sub_name = sname
      sub_items = PopulateSubCategories(cat_name)
      cur_cat = cat_idx[cat_name]
      cur_sub = sub_idx[sub_name]
    end
  end
  
  rv, fx_name = reaper.ImGui_InputText(ctx, "FXName", fx_name)
  rv, creator_id = reaper.ImGui_InputText(ctx, "CreatorID", creator_id)
  rv, source_id = reaper.ImGui_InputText(ctx, "SourceID", source_id)
  
  reaper.ImGui_PopStyleColor(ctx)
  
  -- Fill from Track feature
  
  track = reaper.GetSelectedTrack(0, 0)
  
  if track then
    reaper.ImGui_BeginDisabled(ctx, false)
  else
    reaper.ImGui_BeginDisabled(ctx, true)
  end
  
  if reaper.ImGui_Button(ctx, "Fill from Track") then
    local rv, track_name = reaper.GetTrackName(track)
    cat_id, fx_name, creator_id, source_id = ParseFilename(track_name)
    
    -- update categories if Category ID changed manually
    local rv, cname, sname = ReverseLookup(cat_id)
    
    if rv then
      cat_name = cname
      sub_name = sname
      sub_items = PopulateSubCategories(cat_name)
      cur_cat = cat_idx[cat_name]
      cur_sub = sub_idx[sub_name]
    end
  end
  reaper.ImGui_EndDisabled(ctx)
  
  reaper.ImGui_SameLine(ctx, 0, 10)
  
  if reaper.ImGui_Button(ctx, "Save Data") then
    local data = fx_name .. ";" .. creator_id .. ";" .. source_id
    reaper.SetExtState("tdspk_ucs", "data", data, false)
  end
  
  Tooltip(ctx, "Saves FXName, CreatorID and SourceID")
  
  reaper.ImGui_SameLine(ctx, 0, 10)
  
  if reaper.ImGui_Button(ctx, "Load Data") then
    local data = reaper.GetExtState("tdspk_ucs", "data")
    fx_name, creator_id, source_id = string.match(data, "(.*);(.*);(.*)")
  end
  
  Tooltip(ctx, "Loads FXName, CreatorID and SourceID")
  
  reaper.ImGui_SeparatorText(ctx, "Optional")
  
  rv, user_cat = reaper.ImGui_InputText(ctx, "UserCategory", user_cat)
  rv, vendor_cat = reaper.ImGui_InputText(ctx, "VendorCategory", vendor_cat)
  rv, user_data = reaper.ImGui_InputText(ctx, "UserData", user_data)
  
  reaper.ImGui_SeparatorText(ctx, "Results")
  
  rv, delimiter = reaper.ImGui_InputText(ctx, "Delimiter", delimiter)
  
  if mx_open then
    files = GetMediaExplorerFiles(hWnd)
    if files then
      reaper.ImGui_LabelText(ctx, "Directory", files[0])
    end
  end
  
  ucs_filename = CreateUCSFilename(delimiter, cat_id, user_cat, vendor_cat, fx_name, creator_id, source_id, user_data)
  
  reaper.ImGui_LabelText(ctx, "Filename", ucs_filename)
  
  Rename()
  
  if reaper.ImGui_Button(ctx, "Clear all data", 0, 40) and track then
    fx_name, creator_id, source_id, user_cat, vendor_cat, user_data = ""
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

reaper.ImGui_SetNextWindowSize(ctx, 500, 800)

Loop()
