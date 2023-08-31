-- @description Set snap offset at first transient per selected item
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @changelog
--   First version

item_count = reaper.CountSelectedMediaItems(0)

for i=0, item_count-1 do
  item = reaper.GetSelectedMediaItem(0, i)
  position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  reaper.SetEditCurPos(position, false, false)
  reaper.Main_OnCommand(40836, 0) -- Item navigation: Move cursor to nearest transient in items
  -- calculate snap offset based on edit-cursor minus item position
  offset = reaper.GetCursorPosition() - position
  reaper.SetMediaItemInfo_Value(item, "D_SNAPOFFSET", offset)
end
