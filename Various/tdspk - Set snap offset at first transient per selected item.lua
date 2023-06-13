item_count = reaper.CountSelectedMediaItems(0)

for i=0, item_count-1 do
  item = reaper.GetSelectedMediaItem(0, i)
  position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  reaper.SetEditCurPos(position, false, false)
  reaper.Main_OnCommand(40836, 0)
  reaper.Main_OnCommand(40541, 0)
end
