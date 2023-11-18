-- @description Info Panel (debug)
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @noindex
-- provides [nomain] .

max_font_size = 16
min_font_size = 8
max_height = 50

gfx.init("Modulation Box - Info Panel", 600, max_height)

function run()
  height_ratio = gfx.h / max_height
  font_size = clamp(max_font_size * height_ratio, min_font_size, max_font_size)
  gfx.setfont(1, "Courier New", font_size)
  gfx.x = 0
  gfx.y = 0

  rv, track_nr, fx, param = reaper.GetLastTouchedFX()
  track = reaper.GetTrack(0, track_nr - 1)
  
  if rv then
    rv, track_name = reaper.GetTrackName(track)
    rv, fx_name = reaper.TrackFX_GetFXName(track, tonumber(fx)) 
    rv, param_name = reaper.TrackFX_GetParamName(track, fx, param)
    
    str = "Last Touched: \t" .. fx_name .. " - " .. param_name .. " (Track: " .. track_name .. ")"
    
    gfx.drawstr(str)
    
    gfx.x = 0
    gfx.y = gfx.y + font_size
    
    --[[
    start_x = 0
    start_y = gfx.y
    end_x, end_y = gfx.measurestr(str)
    
    
    if gfx.mouse_cap == 1 then
      if gfx.mouse_x >= start_x and gfx.mouse_y <= end_x and gfx.mouse_y >= start_y and gfx.mouse_y <= end_y then
        reaper.ShowConsoleMsg("Clicked!")
        reaper.TrackFX_Show(track, fx, 1)
      end
    end
    
    ]]--
  end
  
  link_data = reaper.GetExtState("tdspk_mbox", "link_parent")
  if link_data ~= "" then
    data_fx, data_param = string.match(link_data, "(.-);(.+)")
    rv, fx_name = reaper.TrackFX_GetFXName(track, tonumber(data_fx)) 
    rv, param_name = reaper.TrackFX_GetParamName(track, tonumber(data_fx), tonumber(data_param))
    gfx.drawstr("Link Parent:  " .. fx_name .. " - " .. param_name)
  end

  
  lfo_data = reaper.GetExtState("tdspk_mbox", "lfo_data")
  gfx.update()
  
  reaper.defer(run)
end

function clamp(value, min, max)
  if value > max then
    return max
  elseif value < min then
    return min
  else
    return value
  end
end

reaper.defer(run)
