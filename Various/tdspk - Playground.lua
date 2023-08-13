rv, track_id, fx, param_id = reaper.GetLastTouchedFX()
track = reaper.GetTrack(0, track_id - 1) --get track of last touched FX param
rv, a = reaper.TrackFX_GetNamedConfigParm(track, fx, "param.1.acs.active")
