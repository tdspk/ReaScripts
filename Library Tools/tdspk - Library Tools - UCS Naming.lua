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
  cat_id, fx_name, creator_id, source_id = string.match(filename, "(.*)_(.*)_(.*)_(.*)")
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
      fname = fname .. d .. v
    end
  end
  
  return fname
end

local function RenderWindow()
  reaper.ImGui_PushFont(ctx, font)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 1, 10)

  track = reaper.GetSelectedTrack(0, 0)

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
  
  if track then
    --rv, fx_name = reaper.GetTrackName(track)
  end
  
  rv, fx_name = reaper.ImGui_InputText(ctx, "FXName", fx_name)
  -- creator
  rv, creator_id = reaper.ImGui_InputText(ctx, "CreatorID", creator_id)
  -- source
  rv, source_id = reaper.ImGui_InputText(ctx, "SourceID", source_id)
  
  ucs_filename = CreateUCSFilename("_", cat_id, fx_name, creator_id, source_id)
  rv, ucs_filename = reaper.ImGui_InputText(ctx, "Filename", ucs_filename)
  
  if reaper.ImGui_Button(ctx, "Apply to Track") and track then
    reaper.GetSetMediaTrackInfo_String(track, "P_NAME", ucs_filename, true)
  end
  
  reaper.ImGui_PopStyleVar(ctx)
  reaper.ImGui_PopFont(ctx)
end

local function Loop()
  reaper.ImGui_SetNextWindowSize(ctx, 500, 300)
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
