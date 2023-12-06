-- @description Unlink last touched parameter
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @noindex

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/tdspk - Modulation Box - Common Functions.lua')

rv, trackidx, itemidx, takeidx, fx, param_id = reaper.GetTouchedOrFocusedFX(0) -- get last touched FX param

if rv then
  -- check if we're dealing with media items or tracks
  if (itemidx ~= -1) then
    itemidx = reaper.GetMediaItem(0, itemidx)
    target = reaper.GetTake(itemidx, takeidx)
    is_item = true
  else
    target = reaper.GetTrack(0, trackidx)
    is_item = false
  end
  
  rv, container_id = GetNamedConfigParm(target, fx, "parent_container", is_item)
  if rv then
    rv, container_map = GetNamedConfigParm(target, container_id, "container_map.get." .. fx .. "." .. param_id, is_item)
    if (rv) then
      param_id = container_map
      fx = container_id
    end
  end
  -- if a mapping has been found, remove mapping from container
  
  param = "param." .. param_id .. ".plink."
  
  SetNamedConfigParm(target, fx, param .. "active", "0", is_item)
  SetNamedConfigParm(target, fx, param .. "effect", "0", is_item)
  SetNamedConfigParm(target, fx, param .. "param", "0", is_item)
end
