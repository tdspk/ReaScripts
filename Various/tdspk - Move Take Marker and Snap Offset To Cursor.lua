item = reaper.GetSelectedMediaItem(0, 0) -- get first selected media item

if item then
  take = reaper.GetActiveTake(item) -- get active take of selected track
  if take then
    marker_count = reaper.GetNumTakeMarkers(take)
    if marker_count > 0 then -- check if active take has any take markers
      -- Save visible markers in a table for later reference
      visible_markers = {}
      
      start_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      end_pos = start_pos + item_length
      
      m_pos, name = reaper.GetTakeMarker(take, 0)
      
      if m_pos + start_pos >= start_pos then
        ok = true
      end
      
      -- get first visible marker and cache it
      --[[
      for i=0,marker_count-1 do
        rv, name = reaper.GetTakeMarker(take, i)
        rel_rv = start_pos + rv
        
        if rel_rv >= start_pos and rel_rv <= end_pos then
          visible_markers[i] = rv .. " " .. name
          --break
        end
      end
      
      for k,v in pairs(visible_markers) do
        --yolo = k .. " "
      end
      ]]--
      
      
    
      --rv, name = reaper.GetTakeMarker(take, 0) -- get first take maker in take
      --curPos = reaper.GetCursorPosition() -- get cursor position in seconds
      --miPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") -- get media item position in seconds
      
      --reaper.Main_OnCommand(40541, 0) -- call action "Item: Set snap offset to cursor"
      --start_offs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
      --target_pos = curPos -- miPos - start_offs
      --reaper.SetTakeMarker(take, 0, name, target_pos) -- Set take marker at delta positixon
    end
  end
end
