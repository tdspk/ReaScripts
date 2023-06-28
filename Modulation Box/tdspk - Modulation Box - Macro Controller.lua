dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

ctx = reaper.ImGui_CreateContext("Modulation Box")

function loop()
  reaper.ImGui_SetNextWindowSize(ctx, 600, 600, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, "Macro Controller", true)
  if visible then
    window()
    reaper.ImGui_End(ctx)
  end

  if open then
    reaper.defer(loop)
  end
end

reaper.defer(loop)

function window()
  track = reaper.GetSelectedTrack(0, 0)
  rv, track_name = reaper.GetTrackName(track)
  
  for i=0, reaper.TrackFX_GetCount(track) - 1 do
    rv, fx_name = reaper.TrackFX_GetFXName(track, i)
    if fx_name == "JS: ReaTeam JSFX/Utility/ReaperBlog_Macro Controller.jsfx" then
      child_found = true
      child_id = i
    end
  end
  
  reaper.ImGui_Text(ctx, track_name)
  
  if child_found then
    rv, m0_val = reaper.ImGui_VSliderInt(ctx, "M1", 50, 100, 50, 0, 100)
    reaper.TrackFX_SetParam(track, child_id, 0, m0_val)
    m0_val = reaper.TrackFX_GetParam(track, child_id, 0)
  end
end
