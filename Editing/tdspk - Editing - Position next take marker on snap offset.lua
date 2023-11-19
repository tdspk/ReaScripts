item_count = reaper.CountSelectedMediaItems(0)

for i=0, item_count - 1 do
  item = reaper.GetSelectedMediaItem(0, i)
  take = reaper.GetTake(item, 0)
  
  marker_count = reaper.GetNumTakeMarkers(take)
  
  if marker_count > 0 then
    snap_offset = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
    take_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    take_rate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    
    item_data = tostring(item)
    key = "cur_marker_" .. item_data
    if reaper.HasExtState("tdspk_test", key) then
      cur_marker = tonumber(reaper.GetExtState("tdspk_test", key))
    else
      cur_marker = 0
    end
    
    rv, name = reaper.GetTakeMarker(take, cur_marker)
    position = (rv - snap_offset * take_rate)
    reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", position)
    
    cur_marker = cur_marker + 1
    if cur_marker >= marker_count then
      cur_marker = 0
    end
    
    reaper.SetExtState("tdspk_test", key, cur_marker, false)
  end
  reaper.UpdateArrange()
end
