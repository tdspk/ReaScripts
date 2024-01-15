-- @description Enclose Track Items with Razor Edit Area
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @changelog
--   First version

local track_count = reaper.CountSelectedTracks(0)

for i=0, track_count-1 do
  local track = reaper.GetSelectedTrack(0, i)
  local item_count = reaper.GetTrackNumMediaItems(track)
  
  local first_item = reaper.GetTrackMediaItem(track, 0)
  local last_item = reaper.GetTrackMediaItem(track, item_count - 1)
  
  local start_pos = reaper.GetMediaItemInfo_Value(first_item, "D_POSITION")
  local end_pos = reaper.GetMediaItemInfo_Value(last_item, "D_POSITION") + reaper.GetMediaItemInfo_Value(last_item, "D_LENGTH")
  
  area = string.format("%f %f", start_pos, end_pos)
  
  rv, buf = reaper.GetSetMediaTrackInfo_String(track, "P_RAZOREDITS", area, true)
end
