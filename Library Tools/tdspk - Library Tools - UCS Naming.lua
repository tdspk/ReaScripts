dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]
ucs_file = script_path .. "UCS.csv"

local ctx = reaper.ImGui_CreateContext("USC Naming")
local font = reaper.ImGui_CreateFont("sans-serif", 16)
reaper.ImGui_Attach(ctx, font)

local categories = {}

local idx_cat = {}
local cat_idx = {}

local idx_sub = {}
local sub_idx = {}

cat_items = ""
sub_items = ""
cat_id = ""
delimiter = "_"

wildcards = {
  ["$project"] = reaper.GetProjectName(0),
  ["$author"] = select(2, reaper.GetSetProjectInfo_String(0, "PROJECT_AUTHOR", "", false))
}

local i = 0
local prev_cat = ""

-- read UCS values from CSV to categories table
for line in io.lines(ucs_file) do
  cat, subcat, id = string.match(line, "(.*),(.*),(.*)")
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
  local i = 0
  
  sorted_keys = {}
  
  for k in pairs(categories[cat_name]) do
    table.insert(sorted_keys, k)
  end
  
  table.sort(sorted_keys)
  sub_idx = {}
  
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

function GetMediaExplorerFiles(hWnd)
  local files = {}
  
  reaper.JS_Window_OnCommand(hWnd, 1009) -- Preview: Stop
  reaper.JS_Window_OnCommand(hWnd, 1009) -- Preview: Stop
  
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

local function RenderWindow()
  reaper.ImGui_PushFont(ctx, font)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 1, 10)
  
  -- Check if MX is open
  local title = reaper.JS_Localize("Media Explorer", "common")
  local hWnd = reaper.JS_Window_Find(title, true)
  
  if hWnd then
    mx_open = true
  else
    mx_open = false
  end
  
  if mx_open then
    reaper.ImGui_Text(ctx, "Operating on Media Explorer files")
  else
    reaper.ImGui_Text(ctx, "Operating on Tracks and Items")
  end
  
  if reaper.ImGui_Button(ctx, "Save Data") then
    local data = fx_name .. ";" .. creator_id .. ";" .. source_id
    reaper.SetExtState("tdspk_ucs", "data", data, false)
  end
  
  reaper.ImGui_SameLine(ctx, 0, 10)
  
  if reaper.ImGui_Button(ctx, "Load Data") then
    local data = reaper.GetExtState("tdspk_ucs", "data")
    fx_name, creator_id, source_id = string.match(data, "(.*);(.*);(.*)")
  end
  
  
  reaper.ImGui_SeparatorText(ctx, "Mandatory Fields")

  cat_changed, cur_cat = reaper.ImGui_Combo(ctx, "Category", cur_cat, cat_items)
  
  if cat_changed or sub_items == "" then
    -- populate subcategories based on selected category
    cat_name = idx_cat[cur_cat]
    sub_items = PopulateSubCategories(cat_name)
    cur_sub = 0
  end
  
  sub_changed, cur_sub = reaper.ImGui_Combo(ctx, "Subcategory", cur_sub, sub_items)
  
  if cat_changed or sub_changed or cat_id == "" then
    sub_name = idx_sub[cur_sub]
    cat_id = categories[cat_name][sub_name]
  end
  
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
  
  if mx_open then
    if files then
      if reaper.ImGui_Button(ctx, "Rename " .. #files .. " File(s)", 0, 40) then
        local dir = files[0]
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
  end
  
  reaper.ImGui_SameLine(ctx, 0, 10)
  
  if reaper.ImGui_Button(ctx, "Clear all data", 0, 40) and track then
    fx_name, creator_id, source_id, user_cat, vendor_cat, user_data = ""
  end
  
  reaper.ImGui_PopStyleVar(ctx)
  reaper.ImGui_PopFont(ctx)
end

local function Loop()
  reaper.ImGui_SetNextWindowSize(ctx, 500, 800)
  local visible, open = reaper.ImGui_Begin(ctx, 'USC Naming', true)
  if visible then
    RenderWindow()
    reaper.ImGui_End(ctx)
  end
  if open then
    reaper.defer(Loop)
  end
end

Loop()
