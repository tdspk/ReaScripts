-- @description Toggle solo for tracks of selected items
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @changelog
--   First version

tracks = {}

function table.contains(table, value)
    for i = 1, #table do if table[i] == value then return true end end
    return false
end

for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
    item = reaper.GetSelectedMediaItem(0, i)
    track = reaper.GetMediaItemTrack(item)

    if not table.contains(tracks, track) then table.insert(tracks, track) end
end

for i = 1, #tracks do
    local track = tracks[i]
    local is_solo = reaper.GetMediaTrackInfo_Value(track, "I_SOLO")
    aa = is_solo
    if is_solo ~= 0 then
        reaper.SetTrackUISolo(track, 0, 0)
    else
        reaper.SetTrackUISolo(track, 1, 0)
    end
end
