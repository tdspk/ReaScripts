dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

bitmask = {
  syn = 7,   -- 0000 0000 0111
  ano = 24,  -- 0000 0001 1000
  fft = 96,  -- 0000 0110 0000
  anw = 384, -- 0001 0000 0000
  syw = 1536 -- 0110 0000 0000
}

-- Helper tables for Synthesis

local syn_to_slider = {
  [7] = 3,
  [0] = 4,
  [1] = 5,
  [2] = 6,
  [3] = 7,
  [4] = 8,
  [5] = 9,
  [6] = 10
}

local slider_to_syn = {
  [3] = 7,
  [4] = 0,
  [5] = 1,
  [6] = 2,
  [7] = 3,
  [8] = 4,
  [9] = 5,
  [10] = 6
}

-- Helper Tables for FFT

local fft_to_slider = {
  [0] = 0,
  [32] = 1,
  [64] = 2,
  [96] = 3
}

local fft_names = {
  [0] = "FFT: 32768",
  [1] = "FFT: 16364",
  [2] = "FFT: 8192",
  [3] = "FFT: 4096"
}

local slider_to_fft = {
  [0] = 0,
  [1] = 32,
  [2] = 64,
  [3] = 96
}

-- Helper tables for analysis offset

local ano_to_slider = {
  [0] = 0,
  [8] = 1,
  [16] = 2,
  [24] = 3
}

local ano_names = {
  [0] = "1/2",
  [1] = "1/4",
  [2] = "1/6",
  [3] = "1/8"
}

local slider_to_ano = {
  [0] = 0,
  [1] = 8,
  [2] = 16,
  [3] = 24
}

-- Analysis Window

local anw_to_slider = {
  [0] = 0,
  [128] = 1,
  [256] = 2,
  [384] = 3,
}

local anw_names = {
  [0] = "Blackman-Harris",
  [1] = "Hamming",
  [2] = "Blackman",
  [3] = "Rectangular"
}

local slider_to_anw = {
  [0] = 0,
  [1] = 128,
  [2] = 256,
  [3] = 384
}

-- Synthesis Window

local syw_to_slider = {
  [0] = 0,
  [512] = 1,
  [1024] = 2,
  [1536] = 3,
}

local syw_names = {
  [0] = "Blackman-Harris",
  [1] = "Hamming",
  [2] = "Blackman",
  [3] = "Triangular"
}

local slider_to_syw = {
  [0] = 0,
  [1] = 512,
  [2] = 1024,
  [3] = 1536
}


reastretch = {
  window_title = "ReaStretch",
  enabled = false,
  syn = 0,
  ano = 0,
  fft = 0,
  anw = 0,
  syw = 0
}

local can_space = true
ctx = reaper.ImGui_CreateContext(reastretch.window_title)

function main()
  item_count = reaper.CountSelectedMediaItems(0)
  
  if item_count > 0 then
    item = reaper.GetSelectedMediaItem(0, 0)
    take = reaper.GetTake(item, 0)
    source = reaper.GetMediaItemTake_Source(take)
    source_length = reaper.GetMediaSourceLength(source)
    
    pitchmode = reaper.GetMediaItemTakeInfo_Value(take, "I_PITCHMODE")
    mode = (pitchmode >> 16) & 0xFFFF
    parms = pitchmode & 0xFFFF
    
    if mode == 14 then
      reastretch.enabled = true
    else
      reastretch.enabled = false
    end
    
    rv, reastretch.enabled = reaper.ImGui_Checkbox(ctx, "Enable Rrreeeaaa", reastretch.enabled)

    if reastretch.enabled then
      -- Read values
      reastretch.rate = 1 / reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
 
      reastretch.syn = parms & bitmask.syn
      reastretch.ano = parms & bitmask.ano
      reastretch.fft = parms & bitmask.fft
      reastretch.anw = parms & bitmask.anw
      reastretch.syw = parms & bitmask.syw
      
      reaper.ImGui_Text(ctx, "")
      
      rv, reastretch.rate = reaper.ImGui_SliderDouble(ctx, "Playrate", reastretch.rate, 0.5, 100, "%fx")
      reastretch.rate = 1 / reastretch.rate
      
      syn_slider = syn_to_slider[reastretch.syn]
      rv, syn_slider = reaper.ImGui_SliderInt(ctx, "Synthesis", syn_slider, 3, 10, "%dx")
      reastretch.syn = slider_to_syn[syn_slider]
      
      reaper.ImGui_Text(ctx, "")
      
      fft_slider = fft_to_slider[reastretch.fft]
      rv, fft_slider  = reaper.ImGui_SliderInt(ctx, "FFT", fft_slider, 0, 3, fft_names[fft_slider])
      reastretch.fft = slider_to_fft[fft_slider]
      
      ano_slider = ano_to_slider[reastretch.ano]
      rv, ano_slider = reaper.ImGui_SliderInt(ctx, "Analysis Offset", ano_slider, 0, 3, ano_names[ano_slider])
      reastretch.ano = slider_to_ano[ano_slider]
      
      anw_slider = anw_to_slider[reastretch.anw]
      rv, anw_slider = reaper.ImGui_SliderInt(ctx, "Analysis Window", anw_slider, 0, 3, anw_names[anw_slider])
      reastretch.anw = slider_to_anw[anw_slider]
      
      syw_slider = syw_to_slider[reastretch.syw]
      rv, syw_slider = reaper.ImGui_SliderInt(ctx, "Synthesis Window", syw_slider, 0, 3, syw_names[syw_slider])
      reastretch.syw = slider_to_syw[syw_slider]
      
      -- Collect all shifter data and write at end of loop
      md = 14 << 16
      md = md + reastretch.syn
      md = md + reastretch.ano
      md = md + reastretch.fft
      md = md + reastretch.anw
      md = md + reastretch.syw
      
      reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", reastretch.rate)
      reaper.SetMediaItemLength(item, source_length * (1 / reastretch.rate), false)
      reaper.UpdateArrange()
    else
      md = -1
    end
    
    reaper.SetMediaItemTakeInfo_Value(take, "I_PITCHMODE", md)
    
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Space()) and can_space then
      can_space = false
      reaper.Main_OnCommand(40044, 0) -- Transport: Play/stop
    end
    
    if reaper.ImGui_IsKeyReleased(ctx, reaper.ImGui_Key_Space()) then
      can_space = true
    end
    
  else
    reaper.ImGui_Text(ctx, "Please select a Media Item to stretch!")
  end
  
end

function loop()
    reaper.ImGui_SetNextWindowSize(ctx, 400, 400, reaper.ImGui_Cond_FirstUseEver())
    local visible, open = reaper.ImGui_Begin(ctx, reastretch.window_title, true)
    if visible then
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 5, 5)
        main()
        reaper.ImGui_PopStyleVar(ctx)
        reaper.ImGui_End(ctx)
    end

    if open then reaper.defer(loop) end
end

reaper.defer(loop)

