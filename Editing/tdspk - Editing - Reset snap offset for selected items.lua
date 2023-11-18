-- @description Reset snap offset for selected items
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @changelog
--   First version

item_count = reaper.CountSelectedMediaItems(0)

for i=0, item_count-1 do
  item = reaper.GetSelectedMediaItem(0, i)
  reaper.SetMediaItemInfo_Value(item, "D_SNAPOFFSET", 0)
end
