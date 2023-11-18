-- @description Show knobs for each modulated FX parameter in TCP
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @noindex

function p(msg)
  reaper.ShowConsoleMsg(msg)
end

for track_id = 0, reaper.CountTracks(0) - 1 do
  track = reaper.GetTrack(0, track_id)

  for fx_id = 0, reaper.TrackFX_GetCount(track) do
    for param_id = 0, reaper.TrackFX_GetNumParams(track, fx_id) - 1 do
      
      rv, has_lfo = reaper.TrackFX_GetNamedConfigParm(track, fx_id, "param." .. param_id .. ".lfo.active")
      rv, has_acs  =reaper.TrackFX_GetNamedConfigParm(track, fx_id, "param." .. param_id .. ".acs.active")
      if has_lfo == "1" or has_acs == "1" then
         reaper.SNM_AddTCPFXParm(track, fx_id, param_id)
      end
    end
  end
end
