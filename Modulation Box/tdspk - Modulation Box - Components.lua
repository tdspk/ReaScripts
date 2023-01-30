dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

function RenderModulationList()
  item_count = 0

  for track_id = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, track_id)
    local rv, tname = reaper.GetTrackName(track)

    if reaper.ImGui_TreeNodeEx(ctx, track_id, track_id .. " - " .. tname, reaper.ImGui_TreeNodeFlags_DefaultOpen()) then
      for fx_id = 0, reaper.TrackFX_GetCount(track) - 1 do
        local first_pass = true

        local rv, fx_name = reaper.TrackFX_GetFXName(track, fx_id)

        for param_id = 0, reaper.TrackFX_GetNumParams(track, fx_id) - 1 do
          p = "param." .. param_id
          rv, has_mod = reaper.TrackFX_GetNamedConfigParm(track, fx_id, p .. ".mod.active")
          
          if has_mod == "1" then
            mbox.ready = true
            item_count = item_count + 1

            local rv, param_name = reaper.TrackFX_GetParamName(track, fx_id, param_id)
            local rv, fx_name = reaper.TrackFX_GetFXName(track, fx_id)
            local rv, param_name = reaper.TrackFX_GetParamName(track, fx_id, param_id)
            local rv, track_name = reaper.GetTrackName(track)

            if reaper.ImGui_Selectable(ctx, fx_name .. " - " .. param_name, mbox.selected_item == item_count) then
              mbox.track = track
              mbox.track_name = track_name
              mbox.fx_id = fx_id
              mbox.fx_name = fx_name
              mbox.param_id = param_id
              mbox.param_name = param_name
            end

          end
          
        end
        
      end

    end
    reaper.ImGui_TreePop(ctx)
  end
end

function HSV(h, s, v, a)
  local r, g, b = reaper.ImGui_ColorConvertHSVtoRGB(h, s, v)
  return reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a or 1.0)
end

ctx = reaper.ImGui_CreateContext("Components Test")

function myWindow()
  RenderModulationList()
end

function loop()
  local visible, open = reaper.ImGui_Begin(ctx, "Components Test", true)
  if visible then
    myWindow()
    reaper.ImGui_End(ctx)
  end

  if open then
    reaper.defer(loop)
  end
end

loop()
