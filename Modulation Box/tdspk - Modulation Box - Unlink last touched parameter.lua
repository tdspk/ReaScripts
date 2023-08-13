rv, track_nr, fx, param_id = reaper.GetLastTouchedFX()

if rv then
    track = reaper.GetTrack(0, track_nr - 1)
    param = "param." .. param_id .. ".plink."
    
    reaper.TrackFX_SetNamedConfigParm(track, fx, param .. "active", "0")
    reaper.TrackFX_SetNamedConfigParm(track, fx, param .. "effect", "")
    reaper.TrackFX_SetNamedConfigParm(track, fx, param .. "param", "")
end
