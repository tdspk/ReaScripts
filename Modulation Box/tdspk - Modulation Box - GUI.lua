--@description Modulation Box - GUI
--@version 0.1pre3
--@author Tadej Supukovic (tdspk)
--@about
--  # Modulation Box
--  Work in progress...
--  # Requirements
--  JS_ReaScriptAPI, SWS Extension, ReaImGui
--@links
--  Website https://www.tdspkaudio.com
--  Forum Thread https://www.tdspkaudio.com
--@donation
--  https://ko-fi.com/tdspkaudio
--  https://coindrop.to/tdspkaudio
--@provides
--  [main] .
-- @changelog
--  first draft (0.1pre1)

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

local ctx = reaper.ImGui_CreateContext('Modulation Box - GUI')

fx_data = {}
fx_keys = {}

local color = {
    red = reaper.ImGui_ColorConvertDouble4ToU32(1, 0, 0, 1),
    blue = reaper.ImGui_ColorConvertDouble4ToU32(0, 0.91, 1, 1),
    gray = reaper.ImGui_ColorConvertDouble4ToU32(0.75, 0.75, 0.75, 1),
    green = reaper.ImGui_ColorConvertDouble4ToU32(0, 1, 0, 0.5),
    yellow = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 0, 0.5),
    purple = reaper.ImGui_ColorConvertDouble4ToU32(0.667, 0, 1, 0.5),
    turquois = reaper.ImGui_ColorConvertDouble4ToU32(0, 1, 0.957, 0.5),
    mainfields = reaper.ImGui_ColorConvertDouble4ToU32(0.2, 0.2, 0.2, 1),
    transparent = reaper.ImGui_ColorConvertDouble4ToU32(0, 0, 0, 0),
    black = reaper.ImGui_ColorConvertDouble4ToU32(0, 0, 0, 1),
}

local style = {
    item_spacing_x = 10,
    item_spacing_y = 10,
    big_btn_height = 50,
    frame_rounding = 2,
    frame_border = 1,
    window_rounding = 12,
}


ui = {
    show_settings = false,
    tracks = {},
    selected_track = 0,
    selected_track_ref = nil,
    selected_fx = nil,
    selected_param = nil,
    lfo_map = { "Sine", "Square", "Saw L", "Saw R", "Triangle", "Random" },
    dir_map = { [-1] = "Negative", [0] = "Centered", [1] = "Positive" },
    plot = {
        offset = 1,
        time = 0.0,
        data = reaper.new_array(50)
    },
    param_filter = reaper.ImGui_CreateTextFilter()
}

function map(x, in_min, in_max, out_min, out_max)
    return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

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

    if not ui.selected_track_ref then return end
    -- iterate all fx and add them to data array
    for i = 0, reaper.TrackFX_GetCount(ui.selected_track_ref) - 1 do
        -- iterate all params from each fx
        local fx_params = {}

        for j = 0, reaper.TrackFX_GetNumParams(ui.selected_track_ref, i) - 1 do
            -- if param modulation is enabled, add it to the list
            local rv, mod = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref, i,
                "param." .. j ..
                ".mod.active")
            if mod == "1" then
                local rv, pname = reaper.TrackFX_GetParamName(ui.selected_track_ref, i, j)
                -- get plink effect and param id
                local rv, plink_fx = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref, i,
                    "param." .. j .. ".plink.effect")
                local rv, plink_param = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref, i,
                    "param." .. j .. ".plink.param")
                local rv, plink_scale = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref, i,
                    "param." .. j .. ".plink.scale")

                local plink_fx = tonumber(plink_fx)
                local plink_param = tonumber(plink_param)
                local plink_scale = tonumber(plink_scale)

                local param_info = {
                    name = pname,
                    plink_fx = plink_fx,
                    plink_param = plink_param,
                    plink_scale = plink_scale
                }

                fx_params[j] = param_info
            end
        end

        local rv, fx_name = reaper.TrackFX_GetFXName(ui.selected_track_ref, i)
        local fx_info = { name = fx_name, params = fx_params }
        fx_data[i] = fx_info
    end

    -- sort fx keys for later iteration
    fx_keys = {}
    for k, _ in pairs(fx_data) do
        table.insert(fx_keys, k)
    end
    table.sort(fx_keys)
end

local function DrawModIndicator(val, minval, maxval)
    local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
    -- reaper.ImGui_Text(ctx, ("%d, %d"):format(x, y))
    local drawlist = reaper.ImGui_GetWindowDrawList(ctx)

    val = map(val, minval, maxval, 0, 1)
    local white = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, val)

    reaper.ImGui_DrawList_AddCircleFilled(drawlist, x + 5, y + 5, 8, white, 0)
end

local function GetLinkTargets(in_fx_id, in_p_id)
    local link_targets = {}

    for _, fx_id in ipairs(fx_keys) do
        local v = fx_data[fx_id]
        for p_id, v in pairs(v.params) do
            if v.plink_fx == in_fx_id and v.plink_param == in_p_id then
                local target = { -- TODO use v instead when refactoring?
                    fx_id = fx_id,
                    p_id = p_id,
                    scale = v.plink_scale,
                    name = v.name
                }
                table.insert(link_targets, target)
            end
        end
    end

    return link_targets
end

local function RenderFxList()
    -- table for button coordinate data
    button_data = {}
    local hov_btn = 0
    local btn_id = 0

    for _, fx_id in ipairs(fx_keys) do
        local v = fx_data[fx_id]
        local fx_name = v.name
        reaper.ImGui_SeparatorText(ctx, ("%d - %s"):format(fx_id + 1, fx_name))
        reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)

        if reaper.ImGui_Button(ctx, "Open FX") then
            reaper.TrackFX_SetOpen(ui.selected_track_ref, fx_id, true)
        end

        local counter = 0
        for p_id, v in pairs(v.params) do
            btn_id = btn_id + 1

            local p_name = v.name

            local rv, mod = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref, fx_id,
                "param." .. p_id ..
                ".mod.active")

            if ui.selected_param == p_id then
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),
                    reaper.ImGui_GetStyleColor(ctx, reaper.ImGui_Col_ButtonActive()))
            end

            if mod == "1" then
                local val, minval, maxval = reaper.TrackFX_GetParam(ui.selected_track_ref, fx_id, p_id)
                val = map(val, minval, maxval, 0, 1)
                local col = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, val)
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), 2)
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), col)
            end

            local rv, has_lfo = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref, fx_id,
                "param." .. p_id .. ".lfo.active")
            has_lfo = has_lfo == "1" and "~" or ""
            local rv, has_acs = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref, fx_id,
                "param." .. p_id .. ".acs.active")
            has_acs = has_acs == "1" and "/" or ""
            local link_targets = GetLinkTargets(fx_id, p_id)

            local indicators = ("%s %s"):format(has_acs, has_lfo)

            local btn = reaper.ImGui_Button(ctx, ("%s  %s  ##%d%d"):format(indicators, p_name, fx_id, p_id), 0,
                style.big_btn_height)
            if reaper.ImGui_IsItemHovered(ctx) then hov_btn = btn_id end

            local x, y = reaper.ImGui_GetItemRectMin(ctx)
            local w, h = reaper.ImGui_GetItemRectSize(ctx)
            x = x + w / 2
            local target_y = y + h
            y = y + h
            button_data[btn_id] = { fx_id = fx_id, p_id = p_id, fx_name = fx_name, p_name = p_name, x = x, y = y }

            if hov_btn == btn_id then
                button_data[btn_id].y = target_y
            end

            if #link_targets > 0 then
                reaper.ImGui_SetCursorPos(ctx, x, y)
                local drawlist = reaper.ImGui_GetWindowDrawList(ctx)
                reaper.ImGui_DrawList_AddCircleFilled(drawlist, x, target_y, 8, -- TODO adapt to font-size
                    reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_Text()))
                reaper.ImGui_DrawList_AddText(drawlist, x - 4, target_y - 8, color.black, #link_targets)
            end

            if ui.selected_param == p_id then reaper.ImGui_PopStyleColor(ctx) end
            if mod == "1" then
                reaper.ImGui_PopStyleColor(ctx)
                reaper.ImGui_PopStyleVar(ctx)
            end

            if #link_targets > 0 and reaper.ImGui_BeginPopupContextItem(ctx) then
                reaper.ImGui_Text(ctx, "Link Settings")
                -- iterate link targets and create scale slider for each
                for _, v in ipairs(link_targets) do
                    -- separate by fx
                    local scale = v.scale
                    scale = tonumber(scale) * 100
                    rv, scale = reaper.ImGui_SliderDouble(ctx, ("%s##%d%d"):format(v.name, v.fx_id, v.p_id), scale, -100,
                        100, "%.1f")
                    scale = scale / 100

                    reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)

                    if reaper.ImGui_SmallButton(ctx, ("X##%d%d"):format(v.fx_id, v.p_id)) then
                        reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, v.fx_id,
                            "param." .. v.p_id .. ".plink.active", 0)
                        reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, v.fx_id,
                            "param." .. v.p_id .. ".plink.effect", -1)
                        reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, v.fx_id,
                            "param." .. v.p_id .. ".plink.param", -1)
                    end

                    reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, v.fx_id,
                        "param." .. v.p_id .. ".plink.scale", scale)
                end
                reaper.ImGui_EndPopup(ctx)
            end

            if reaper.ImGui_BeginDragDropSource(ctx, reaper.ImGui_DragDropFlags_None()) then
                -- fxid and param id as payload

                reaper.ImGui_SetDragDropPayload(ctx, "DND_LINK", ("%d.%d"):format(fx_id, p_id))
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

                    reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, fx_id,
                        ("param.%d.plink.active"):format(p_id), "1")
                    reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, fx_id,
                        ("param.%d.plink.effect"):format(p_id), linkfx)
                    reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, fx_id, ("param.%d.plink.param"):format(p_id),
                        linkparm)
                end
                reaper.ImGui_EndDragDropTarget(ctx)
            end

            if btn then
                if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then
                    reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, fx_id, "param." ..
                        p_id .. ".mod.active",
                        "0")
                    ui.selected_param = nil
                    ui.selected_fx = nil
                else
                    ui.selected_fx = fx_id
                    ui.selected_param = p_id
                    ui.show_settings = true

                    -- get and set param values to force last touched
                    local val = reaper.TrackFX_GetParam(ui.selected_track_ref, ui.selected_fx, ui.selected_param)
                    reaper.TrackFX_SetParam(ui.selected_track_ref, ui.selected_fx, ui.selected_param, val)
                end
            end

            counter = counter + 1

            -- do a SameLine until 5 elements have been drawn
            if counter % 5 ~= 0 then reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x) end
        end

        local popup_id = ("Popup##%d"):format(fx_id)

        if reaper.ImGui_Button(ctx, ("  +  ##%d"):format(fx_id), style.big_btn_height, style.big_btn_height) then
            reaper.ImGui_OpenPopup(ctx, popup_id)
        end

        reaper.ImGui_SetNextWindowSize(ctx, -1, 300, reaper.ImGui_Cond_Always())
        -- open parameter dialog to for param selection
        if reaper.ImGui_BeginPopup(ctx, popup_id) then
            -- create filter field for parameter selection
            reaper.ImGui_TextFilter_Draw(ui.param_filter, ctx)

            for j = 0, reaper.TrackFX_GetNumParams(ui.selected_track_ref, fx_id) - 1 do
                local rv, pname = reaper.TrackFX_GetParamName(ui.selected_track_ref, fx_id, j)

                if not pname:lower():find("midi") then
                    local disabled = false
                    local rv, mod = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref, fx_id,
                        "param." .. j ..
                        ".mod.active")
                    if mod == "1" then disabled = true end

                    if reaper.ImGui_TextFilter_PassFilter(ui.param_filter, pname) then
                        reaper.ImGui_BeginDisabled(ctx, disabled)

                        if reaper.ImGui_Selectable(ctx, ("%s##%d"):format(pname, j)) then
                            -- TODO Refactor this for later use when adding last touhed
                            -- enable parameter modulation of selected parameter
                            reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, fx_id,
                                "param." .. j ..
                                ".mod.active", "1")

                            local param_info = { name = pname }

                            v.params[j] = param_info

                            ui.selected_fx = fx_id
                            ui.selected_param = j

                            reaper.ImGui_TextFilter_Clear(ui.param_filter)
                        end

                        reaper.ImGui_EndDisabled(ctx)
                    end
                end
            end

            reaper.ImGui_EndPopup(ctx)
        end

        if not reaper.ImGui_IsPopupOpen(ctx, popup_id) then
            reaper.ImGui_TextFilter_Clear(ui.param_filter)
        end
    end

    local rv, _, _, _, last_fx, last_param = reaper.GetTouchedOrFocusedFX(0)
    local rv, fx_name = reaper.TrackFX_GetFXName(ui.selected_track_ref, last_fx)
    local rv, param_name = reaper.TrackFX_GetParamName(ui.selected_track_ref, last_fx, last_param)

    -- Feature for last touched parameter
    if rv and reaper.ImGui_Button(ctx, "  + Last Touched   ", 0, style.big_btn_height) then
        -- add parameter to fx_data array
        reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, last_fx,
            "param." .. last_param ..
            ".mod.active", "1")

        local param_info = { name = param_name }

        fx_data[last_fx].params[last_param] = param_info

        ui.selected_fx = fx_id
        ui.selected_param = last_param
    end

    -- show last touched on hover
    if rv and reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_BeginTooltip(ctx) -- TODO Tooltip function refactor
        reaper.ImGui_SetTooltip(ctx, ("Last touched: %s - %s"):format(fx_name, param_name))
        reaper.ImGui_EndTooltip(ctx)
    end

    -- Draw lines to link targets when hovering

    if hov_btn > 0 then
        -- get link targets for currently hovered button
        local link_targets = GetLinkTargets(button_data[hov_btn].fx_id,
            button_data[hov_btn].p_id)

        -- iterate button data and draw line to all buttons with link targets
        if link_targets then
            local drawlist = reaper.ImGui_GetWindowDrawList(ctx)

            for i, v in ipairs(button_data) do
                for _, t in ipairs(link_targets) do
                    if v.fx_id == t.fx_id and v.p_id == t.p_id then
                        local white = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 1)
                        local start_x = button_data[hov_btn].x
                        local start_y = button_data[hov_btn].y
                        local end_x = v.x
                        local end_y = v.y

                        local bez_x = end_x
                        local bez_y = start_y

                        local bez_mod = 100

                        if start_x == end_x then
                            bez_x = bez_x - bez_mod
                        end

                        if start_y == end_y then
                            bez_y = bez_y + bez_mod
                        end

                        reaper.ImGui_DrawList_AddBezierQuadratic(drawlist, start_x, start_y + 4, bez_x, bez_y, end_x,
                            end_y, white, t.scale * 2)
                        reaper.ImGui_DrawList_AddCircleFilled(drawlist, end_x, end_y, 5, white)
                    end
                end
            end
        end
    end
end

local function RenderACSModulation()
    local rv, acs = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref, ui.selected_fx,
        "param." .. ui.selected_param .. ".acs.active")

    acs = acs == "1" and true or false
    local rv, acs = reaper.ImGui_Checkbox(ctx, "ACS", acs)

    if rv then
        acs = acs and 1 or 0
        reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, ui.selected_fx, "param." ..
            ui.selected_param .. ".acs.active",
            acs)
    end

    if acs then
        reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)

        if reaper.ImGui_SmallButton(ctx, "Edit Channels and Curve") then
            reaper.Main_OnCommand(41143, 0) -- FX: Show parameter modulation/link for last touched FX parameter
        end

        local rv, attack = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref, ui.selected_fx, "param." ..
            ui.selected_param ..
            ".acs.attack")
        -- create SliderInt from 0 to 1000 ms and update attack time when it's value changes
        local rv, attack = reaper.ImGui_SliderInt(ctx, "Attack", attack, 0, 1000, "%d ms")

        if rv then
            reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, ui.selected_fx, "param." ..
                ui.selected_param .. ".acs.attack",
                attack)
        end

        local rv, release = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref, ui.selected_fx, "param." ..
            ui.selected_param ..
            ".acs.release")
        -- create SliderInt from 0 to 1000 ms and update release time when it's value changes
        local rv, release = reaper.ImGui_SliderInt(ctx, "Release", release, 0, 1000, "%d ms")

        if rv then
            reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, ui.selected_fx, "param." ..
                ui.selected_param .. ".acs.release",
                release)
        end

        -- get acs dblo and output as imgui_text (dB Range from -60 to 12)
        local rv, dblo = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref, ui.selected_fx, "param." ..
            ui.selected_param ..
            ".acs.dblo")
        -- create SliderDouble from -60.00 to 12.00 dB and update value when changes
        local rv, dblo = reaper.ImGui_SliderDouble(ctx, "Min Volume", dblo, -60, 12, "%.2f dB")

        if rv then
            reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, ui.selected_fx, "param." ..
                ui.selected_param .. ".acs.dblo",
                dblo)
        end

        -- get acs dbhi and output as imgui_text (dB Range from -60 to 12)
        local rv, dbhi = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref, ui.selected_fx, "param." ..
            ui.selected_param ..
            ".acs.dbhi")
        -- create SliderDouble from -60.00 to 12.00 dB and update value when changes
        local rv, dbhi = reaper.ImGui_SliderDouble(ctx, "Max Volume", dbhi, -60, 12, "%.2f dB")

        if rv then
            reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, ui.selected_fx, "param." ..
                ui.selected_param .. ".acs.dbhi",
                dbhi)
        end

        -- get acs strength and output as imgui_text
        local rv, strength = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref, ui.selected_fx, "param." ..
            ui.selected_param ..
            ".acs.strength")
        -- create SliderDouble from 0.0 to 1.0 and update value when changes
        strength = strength * 100
        local rv, strength = reaper.ImGui_SliderDouble(ctx, "Strength", strength, 0, 100, "%.2f")
        strength = strength / 100

        if rv then
            reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, ui.selected_fx, "param." ..
                ui.selected_param .. ".acs.strength",
                strength)
        end


        -- get acs dir and output as imgui_text
        local rv, dir = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref, ui.selected_fx, "param." ..
            ui.selected_param ..
            ".acs.dir")

        local rv, dir = reaper.ImGui_SliderInt(ctx, "Direction", dir, -1,
            1, ui.dir_map[tonumber(dir)])

        if rv then
            reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, ui.selected_fx, "param." ..
                ui.selected_param .. ".acs.dir",
                dir)
        end
    end

    reaper.ImGui_Separator(ctx)
end

local function RenderLFOModulation()
    -- create checkbox for LFO activation
    local rv, lfo = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref, ui.selected_fx,
        "param." ..
        ui.selected_param ..
        ".lfo.active")
    lfo = lfo == "1" and true or false

    local rv, lfo = reaper.ImGui_Checkbox(ctx, "LFO", lfo)
    if rv then
        lfo = lfo and 1 or 0
        reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, ui.selected_fx, "param." ..
            ui.selected_param .. ".lfo.active",
            lfo)
    end

    if lfo then
        local rv, lfo_shape = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref,
            ui.selected_fx,
            "param." ..
            ui.selected_param ..
            ".lfo.shape")
        -- shape returns 0 - 5 - map it to: sine, square, saw L, saw R, triangle, random
        local rv, lfo_shape = reaper.ImGui_SliderInt(ctx, "Shape", lfo_shape, 0,
            5, ui.lfo_map[tonumber(lfo_shape) + 1])

        if rv then
            reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, ui.selected_fx,
                "param." .. ui.selected_param ..
                ".lfo.shape", lfo_shape)
        end

        -- read tempo sync from config
        local rv, lfo_tempo_sync = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref,
            ui.selected_fx,
            "param." ..
            ui.selected_param ..
            ".lfo.temposync")
        lfo_tempo_sync = lfo_tempo_sync == "1" and true or false
        local rv, lfo_tempo_sync = reaper.ImGui_Checkbox(ctx, "Tempo Sync", lfo_tempo_sync)
        lfo_tempo_sync = lfo_tempo_sync and 1 or 0

        if rv then
            reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, ui.selected_fx,
                "param." .. ui.selected_param ..
                ".lfo.temposync", lfo_tempo_sync)
        end

        -- read lfo speed from config
        local rv, lfo_speed = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref,
            ui.selected_fx,
            "param." ..
            ui.selected_param ..
            ".lfo.speed")

        if lfo_tempo_sync == 0 then
            rv, lfo_speed = reaper.ImGui_SliderDouble(ctx, "Speed", lfo_speed, 0, 8, "%.2f Hz")
        else
            rv, lfo_speed = reaper.ImGui_SliderDouble(ctx, "Speed", lfo_speed, 0.25, 8, "%.4f QN")
        end

        if rv then
            reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, ui.selected_fx,
                "param." .. ui.selected_param ..
                ".lfo.speed", lfo_speed)
        end

        -- read lfo strength from config
        local rv, lfo_strength = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref,
            ui.selected_fx,
            "param." ..
            ui.selected_param ..
            ".lfo.strength")
        lfo_strength = tonumber(lfo_strength) * 100
        local rv, lfo_strength = reaper.ImGui_SliderDouble(ctx, "Strength", lfo_strength, 0, 100, "%.1f")
        lfo_strength = lfo_strength / 100

        if rv then
            reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, ui.selected_fx,
                "param." .. ui.selected_param ..
                ".lfo.strength", lfo_strength)
        end

        -- read lfo phase from config
        local rv, lfo_phase = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref,
            ui.selected_fx,
            "param." ..
            ui.selected_param ..
            ".lfo.phase")
        local rv, lfo_phase = reaper.ImGui_SliderDouble(ctx, "Phase", lfo_phase, 0, 1, "%.2f")

        if rv then
            reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, ui.selected_fx,
                "param." .. ui.selected_param ..
                ".lfo.phase", lfo_phase)
        end

        -- read direction from config and
        local rv, lfo_dir = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref,
            ui.selected_fx,
            "param." ..
            ui.selected_param ..
            ".lfo.dir")

        local rv, lfo_dir = reaper.ImGui_SliderInt(ctx, "Direction", lfo_dir, -1,
            1, ui.dir_map[tonumber(lfo_dir)])

        if rv then
            reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, ui.selected_fx,
                "param." .. ui.selected_param ..
                ".lfo.dir", lfo_dir)
        end

        -- read free parameter from config
        local rv, lfo_free = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref,
            ui.selected_fx,
            "param." ..
            ui.selected_param ..
            ".lfo.free")
        lfo_free = lfo_free == "1" and true or false
        local rv, lfo_free = reaper.ImGui_Checkbox(ctx, "Free", lfo_free)

        if rv then
            reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, ui.selected_fx,
                "param." .. ui.selected_param ..
                ".lfo.free", lfo_free and 1 or 0)
        end
    end

    reaper.ImGui_Separator(ctx)
end

local function RenderLinkModulation()
    -- display fx name and linked parameter as text
    local plink_fx = fx_data[ui.selected_fx].params[ui.selected_param].plink_fx
    local plink_param = fx_data[ui.selected_fx].params[ui.selected_param].plink_param

    if not plink_fx or not plink_param then return end

    if tonumber(plink_fx) > -1 then
        reaper.ImGui_Text(ctx, "Linked to:")
        reaper.ImGui_Text(ctx, ("%d - %s"):format(plink_fx + 1, fx_data[plink_fx].name))
        reaper.ImGui_Text(ctx, fx_data[plink_fx].params[plink_param].name)
    end

    local link_targets = GetLinkTargets(ui.selected_fx, ui.selected_param)

    if #link_targets > 0 then
        reaper.ImGui_Text(ctx, ("%d Targets:"):format(#link_targets))
        for _, v in ipairs(link_targets) do
            local fx_name = fx_data[v.fx_id].name
            local param_name = fx_data[v.fx_id].params[v.p_id].name
            reaper.ImGui_Text(ctx, ("%d - %s - %s"):format(v.fx_id + 1, fx_name, param_name))
        end
    end
end

local function RenderModulation()
    if not ui.selected_fx then return end
    if not ui.selected_param then return end

    -- check if track has any fx, otherwise unset ui.selected_fx and param
    if reaper.TrackFX_GetCount(ui.selected_track_ref) == 0 then
        ui.selected_fx = nil
        ui.selected_param = nil
        return
    end
    local p_name = fx_data[ui.selected_fx].params[ui.selected_param].name

    local val, minval, maxval = reaper.TrackFX_GetParam(ui.selected_track_ref, ui.selected_fx, ui.selected_param)
    DrawModIndicator(val, minval, maxval)

    reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x + 8)
    reaper.ImGui_Text(ctx, p_name)

    -- create slider for modulation baseline
    -- read parameter modulation baseline value
    local rv, mod = reaper.TrackFX_GetNamedConfigParm(ui.selected_track_ref, ui.selected_fx,
        "param." ..
        ui.selected_param ..
        ".mod.baseline")

    local rv, mod = reaper.ImGui_SliderDouble(ctx, "Baseline", tonumber(mod), minval,
        maxval)
    if rv then
        -- set parameter modulation baseline to mod
        reaper.TrackFX_SetNamedConfigParm(ui.selected_track_ref, ui.selected_fx, "param." ..
            ui.selected_param ..
            ".mod.baseline", mod)
    end

    RenderACSModulation()
    RenderLFOModulation()
    -- RenderLinkModulation()

    -- while ui.plot.time < reaper.ImGui_GetTime(ctx) do
    --     local val = reaper.TrackFX_GetParam(ui.selected_track_ref, ui.selected_fx, ui.selected_param)
    --     ui.plot.data[ui.plot.offset] = val
    --     ui.plot.offset = (ui.plot.offset % #ui.plot.data) + 1
    --     ui.plot.time = ui.plot.time + (1.0 / 60.0)
    -- end
    -- -- get current value from parameter and output as text

    -- local w = reaper.ImGui_GetWindowSize(ctx)
    -- reaper.ImGui_PlotLines(ctx, "##ModulationValue", ui.plot.data, ui.plot.offset - 1, nil, FLT_MAX, FLT_MAX, w, 100)
end

function PushMainStyleVars()
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 1, style.item_spacing_y)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_SeparatorTextPadding(), 0, 0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_SeparatorTextBorderSize(), 1)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), style.frame_rounding)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), style.frame_border)

    return 5
end

local function Loop()
    local pushes = PushMainStyleVars()

    local visible, open = reaper.ImGui_Begin(ctx, 'Modulation Box - GUI', true)
    if visible then
        local child_flags = reaper.ImGui_ChildFlags_Border()

        local w = reaper.ImGui_GetWindowSize(ctx)
        if ui.show_settings then w = w * 0.7 end
        if reaper.ImGui_BeginChild(ctx, "Tracks and FX", w, 0, child_flags) then
            CacheTracks()
            -- unpack ui.tracks, separate them by \n and null terminate the string
            local track_list = table.concat(ui.tracks, '\0') .. "\0"
            rv, ui.selected_track = reaper.ImGui_Combo(ctx, 'Tracks',
                ui.selected_track,
                track_list, 0)

            if rv then
                ui.selected_track_ref = nil
                ui.selected_fx = nil
                ui.selected_param = nil
            end

            if not ui.selected_track_ref then ui.selected_track_ref = reaper.GetTrack(0, ui.selected_track) end

            -- reaper.ImGui_SameLine(ctx, 0, 100)

            -- local arrow_btn = ui.show_settings and reaper.ImGui_Dir_Right() or reaper.ImGui_Dir_Left()
            -- if reaper.ImGui_ArrowButton(ctx, "ToggleModWindow", arrow_btn) then
            --     ui.show_settings = not ui.show_settings
            -- end

            CacheTrackFxData()
            RenderFxList()

            reaper.ImGui_EndChild(ctx)
        end

        if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
            ui.show_settings = false
        end

        reaper.ImGui_SameLine(ctx)

        if ui.show_settings then
            if reaper.ImGui_BeginChild(ctx, "Parameter Modulation", 0, 0,
                    child_flags) then
                RenderModulation()
                reaper.ImGui_EndChild(ctx)
            end
        end

        reaper.ImGui_End(ctx)
    end

    reaper.ImGui_PopStyleVar(ctx, pushes)

    if open then reaper.defer(Loop) end
end

reaper.ImGui_Attach(ctx, ui.param_filter)

reaper.defer(Loop)
