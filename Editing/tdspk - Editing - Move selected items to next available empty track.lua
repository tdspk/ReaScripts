-- @description Move selected items to next available empty track
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @changelog
--   First version

items = {}
for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
    item = reaper.GetSelectedMediaItem(0, i)
    table.insert(items, item)
end

if #items > 0 then
    reaper.Undo_BeginBlock2(0)

    local cur_track = reaper.GetMediaItemTrack(items[1])
    local cur_idx = reaper.GetMediaTrackInfo_Value(cur_track, "IP_TRACKNUMBER")
    local empty_track
    
    for i = cur_idx, reaper.CountTracks() - 1 do
        local track = reaper.GetTrack(0, i)
        if reaper.CountTrackMediaItems(track) == 0 then
            empty_track = track
            break
        end
    end

    if not empty_track then
        reaper.InsertTrackAtIndex(reaper.CountTracks(), false)
        empty_track = reaper.GetTrack(0, reaper.CountTracks() - 1)
    end

    for i = 1, #items do
        reaper.MoveMediaItemToTrack(items[i], empty_track)
    end
    
    reaper.UpdateArrange()
    
    reaper.Undo_EndBlock2(0, "Move selected items to next available empty track", 0)
end
