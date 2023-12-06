-- @description Common Functions
-- @version 1.0.1
-- @author Tadej Supukovic (tdspk)
-- @provides [nomain] .
-- @noindex

function SetNamedConfigParm(target, fx, parmname, value, is_item)
  if (is_item) then
    return reaper.TakeFX_SetNamedConfigParm(target, fx, parmname, value)
  else
    return reaper.TrackFX_SetNamedConfigParm(target, fx, parmname, value)
  end
end

function GetNamedConfigParm(target, fx, parmname, is_item)
  if (is_item) then
    return reaper.TakeFX_GetNamedConfigParm(target, fx, parmname)
  else
    return reaper.TrackFX_GetNamedConfigParm(target, fx, parmname)
  end
end

function copy_parameter_data(param_base, param_list, ext_section, ext_key)
    rv, trackidx, itemidx, takeidx, fx, param_id = reaper.GetTouchedOrFocusedFX(0) -- get last touched FX param
    
    if rv then
      param = "param." .. param_id .. param_base
      data = ""

      if (itemidx ~= -1) then
        itemidx = reaper.GetMediaItem(0, itemidx)
        target = reaper.GetTake(itemidx, takeidx)
        is_item = true
      else
        target = reaper.GetTrack(0, trackidx)
        is_item = false
      end
      
      for k, v in pairs(param_list) do
        rv, buf = GetNamedConfigParm(target, fx, param .. v, is_item)
        if rv then
            data = data .. v .. ":" .. buf .. ";"
        end
      end
      
      if data then
          reaper.SetExtState(ext_section, ext_key, data, false)
      end
    end
end

function paste_parameter_data(param_base, param_names, ext_section, ext_key)
    rv, trackidx, itemidx, takeidx, fx, param_id = reaper.GetTouchedOrFocusedFX(0) -- get last touched FX param
    if rv then
      data = reaper.GetExtState(ext_section, ext_key)
      if not data then
          return
      end
      
      data_map = {}
      for substr in string.gmatch(data, "[^;]+") do
          local key, value = string.match(substr, "(.-):(.+)")
          data_map[key] = value
      end
      
      param = "param." .. param_id .. param_base
      
      if (itemidx ~= -1) then
        itemidx = reaper.GetMediaItem(0, itemidx)
        target = reaper.GetTake(itemidx, takeidx)
        is_item = true
      else
        target = reaper.GetTrack(0, trackidx) --get track of last touched FX param
        is_item = false
      end
      
      for k, v in pairs(data_map) do
          rv, buf = SetNamedConfigParm(target, fx, param .. k, v, is_item)
      end
    end
end

function set_modulation(param_base, value)
  rv, trackidx, itemidx, takeidx, fx, param_id = reaper.GetTouchedOrFocusedFX(0) -- get last touched FX param
  
  if rv then
    param = "param." .. param_id .. "." .. param_base

    if (itemidx ~= -1) then
      itemidx = reaper.GetMediaItem(0, itemidx)
      take = reaper.GetTake(itemidx, takeidx)
      SetNamedConfigParm(take, fx, param, value, true)
    else
      track = reaper.GetTrack(0, trackidx)
      SetNamedConfigParm(track, fx, param, value, false)
      
      -- get value of ext state from toggle
      tcp_toggle = reaper.GetExtState("tdspk_mbox", "tcp_toggle")
      if (tcp_toggle == "1") then
        reaper.SNM_AddTCPFXParm(track, fx, param_id) -- add a knob to the tcp
      end
    end

    if (value == "1") then
      reaper.Main_OnCommand(41143, 0) -- FX: Show parameter modulation/link for last touched FX parameter
    end
  end
end
