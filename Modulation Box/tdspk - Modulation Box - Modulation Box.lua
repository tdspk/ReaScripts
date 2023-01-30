dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

if not mbox then
  mbox = {
    window_title = "Modulation Box",
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
tick = 0
is_livemode = false

function myWindow()
  tick = tick + 1
  reaper.ImGui_BeginDisabled(ctx, is_livemode)
  RenderList()
  reaper.ImGui_EndDisabled(ctx)
  RenderModulation()
end

function loop()
  reaper.ImGui_SetNextWindowSize(ctx, 400, 80, reaper.ImGui_Cond_FirstUseEver())
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
  reaper.ImGui_BeginChild(ctx, "List", 300)
  reaper.ImGui_Text(ctx, "Modulation List")

  QueryTrackFx()

  reaper.ImGui_EndChild(ctx)
  reaper.ImGui_SameLine(ctx)
end

function RenderModulation()
  reaper.ImGui_BeginGroup(ctx)

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

  -- Handle getting the infos for the modulation section
  if is_livemode then
    QueryLiveFxInfo()
  end

  if mbox.param_id then
    reaper.ImGui_Text(ctx, mbox.fx_name)
    reaper.ImGui_Text(ctx, mbox.param_name)

    GetModulationSettings()
    
    p = "param." .. mbox.param_id
    
    if is_livemode then
      reaper.TrackFX_SetNamedConfigParm(mbox.track, mbox.fx_id, p .. "mod.active", "1")
    else
      -- Toggle Parameter Modulation
      rv, mbox.has_mod = reaper.ImGui_Checkbox(ctx, "Enable Parameter Modulation", mbox.has_mod)
      has_mod = mbox.has_mod and "1" or "0"
      
      reaper.TrackFX_SetNamedConfigParm(mbox.track, mbox.fx_id, p .. "mod.active", has_mod)
    end
    
    if mbox.has_mod then
      rv, mbox.mod_baseline = reaper.ImGui_SliderDouble(ctx, "Baseline", mbox.mod_baseline, 0, 1)
      reaper.TrackFX_SetNamedConfigParm(mbox.track, mbox.fx_id, p .. "mod.baseline", mbox.mod_baseline)
      
      GetLFOSettings()
      rv, mbox.has_lfo = reaper.ImGui_Checkbox(ctx, "LFO", mbox.has_lfo)
      has_lfo = mbox.has_lfo and "1" or "0"
      reaper.TrackFX_SetNamedConfigParm(mbox.track, mbox.fx_id, p .. "lfo.active", has_lfo)

      if mbox.has_lfo then

        rv, mbox.lfo_shape = reaper.ImGui_Combo(ctx, "LFO Shape", mbox.lfo_shape,
          "Sine\0Square\0Saw L\0Saw R\0Triangle\0Random\0")
        rv, mbox.lfo_speed = reaper.ImGui_SliderDouble(ctx, "Speed", mbox.lfo_speed, 0, 8);
        reaper.ImGui_SameLine(ctx)
        rv, mbox.lfo_sync = reaper.ImGui_Checkbox(ctx, "Tempo Sync", mbox.lfo_sync)
        rv, mbox.lfo_strength = reaper.ImGui_SliderDouble(ctx, "Strength", mbox.lfo_strength, 0, 1)
        rv, mbox.lfo_phase = reaper.ImGui_SliderDouble(ctx, "Phase", mbox.lfo_phase, 0, 1)
        rv, mbox.lfo_direction = reaper.ImGui_Combo(ctx, "Direction", mbox.lfo_direction,
          "Negative\0Centered\0Positive\0");
        reaper.ImGui_SameLine(ctx)
        rv, mbox.lfo_free = reaper.ImGui_Checkbox(ctx, "Free Running", mbox.lfo_free)

        if reaper.ImGui_IsWindowFocused(ctx) then
          --SetLFOSettings()
        end
      end

      
    end
  else
    reaper.ImGui_Text(ctx, "Select a fx parameter")
  end
  reaper.ImGui_EndGroup(ctx)
end

function QueryTrackFx()
  item_count = 0

  for track_id = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, track_id)
    local rv, tname = reaper.GetTrackName(track)

    if reaper.ImGui_TreeNodeEx(ctx, track_id, track_id .. " - " .. tname, reaper.ImGui_TreeNodeFlags_DefaultOpen()) then
      for fx_id = 0, reaper.TrackFX_GetCount(track) do
        for param_id = 0, reaper.TrackFX_GetNumParams(track, fx_id) - 1 do
          rv, has_mod = reaper.TrackFX_GetNamedConfigParm(track, fx_id, "param." .. param_id .. ".mod.active")

          if has_mod == "1" then
            local rv, fx_name = reaper.TrackFX_GetFXName(track, fx_id)
            local rv, param_name = reaper.TrackFX_GetParamName(track, fx_id, param_id)
            item_count = item_count + 1
            if reaper.ImGui_Selectable(ctx, fx_name .. " - " .. param_name, mbox.selected_item == item_count) then
              mbox.track = track
              mbox.fx_id = fx_id
              mbox.fx_name = fx_name
              mbox.param_id = param_id
              mbox.param_name = param_name
            end
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

function GetModulationSettings()
  rv, has_mod = reaper.TrackFX_GetNamedConfigParm(mbox.track, mbox.fx_id, "param." .. mbox.param_id .. "mod.active")
  mbox.has_mod = has_mod == "1" and true or false
  rv, mbox.mod_baseline = reaper.TrackFX_GetNamedConfigParm(mbox.track, mbox.fx_id, "param." .. mbox.param_id .. "mod.baseline")
end

function GetLFOSettings()
  rv, mbox.lfo_speed = reaper.TrackFX_GetNamedConfigParm(mbox.track, mbox.fx_id, "param." .. mbox.param_id .. "lfo.speed")
end

function SetLFOSettings()
  has_lfo = "0"
  if mbox.has_lfo then
    has_lfo = "1"
  end

  p = "param." .. mbox.param_id
  mbox.lfo_direction = mbox.lfo_direction

  reaper.TrackFX_SetNamedConfigParm(mbox.track, mbox.fx_id, p .. "lfo.active", has_lfo)
  reaper.TrackFX_SetNamedConfigParm(mbox.track, mbox.fx_id, p .. "lfo.shape", mbox.lfo_shape)
  reaper.TrackFX_SetNamedConfigParm(mbox.track, mbox.fx_id, p .. "lfo.speed", mbox.lfo_speed)
  reaper.TrackFX_SetNamedConfigParm(mbox.track, mbox.fx_id, p .. "lfo.strength", mbox.lfo_strength)
  reaper.TrackFX_SetNamedConfigParm(mbox.track, mbox.fx_id, p .. "lfo.phase", mbox.lfo_phase)
  reaper.TrackFX_SetNamedConfigParm(mbox.track, mbox.fx_id, p .. "lfo.dir", mbox.lfo_direction - 1)

  sync = "0"
  if mbox.lfo_sync then
    sync = "1"
  end

  reaper.TrackFX_SetNamedConfigParm(mbox.track, mbox.fx_id, p .. "lfo.temposync", sync)

  free = "0"
  if mbox.lfo_free then
    free = "1"
  end

  reaper.TrackFX_SetNamedConfigParm(mbox.track, mbox.fx_id, p .. "lfo.free", free)
end
