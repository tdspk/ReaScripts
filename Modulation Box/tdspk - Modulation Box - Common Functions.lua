-- @description Common Functions
-- @version 1.0.1
-- @author Tadej Supukovic (tdspk)
-- @provides [nomain] .
-- @noindex

function copy_parameter_data(param_base, param_list, ext_section, ext_key)
    rv, trackidx, itemidx, takeidx, fx, param_id = reaper.GetTouchedOrFocusedFX(0) -- get last touched FX param
    if rv then
      param = "param." .. param_id .. param_base
      data = ""

      if (itemidx ~= -1) then
        itemidx = reaper.GetMediaItem(0, itemidx)
        take = reaper.GetTake(itemidx, takeidx)
        for k, v in pairs(param_list) do
          rv, buf = reaper.TakeFX_GetNamedConfigParm(take, fx, param .. v)
          if rv then
              data = data .. v .. ":" .. buf .. ";"
          end
        end
      else
        track = reaper.GetTrack(0, trackidx)
        for k, v in pairs(param_list) do
          rv, buf = reaper.TrackFX_GetNamedConfigParm(track, fx, param .. v)
          if rv then
              data = data .. v .. ":" .. buf .. ";"
          end
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
        take = reaper.GetTake(itemidx, takeidx)
        for k, v in pairs(data_map) do
            rv, buf = reaper.TakeFX_SetNamedConfigParm(take, fx, param .. k, v)
        end
      else
        track = reaper.GetTrack(0, trackidx) --get track of last touched FX param
        for k, v in pairs(data_map) do
            rv, buf = reaper.TrackFX_SetNamedConfigParm(track, fx, param .. k, v)
        end
      end 
    end
end

function set_modulation(param_base, value)
  rv, trackidx, itemidxidx, takeidx, fx, param_id = reaper.GetTouchedOrFocusedFX(0) -- get last touched FX param
  
  if rv then
    param = "param." .. param_id .. "." .. param_base

    if (itemidxidx ~= -1) then
      itemidx = reaper.GetMediaItem(0, itemidxidx)
      take = reaper.GetTake(itemidx, takeidx)
      reaper.TakeFX_SetNamedConfigParm(take, fx, param, value)
    else
      track = reaper.GetTrack(0, trackidx)
      reaper.TrackFX_SetNamedConfigParm(track, fx, param, value)
      
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
