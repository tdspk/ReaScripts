item_count = reaper.CountSelectedMediaItems(0)

items = {}
-- iterate all selected items and save them into a table
for i=0, item_count - 1 do
  item = reaper.GetSelectedMediaItem(0, i)
  table.insert(items, item)
end

-- Unselect all media items
for k, item in pairs(items) do
  reaper.SetMediaItemSelected(item, false)
end

for k, item in pairs(items) do
  -- set items selected, item by item
  reaper.SetMediaItemSelected(item, true)
  
  take = reaper.GetTake(item, 0)
  
  item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  item_length =  reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  take_rate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
  
  -- Delete all existing take markers
  marker_count = reaper.GetNumTakeMarkers(take)
  for k=0, marker_count - 1 do
    --reaper.Main_OnCommand(42387, 0) -- Item: Delete all take markers
    reaper.DeleteTakeMarker(take, k)
  end
  
  -- set the edit cursor position to the start of the item
  reaper.SetEditCurPos(item_start, false, false)
  
  -- iterate transients until end is reached
  index = 0
  while reaper.GetCursorPosition() < item_start + item_length do
    reaper.Main_OnCommand(40375, 0) -- Item navigation: Move cursor to next transient in items
    cur_pos = reaper.GetCursorPosition()
    
    if prev_pos == cur_pos then
      break
    end
    
    if index == 0 then
      reaper.Main_OnCommand(40541, 0) -- Item: Set snap offset to cursor
    end
    
    reaper.SetTakeMarker(take, index, tostring(index + 1), (cur_pos - item_start) * take_rate)
    
    index = index + 1
    prev_pos = cur_pos
  end
  
  -- unselect media item to avoid cursor transient confusion
  reaper.SetMediaItemSelected(item, false)
end
