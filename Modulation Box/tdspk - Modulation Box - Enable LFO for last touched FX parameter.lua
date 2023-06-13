rv, track_nr, fx, param_id = reaper.GetLastTouchedFX()

if rv then
  track = reaper.GetTrack(0, track_nr - 1)
  param = "param." .. param_id .. ".lfo.active"
  
  -- Check if there is already an LFO
  rv, buf = reaper.TrackFX_GetNamedConfigParm(track, fx, param)
  
  
  -- if not, create a default one
  if buf == "" or buf == "0" then
    a_db = "no value"
    reaper.TrackFX_SetNamedConfigParm(track, fx, param, "1")
  end
  reaper.Main_OnCommand(41143, 0) -- FX: Show parameter modulation/link for last touched FX parameter
  
end
