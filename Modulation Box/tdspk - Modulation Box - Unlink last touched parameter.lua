-- @description This scripts disabled the link for the last touched parameter.
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @changelog
--   First version

rv, track_nr, fx, param_id = reaper.GetLastTouchedFX()

if rv then
    track = reaper.GetTrack(0, track_nr - 1)
    param = "param." .. param_id .. ".plink."
    
    reaper.TrackFX_SetNamedConfigParm(track, fx, param .. "active", "0")
    reaper.TrackFX_SetNamedConfigParm(track, fx, param .. "effect", "")
    reaper.TrackFX_SetNamedConfigParm(track, fx, param .. "param", "")
end
