-- @description Align item positions to project markers
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @noindex
-- @changelog
--   First version

item_count = reaper.CountSelectedMediaItems(0)
marker_count = reaper.CountProjectMarkers(0)

if item_count > 0 and marker_count > 0 then
  -- first, go to the previous marker / project start, and then start from the next marker
  reaper.Main_OnCommand(40172, 0) -- Markers: Go to previous marker/project start
  
  if item_count > marker_count then
    iterations = marker_count
  elseif item_count < marker_count then
    iterations = item_count
  else
    iterations = item_count
  end
  
  -- iterate the selected items array and move each item sequentially to the markers
  for i=0, iterations-1 do
    reaper.Main_OnCommand(40173, 0) -- Markers: Go to next marker/project end
    item = reaper.GetSelectedMediaItem(0, i)
    
    cur_pos = reaper.GetCursorPosition()
    offset = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", cur_pos - offset)
  end
end
