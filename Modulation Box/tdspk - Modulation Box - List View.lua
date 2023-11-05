dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')(
    '0.8')

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

ctx = reaper.ImGui_CreateContext("Modulation Box")

mbox = {window_title = "Modulation Box"}

function RGBToInt(r, g, b, a)
  return reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a or 1.0)
end

function main()
    reaper.ImGui_TreeNodeFlags_DefaultOpen()
    RenderList()
end

function loop()
    reaper.ImGui_SetNextWindowSize(ctx, 600, 600,
                                   reaper.ImGui_Cond_FirstUseEver())
    local visible, open = reaper.ImGui_Begin(ctx, mbox.window_title, true)
    if visible then
        -- reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), style.item_spacing_x, style.item_spacing_y)
        main()
        -- reaper.ImGui_PopStyleVar(ctx)
        reaper.ImGui_End(ctx)
    end

    if open then reaper.defer(loop) end
end

reaper.defer(loop)

function RenderList()
    -- table for tracking tracks with modulated parameters
    tracks = {}

    -- iterate all tracks
    for track_id = 0, reaper.CountTracks(0) - 1 do
        track = reaper.GetTrack(0, track_id)
        rv, track_name = reaper.GetTrackName(track)
        track_info = {name = track_name, track_ref = track}

        -- table for tracking fx with modulated parameters
        fxs = {}

        -- Get modulated parameter per track fx
        for fx_id = 0, reaper.TrackFX_GetCount(track) do
            rv, fx_name = reaper.TrackFX_GetFXName(track, fx_id)

            fx_info = {name = fx_name, id = fx_id}

            param_table = {}

            for p_id = 0, reaper.TrackFX_GetNumParams(track, fx_id) do
                -- check if fx parameter has modulators: LFO, ACS, or link
                -- if so, add them to a table. Populate tree if table is not empty
                rv, p_name = reaper.TrackFX_GetParamName(track, fx_id, p_id)
                found = false
                param_info = {
                    name = p_name,
                    id = p_id,
                    mod = false,
                    lfo = false,
                    acs = false
                }

                rv, mod = reaper.TrackFX_GetNamedConfigParm(track, fx_id,
                                                            "param." .. p_id ..
                                                                ".mod.active")
                rv, acs = reaper.TrackFX_GetNamedConfigParm(track, fx_id,
                                                            "param." .. p_id ..
                                                                ".acs.active")
                rv, lfo = reaper.TrackFX_GetNamedConfigParm(track, fx_id,
                                                            "param." .. p_id ..
                                                                ".lfo.active")

                if mod == "1" then found = true end

                if lfo == "1" then param_info.lfo = true end

                if acs == "1" then param_info.acs = true end

                if (found) then
                    table.insert(param_table, param_info)
                end
            end

            if #param_table > 0 then
                fx_info["params"] = param_table
                table.insert(fxs, fx_info)
            end
        end

        if #fxs > 0 then
            -- if fx has mods...
            track_info["fx"] = fxs
            table.insert(tracks, track_info)
        end
    end

    -- Build Tree based on tracks table

    for k, track_info in pairs(tracks) do
        reaper.ImGui_SetNextItemOpen(ctx, true, reaper.ImGui_Cond_Once())

        if reaper.ImGui_TreeNode(ctx, track_info.name) then
            for k, fx_info in pairs(track_info.fx) do
                reaper.ImGui_SetNextItemOpen(ctx, true, reaper.ImGui_Cond_Once())
            
                if reaper.ImGui_TreeNode(ctx, fx_info.id + 1 .. " " .. fx_info.name) then
                    reaper.ImGui_SameLine(ctx)
                    
                    if reaper.ImGui_SmallButton(ctx, "FX") then
                        reaper.TrackFX_SetOpen(track_info.track_ref, fx_info.id, true)
                    end

                    for k, param_info in pairs(fx_info.params) do
                        if reaper.ImGui_SmallButton(ctx, param_info.name) then
                          val = reaper.TrackFX_GetParam(track_info.track_ref, fx_info.id, param_info.id)
                          reaper.TrackFX_SetParam(track_info.track_ref, fx_info.id, param_info.id, val)
                          reaper.Main_OnCommand(41143, 0) -- FX: Show parameter modulation/link for last touched FX parameter
                        end
                        
                        reaper.ImGui_SameLine(ctx)
                        
                        if param_info.lfo then
                          btn_color = RGBToInt(0, 1, 0, 1)
                          text_color = RGBToInt(0, 0, 0, 1)
                          next_state = "0"
                        else
                          btn_color = RGBToInt(1, 0, 0, 1)
                          text_color = RGBToInt(1, 1, 1, 1)
                          next_state = "1"
                        end
                        
                        PushModButtonColors("lfo_btn" .. param_info.id)
                        
                        if reaper.ImGui_SmallButton(ctx, "LFO") then
                          -- toggle LFO for pressed parameter
                          reaper.TrackFX_SetNamedConfigParm(track_info.track_ref, fx_info.id, "param." .. param_info.id .. ".lfo.active", next_state)
                        end
                        
                        PopStyleColors()
                        
                        reaper.ImGui_SameLine(ctx)
                        
                        if param_info.acs then
                          btn_color = RGBToInt(0, 1, 0, 1)
                          text_color = RGBToInt(0, 0, 0, 1)
                          next_state = "0"
                        else
                          btn_color = RGBToInt(1, 0, 0, 1)
                          text_color = RGBToInt(1, 1, 1, 1)
                          next_state = "1"
                        end
                        
                        PushModButtonColors("acs_btn" .. param_info.id)
                        
                        if reaper.ImGui_SmallButton(ctx, "ACS") then
                          -- toggle LFO for pressed parameter
                          reaper.TrackFX_SetNamedConfigParm(track_info.track_ref, fx_info.id, "param." .. param_info.id .. ".acs.active", next_state)
                        end
                        
                        PopStyleColors()
                        
                    end

                    reaper.ImGui_TreePop(ctx)
                end
            end

            reaper.ImGui_TreePop(ctx)
        end

    end
end

function PushModButtonColors(str_id)
  style_counter  = 4
  reaper.ImGui_PushID(ctx, str_id)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), btn_color)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), btn_color)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), btn_color)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), text_color)
end

function PopStyleColors()
  for i=0,style_counter-1 do
    reaper.ImGui_PopStyleColor(ctx)
  end
  reaper.ImGui_PopID(ctx)
end