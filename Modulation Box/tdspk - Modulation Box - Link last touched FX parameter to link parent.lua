-- @description Link last touched FX parameter to link parent
-- @version 1.0.2
-- @author Tadej Supukovic (tdspk)
-- @noindex

function GetLocalFxIndex(track, container, fx)
  rv, count = reaper.TrackFX_GetNamedConfigParm(track, container, "container_count")
  count = tonumber(count)
  
  for i=0, count - 1 do
    p = "container_item." .. i
    rv, fx_idx = reaper.TrackFX_GetNamedConfigParm(track, container, p)
    if tonumber(fx_idx) == tonumber(fx) then
      return i
    end
  end
  
  return -1
end

rv, track_nr, item, take, fx, param_id = reaper.GetTouchedOrFocusedFX(0) -- get last touched FX param

if rv then
  data = reaper.GetExtState("tdspk_mbox", "link_parent")
  
  if data ~= "" then
    a_log = {}
  
    data_fx, data_param = string.match(data, "(.-);(.+)")
    
    -- check if it's not the same fx / param
    if tonumber(data_fx) == fx and tonumber(data_param) == param_id then
      return
    end
    
    track = reaper.GetTrack(0, track_nr)
    
    is_container, c_id_parent = reaper.TrackFX_GetNamedConfigParm(track, data_fx, "parent_container")
    is_container, c_id_child = reaper.TrackFX_GetNamedConfigParm(track, fx, "parent_container")
    
    parent_fx = data_fx
    parent_param = data_param
    map_param = param_id
    
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
      is_container, container_id = reaper.TrackFX_GetNamedConfigParm(track, map_target, "parent_container")
      
      -- expose container parameters, until same depth is reached
      while (container_id ~= target_container) do
        mapped_param = "container_map.add." .. map_target .. "." .. map_param
        rv, c_param = reaper.TrackFX_GetNamedConfigParm(track, container_id, mapped_param)
        map_target = container_id
        map_param = c_param
        is_container, container_id = reaper.TrackFX_GetNamedConfigParm(track, map_target, "parent_container")
      end

      if (c_id_child > c_id_parent) then
        child = map_target
      else
        parent_fx = map_target
        parent_param = c_param
        map_param = data_param
      end
      
      if (is_container) then
        parent_fx = GetLocalFxIndex(track, container_id, parent_fx)
      end
    end
    
    -- link child parameters to parent
    param = "param." .. map_param .. ".plink."
    reaper.TrackFX_SetNamedConfigParm(track, child, param .. "active", "1")
    reaper.TrackFX_SetNamedConfigParm(track, child, param .. "effect", parent_fx)
    reaper.TrackFX_SetNamedConfigParm(track, child, param .. "param", parent_param)
    
    -- tcp_toggle = reaper.GetExtState("tdspk_mbox", "tcp_toggle")
    -- if (tcp_toggle == "1") then
    --   reaper.SNM_AddTCPFXParm(track, fx, param_id) -- add a knob to the tcp
    -- end
  end
end

