--@description Media Item Spacer
--@version 1.1
--@author Tadej Supukovic (tdspk)
--@about
--  # Media Item Spacer
--  Tool for creating space between Media Items in seconds. Useful for Sound Library creation
--  # Requirements
--  JS_ReaScriptAPI, SWS Extension, ReaImGui
--@links
--  Website https://www.tdspkaudio.com
--@donation
--  https://ko-fi.com/tdspkaudio
--  https://coindrop.to/tdspkaudio
--@changelog
--  Increased max spacing and added new modes (absolute and additive)
--  First version

dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

local ctx = reaper.ImGui_CreateContext('Media Item Spacer')

min_spacing = 1
max_spacing = 25
spacing = 5
mode = 0

local function CacheSelectedTracks()
  tracks = {} 
   track_count = reaper.CountSelectedTracks(0)
   
   -- cache selected tracks for later selection & deselection
   for i = 0, track_count - 1 do
     track = reaper.GetSelectedTrack(0, i)
     table.insert(tracks, track)
   end
   
   return tracks
end

local function RenderWindow()
  track_count = reaper.CountSelectedTracks(0)
  
  if track_count > 0 then
    reaper.ImGui_Text(ctx, track_count .. " tracks selected.")
    
    rv, mode = reaper.ImGui_RadioButtonEx(ctx, "Absolute", mode, 0)
    reaper.ImGui_SameLine(ctx)
    rv, mode = reaper.ImGui_RadioButtonEx(ctx, "Additive", mode, 1)
    
    rv, spacing = reaper.ImGui_SliderInt(ctx, "Spacing", spacing, min_spacing, max_spacing, "%d seconds")
    if rv then
      tracks = CacheSelectedTracks()
      
      reaper.Undo_BeginBlock()
      
      for k, track in pairs(tracks) do
        reaper.SetTrackSelected(track, true)
        reaper.Main_OnCommand(40421, 0) -- Item: Select all items in track
        
        count = reaper.CountTrackMediaItems(track)
        
        for i = 0, count - 1 do
          item = reaper.GetSelectedMediaItem(0, i)
          
          if i == 0 then
            current_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
          end
          
          reaper.SetMediaItemPosition(item, current_pos, false)
          if mode == 1 then
            -- add item length to current pos for additive positioning
            local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            current_pos = current_pos + item_length
          end
          current_pos = current_pos + spacing
        end
        
        reaper.SetTrackSelected(track, false)
      end
      
      for k, track in pairs(tracks) do
        reaper.SetTrackSelected(track, true)
      end
      
      reaper.UpdateArrange()
      
      reaper.Undo_EndBlock("Media Item Spacer - spaced items for " .. spacing .. " seconds.", 0)
    end
  else
    reaper.ImGui_Text(ctx, "Please select a track")
  end
end

local function Loop()
  reaper.ImGui_SetNextWindowSize(ctx, 300, 100)
  local visible, open = reaper.ImGui_Begin(ctx, 'Media Item Spacer', true)
  if visible then
    RenderWindow()
    reaper.ImGui_End(ctx)
  end
  if open then
    reaper.defer(Loop)
  end
end

Loop()
