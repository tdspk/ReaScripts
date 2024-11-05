local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]
json = dofile(script_path .. "/json/json.lua") -- import json library

local version = reaper.GetAppVersion()
version = tonumber(version:match("%d.%d"))

if version >= 7.0 then
  reaper.set_action_options(3) -- Terminate and restart the script if it's already running
end

local ctx = reaper.ImGui_CreateContext("Render Chunks")

chunks = {}
selected_chunk = 1

-- chunk format: name, item guids, items (only in runtime - loaded on demand)

local function SaveChunks()
  -- copy chunks to table and remove items
  local t = {}
  for i = 1, #chunks do
    local chunk = chunks[i]
    chunk.items = nil
    t[i] = chunk
  end

  reaper.SetProjExtState(0, "tdspk_renderchunks", "chunks", json.encode(t))
end

local function LoadChunks()
  local rv, chunk_str = reaper.GetProjExtState(0, "tdspk_renderchunks", "chunks")
  if chunk_str == "" then return end
  chunks = json.decode(chunk_str)

  -- add items to chunks
  for i = 1, #chunks do
    local chunk = chunks[i]
    chunk.items = {}
    for j = 1, #chunk.item_guids do
      local item = reaper.BR_GetMediaItemByGUID(0, chunk.item_guids[j])
      if item then
        table.insert(chunk.items, item)
      end
    end
  end
end

local function SelectChunkItems(chunk)
  for _, item in pairs(chunk.items) do
    reaper.SetMediaItemSelected(item, true)
  end
  reaper.UpdateArrange()
end

local function Loop()
  reaper.ImGui_SetNextWindowSize(ctx, 300, 100, reaper.ImGui_Cond_Once())
  local visible, open = reaper.ImGui_Begin(ctx, "Render Chunks", true)
  if visible then
    -- create list view for chunks
    for i = 1, #chunks do
      if reaper.ImGui_Selectable(ctx, ("%s##%d"):format(chunks[i].name, i), false) then
        local chunk = chunks[i]
        selected_chunk = i

        reaper.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
        SelectChunkItems(chunk)
        reaper.Main_OnCommand(42409, 0) -- Razor edit: Enclose media items, including space between items
        SelectChunkItems(chunk)
      end
    end

    if reaper.ImGui_Button(ctx, "Add Chunk") then
      local item_guids = {}
      local items = {}

      for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        table.insert(items, item)
        local rv, guid = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)
        table.insert(item_guids, guid)
      end

      table.insert(chunks, { name = ("New Chunk %d"):format(#chunks + 1), item_guids = item_guids, items = items })
    end

    local btn_pressed = false

    if reaper.ImGui_Button(ctx, "Render Chunk") then
      -- reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", 2048*2, true)
      reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", 0, true)
      reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 2, true)

      -- select chunk media items
      SelectChunkItems(chunks[selected_chunk])
      reaper.Main_OnCommand(40290, 0)

      reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_SELTRKWITEM"), 0)
      reaper.Main_OnCommand(40728, 0) -- Track: Solo tracks
      
      reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", chunks[selected_chunk].name, true)

      reaper.Main_OnCommand(41823, 0) -- File: Add project to render queue, using the most recent render settings

      reaper.Main_OnCommand(40729, 0) -- Track: Unsolo tracks

      -- btn_pressed = true
    end

    if reaper.ImGui_Button(ctx, "Render Items") then
      reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", 32, true)
      reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", chunks[selected_chunk].name, true)
      -- btn_pressed = true
    end

    if btn_pressed then
      reaper.Main_OnCommand(41824, 0) -- File: Render project, using the most recent render settings
    end

    reaper.ImGui_End(ctx)
  end
  if open then
    reaper.defer(Loop)
  else
    SaveChunks()
  end
end

LoadChunks()
Loop()
