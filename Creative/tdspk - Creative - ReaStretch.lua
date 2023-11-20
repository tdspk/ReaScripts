dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')(
    '0.8')

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

fft_names = {
  [0] = "FFT: 32768",
  [32] = "FFT: 16364",
  [64] = "FFT: 8192",
  [96] = "FFT: 4096"
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
      -- Display stuff
      reastretch.syn = extract_bit_values(parms, 0)
      reastretch.ano = extract_bit_values(parms, 3)
      reastretch.fft = extract_bit_values(parms, 5)
      reastretch.anw = extract_bit_values(parms, 7)
      reastretch.syw = extract_bit_values(parms, 9)
      
      -- slider enum
      
      reaper.ImGui_Text(ctx, fft_names[reastretch.fft])
      reaper.ImGui_Text(ctx, ano_names[reastretch.ano])
      
      reaper.ImGui_Text(ctx, "FFT")
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_SmallButton(ctx, "32768")
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_SmallButton(ctx, "16384")
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_SmallButton(ctx, "8192")
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_SmallButton(ctx, "4096")
      
      reaper.ImGui_Text(ctx, "Analysis Offset")
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_SmallButton(ctx, "1/2")
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_SmallButton(ctx, "1/4")
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_SmallButton(ctx, "1/6")
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_SmallButton(ctx, "1/8")
      
      -- awindow
      
      -- swindow
      
      reaper.ImGui_Text(ctx, "Synthesis")
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_SliderInt(ctx, "a", 3, 3, 10, "%dx")
    end
    
    if reastretch.enabled then
      md = params.rrreeeaaa << 16
    else
      md = -1
    end
    
    -- Collect all shifter data and write at end of loop
    
    --reaper.SetMediaItemTakeInfo_Value(take, "I_PITCHMODE", md)
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

