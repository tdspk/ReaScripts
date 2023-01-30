count = reaper.CountSelectedMediaItems(0);

if count > 0 then
  reaper.Main_OnCommandEx(40012, 0, 0);
end
