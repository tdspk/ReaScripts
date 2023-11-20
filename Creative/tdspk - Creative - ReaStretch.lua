params = {
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
  syn_bh = 0,
  syn_ham = 512,
  syn_bman = 1024,
  syn_bman = 1536 
}

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
  
  an_off = low_bytes & 0xFF
  fft = (low_bytes >> 4) & 0xFF
  
end
