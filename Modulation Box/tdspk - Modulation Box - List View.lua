dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

ctx = reaper.ImGui_CreateContext("Modulation Box - List View")

mbox = {
  window_title = "Modulation Box - List View"
}

function main()
  reaper.ImGui_TreeNodeFlags_DefaultOpen()
  RenderList()
end

function loop()
  reaper.ImGui_SetNextWindowSize(ctx, 600, 600, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, mbox.window_title, true)
  if visible then
    --reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), style.item_spacing_x, style.item_spacing_y)
    main()
    --reaper.ImGui_PopStyleVar(ctx)
    reaper.ImGui_End(ctx)
  end

  if open then
    reaper.defer(loop)
  end
end

reaper.defer(loop)

function RenderList()
    -- Iterate track list
    for track_id=0,reaper.CountTracks(0)-1 do
      track = reaper.GetTrack(0, track_id)
      rv, track_name = reaper.GetTrackName(track)
      
      reaper.ImGui_SetNextItemOpen(ctx, true, reaper.ImGui_Cond_Once())
      if reaper.ImGui_TreeNode(ctx, track_name) then
        -- Get modulated parameter per track fx
        for fx_id=0, reaper.TrackFX_GetCount(track) do
          rv, fx_name = reaper.TrackFX_GetFXName(track, fx_id)
          param_table = {}
          
          for p_id=0, reaper.TrackFX_GetNumParams(track, fx_id) do
            -- check if fx parameter has modulators: LFO, ACS, or link
            -- if so, add them to a table. Populate tree if table is not empty
            rv, p_name = reaper.TrackFX_GetParamName(track, fx_id, p_id)
            found = false
            param_info = {
              name = p_name,
              id = p_id,
              mod = 0,
              lfo = 0,
              acs = 0
            }
            
            rv, mod = reaper.TrackFX_GetNamedConfigParm(track, fx_id, "param." .. p_id .. ".mod.active")
            rv, acs = reaper.TrackFX_GetNamedConfigParm(track, fx_id, "param." .. p_id .. ".acs.active")
            rv, lfo = reaper.TrackFX_GetNamedConfigParm(track, fx_id, "param." .. p_id .. ".lfo.active")
            
            if mod == "1" then
              found = true
            end
            
            if lfo == "1" then
              param_info.lfo = true
            end
            
            if acs == "1" then
              param_info.acs = true
            end
            
            if (found) then
              table.insert(param_table, param_info)
            end
          end
          
          if #param_table > 0 then
            -- populate tree
            reaper.ImGui_SetNextItemOpen(ctx, true, reaper.ImGui_Cond_Once())
            if reaper.ImGui_TreeNode(ctx, fx_name) then
              if reaper.ImGui_Button(ctx, "Open FX") then
                reaper.TrackFX_SetOpen(track, fx_id, true)
              end
              
              -- iterate fx parameter table

              for k,v in pairs(param_table) do

                if reaper.ImGui_Button(ctx, v.name, 100) then
                  val = reaper.TrackFX_GetParam(track, fx_id, v.id)
                  reaper.TrackFX_SetParam(track, fx_id, v.id, val)
                  reaper.Main_OnCommand(41143, 0)
                end
                reaper.ImGui_SameLine(ctx)
                
                --Push button style for LFO Button
                
                reaper.ImGui_SmallButton(ctx, "ACS")
                reaper.ImGui_SameLine(ctx)
                
                --Push button style for LFO Button
                if v.lfo then
                  reaper.ImGui_PushID(ctx, "lfo_btn")
                  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0)
                  reaper.ImGui_SmallButton(ctx, "LFO")
                  reaper.ImGui_PopStyleColor(ctx)
                  reaper.ImGui_PopID(ctx)
                else
                  reaper.ImGui_SmallButton(ctx, "LFO")
                end
                
                
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_SmallButton(ctx, "X") then
                  reaper.TrackFX_SetNamedConfigParm(track, fx_id, "param." .. v.id .. ".mod.active", "0")
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
