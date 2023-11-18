-- @description Link last touched FX parameter to link parent
-- @version 1.0.2
-- @author Tadej Supukovic (tdspk)
-- @noindex
-- @changelog
--   Support for FX Containers
--   Added support for tcp toggle
--   First version

rv, track_nr, item, take, fx, param_id = reaper.GetTouchedOrFocusedFX(0) -- get last touched FX param

if rv then
  data = reaper.GetExtState("tdspk_mbox", "link_parent")
  
  if data ~= "" then
  
    data_fx, data_param = string.match(data, "(.-);(.+)")
    
    -- check if it's not the same fx / param
    if tonumber(data_fx) == fx and tonumber(data_param) == param_id then
      return
    end
  
    track = reaper.GetTrack(0, track_nr)
    param = "param." .. param_id .. ".plink."
    reaper.TrackFX_SetNamedConfigParm(track, fx, param .. "active", "1")
    reaper.TrackFX_SetNamedConfigParm(track, fx, param .. "effect", data_fx)
    reaper.TrackFX_SetNamedConfigParm(track, fx, param .. "param", data_param)
    
    tcp_toggle = reaper.GetExtState("tdspk_mbox", "tcp_toggle")
    if (tcp_toggle == "1") then
      reaper.SNM_AddTCPFXParm(track, fx, param_id) -- add a knob to the tcp
    end
  end
end
