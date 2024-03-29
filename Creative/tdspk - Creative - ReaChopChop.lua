--@description ReaChopChop
--@version 1.0.1
--@author Tadej Supukovic (tdspk)
--@about
--  # ReaChopChop
--  Chop your items and randomize the leftovers
--  # Requirements
--  JS_ReaScriptAPI, SWS Extension, ReaImGui
--@links
--  Website https://www.tdspkaudio.com
--@donation
--  https://ko-fi.com/tdspkaudio
--  https://coindrop.to/tdspkaudio
--@changelog
--  Added Randomize option
--  First version

dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

window_title = "tdspk - ReaChopChop"

data = {
  chop_amt = 1,
  rnd_length = 0,
  rnd_offset = 0,
  rnd_rev = 0,
  rnd_pitch = 0,
  pitch_range = 1
}

function map(x, in_min, in_max, out_min, out_max)
  return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

function CacheSelectedMediaItems()
  item_count = reaper.CountSelectedMediaItems(0)
  
  items = {}
  -- iterate all selected items and save them into a table
  for i=0, item_count - 1 do
    item = reaper.GetSelectedMediaItem(0, i)
    table.insert(items, item)
  end
  
  -- Unselect all media items
  for k, item in pairs(items) do
    reaper.SetMediaItemSelected(item, false)
  end
end

-- Linear vs recursive
-- Precise vs Sloppy (nudge)

local ctx = reaper.ImGui_CreateContext(window_title)
local font = reaper.ImGui_CreateFont("sans-serif", 16)
reaper.ImGui_Attach(ctx, font)

function Main()
  reaper.ImGui_PushFont(ctx, font)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 10, 10)
  
  item_count = reaper.CountSelectedMediaItems(0)

  if item_count > 0 then
    if item_count < 100 then
      reaper.ImGui_Text(ctx, item_count .. " Media Items selected")
    else
      reaper.ImGui_Text(ctx, item_count .. " Media Items selected??? Don't be silly.")
    end

    rv, data.chop_amt = reaper.ImGui_SliderInt(ctx, "Chop Amount", data.chop_amt, 1, 50)
    reaper.ImGui_Separator(ctx)
    rv, data.rnd_length = reaper.ImGui_SliderDouble(ctx, "Randomize Length", data.rnd_length, 0, 1)
    rv, data.rnd_offset = reaper.ImGui_SliderDouble(ctx, "Randomize Offset", data.rnd_offset, 0, 1)
    rv, data.rnd_rev = reaper.ImGui_SliderDouble(ctx, "Randomize Reverse", data.rnd_rev, 0, 1)
    reaper.ImGui_Separator(ctx)
    rv, data.pitch_range = reaper.ImGui_SliderDouble(ctx, "Pitch Range", data.pitch_range, 0, 12)
    rv, data.rnd_pitch = reaper.ImGui_SliderDouble(ctx, "Randomize Pitch", data.rnd_pitch, 0, 1)
    
    if reaper.ImGui_Button(ctx, "Randomize Parameters") then
      data.chop_amt = math.floor(math.random() * 50)
      if data.chop_amt <= 0 then data.chop_amt = 1 end
      data.rnd_length = math.random()
      data.rnd_offset = math.random()
      data.rnd_rev = math.random()
      data.rnd_pitch = math.random()
      data.pitch_range = math.random() * 12
    end
    
    reaper.ImGui_Separator(ctx)
    
    if reaper.ImGui_Button(ctx, "Chop Chop!") then
      CacheSelectedMediaItems()
      for k, item in pairs(items) do
        reaper.SetMediaItemSelected(item, true)
        Chop(item, interval)
      end
      
      reaper.UpdateArrange()
    end
  else
    reaper.ImGui_Text(ctx, "Select a Media Item to chop")
  end
  
  reaper.ImGui_PopStyleVar(ctx)
  reaper.ImGui_PopFont(ctx)
  reaper.ImGui_End(ctx)
end

function Chop(item, interval)
  item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  interval = item_length / (data.chop_amt + 1)
  
  -- Chop equally iterating chop interval
  for i=1, data.chop_amt + 1 do
    --rh_item = reaper.SplitMediaItem(item, 
    item_pos =reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    rh_item = reaper.SplitMediaItem(item, item_pos + interval)
    
    item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    
    rnd = math.random()
    if rnd <= data.rnd_length then
      reaper.SetMediaItemLength(item, item_length * rnd, false)
    end
    
    rnd = math.random()
    if rnd <= data.rnd_offset then
      take = reaper.GetMediaItemTake(item, 0)
      source = reaper.GetMediaItemTake_Source(take)
      source_len = reaper.GetMediaSourceLength(source)
      reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", source_len * rnd)
    end
    
    rnd = math.random()
    if rnd <= data.rnd_rev then
      take = reaper.GetMediaItemTake(item, 0)
      rv, section, start, length, fade = reaper.BR_GetMediaSourceProperties(take)
      rv = reaper.BR_SetMediaSourceProperties(take, section, start, length, fade, true)
    end
    
    rnd = math.random()
    if rnd <= data.rnd_pitch then
      take = reaper.GetMediaItemTake(item, 0)
      pitch = map(rnd, 0, 1, -data.pitch_range, data.pitch_range)
      reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH", pitch)
    end
    
    item = rh_item
  end
end

function Menu()
  if reaper.ImGui_BeginMenuBar(ctx) then 
    if reaper.ImGui_BeginMenu(ctx, "Info", true) then
      local info = {
        "ReaChopChop",
        "A tool by tdspk"
      }
      
      for _, v in ipairs(info) do
        reaper.ImGui_MenuItem(ctx, v, "", false, false)
      end
      
      reaper.ImGui_Separator(ctx)
      
      if reaper.ImGui_MenuItem(ctx, "Website") then
        reaper.CF_ShellExecute("https://www.tdspkaudio.com")
      end
      
      if reaper.ImGui_MenuItem(ctx, "Donate") then
        reaper.CF_ShellExecute("https://coindrop.to/tdspkaudio")
      end
      
      if reaper.ImGui_MenuItem(ctx, "GitHub Repository") then
        reaper.CF_ShellExecute("https://github.com/tdspk/ReaScripts")
      end
      
      reaper.ImGui_EndMenu(ctx)
    end
    
    reaper.ImGui_EndMenuBar(ctx)
  end
end

local function Loop()
  reaper.ImGui_SetNextWindowSize(ctx, 450, 400)
  local visible, open = reaper.ImGui_Begin(ctx, window_title, true, reaper.ImGui_WindowFlags_MenuBar())
  if visible then
    Menu()
    Main()
  end
  if open then
    reaper.defer(Loop)
  end
end

math.randomseed(os.time())
Loop()
