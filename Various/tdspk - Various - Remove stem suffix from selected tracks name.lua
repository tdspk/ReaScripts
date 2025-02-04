-- @description Remove stem suffix from selected tracks name
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @noindex
-- @changelog
--   First version

for i = 0, reaper.CountSelectedTracks(0) - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    local rv, name = reaper.GetTrackName(track)
    -- remove "- stem" suffix from track name
    name = string.gsub(name, "- stem", "")
    reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)
end
