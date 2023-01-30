dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

if not mbox then
  mbox = {
    window_title = "Modulation List",
    live_clicked = 0,
    track_id, fx_id, param_id = nil,
    has_lfo = false,
    mod_baseline = 0.5,
    lfo_shape = 0,
    lfo_sync = 0,
    lfo_speed = 4,
    lfo_strength = 1,
    lfo_phase = 0,
    lfo_direction = 0,
    lfo_phase = 0,
    lfo_free = false
  }
end

ctx = reaper.ImGui_CreateContext('My script')
is_livemode = false

function myWindow()
  
  if reaper.ImGui_Button(ctx, "Live Mode") then
   mbox.live_clicked = mbox.live_clicked + 1
  end
  
  if mbox.live_clicked & 1 ~= 0 then
   is_livemode = true
   reaper.ImGui_SameLine(ctx)
   reaper.ImGui_Text(ctx, "LIVE MODE ENABLED")
  else
   is_livemode = false
  end
  
  RenderList()
end

function loop()
  reaper.ImGui_SetNextWindowSize(ctx, 400, 400, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, mbox.window_title, true)
  if visible then
    myWindow()
    reaper.ImGui_End(ctx)
  end

  if open then
    reaper.defer(loop)
  end
end

reaper.defer(loop)

function RenderList()
  QueryTrackFx()
end

function QueryTrackFx()
  item_count = 0

  for track_id = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, track_id)
    local rv, tname = reaper.GetTrackName(track)

    if reaper.ImGui_TreeNodeEx(ctx, track_id, track_id .. " - " .. tname, reaper.ImGui_TreeNodeFlags_DefaultOpen()) then
      for fx_id = 0, reaper.TrackFX_GetCount(track) do
        for param_id = 0, reaper.TrackFX_GetNumParams(track, fx_id) - 1 do
          p =  "param." .. param_id
          rv, has_mod = reaper.TrackFX_GetNamedConfigParm(track, fx_id, p .. ".mod.active")

          if has_mod == "1" then
            --item_count = item_count + 1
            
            local rv, fx_name = reaper.TrackFX_GetFXName(track, fx_id)
            local rv, param_name = reaper.TrackFX_GetParamName(track, fx_id, param_id)
            
            if reaper.ImGui_SmallButton(ctx, "X") then
              reaper.TrackFX_SetNamedConfigParm(track, fx_id, p .. "mod.active", "0")
            end
            
            reaper.ImGui_SameLine(ctx);
            
            if reaper.ImGui_SmallButton(ctx, "SHOW") then
              show = "yes"
              reaper.TrackFX_SetNamedConfigParm(track, fx_id,  p .. "mod.visible", "1")
            end
            reaper.ImGui_SameLine(ctx)
            
            if reaper.ImGui_SmallButton(ctx, "LFO") then
              reaper.TrackFX_SetNamedConfigParm(track, fx_id, p .. "lfo.active", "0")
            end
            reaper.ImGui_SameLine(ctx)
            
            reaper.ImGui_SmallButton(ctx, "ENV")
            reaper.ImGui_SameLine(ctx);
            reaper.ImGui_Selectable(ctx, fx_name .. " - " .. param_name, false)
          end
        end
      end

      reaper.ImGui_TreePop(ctx)
    end
  end
end

function QueryLiveFxInfo()
  rv, track_nr, mbox.fx_id, mbox.param_id = reaper.GetLastTouchedFX()

  if rv then
    mbox.track = reaper.GetTrack(0, track_nr - 1)
    rv, mbox.fx_name = reaper.TrackFX_GetNamedConfigParm(mbox.track, mbox.fx_id, "fx_name")
    rv, mbox.param_name = reaper.TrackFX_GetParamName(mbox.track, mbox.fx_id, mbox.param_id)

    --p = "param." .. mbox.param
    --reaper.TrackFX_SetNamedConfigParm(mbox.track, mbox.fx, p .. "mod.active", "1")
  end
end
