sel_items = reaper.CountSelectedMediaItems(0)

if sel_items > 1 then
  first_item = reaper.GetSelectedMediaItem(0, 0) -- get the first item
end

for i=1,sel_items-1 do
  item = reaper.GetSelectedMediaItem(0, i)
  reaper.SetMediaItemSelected(item, false)
end

reaper.SetMediaItemSelected(first_item, true)

reaper.Main_OnCommand(40290, 0)
