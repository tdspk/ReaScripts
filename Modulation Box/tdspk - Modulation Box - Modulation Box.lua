dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/tdspk - Modulation Box - Components.lua')

  mbox = {
    window_title = "Modulation Box",
    ready = false,
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

if not defaults then
  defaults = {
    mod_baseline = 50,
    lfo_shape = 0,
    lfo_speed = 4,
    lfo_strength = 1,
    lfo_direction = 0,
    lfo_phase = 0,
    lfo_free = 0
  }
end

if not style then
  style = {
    button_selected = HSV(0, 1, 0.5, 1),
    item_spacing_x = 10,
    item_spacing_y = 10
  }
end

ctx = reaper.ImGui_CreateContext("Modulation Box")
is_livemode = false

function myWindow()
  reaper.ImGui_BeginDisabled(ctx, is_livemode)
  RenderList()
  reaper.ImGui_EndDisabled(ctx)
  RenderModulation()
end

function loop()
  reaper.ImGui_SetNextWindowSize(ctx, 600, 600, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, mbox.window_title, true)
  if visible then
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), style.item_spacing_x, style.item_spacing_y)
    myWindow()
    reaper.ImGui_PopStyleVar(ctx)
    reaper.ImGui_End(ctx)
  end

  if open then
    reaper.defer(loop)
  end
end

reaper.defer(loop)

function RenderList()
  reaper.ImGui_BeginChild(ctx, "List", reaper.ImGui_GetContentRegionAvail(ctx) * 0.3, 0, true)
  RenderModulationList()
  reaper.ImGui_EndChild(ctx)
  reaper.ImGui_SameLine(ctx)
end

function RenderModulation()
  reaper.ImGui_BeginGroup(ctx)

  if reaper.ImGui_Button(ctx, "Live Mode", 100) then
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

  if mbox.ready and mbox.param_id then
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Show Window", 100) then
      SetNamedConfigParam("mod.visible", "1")
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Show Knob", 100) then
      reaper.SNM_AddTCPFXParm(mbox.track, mbox.fx_id, mbox.param_id)
    end
  
    reaper.ImGui_Text(ctx, mbox.track_name)
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_Text(ctx, mbox.fx_name)
    reaper.ImGui_Text(ctx, mbox.param_name)

    ReadModulationSettings()

    p = "param." .. mbox.param_id

    if is_livemode then
      local has_mod = ToBoolean(GetNamedConfigParam("mod.active"))
      
      if not has_mod then
        mbox.ready = true
        SetNamedConfigParam("mod.active", "1")
        SetNamedConfigParam("mod.baseline", mbox.pmax / 2)
        SetNamedConfigParam("lfo.speed", defaults.lfo_speed)
        SetNamedConfigParam("lfo.strength", defaults.lfo_strength)
        SetNamedConfigParam("lfo.phase", defaults.lfo_phase)
        SetNamedConfigParam("lfo.dir", defaults.lfo_direction)
        SetNamedConfigParam("lfo.free", defaults.lfo_free)
      end
    else
      -- Toggle Parameter Modulation
      rv, mbox.has_mod = reaper.ImGui_Checkbox(ctx, "Enable Parameter Modulation", mbox.has_mod)
      has_mod = mbox.has_mod and "1" or "0"

      SetNamedConfigParam("mod.active", has_mod)
    end

    if mbox.has_mod then
      rv, mbox.mod_baseline = reaper.ImGui_SliderDouble(ctx, "##Baseline", mbox.mod_baseline, mbox.pmin, mbox.pmax, "Baseline = %f")
      SetNamedConfigParam("mod.baseline", mbox.mod_baseline)
      
      ReadLFOSettings()

      rv, mbox.has_lfo = reaper.ImGui_Checkbox(ctx, "LFO", mbox.has_lfo)
      local has_lfo = mbox.has_lfo and "1" or "0"

      SetNamedConfigParam("lfo.active", has_lfo)

      if mbox.has_lfo then 
        RenderShapeButtons()
        reaper.ImGui_SameLine(ctx)
        rv, mbox.lfo_speed = reaper.ImGui_VSliderDouble(ctx, "##Speed", 50, 200, mbox.lfo_speed, 0, 8, "Speed\n%.3f")
        reaper.ImGui_SameLine(ctx)
        rv, mbox.lfo_strength = reaper.ImGui_VSliderDouble(ctx, "##Strength", 50, 200, mbox.lfo_strength, 0, 1,
          "Strength\n%.3f")
        reaper.ImGui_SameLine(ctx)
        rv, mbox.lfo_phase = reaper.ImGui_VSliderDouble(ctx, "##Phase", 50, 200, mbox.lfo_phase, 0, 1, "Phase\n%.3f")
        reaper.ImGui_SameLine(ctx)

        RenderDirButtons()
        
        rv, mbox.lfo_sync = reaper.ImGui_Checkbox(ctx, "Tempo Sync", mbox.lfo_sync)
        reaper.ImGui_SameLine(ctx)
        rv, mbox.lfo_free = reaper.ImGui_Checkbox(ctx, "Free Running", mbox.lfo_free)
        

        if reaper.ImGui_IsWindowFocused(ctx) then
          WriteLFOSettings()
        end
      end
      
      --rv, mbox.has_acs = reaper.ImGui_Checkbox(ctx, "Audio Control Signal", mbox.has_acs)
      --local has_acs = mbox.has_acs and "1" or "0"
      --SetNamedConfigParam("acs.active", has_acs) 
    end
  else
    reaper.ImGui_Text(ctx, "Select a fx parameter")
  end
  reaper.ImGui_EndGroup(ctx)
end

function RenderShapeButtons()
  local labels = { "Sine", "Square", "Saw L", "Saw R", "Triangle", "Random" }
  reaper.ImGui_BeginGroup(ctx)
  reaper.ImGui_Text(ctx, "Shape")
  
  for i = 1, 6 do
    if mbox.lfo_shape == i - 1 then
      reaper.ImGui_PushID(ctx, "shape_btn")
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), style.button_selected)
      reaper.ImGui_Button(ctx, labels[i], 70)
      reaper.ImGui_PopStyleColor(ctx)
      reaper.ImGui_PopID(ctx)
    else
      if reaper.ImGui_Button(ctx, labels[i], 70) then
        mbox.lfo_shape = i - 1
      end
    end
  end
  reaper.ImGui_EndGroup(ctx)
end

function RenderDirButtons()
  local labels = { "Negative", "Centered", "Positive" }
  reaper.ImGui_BeginGroup(ctx)
  reaper.ImGui_Text(ctx, "Direction")
  for i = 1, 3 do
    if mbox.lfo_direction == i - 2 then
      reaper.ImGui_PushID(ctx, "dir_btn")
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), style.button_selected)
      reaper.ImGui_Button(ctx, labels[i], 70)
      reaper.ImGui_PopStyleColor(ctx)
      reaper.ImGui_PopID(ctx)
    else
      if reaper.ImGui_Button(ctx, labels[i], 70) then
        mbox.lfo_direction = i - 2
      end
    end
  end
  reaper.ImGui_EndGroup(ctx)
end

function ReadModulationSettings()
  mbox.has_mod = ToBoolean(GetNamedConfigParam("mod.active"))
  mbox.mod_baseline = GetNamedConfigParam("mod.baseline")
  dummy, mbox.pmin, mbox.pmax = reaper.TrackFX_GetParam(mbox.track, mbox.fx_id, mbox.param_id)
end

function ReadLFOSettings()
  mbox.has_lfo = ToBoolean(GetNamedConfigParam("lfo.active"))
  mbox.lfo_shape = tonumber(GetNamedConfigParam("lfo.shape"))
  mbox.lfo_speed = GetNamedConfigParam("lfo.speed")
  mbox.lfo_strength = GetNamedConfigParam("lfo.strength")
  mbox.lfo_phase = GetNamedConfigParam("lfo.phase")
  mbox.lfo_direction = tonumber(GetNamedConfigParam("lfo.dir"))
  mbox.lfo_free = ToBoolean(GetNamedConfigParam("lfo.free"))
end

function WriteLFOSettings()
  has_lfo = mbox.has_lfo and "1" or "0"

  --reaper.TrackFX_SetNamedConfigParm(mbox.track, mbox.fx_id, p .. "lfo.active", has_lfo)
  SetNamedConfigParam("lfo.shape", mbox.lfo_shape)
  SetNamedConfigParam("lfo.speed", mbox.lfo_speed)
  SetNamedConfigParam("lfo.strength", mbox.lfo_strength)
  SetNamedConfigParam("lfo.phase", mbox.lfo_phase)
  SetNamedConfigParam("lfo.dir", mbox.lfo_direction)

  sync = "0"
  if mbox.lfo_sync then
    sync = "1"
  end
  SetNamedConfigParam("lfo.temposync", sync)

  free = "0"
  if mbox.lfo_free then
    free = "1"
  end

  SetNamedConfigParam("lfo.free", free)
end

function GetNamedConfigParam(param_name)
  rv, value = reaper.TrackFX_GetNamedConfigParm(mbox.track, mbox.fx_id, "param." .. mbox.param_id .. param_name)
  return value
end

function SetNamedConfigParam(param_name, value)
  reaper.TrackFX_SetNamedConfigParm(mbox.track, mbox.fx_id, "param." .. mbox.param_id .. param_name, value)
end

function ToBoolean(value)
  if value == "1" then
    return true
  end
  return false
end
