dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

local params = {
  rrreeeaaa = 14,

  -- Bits for Synthesis
  syn_3 = 7,
  syn_4 = 0,
  syn_5 = 1,
  syn_6 = 2,
  syn_7 = 3,
  syn_8 = 4,
  syn_9 = 5,
  syn_10 = 6,
  
  -- Bits for Analysis Offset
  ano_12 = 0,
  ano_14 = 8,
  ano_16 = 16,
  ano_18 = 24,
  
  -- Bits for FFT
  fft_32768 = 0,
  fft_16364 = 32,
  fft_8192 = 64,
  fft_4096 = 96,
  
  -- Bits for Analysis Window
  anw_bh = 0,
  anw_ham = 128,
  anw_bman = 256,
  anw_rect = 384,
  
  -- Bits for Synthesis Window
  syw_bh = 0,
  syw_ham = 512,
  syw_bman = 1024,
  syw_rect = 1536 
}

syn_to_slider = {
  [7] = 3,
  [0] = 4,
  [1] = 5,
  [2] = 6,
  [3] = 7,
  [4] = 8,
  [5] = 9,
  [6] = 10
}

slider_to_syn = {
  [3] = 7,
  [4] = 0,
  [5] = 1,
  [6] = 2,
  [7] = 3,
  [8] = 4,
  [9] = 5,
  [10] = 6
}

fft_to_slider = {
  [0] = 0,
  [32] = 1,
  [64] = 2,
  [96] = 3
}

fft_names = {
  [0] = "FFT: 32768",
  [1] = "FFT: 16364",
  [2] = "FFT: 8192",
  [3] = "FFT: 4096"
}

slider_to_fft = {
  [0] = 0,
  [1] = 32,
  [2] = 64,
  [3] = 96
}

ano_names = {
  [0] = "Analysis: 1/2",
  [8] = "Analysis: 1/4",
  [16] = "Analysis: 1/6",
  [24] = "Analysis: 1/8"
}

function extract_bit_values(val, shift)
  return ((val >> shift) % 8) << shift
end

reastretch = {
  window_title = "ReaStretch",
  enabled = false,
  syn = 0,
  ano = 0,
  fft = 0,
  anw = 0,
  syw = 0
}

ctx = reaper.ImGui_CreateContext(reastretch.window_title)


function RGBToInt(r, g, b, a)
  return reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a or 1.0)
end

function main()
  item_count = reaper.CountSelectedMediaItems(0)
  
  if item_count > 0 then
    item = reaper.GetSelectedMediaItem(0, 0)
    take = reaper.GetTake(item, 0)
    source = reaper.GetMediaItemTake_Source(take)
    source_length = reaper.GetMediaSourceLength(source)
    
    dbg = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    
    pitchmode = reaper.GetMediaItemTakeInfo_Value(take, "I_PITCHMODE")
    mode = (pitchmode >> 16) & 0xFFFF
    parms = pitchmode & 0xFFFF
    
    if mode == params.rrreeeaaa then
      reastretch.enabled = true
    else
      reastretch.enabled = false
    end
    
    rv, reastretch.enabled = reaper.ImGui_Checkbox(ctx, "Enable Rrreeeaaa", reastretch.enabled)

    if reastretch.enabled then
      -- Read values
      reastretch.rate = 1 / reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
      reastretch.syn = extract_bit_values(parms, 0)
      reastretch.ano = extract_bit_values(parms, 3)
      reastretch.fft = extract_bit_values(parms, 5)
      reastretch.anw = extract_bit_values(parms, 7)
      reastretch.syw = extract_bit_values(parms, 9)
      
      rv, reastretch.rate = reaper.ImGui_SliderDouble(ctx, "Playrate", reastretch.rate, 0.5, 100, "%fx")
      reastretch.rate = 1 / reastretch.rate
      
      syn_slider = syn_to_slider[reastretch.syn]
      rv, syn_slider = reaper.ImGui_SliderInt(ctx, "Synthesis", syn_slider, 3, 10, "%dx")
      reastretch.syn = slider_to_syn[syn_slider]
      
      fft_slider = fft_to_slider[reastretch.fft]
      rv, fft_slider  = reaper.ImGui_SliderInt(ctx, "FFT", fft_slider, 0, 3, fft_names[fft_slider])
      reastretch.fft = slider_to_fft[fft_slider] 
      
      -- Collect all shifter data and write at end of loop
      md = params.rrreeeaaa << 16
      md = md + reastretch.fft
      md = md + reastretch.syn
      
      
      reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", reastretch.rate)
      reaper.SetMediaItemLength(item, source_length * (1 / reastretch.rate), false)
      reaper.UpdateArrange()
    else
      md = -1
    end
    
    reaper.SetMediaItemTakeInfo_Value(take, "I_PITCHMODE", md)
    -- Check for Space key pressed!!
    
  else
    reaper.ImGui_Text(ctx, "Please select a Media Item to stretch!")
  end
  
  
end

function loop()
    reaper.ImGui_SetNextWindowSize(ctx, 600, 600,
                                   reaper.ImGui_Cond_FirstUseEver())
    local visible, open = reaper.ImGui_Begin(ctx, reastretch.window_title, true)
    if visible then
        -- reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), style.item_spacing_x, style.item_spacing_y)
        main()
        -- reaper.ImGui_PopStyleVar(ctx)
        reaper.ImGui_End(ctx)
    end

    if open then reaper.defer(loop) end
end

reaper.defer(loop)

item_count = reaper.CountSelectedMediaItems(0)

if item_count > 0 then
  item = reaper.GetSelectedMediaItem(0, 0)
  take = reaper.GetTake(item, 0)
  
  pitchmode = reaper.GetMediaItemTakeInfo_Value(take, "I_PITCHMODE")
  
  if pitchmode < 0 then
    dbg_mode = "Default"
    return
  end
  
  low_bytes = pitchmode & 0xFFFF
  high_bytes = (pitchmode >> 16) & 0xFFFF
  
  if high_bytes == 14 then
    dbg_mode = "Rrreeeaaa"
  end
  
  syn = extract_bit_values(low_bytes, 0)
  ano = extract_bit_values(low_bytes, 3)
  fft = extract_bit_values(low_bytes, 5)
  anw = extract_bit_values(low_bytes, 7)
  syw = extract_bit_values(low_bytes, 9)
end

