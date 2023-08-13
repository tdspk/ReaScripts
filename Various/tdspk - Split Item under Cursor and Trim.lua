-- @description Splits and trims the shorter side of an item.
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @changelog
--   First version

reaper.Main_OnCommandEx(40747, 0);

-- Get selected item
left_item = reaper.GetSelectedMediaItem(0, 0);

if left_item == nil then
  return
end

left_length = reaper.GetMediaItemInfo_Value(left_item, "D_LENGTH");

-- get the track for the media item
track = reaper.GetMediaItemTrack(left_item);

-- Select next adjacent item and store it
reaper.Main_OnCommandEx(41127, 0);
right_item = reaper.GetSelectedMediaItem(0, 0);
right_length = reaper.GetMediaItemInfo_Value(right_item, "D_LENGTH");

-- compare item lengths and delete the shorter item
if (left_length < right_length)
then
  reaper.DeleteTrackMediaItem(track, left_item);
else
  reaper.DeleteTrackMediaItem(track, right_item);
end

reaper.Main_OnCommand(40289, 0);
