-- @description Splits items only if an item is selected.
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @changelog
--   First version

count = reaper.CountSelectedMediaItems(0);

if count > 0 then
  reaper.Main_OnCommandEx(40012, 0, 0);
end
