-- @description Split Item under cursor and trim shorter side
-- @version 1.0.1
-- @author Tadej Supukovic (tdspk)
-- @changelog
--   First version

reaper.Main_OnCommandEx(40747, 0) -- Item: Split item under mouse cursor (select left, ignore grouping)

-- Get selected item
left_item = reaper.GetSelectedMediaItem(0, 0)

if left_item then
  left_length = reaper.GetMediaItemInfo_Value(left_item, "D_LENGTH")
  
  -- get the track for the media item
  track = reaper.GetMediaItemTrack(left_item)
  
  -- Select next adjacent item and store it
  reaper.Main_OnCommandEx(41127, 0)
  right_item = reaper.GetSelectedMediaItem(0, 0)
  right_length = reaper.GetMediaItemInfo_Value(right_item, "D_LENGTH")
  
  -- compare item lengths and delete the shorter item
  if (left_length < right_length)
  then
    reaper.DeleteTrackMediaItem(track, left_item)
  else
    reaper.DeleteTrackMediaItem(track, right_item)
  end
  
  reaper.UpdateArrange()
  
  reaper.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
end
