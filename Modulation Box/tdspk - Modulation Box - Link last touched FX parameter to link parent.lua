-- @description This script links the last touched parameter to the current link parent.
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @changelog
--   First version

rv, track_nr, fx, param_id = reaper.GetLastTouchedFX()

if rv then
  data = reaper.GetExtState("tdspk_mbox", "link_parent")
  
  if data ~= "" then
  
    data_fx, data_param = string.match(data, "(.-);(.+)")
    
    -- check if it's not the same fx / param
    if tonumber(data_fx) == fx and tonumber(data_param) == param_id then
      return
    end
  
    track = reaper.GetTrack(0, track_nr - 1)
    param = "param." .. param_id .. ".plink."
    reaper.TrackFX_SetNamedConfigParm(track, fx, param .. "active", "1")
    reaper.TrackFX_SetNamedConfigParm(track, fx, param .. "effect", data_fx)
    reaper.TrackFX_SetNamedConfigParm(track, fx, param .. "param", data_param)
  end
end
