local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

local ctx = reaper.ImGui_CreateContext('Modulation Box - GUI')

fx_data = {}

ui = {tracks = {}, selected_track = 0, selected_fx = nil, selected_param = nil}

local function CacheTracks()
    ui.tracks = {}

    -- iterate all tracks and add to ui.tracks array
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        local _, track_name = reaper.GetTrackName(track)
        table.insert(ui.tracks, track_name)
    end
end

local function CacheTrackFxData()
    fx_data = {}

    local track = reaper.GetTrack(0, ui.selected_track)

    -- iterate all fx and add them to data array
    for i = 0, reaper.TrackFX_GetCount(track) - 1 do
        -- iterate all params from each fx
        local fx_params = {}

        for j = 0, reaper.TrackFX_GetNumParams(track, i) - 1 do
            -- if param modulation is enabled, add it to the list
            local rv, mod = reaper.TrackFX_GetNamedConfigParm(track, i,
                                                              "param." .. j ..
                                                                  ".mod.active")
            if mod == "1" then
                local rv, pname = reaper.TrackFX_GetParamName(track, i, j)
                local param_info = {name = pname}

                fx_params[j] = param_info
            end
        end

        local rv, fx_name = reaper.TrackFX_GetFXName(track, i)
        local fx_info = {name = fx_name, params = fx_params}
        fx_data[i] = fx_info
    end
end

local function RenderFxList()
    -- iterate fx_data and render the list
    local track = reaper.GetTrack(0, ui.selected_track)

    for fx_id, v in pairs(fx_data) do
        local fx_name = v.name
        reaper.ImGui_Text(ctx, fx_name)

        local counter = 0
        for p_id, v in pairs(v.params) do
            local p_name = v.name

            if reaper.ImGui_Button(ctx, ("%s##%d%d"):format(p_name, fx_id, p_id)) then
                if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then
                    reaper.TrackFX_SetNamedConfigParm(track, fx_id, "param." ..
                                                          p_id .. ".mod.active",
                                                      "0")

                    ui.selected_param = nil
                    ui.selected_fx = nil
                else
                    ui.selected_fx = fx_id
                    ui.selected_param = p_id
                end

            end
            counter = counter + 1

            -- do a SameLine until 5 elements have been drawn
            if counter % 5 ~= 0 then reaper.ImGui_SameLine(ctx) end
        end

        if reaper.ImGui_Button(ctx, ("+##%d"):format(fx_id)) then
            reaper.ImGui_OpenPopup(ctx, "Parameter Selection")
        end
        -- open parameter dialog to for param selection
        if reaper.ImGui_BeginPopup(ctx, "Parameter Selection") then
            for j = 0, reaper.TrackFX_GetNumParams(track, fx_id) - 1 do
                local rv, pname = reaper.TrackFX_GetParamName(track, fx_id, j)
                if pname ~= "MIDI" then
                    if reaper.ImGui_Selectable(ctx, pname) then
                        -- enable parameter modulation of selected parameter
                        reaper.TrackFX_SetNamedConfigParm(track, fx_id,
                                                          "param." .. j ..
                                                              ".mod.active", "1")
                    end
                end
            end

            reaper.ImGui_EndPopup(ctx)
        end
    end
end

local function RenderModulation()
    if not ui.selected_fx then return end
    if not ui.selected_param then return end

    local track = reaper.GetTrack(0, ui.selected_track)

    local p_name = fx_data[ui.selected_fx].params[ui.selected_param].name
    reaper.ImGui_Text(ctx, p_name)

    -- create slider for modulation baseline
    -- read parameter modulation baseline value
    local rv, mod = reaper.TrackFX_GetNamedConfigParm(track, ui.selected_fx,
                                                      "param." ..
                                                          ui.selected_param ..
                                                          ".mod.baseline")

    local rv, mod = reaper.ImGui_SliderDouble(ctx, "Baseline", tonumber(mod), 0,
                                              1)
    if rv then
        -- set parameter modulation baseline to mod
        reaper.TrackFX_SetNamedConfigParm(track, ui.selected_fx, "param." ..
                                              ui.selected_param ..
                                              ".mod.baseline", mod)
    end

    -- create checkbox for LFO activation
    local rv, lfo = reaper.TrackFX_GetNamedConfigParm(track, ui.selected_fx,
                                                      "param." ..
                                                          ui.selected_param ..
                                                          ".lfo.active")
    lfo = lfo == "1" and true or false
    
    local rv, lfo = reaper.ImGui_Checkbox(ctx, "LFO", lfo)
    if rv then
        lfo = lfo and 1 or 0
        reaper.TrackFX_SetNamedConfigParm(track, ui.selected_fx, "param." ..
                                              ui.selected_param ..
                                              ".lfo.active", lfo)
    end
end

local function Loop()
    local visible, open = reaper.ImGui_Begin(ctx, 'Modulation Box - GUI', true)
    if visible then
        local child_flags = reaper.ImGui_ChildFlags_Border() |
                                reaper.ImGui_ChildFlags_ResizeX()
        if reaper.ImGui_BeginChild(ctx, "Tracks and FX", 500, 0, child_flags) then
            CacheTracks()
            -- unpack ui.tracks, separate them by \n and null terminate the string
            local track_list = table.concat(ui.tracks, '\0') .. "\0"
            rv, ui.selected_track = reaper.ImGui_Combo(ctx, 'Tracks',
                                                       ui.selected_track,
                                                       track_list, 0)

            if rv then
                ui.selected_fx = nil
                ui.selected_param = nil
            end

            CacheTrackFxData()
            RenderFxList()

            reaper.ImGui_EndChild(ctx)
        end

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_BeginChild(ctx, "Parameter Modulation", nil, nil,
                                   child_flags) then
            RenderModulation()
            reaper.ImGui_EndChild(ctx)
        end

        reaper.ImGui_End(ctx)
    end
    if open then reaper.defer(Loop) end
end

reaper.defer(Loop)
