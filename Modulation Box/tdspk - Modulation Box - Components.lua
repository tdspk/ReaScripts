dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

mod_data = {}
mbox = {}

function QueryModData()
  item_count = 0
  for track_id = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, track_id)
    local rv, tname = reaper.GetTrackName(track)

    track_data = { tname = tname }

    local found = false
    
    for fx_id = 0, reaper.TrackFX_GetCount(track) - 1 do
      local rv, fx_name = reaper.TrackFX_GetFXName(track, fx_id)
      local fx_data = { fname = fx_name, fid = fx_id }
      local param_count = 0

      for param_id = 0, reaper.TrackFX_GetNumParams(track, fx_id) - 1 do
        p = "param." .. param_id
        rv, has_mod = reaper.TrackFX_GetNamedConfigParm(track, fx_id, p .. ".mod.active")

        if has_mod == "1" then
          found = true
          param_count = param_count + 1

          local rv, param_name = reaper.TrackFX_GetParamName(track, fx_id, param_id)
          local rv, fx_name = reaper.TrackFX_GetFXName(track, fx_id)
          
          rv, has_lfo = reaper.TrackFX_GetNamedConfigParm(track, fx_id, p .. ".lfo.active")
          rv, has_acs = reaper.TrackFX_GetNamedConfigParm(track, fx_id, p .. ".acs.active")
          
          local mods = ""
          if has_lfo == "1" then mods = mods .. "~ " end
          if has_acs == "1" then mods = mods .. "/ " end

          fx_data[param_id] = {pname = param_name, pmods = mods}
        end
      end

      if param_count > 0 then
        track_data[fx_id] = fx_data
      end
    end

    if found then
      if reaper.ImGui_TreeNodeEx(ctx, track_id, track_id + 1 .. " - " .. tname, reaper.ImGui_TreeNodeFlags_DefaultOpen()) then
        for k, v in pairs(track_data) do
          if v.fname then
            local fname = v.fname
            local fid = v.fid
            if reaper.ImGui_TreeNodeEx(ctx,fid, fname, reaper.ImGui_TreeNodeFlags_DefaultOpen()) then
              for k, v in pairs(v) do
                if k ~= "fname" and k ~= "fid" then
                  local pid = k
                  local pname = v.pname
                  local display = v.pmods .. pname
                  
                  item_count = item_count + 1
                  if reaper.ImGui_Selectable(ctx, display, mbox.selected_item == item_count) then
                    mbox.track = track
                    mbox.track_name = tname
                    mbox.fx_id = fid
                    mbox.fx_name = fname
                    mbox.param_id = pid
                    mbox.param_name = pname
                    mbox.ready = true
                    mbox.selected_item = item_count
                  end
                end
              end
              reaper.ImGui_TreePop(ctx)
            end

          end
        end
        reaper.ImGui_TreePop(ctx)
      end
    end
  end
end

function QueryLiveFxInfo()
  rv, track_nr, mbox.fx_id, mbox.param_id = reaper.GetLastTouchedFX()

  if rv then
    mbox.track = reaper.GetTrack(0, track_nr - 1)
    rv, mbox.track_name = reaper.GetTrackName(mbox.track)
    rv, mbox.fx_name = reaper.TrackFX_GetNamedConfigParm(mbox.track, mbox.fx_id, "fx_name")
    rv, mbox.param_name = reaper.TrackFX_GetParamName(mbox.track, mbox.fx_id, mbox.param_id)
    mbox.ready = true
  else
    mbox.ready = false
  end
end

function RenderModulationList()
  QueryModData()
end

-- function RenderModulationList()
--   item_count = 0

--   for track_id = 0, reaper.CountTracks(0) - 1 do
--     local track = reaper.GetTrack(0, track_id)
--     local rv, tname = reaper.GetTrackName(track)

--     if reaper.ImGui_TreeNodeEx(ctx, track_id, track_id .. " - " .. tname, reaper.ImGui_TreeNodeFlags_DefaultOpen()) then
--       for fx_id = 0, reaper.TrackFX_GetCount(track) - 1 do
--         local first_pass = true

--         local rv, fx_name = reaper.TrackFX_GetFXName(track, fx_id)

--         for param_id = 0, reaper.TrackFX_GetNumParams(track, fx_id) - 1 do
--           p = "param." .. param_id
--           rv, has_mod = reaper.TrackFX_GetNamedConfigParm(track, fx_id, p .. ".mod.active")

--           if has_mod == "1" then
--             mbox.ready = true
--             item_count = item_count + 1

--             local rv, param_name = reaper.TrackFX_GetParamName(track, fx_id, param_id)
--             local rv, fx_name = reaper.TrackFX_GetFXName(track, fx_id)
--             local rv, track_name = reaper.GetTrackName(track)

--             if reaper.ImGui_Selectable(ctx, fx_name .. " - " .. param_name, mbox.selected_item == item_count) then
--               mbox.track = track
--               mbox.track_name = track_name
--               mbox.fx_id = fx_id
--               mbox.fx_name = fx_name
--               mbox.param_id = param_id
--               mbox.param_name = param_name
--             end
--           end
--         end
--       end
--     end
--     reaper.ImGui_TreePop(ctx)
--   end
-- end

function HSV(h, s, v, a)
  local r, g, b = reaper.ImGui_ColorConvertHSVtoRGB(h, s, v)
  return reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a or 1.0)
end

ctx = reaper.ImGui_CreateContext("Components Test")

function myWindow()
  RenderModulationList()
end

function loop()
  local visible, open = reaper.ImGui_Begin(ctx, "Components Test", true)
  if visible then
    myWindow()
    reaper.ImGui_End(ctx)
  end

  if open then
    reaper.defer(loop)
  end
end

--loop()
--QueryModData()
