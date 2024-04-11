local ctx = reaper.ImGui_CreateContext('Modulation Box - GUI')

modulators = {}
--targets = {}

local add_mode = false

-- tracks > fx > params

local function AddParamToTable(t)
  rv, trackidx, _, _, fxidx, parm = reaper.GetTouchedOrFocusedFX(0)
  
  local track = reaper.GetTrack(0, trackidx)
  
  if not t[trackidx] then
    t[trackidx] = {}
  end
  
  if not t[trackidx][fxidx] then
    t[trackidx][fxidx] = {}
    rv, t[trackidx][fxidx].name = reaper.TrackFX_GetFXName(track, fxidx)
  end
  
  if not t[trackidx][fxidx][parm] then
    t[trackidx][fxidx][parm] = {}
  end
  
  local rv, parmname = reaper.TrackFX_GetParamName(track, fxidx, parm)
  
  t[trackidx][fxidx][parm].name = parmname
end

local function RenderParamTable(t, trackno)
  if t[trackno] then
    local track = reaper.GetTrack(0, trackno)
    
    for fxidx,v in pairs(t[trackno]) do
      reaper.ImGui_Text(ctx, tostring(v.name)) 
      for parmidx, v in pairs(v) do
        if v.name then
          reaper.ImGui_Button(ctx, ("%s##%d.%d"):format(v.name, fxidx, parmidx))
          
          if reaper.ImGui_BeginDragDropSource(ctx, reaper.ImGui_DragDropFlags_None()) then
            -- fxid and param id as payload
            
            reaper.ImGui_SetDragDropPayload(ctx, "DND_LINK", ("%d.%d"):format(fxidx, parmidx))
            reaper.ImGui_Text(ctx, "Link")
            reaper.ImGui_EndDragDropSource(ctx)
          end
          
          if reaper.ImGui_BeginDragDropTarget(ctx) then
            local rv, payload = reaper.ImGui_AcceptDragDropPayload(ctx, "DND_LINK")
            if rv then
              -- get info from payload: which fx and param to link
              local t = {}
              for i in string.gmatch(payload, "([^.]+)") do
                table.insert(t, i)
              end
              local linkfx = t[1]
              local linkparm = t[2]
              
              reaper.TrackFX_SetNamedConfigParm(track, fxidx, ("param.%d.plink.active"):format(parmidx), "1")
              reaper.TrackFX_SetNamedConfigParm(track, fxidx, ("param.%d.plink.effect"):format(parmidx), linkfx)
              reaper.TrackFX_SetNamedConfigParm(track, fxidx, ("param.%d.plink.param"):format(parmidx), linkparm)
              
            end
            reaper.ImGui_EndDragDropTarget(ctx)
          end
          
          reaper.ImGui_SameLine(ctx)
        end
      end
    end
  end
end

local function Loop()
  local visible, open = reaper.ImGui_Begin(ctx, 'Modulation Box - GUI', true)
  if visible then
  
    local sel_track = reaper.GetSelectedTrack(0, 0)
    if sel_track then
      local rv, track_name = reaper.GetTrackName(sel_track)
      local trackno = reaper.GetMediaTrackInfo_Value(sel_track, "IP_TRACKNUMBER") - 1
      
      reaper.ImGui_Text(ctx, "Track: " .. track_name)
      
      --reaper.ImGui_SeparatorText(ctx, "Targets")
      
      -- Render Targets
      --RenderParamTable(targets, trackno)
      
      --if reaper.ImGui_Button(ctx, "+##Target") then
      --  AddParamToTable(targets)
      --  
      --  -- TODO check if target exists in modulators
      --end
      
      reaper.ImGui_SeparatorText(ctx, "Parameters")
      -- Render modulators
      RenderParamTable(modulators, trackno)
      
      if reaper.ImGui_Button(ctx, "+##Modulator") then
        AddParamToTable(modulators)
      end
    else
      reaper.ImGui_Text(ctx, "Select a track to assign modulators")
    end
    
    itempos = {reaper.ImGui_GetItemRectMin(ctx)}
    
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    
    winpos = {reaper.ImGui_GetWindowPos(ctx)}
    reaper.ImGui_SetCursorScreenPos(ctx, winpos[1], winpos[2])
    local posx, posy = reaper.ImGui_GetCursorScreenPos(ctx)
    reaper.ImGui_DrawList_AddLine(draw_list, itempos[1], itempos[2], itempos[1] + 200, itempos[2] + 200, 0xFFFFFFFF)
  
    reaper.ImGui_End(ctx)
  end
  if open then
    reaper.defer(Loop)
  end
end

reaper.defer(Loop)

function table.contains(table, value)
  for i, v in ipairs(table) do
    if v == value then return true end
  end
  
  return false
end
