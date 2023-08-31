item_count = reaper.CountSelectedMediaItems(0)

if item_count > 1 then
  -- get position of first selected item's offset (position + offset)
  item = reaper.GetSelectedMediaItem(0, 0)
  align_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") + reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")

  -- iterate remaining items and move them to the aligning position
  for i=1, item_count-1 do
    item = reaper.GetSelectedMediaItem(0, i)
    offset = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", align_pos - offset);
  end
end
