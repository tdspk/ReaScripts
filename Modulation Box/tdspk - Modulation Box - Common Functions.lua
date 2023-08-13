function copy_parameter_data(param_base, param_list, ext_section, ext_key)
    rv, track_id, fx, param_id = reaper.GetLastTouchedFX()
    track = reaper.GetTrack(0, track_id - 1) --get track of last touched FX param
    param = "param." .. param_id .. param_base

    data = ""

    for k, v in pairs(param_list) do
        rv, buf = reaper.TrackFX_GetNamedConfigParm(track, fx, param .. v)
        if rv then
            data = data .. v .. ":" .. buf .. ";"
        end
    end

    if data then
        reaper.SetExtState(ext_section, ext_key, data, false)
    end
end

function paste_parameter_data(param_base, param_names, ext_section, ext_key)
    rv, track_id, fx, param_id = reaper.GetLastTouchedFX()
    track = reaper.GetTrack(0, track_id - 1) --get track of last touched FX param
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

    for k, v in pairs(data_map) do
        rv, buf = reaper.TrackFX_SetNamedConfigParm(track, fx, param .. k, v)
    end
end

function set_modulation(param_base, value)
  rv, track_nr, fx, param_id = reaper.GetLastTouchedFX()
  
  if rv then
    track = reaper.GetTrack(0, track_nr - 1)
    param = "param." .. param_id .. "." .. param_base
    
    -- Check if there is already an named parameter
    -- rv, buf = reaper.TrackFX_GetNamedConfigParm(track, fx, param)
    
    -- if not, create a default one
    reaper.TrackFX_SetNamedConfigParm(track, fx, param, value)
    
    if (value == "1") then
      reaper.Main_OnCommand(41143, 0) -- FX: Show parameter modulation/link for last touched FX parameter
    end
  end
end
