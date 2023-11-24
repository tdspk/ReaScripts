dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

bitmask = {
  -- Rrreeeaaa
  syn = 7,    -- 0000 0000 0111
  ano = 24,   -- 0000 0001 1000
  fft = 96,   -- 0000 0110 0000
  anw = 384,  -- 0001 0000 0000
  syw = 1536, -- 0110 0000 0000
  -- ReaReaRea
  rnd = 15,   -- 0000 0000 1111
  fdm = 1008,  -- 0011 1111 0000
  shp = 3072  -- 1100 0000 0000
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

-- ReaReaRea Randomize
local rnd_names = {
  [0] = "0",
  [1] = "6",
  [2] = "12",
  [3] = "18",
  [4] = "25",
  [5] = "31",
  [6] = "37",
  [7] = "43",
  [8] = "50",
  [9] = "52",
  [10] = "62",
  [11] = "68",
  [12] = "75",
  [13] = "81",
  [14] = "87",
  [15] = "93"
}

local fdm_to_slider = {
  -- Shorter Fade Times
  [912] = 0,
  [928] = 1,
  [944] = 2,
  [960] = 3,
  [972] = 4,
  [992] = 5,
  [1008] = 6,
  [0] = 7,
  [16] = 8,
  [32] = 9,
  [48] = 10,
  [64] = 11,
  [80] = 12,
  [96] = 13,
  [112] = 14,
  [128] = 15,
  [144] = 16,
  [160] = 17,
  [176] = 18,
  [192] = 19,
  -- Longer Fade Times
  [208] = 20,
  [224] = 21,
  [240] = 22,
  [256] = 23,
  [272] = 24,
  [288] = 25,
  [304] = 26,
  [320] = 27,
  [336] = 28,
  [352] = 29,
  [368] = 30,
  [384] = 31,
  [400] = 32,
  [416] = 33,
  [432] = 34,
  [448] = 35,
  [464] = 36,
  [480] = 37,
  [496] = 38,
  [512] = 39,
  [528] = 40,
  [544] = 41,
  [560] = 42,
  [576] = 43,
  [592] = 44,
  [608] = 45,
  [624] = 46,
  [640] = 47,
  [656] = 48,
  [672] = 49,
  [688] = 50,
  [704] = 51,
  [720] = 52,
  [736] = 53,
  [752] = 54,
  [768] = 55,
  [784] = 56,
  [800] = 57,
  [816] = 58,
  [832] = 59,
  [848] = 60,
  [864] = 61,
  [880] = 62,
  [896] = 63
}

local fdm_names = {
  -- Shorter Fade times
  [0] = "2 ms",
  [1] = "4 ms",
  [2] = "6 ms",
  [3] = "8 ms",
  [4] = "12 ms",
  [5] = "24 ms",
  [6] = "36 ms",
  [7] = "48 ms",
  [8] = "60 ms",
  [9] = "72 ms",
  [10] = "84 ms",
  [11] = "96 ms",
  [12] = "108 ms",
  [13] = "120 ms",
  [14] = "132 ms",
  [15] = "144 ms",
  [16] = "156 ms",
  [17] = "168 ms",
  [18] = "180 ms",
  [19] = "192 ms",
  -- Longer Fade Times
  [20] = "204 ms",
  [21] = "216 ms",
  [22] = "228 ms",
  [23] = "240 ms",
  [24] = "252 ms",
  [25] = "264 ms",
  [26] = "276 ms",
  [27] = "288 ms",
  [28] = "300 ms",
  [29] = "312 ms",
  [30] = "324 ms",
  [31] = "336 ms",
  [32] = "348 ms",
  [33] = "360 ms",
  [34] = "372 ms",
  [35] = "384 ms",
  [36] = "396 ms",
  [37] = "408 ms",
  [38] = "420 ms",
  [39] = "432 ms",
  [40] = "448 ms",
  [41] = "472 ms",
  [42] = "496 ms",
  [43] = "520 ms",
  [44] = "544 ms",
  [45] = "568 ms",
  [46] = "592 ms",
  [47] = "616 ms",
  [48] = "640 ms",
  [49] = "664 ms",
  [50] = "688 ms",
  [51] = "712 ms",
  [52] = "736 ms",
  [53] = "760 ms",
  [54] = "784 ms",
  [55] = "808 ms",
  [56] = "832 ms",
  [57] = "856 ms",
  [58] = "880 ms",
  [59] = "904 ms",
  [60] = "928 ms",
  [61] = "952 ms",
  [62] = "976 ms",
  [63] = "1000 ms"
}

local slider_to_fdm = {
  -- Shorter Fade Times
  [0] = 912,
  [1] = 928,
  [2] = 944,
  [3] = 960,
  [4] = 972,
  [5] = 992,
  [6] = 1008,
  [7] = 0,
  [8] = 16,
  [9] = 32,
  [10] = 48,
  [11] = 64,
  [12] = 80,
  [13] = 96,
  [14] = 112,
  [15] = 128,
  [16] = 144,
  [17] = 160,
  [18] = 176,
  [19] = 192,
  -- Longer Fade Times
  [20] = 208,
  [21] = 224,
  [22] = 240,
  [23] = 256,
  [24] = 272,
  [25] = 288,
  [26] = 304,
  [27] = 320,
  [28] = 336,
  [29] = 352,
  [30] = 368,
  [31] = 384,
  [32] = 400,
  [33] = 416,
  [34] = 432,
  [35] = 448,
  [36] = 464,
  [37] = 480,
  [38] = 496,
  [39] = 512,
  [40] = 528,
  [41] = 544,
  [42] = 560,
  [43] = 576,
  [44] = 592,
  [45] = 608,
  [46] = 624,
  [47] = 640,
  [48] = 656,
  [49] = 672,
  [50] = 688,
  [51] = 704,
  [52] = 720,
  [53] = 736,
  [54] = 752,
  [55] = 768,
  [56] = 784,
  [57] = 800,
  [58] = 816,
  [59] = 832,
  [60] = 848,
  [61] = 864,
  [62] = 880,
  [63] = 896
}

shp_to_slider = {
  [0] = 0,
  [1024] = 1,
  [2048] = 2
}

shp_names = {
  [0] = "sin",
  [1] = "linear",
  [2] = "rectangular"
}

slider_to_shp = {
  [0] = 0,
  [1] = 1024,
  [2] = 2048
}

reastretch = {
  window_title = "ReaStretch",
  mode = -1,
  enabled = false,
  -- Rrreeeaaa Parameters
  syn = 0,
  ano = 0,
  fft = 0,
  anw = 0,
  syw = 0,
  -- ReaReaRea parameters
  rnd = 0,
  fdm = 0,
  shp = 0
}

local can_space = true
ctx = reaper.ImGui_CreateContext(reastretch.window_title)

function MainWindow()
  item_count = reaper.CountSelectedMediaItems(0)
  
  if item_count > 0 then
    item = reaper.GetSelectedMediaItem(0, 0)
    take = reaper.GetTake(item, 0)
    source = reaper.GetMediaItemTake_Source(take)
    source_length = reaper.GetMediaSourceLength(source)
    
    pitchmode = reaper.GetMediaItemTakeInfo_Value(take, "I_PITCHMODE")
    reastretch.mode = (pitchmode >> 16) & 0xFFFF
    
    if reastretch.mode ~= 14 and reastretch.mode ~= 15 then
      reastretch.mode = -1
    end
    
    changed = false
    
    rv, reastretch.mode = reaper.ImGui_RadioButtonEx(ctx, "Off", reastretch.mode, -1)
    changed = changed or rv
    
    reaper.ImGui_SameLine(ctx)
    rv, reastretch.mode = reaper.ImGui_RadioButtonEx(ctx, "Rrreeeaaa", reastretch.mode, 14)
    changed = changed or rv
    
    reaper.ImGui_SameLine(ctx)
    rv, reastretch.mode = reaper.ImGui_RadioButtonEx(ctx, "ReaReaRea", reastretch.mode, 15)
    changed = changed or rv

    if reastretch.mode == 14 then
      RenderCommonParameters()
      RenderRrreeeaaa()
    elseif reastretch.mode == 15 then
      RenderCommonParameters()
      RenderReaReaRea()
    else
      md = -1
    end
    
    if changed then
      reaper.SetMediaItemTakeInfo_Value(take, "I_PITCHMODE", md)
    end
    
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

function RenderCommonParameters()
  parms = pitchmode & 0xFFFF
  -- Read values
  reastretch.rate = 1 / reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
  rv, reastretch.rate = reaper.ImGui_SliderDouble(ctx, "Playrate", reastretch.rate, 0.5, 100, "%fx")
  reastretch.rate = 1 / reastretch.rate
  
  changed = changed or rv
end

function RenderRrreeeaaa()
  -- Get values from &ing with bitmask
  reastretch.syn = parms & bitmask.syn
  reastretch.ano = parms & bitmask.ano
  reastretch.fft = parms & bitmask.fft
  reastretch.anw = parms & bitmask.anw
  reastretch.syw = parms & bitmask.syw
  
  reaper.ImGui_Text(ctx, "")
  
  syn_slider = syn_to_slider[reastretch.syn]
  rv, syn_slider = reaper.ImGui_SliderInt(ctx, "Synthesis", syn_slider, 3, 10, "%dx")
  reastretch.syn = slider_to_syn[syn_slider]
  changed = changed or rv
  
  reaper.ImGui_Text(ctx, "")
  
  fft_slider = fft_to_slider[reastretch.fft]
  rv, fft_slider  = reaper.ImGui_SliderInt(ctx, "FFT", fft_slider, 0, 3, fft_names[fft_slider])
  reastretch.fft = slider_to_fft[fft_slider]
  changed = changed or rv
  
  ano_slider = ano_to_slider[reastretch.ano]
  rv, ano_slider = reaper.ImGui_SliderInt(ctx, "Analysis Offset", ano_slider, 0, 3, ano_names[ano_slider])
  reastretch.ano = slider_to_ano[ano_slider]
  changed = changed or rv
  
  anw_slider = anw_to_slider[reastretch.anw]
  rv, anw_slider = reaper.ImGui_SliderInt(ctx, "Analysis Window", anw_slider, 0, 3, anw_names[anw_slider])
  reastretch.anw = slider_to_anw[anw_slider]
  changed = changed or rv
  
  syw_slider = syw_to_slider[reastretch.syw]
  rv, syw_slider = reaper.ImGui_SliderInt(ctx, "Synthesis Window", syw_slider, 0, 3, syw_names[syw_slider])
  reastretch.syw = slider_to_syw[syw_slider]
  changed = changed or rv
  
  -- Collect all shifter data and write at end of loop
  md = 14 << 16
  md = md + reastretch.syn
  md = md + reastretch.ano
  md = md + reastretch.fft
  md = md + reastretch.anw
  md = md + reastretch.syw
  
  if changed then
    reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", reastretch.rate)
    reaper.SetMediaItemLength(item, source_length * (1 / reastretch.rate), false)
    reaper.UpdateArrange()
  end
end

function RenderReaReaRea()
  reastretch.rnd = parms & bitmask.rnd
  reastretch.fdm = parms & bitmask.fdm
  reastretch.shp = parms & bitmask.shp
  
  fdm_slider = fdm_to_slider[reastretch.fdm]
  rv, fdm_slider = reaper.ImGui_SliderInt(ctx, "Fade", fdm_slider, 0, 63, fdm_names[fdm_slider])
  reastretch.fdm = slider_to_fdm[fdm_slider]
  changed = changed or rv
  
  rv, reastretch.rnd = reaper.ImGui_SliderInt(ctx, "Randomize", reastretch.rnd, 0, 15, rnd_names[reastretch.rnd])
  changed = changed or rv
  
  shp_slider = shp_to_slider[reastretch.shp]
  rv, shp_slider = reaper.ImGui_SliderInt(ctx, "Shape", shp_slider, 0, 2, shp_names[shp_slider])
  reastretch.shp = slider_to_shp[shp_slider]
  changed = changed or rv
  
  md = 15 << 16
  md = md + reastretch.rnd
  md = md + reastretch.fdm
  md = md + reastretch.shp
  
  if changed then
    reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", reastretch.rate)
    reaper.SetMediaItemLength(item, source_length * (1 / reastretch.rate), false)
    reaper.UpdateArrange()
  end
end

function Loop()
    reaper.ImGui_SetNextWindowSize(ctx, 400, 400, reaper.ImGui_Cond_FirstUseEver())
    local visible, open = reaper.ImGui_Begin(ctx, reastretch.window_title, true)
    if visible then
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 5, 5)
        MainWindow()
        reaper.ImGui_PopStyleVar(ctx)
        reaper.ImGui_End(ctx)
    end

    if open then reaper.defer(Loop) end
end

reaper.defer(Loop)
