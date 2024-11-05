-- @description Glue individual items
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @changelog
--   First version

reaper.Undo_BeginBlock2(0)

items = {}
for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    table.insert(items, item)
end

reaper.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items

for i = 1, #items do
    local item = items[i]
    reaper.SetMediaItemSelected(item, true)
    reaper.Main_OnCommand(40362, 0) -- Item: Glue items, ignoring time selection
    reaper.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
end

reaper.Undo_EndBlock2(0, "tdspk - Glue individual items", 0)