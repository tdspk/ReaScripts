-- @description Link last touched FX parameter to link parent
-- @version 1.0.2
-- @author Tadej Supukovic (tdspk)
-- @noindex

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/tdspk - Modulation Box - Common Functions.lua')

-- Returns the local index for a container item - needed for linking, since links work with index rather than fx id
function GetLocalFxIndex(target, container, fx, is_item)
  rv, count = GetNamedConfigParm(target, container, "container_count", is_item)
  count = tonumber(count)
  
  for i=0, count - 1 do
    p = "container_item." .. i
    rv, fx_idx = GetNamedConfigParm(target, container, p, is_item)
    if tonumber(fx_idx) == tonumber(fx) then
      return i
    end
  end
  
  return -1
end

rv, trackidx, itemidx, takeidx, fx, param_id = reaper.GetTouchedOrFocusedFX(0) -- get last touched FX param

if rv then
  data = reaper.GetExtState("tdspk_mbox", "link_parent") -- get data for link parent
  
  if data ~= "" then 
    data_fx, data_param = string.match(data, "(.-);(.+)")
    
    -- check if it's not the same fx / param as link parent
    if tonumber(data_fx) == fx and tonumber(data_param) == param_id then
      return
    end
    
    -- check if we're dealing with media items or tracks
    if (itemidx ~= -1) then
      itemidx = reaper.GetMediaItem(0, itemidx)
      target = reaper.GetTake(itemidx, takeidx)
      is_item = true
    else
      target = reaper.GetTrack(0, trackidx)
      is_item = false
    end
    
    -- get the container ids for link parent and link child
    rv, c_id_parent = GetNamedConfigParm(target, data_fx, "parent_container", is_item)
    rv, c_id_child = GetNamedConfigParm(target, fx, "parent_container", is_item)
    
    parent_fx = data_fx
    parent_param = data_param
    map_param = param_id
    
    -- check which one is higher in the hiearchy
    if (c_id_child > c_id_parent) then
      -- child id needs to be overwritten with container maps
      target_container = c_id_parent
      map_target = fx
      map_param = param_id
    elseif (c_id_child < c_id_parent) then
      -- parent id needs to be overwritten with container maps
      target_container = c_id_child
      map_target = data_fx
      map_param = data_param
      child = fx
    else
      -- nothing to do
      target_container = -1
      child = fx
    end
    
    if (target_container ~= -1) then
      is_container, container_id = GetNamedConfigParm(target, map_target, "parent_container", is_item)

      -- expose container parameters, until current container reaches target container
      while (container_id ~= target_container) do
        local mapped_param = "container_map.add." .. map_target .. "." .. map_param
        rv, c_param = GetNamedConfigParm(target, container_id, mapped_param, is_item)
        map_target = container_id
        map_param = c_param
        is_container, container_id = GetNamedConfigParm(target, map_target, "parent_container", is_item)
      end

      if (c_id_child > c_id_parent) then
        child = map_target
      else
        parent_fx = map_target
        parent_param = c_param
        map_param = data_param
      end
      
      if (is_container) then
        parent_fx = GetLocalFxIndex(target, container_id, parent_fx, is_item)
      end
    end
    
    -- link child parameters to parent
    param = "param." .. map_param .. ".plink."
    
    SetNamedConfigParm(target, child, param .. "active", "1", is_item)
    SetNamedConfigParm(target, child, param .. "effect", parent_fx, is_item)
    SetNamedConfigParm(target, child, param .. "param", parent_param, is_item)
    
    tcp_toggle = reaper.GetExtState("tdspk_mbox", "tcp_toggle")
    if (tcp_toggle == "1" and is_item == false) then
      reaper.SNM_AddTCPFXParm(target, fx, param_id) -- add a knob to the tcp
    end
  end
end

