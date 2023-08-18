-- @description Set item length of all selected items to first item's length
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @changelog
--   First version

item_count = reaper.CountSelectedMediaItems(0)

if item_count > 1 then
  first_item = reaper.GetSelectedMediaItem(0, 0)
  length = reaper.GetMediaItemInfo_Value(first_item, "D_LENGTH")
  
  for i=1, item_count - 1 do
    item = reaper.GetSelectedMediaItem(0, i)
    reaper.SetMediaItemInfo_Value(item, "D_LENGTH", length)
  end
end
