--@description Modulation Box - GUI
--@version 0.1pre5
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

-- TODO separate tables into mapping and data tables
data = {
    show_settings = false,
    tracks = {},
    selected_track = 0,
    track = nil,
    selected_fx = nil,
    selected_param = nil,
    lfo_map = { "Sine", "Square", "Saw L", "Saw R", "Triangle", "Random" },
    dir_map = { [-1] = "Negative", [0] = "Centered", [1] = "Positive" },
    param_filter = reaper.ImGui_CreateTextFilter()
}

function Debug(msg)
    reaper.ClearConsole()
    reaper.ShowConsoleMsg(msg)
end

function Map(x, in_min, in_max, out_min, out_max)
    return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

function CacheTracks()
    data.tracks = {}

    -- iterate all tracks and add to ui.tracks array
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        local _, track_name = reaper.GetTrackName(track)
        track_name = ("%d: %s"):format(i + 1, track_name)
        table.insert(data.tracks, track_name)
    end
end

function BuildParameterInfo(fx_id, p_id)
    local rv, pname = reaper.TrackFX_GetParamName(data.track, fx_id, p_id)

    local rv, link_fx = reaper.TrackFX_GetNamedConfigParm(data.track, fx_id,
        "param." .. p_id .. ".plink.effect")
    local rv, link_param = reaper.TrackFX_GetNamedConfigParm(data.track, fx_id,
        "param." .. p_id .. ".plink.param")
    local rv, link_scale = reaper.TrackFX_GetNamedConfigParm(data.track, fx_id,
        "param." .. p_id .. ".plink.scale")
    local rv, link_offset = reaper.TrackFX_GetNamedConfigParm(data.track, fx_id,
        "param." .. p_id .. ".plink.offset")
    local rv, baseline = reaper.TrackFX_GetNamedConfigParm(data.track, fx_id,
        "param." .. p_id .. ".mod.baseline")
    local val, minval, maxval = reaper.TrackFX_GetParam(data.track, fx_id, p_id)

    local link_fx = tonumber(link_fx)
    local link_param = tonumber(link_param)
    local link_scale = tonumber(link_scale)
    local link_offset = tonumber(link_offset)
    local baseline = tonumber(baseline)

    local param_info = {
        fx_id = fx_id,
        p_id = p_id,
        name = pname,
        val = val,
        minval = minval,
        maxval = maxval,
        link_fx = link_fx,
        link_param = link_param,
        link_scale = link_scale,
        link_offset = link_offset,
        baseline = baseline,
    }

    return param_info
end

function CacheTrackFxData()
    fx_data = {}

    if not data.track then return end

    -- iterate all fx and add them to data array
    for i = 0, reaper.TrackFX_GetCount(data.track) - 1 do
        -- iterate all params from each fx
        local fx_params = {}

        for j = 0, reaper.TrackFX_GetNumParams(data.track, i) - 1 do
            -- if param modulation is enabled, add it to the list
            local rv, mod = reaper.TrackFX_GetNamedConfigParm(data.track, i,
                "param." .. j ..
                ".mod.active")

            if mod == "1" then
                fx_params[j] = BuildParameterInfo(i, j)
            end
        end

        local rv, fx_name = reaper.TrackFX_GetFXName(data.track, i)
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

function DrawModIndicator(val, minval, maxval)
    local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
    -- reaper.ImGui_Text(ctx, ("%d, %d"):format(x, y))
    local drawlist = reaper.ImGui_GetWindowDrawList(ctx)

    val = Map(val, minval, maxval, 0, 1)
    local white = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, val)

    reaper.ImGui_DrawList_AddCircleFilled(drawlist, x + 5, y + 5, 8, white, 0)
end

function GetLinkTargets(in_fx_id, in_p_id)
    local link_targets = {}
    -- Filter targets to a new table and return the existing data structure instead of creating a new one
    for _, fx_id in ipairs(fx_keys) do
        local v = fx_data[fx_id]
        for p_id, v in pairs(v.params) do
            if v.link_fx == in_fx_id and v.link_param == in_p_id then
                table.insert(link_targets, v)
            end
        end
    end

    return link_targets
end

function RenderParameterButtons()
    local btn_id = 0
    local button_data = {}
    local hov_btn = 0

    for _, fx_id in ipairs(fx_keys) do
        local v = fx_data[fx_id]
        local fx_name = v.name
        reaper.ImGui_SeparatorText(ctx, ("%d - %s"):format(fx_id + 1, fx_name))
        reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)

        if reaper.ImGui_Button(ctx, "Open FX") then
            reaper.TrackFX_SetOpen(data.track, fx_id, true)
        end

        local counter = 0
        for p_id, v in pairs(v.params) do
            btn_id = btn_id + 1

            local p_name = v.name

            local rv, mod = reaper.TrackFX_GetNamedConfigParm(data.track, fx_id,
                "param." .. p_id ..
                ".mod.active")
            local style_colors, style_vars = 0, 0

            if data.selected_fx == fx_id and data.selected_param == p_id then
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),
                    reaper.ImGui_GetStyleColor(ctx, reaper.ImGui_Col_ButtonActive()))
                style_colors = style_colors + 1
            end

            if mod == "1" then
                local val, minval, maxval = reaper.TrackFX_GetParam(data.track, fx_id, p_id)
                val = Map(val, minval, maxval, 0, 1)
                local col = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, val)
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), 2)
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), col)

                style_colors = style_colors + 1
                style_vars = style_vars + 1
            end

            local rv, has_lfo = reaper.TrackFX_GetNamedConfigParm(data.track, fx_id,
                "param." .. p_id .. ".lfo.active")
            has_lfo = has_lfo == "1" and "~" or ""
            local rv, has_acs = reaper.TrackFX_GetNamedConfigParm(data.track, fx_id,
                "param." .. p_id .. ".acs.active")
            has_acs = has_acs == "1" and "/" or ""
            local link_targets = GetLinkTargets(fx_id, p_id)

            local indicators = ("%s %s"):format(has_acs, has_lfo)

            local btn = reaper.ImGui_Button(ctx, ("%s  %s  ##%d%d"):format(indicators, p_name, fx_id, p_id, btr_id), 0,
                style.big_btn_height)
            if reaper.ImGui_IsItemHovered(ctx) then hov_btn = btn_id end

            -- Calculate button position
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

            reaper.ImGui_PopStyleColor(ctx, style_colors)
            reaper.ImGui_PopStyleVar(ctx, style_vars)

            if reaper.ImGui_BeginPopupContextItem(ctx) then
                reaper.ImGui_Text(ctx, "Parameter Settings")
                local baseline = v.baseline
                RenderBaselineSlider(fx_id, p_id, v, v.minval, v.maxval)

                if #link_targets > 0 then
                    reaper.ImGui_Text(ctx, "Link Settings")
                    -- iterate link targets and create scale slider for each
                    for _, v in ipairs(link_targets) do
                        -- separate by fx
                        local scale = v.link_scale
                        local baseline = v.baseline
                        scale = tonumber(scale) * 100

                        local item_w = reaper.ImGui_CalcItemWidth(ctx)
                        reaper.ImGui_SetNextItemWidth(ctx, item_w / 2)
                        rv, scale = reaper.ImGui_SliderDouble(ctx, ("##Scale%d%d"):format(v.fx_id, v.p_id), scale, -100,
                            100)

                        if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Right()) then scale = 0 end

                        reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
                        reaper.ImGui_SetNextItemWidth(ctx, item_w / 2)
                        rv, baseline = reaper.ImGui_SliderDouble(ctx, ("##Baseline%d%d"):format(v.fx_id, v.p_id),
                            baseline,
                            v.minval, v.maxval)

                        if reaper.ImGui_IsItemClicked(ctx, 1) then baseline = v.minval end

                        reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)
                        reaper.ImGui_Text(ctx, ("%s (Scale / Baseline)"):format(v.name))

                        scale = scale / 100

                        reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)

                        if reaper.ImGui_SmallButton(ctx, ("X##%d%d"):format(v.fx_id, v.p_id)) then
                            reaper.TrackFX_SetNamedConfigParm(data.track, v.fx_id,
                                "param." .. v.p_id .. ".plink.active", 0)
                            reaper.TrackFX_SetNamedConfigParm(data.track, v.fx_id,
                                "param." .. v.p_id .. ".plink.effect", -1)
                            reaper.TrackFX_SetNamedConfigParm(data.track, v.fx_id,
                                "param." .. v.p_id .. ".plink.param", -1)
                        end

                        reaper.TrackFX_SetNamedConfigParm(data.track, v.fx_id,
                            "param." .. v.p_id .. ".plink.scale", scale)
                        reaper.TrackFX_SetNamedConfigParm(data.track, v.fx_id,
                            "param." .. v.p_id .. ".mod.baseline", baseline)
                    end
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

                    reaper.TrackFX_SetNamedConfigParm(data.track, fx_id,
                        ("param.%d.plink.active"):format(p_id), "1")
                    reaper.TrackFX_SetNamedConfigParm(data.track, fx_id,
                        ("param.%d.plink.effect"):format(p_id), linkfx)
                    reaper.TrackFX_SetNamedConfigParm(data.track, fx_id, ("param.%d.plink.param"):format(p_id),
                        linkparm)
                end
                reaper.ImGui_EndDragDropTarget(ctx)
            end

            if btn then
                if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then
                    reaper.TrackFX_SetNamedConfigParm(data.track, fx_id, "param." ..
                        p_id .. ".mod.active",
                        "0")
                    data.selected_param = nil
                    data.selected_fx = nil
                    data.show_settings = false
                else
                    data.selected_fx = fx_id
                    data.selected_param = p_id
                    data.show_settings = true

                    -- get and set param values to force last touched
                    local val = reaper.TrackFX_GetParam(data.track, data.selected_fx, data.selected_param)
                    reaper.TrackFX_SetParam(data.track, data.selected_fx, data.selected_param, val)
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
            reaper.ImGui_TextFilter_Draw(data.param_filter, ctx)

            for j = 0, reaper.TrackFX_GetNumParams(data.track, fx_id) - 1 do
                local rv, pname = reaper.TrackFX_GetParamName(data.track, fx_id, j)

                if not pname:lower():find("midi") then
                    local disabled = false
                    local rv, mod = reaper.TrackFX_GetNamedConfigParm(data.track, fx_id,
                        "param." .. j ..
                        ".mod.active")
                    if mod == "1" then disabled = true end

                    if reaper.ImGui_TextFilter_PassFilter(data.param_filter, pname) then
                        reaper.ImGui_BeginDisabled(ctx, disabled)

                        if reaper.ImGui_Selectable(ctx, ("%s##%d"):format(pname, j)) then
                            -- TODO Refactor this for later use when adding last touched
                            -- enable parameter modulation of selected parameter
                            reaper.TrackFX_SetNamedConfigParm(data.track, fx_id,
                                "param." .. j ..
                                ".mod.active", "1")

                            v.params[j] = BuildParameterInfo(fx_id, j)

                            data.selected_fx = fx_id
                            data.selected_param = j
                            data.show_settings = true

                            reaper.ImGui_TextFilter_Clear(data.param_filter)
                        end

                        reaper.ImGui_EndDisabled(ctx)
                    end
                end
            end

            reaper.ImGui_EndPopup(ctx)
        end

        if not reaper.ImGui_IsPopupOpen(ctx, popup_id) then
            reaper.ImGui_TextFilter_Clear(data.param_filter)
        end
    end

    return button_data, hov_btn
end

function RenderLastTouchedButton()
    if not data.track then return end
    local rv, _, _, _, last_fx, last_param = reaper.GetTouchedOrFocusedFX(0)
    local rv, fx_name = reaper.TrackFX_GetFXName(data.track, last_fx)
    local rv, param_name = reaper.TrackFX_GetParamName(data.track, last_fx, last_param)

    -- Feature for last touched parameter
    if rv and reaper.ImGui_Button(ctx, "  + Last Touched   ", 0, style.big_btn_height) then
        -- add parameter to fx_data array
        reaper.TrackFX_SetNamedConfigParm(data.track, last_fx,
            "param." .. last_param ..
            ".mod.active", "1")

        local param_info = { name = param_name }

        fx_data[last_fx].params[last_param] = param_info

        data.selected_fx = fx_id
        data.selected_param = last_param
    end

    -- show last touched on hover
    if rv and reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_BeginTooltip(ctx) -- TODO Tooltip function refactor
        reaper.ImGui_SetTooltip(ctx, ("Last touched: %s - %s"):format(fx_name, param_name))
        reaper.ImGui_EndTooltip(ctx)
    end
end

function RenderLinkConnections(button_data, hov_btn)
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
                            end_y, white, t.link_scale * 2)
                        reaper.ImGui_DrawList_AddCircleFilled(drawlist, end_x, end_y, 5, white)
                    end
                end
            end
        end
    end
end

function RenderParameterList()
    -- table for button coordinate data
    local button_data, hov_btn = RenderParameterButtons()
    RenderLastTouchedButton()
    RenderLinkConnections(button_data, hov_btn)
end

function RenderACSModulation()
    local rv, acs = reaper.TrackFX_GetNamedConfigParm(data.track, data.selected_fx,
        "param." .. data.selected_param .. ".acs.active")

    acs = acs == "1" and true or false
    local rv, acs = reaper.ImGui_Checkbox(ctx, "ACS", acs)

    if rv then
        acs = acs and 1 or 0
        reaper.TrackFX_SetNamedConfigParm(data.track, data.selected_fx, "param." ..
            data.selected_param .. ".acs.active",
            acs)
    end

    if acs then
        reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)

        if reaper.ImGui_SmallButton(ctx, "Edit Channels and Curve") then
            reaper.Main_OnCommand(41143, 0) -- FX: Show parameter modulation/link for last touched FX parameter
        end

        local rv, attack = reaper.TrackFX_GetNamedConfigParm(data.track, data.selected_fx, "param." ..
            data.selected_param ..
            ".acs.attack")
        -- create SliderInt from 0 to 1000 ms and update attack time when it's value changes
        local rv, attack = reaper.ImGui_SliderInt(ctx, "Attack", attack, 0, 1000, "%d ms")

        if rv then
            reaper.TrackFX_SetNamedConfigParm(data.track, data.selected_fx, "param." ..
                data.selected_param .. ".acs.attack",
                attack)
        end

        local rv, release = reaper.TrackFX_GetNamedConfigParm(data.track, data.selected_fx, "param." ..
            data.selected_param ..
            ".acs.release")
        -- create SliderInt from 0 to 1000 ms and update release time when it's value changes
        local rv, release = reaper.ImGui_SliderInt(ctx, "Release", release, 0, 1000, "%d ms")

        if rv then
            reaper.TrackFX_SetNamedConfigParm(data.track, data.selected_fx, "param." ..
                data.selected_param .. ".acs.release",
                release)
        end

        -- get acs dblo and output as imgui_text (dB Range from -60 to 12)
        local rv, dblo = reaper.TrackFX_GetNamedConfigParm(data.track, data.selected_fx, "param." ..
            data.selected_param ..
            ".acs.dblo")
        -- create SliderDouble from -60.00 to 12.00 dB and update value when changes
        local rv, dblo = reaper.ImGui_SliderDouble(ctx, "Min Volume", dblo, -60, 12, "%.2f dB")

        if rv then
            reaper.TrackFX_SetNamedConfigParm(data.track, data.selected_fx, "param." ..
                data.selected_param .. ".acs.dblo",
                dblo)
        end

        -- get acs dbhi and output as imgui_text (dB Range from -60 to 12)
        local rv, dbhi = reaper.TrackFX_GetNamedConfigParm(data.track, data.selected_fx, "param." ..
            data.selected_param ..
            ".acs.dbhi")
        -- create SliderDouble from -60.00 to 12.00 dB and update value when changes
        local rv, dbhi = reaper.ImGui_SliderDouble(ctx, "Max Volume", dbhi, -60, 12, "%.2f dB")

        if rv then
            reaper.TrackFX_SetNamedConfigParm(data.track, data.selected_fx, "param." ..
                data.selected_param .. ".acs.dbhi",
                dbhi)
        end

        -- get acs strength and output as imgui_text
        local rv, strength = reaper.TrackFX_GetNamedConfigParm(data.track, data.selected_fx, "param." ..
            data.selected_param ..
            ".acs.strength")
        -- create SliderDouble from 0.0 to 1.0 and update value when changes
        strength = strength * 100
        local rv, strength = reaper.ImGui_SliderDouble(ctx, "Strength", strength, 0, 100, "%.2f")
        strength = strength / 100

        if rv then
            reaper.TrackFX_SetNamedConfigParm(data.track, data.selected_fx, "param." ..
                data.selected_param .. ".acs.strength",
                strength)
        end


        -- get acs dir and output as imgui_text
        local rv, dir = reaper.TrackFX_GetNamedConfigParm(data.track, data.selected_fx, "param." ..
            data.selected_param ..
            ".acs.dir")

        local rv, dir = reaper.ImGui_SliderInt(ctx, "Direction", dir, -1,
            1, data.dir_map[tonumber(dir)])

        if rv then
            reaper.TrackFX_SetNamedConfigParm(data.track, data.selected_fx, "param." ..
                data.selected_param .. ".acs.dir",
                dir)
        end
    end

    reaper.ImGui_Separator(ctx)
end

function RenderLFOModulation()
    -- create checkbox for LFO activation
    local rv, lfo = reaper.TrackFX_GetNamedConfigParm(data.track, data.selected_fx,
        "param." ..
        data.selected_param ..
        ".lfo.active")
    lfo = lfo == "1" and true or false

    local rv, lfo = reaper.ImGui_Checkbox(ctx, "LFO", lfo)
    if rv then
        lfo = lfo and 1 or 0
        reaper.TrackFX_SetNamedConfigParm(data.track, data.selected_fx, "param." ..
            data.selected_param .. ".lfo.active",
            lfo)
    end

    if lfo then
        local rv, lfo_shape = reaper.TrackFX_GetNamedConfigParm(data.track,
            data.selected_fx,
            "param." ..
            data.selected_param ..
            ".lfo.shape")
        -- shape returns 0 - 5 - map it to: sine, square, saw L, saw R, triangle, random
        local rv, lfo_shape = reaper.ImGui_SliderInt(ctx, "Shape", lfo_shape, 0,
            5, data.lfo_map[tonumber(lfo_shape) + 1])

        if rv then
            reaper.TrackFX_SetNamedConfigParm(data.track, data.selected_fx,
                "param." .. data.selected_param ..
                ".lfo.shape", lfo_shape)
        end

        -- read tempo sync from config
        local rv, lfo_tempo_sync = reaper.TrackFX_GetNamedConfigParm(data.track,
            data.selected_fx,
            "param." ..
            data.selected_param ..
            ".lfo.temposync")
        lfo_tempo_sync = lfo_tempo_sync == "1" and true or false
        local rv, lfo_tempo_sync = reaper.ImGui_Checkbox(ctx, "Tempo Sync", lfo_tempo_sync)
        lfo_tempo_sync = lfo_tempo_sync and 1 or 0

        if rv then
            reaper.TrackFX_SetNamedConfigParm(data.track, data.selected_fx,
                "param." .. data.selected_param ..
                ".lfo.temposync", lfo_tempo_sync)
        end

        -- read lfo speed from config
        local rv, lfo_speed = reaper.TrackFX_GetNamedConfigParm(data.track,
            data.selected_fx,
            "param." ..
            data.selected_param ..
            ".lfo.speed")

        if lfo_tempo_sync == 0 then
            rv, lfo_speed = reaper.ImGui_SliderDouble(ctx, "Speed", lfo_speed, 0, 8, "%.2f Hz")
        else
            rv, lfo_speed = reaper.ImGui_SliderDouble(ctx, "Speed", lfo_speed, 0.25, 8, "%.4f QN")
        end

        if rv then
            reaper.TrackFX_SetNamedConfigParm(data.track, data.selected_fx,
                "param." .. data.selected_param ..
                ".lfo.speed", lfo_speed)
        end

        -- read lfo strength from config
        local rv, lfo_strength = reaper.TrackFX_GetNamedConfigParm(data.track,
            data.selected_fx,
            "param." ..
            data.selected_param ..
            ".lfo.strength")
        lfo_strength = tonumber(lfo_strength) * 100
        local rv, lfo_strength = reaper.ImGui_SliderDouble(ctx, "Strength", lfo_strength, 0, 100, "%.1f")
        lfo_strength = lfo_strength / 100

        if rv then
            reaper.TrackFX_SetNamedConfigParm(data.track, data.selected_fx,
                "param." .. data.selected_param ..
                ".lfo.strength", lfo_strength)
        end

        -- read lfo phase from config
        local rv, lfo_phase = reaper.TrackFX_GetNamedConfigParm(data.track,
            data.selected_fx,
            "param." ..
            data.selected_param ..
            ".lfo.phase")
        local rv, lfo_phase = reaper.ImGui_SliderDouble(ctx, "Phase", lfo_phase, 0, 1, "%.2f")

        if rv then
            reaper.TrackFX_SetNamedConfigParm(data.track, data.selected_fx,
                "param." .. data.selected_param ..
                ".lfo.phase", lfo_phase)
        end

        -- read direction from config and
        local rv, lfo_dir = reaper.TrackFX_GetNamedConfigParm(data.track,
            data.selected_fx,
            "param." ..
            data.selected_param ..
            ".lfo.dir")

        local rv, lfo_dir = reaper.ImGui_SliderInt(ctx, "Direction", lfo_dir, -1,
            1, data.dir_map[tonumber(lfo_dir)])

        if rv then
            reaper.TrackFX_SetNamedConfigParm(data.track, data.selected_fx,
                "param." .. data.selected_param ..
                ".lfo.dir", lfo_dir)
        end

        -- read free parameter from config
        local rv, lfo_free = reaper.TrackFX_GetNamedConfigParm(data.track,
            data.selected_fx,
            "param." ..
            data.selected_param ..
            ".lfo.free")
        lfo_free = lfo_free == "1" and true or false
        local rv, lfo_free = reaper.ImGui_Checkbox(ctx, "Free", lfo_free)

        if rv then
            reaper.TrackFX_SetNamedConfigParm(data.track, data.selected_fx,
                "param." .. data.selected_param ..
                ".lfo.free", lfo_free and 1 or 0)
        end
    end

    reaper.ImGui_Separator(ctx)
end

function RenderLinkModulation()
    -- display fx name and linked parameter as text
    local plink_fx = fx_data[data.selected_fx].params[data.selected_param].plink_fx
    local plink_param = fx_data[data.selected_fx].params[data.selected_param].plink_param

    if not plink_fx or not plink_param then return end

    if tonumber(plink_fx) > -1 then
        reaper.ImGui_Text(ctx, "Linked to:")
        reaper.ImGui_Text(ctx, ("%d - %s"):format(plink_fx + 1, fx_data[plink_fx].name))
        reaper.ImGui_Text(ctx, fx_data[plink_fx].params[plink_param].name)
    end

    local link_targets = GetLinkTargets(data.selected_fx, data.selected_param)

    if #link_targets > 0 then
        reaper.ImGui_Text(ctx, ("%d Targets:"):format(#link_targets))
        for _, v in ipairs(link_targets) do
            local fx_name = fx_data[v.fx_id].name
            local param_name = fx_data[v.fx_id].params[v.p_id].name
            reaper.ImGui_Text(ctx, ("%d - %s - %s"):format(v.fx_id + 1, fx_name, param_name))
        end
    end
end

function RenderBaselineSlider(fx_id, p_id, param, minval, maxval)
    local baseline = param.baseline

    local rv, baseline = reaper.ImGui_SliderDouble(ctx, "Baseline", baseline, minval,
        maxval)

    if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Right()) then
        baseline = minval; rv = true
    end

    if rv then
        -- TODO Write wrapper for this get/set functions set parameter modulation baseline to mod
        reaper.TrackFX_SetNamedConfigParm(data.track, fx_id, "param." ..
            p_id ..
            ".mod.baseline", baseline)
    end
end

function RenderModulation()
    if not data.selected_fx then return end
    if not data.selected_param then return end

    -- check if track has any fx, otherwise unset ui.selected_fx and param
    if reaper.TrackFX_GetCount(data.track) == 0 then
        data.selected_fx = nil
        data.selected_param = nil
        return
    end

    local current_param = fx_data[data.selected_fx].params[data.selected_param]

    local p_name = current_param.name
    local val = current_param.val
    local minval = current_param.minval
    local maxval = current_param.maxval

    DrawModIndicator(val, minval, maxval)

    reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x + 8)
    reaper.ImGui_Text(ctx, p_name)

    RenderBaselineSlider(data.selected_fx, data.selected_param, current_param, minval, maxval)

    RenderACSModulation()
    RenderLFOModulation()
end

function PushMainStyleVars()
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 1, style.item_spacing_y)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_SeparatorTextPadding(), 0, 0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_SeparatorTextBorderSize(), 1)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), style.frame_rounding)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), style.frame_border)

    return 5
end

function Loop()
    local pushes = PushMainStyleVars()

    local visible, open = reaper.ImGui_Begin(ctx, 'Modulation Box - GUI', true)
    if visible then
        local child_flags = reaper.ImGui_ChildFlags_Border()

        local w = reaper.ImGui_GetWindowSize(ctx)
        if data.show_settings then w = w * 0.7 end

        if reaper.ImGui_BeginChild(ctx, "Tracks and FX", w, 0, child_flags) then
            CacheTracks()
            -- unpack ui.tracks, separate them by \n and null terminate the string
            local track_list = table.concat(data.tracks, '\0') .. "\0"
            rv, data.selected_track = reaper.ImGui_Combo(ctx, 'Tracks',
                data.selected_track,
                track_list, 0)

            if rv then
                data.track = nil
                data.selected_fx = nil
                data.selected_param = nil
            end

            if not data.track then data.track = reaper.GetTrack(0, data.selected_track) end

            CacheTrackFxData()
            if #fx_data > 0 then RenderParameterList() end

            reaper.ImGui_EndChild(ctx)
        end

        if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
            data.show_settings = false
        end

        reaper.ImGui_SameLine(ctx)

        if data.show_settings then
            if reaper.ImGui_BeginChild(ctx, "Parameter Modulation", 0, 0,
                    child_flags) then
                RenderModulation()
                reaper.ImGui_EndChild(ctx)
            end
        end

        reaper.ImGui_End(ctx)

        data.track = nil
    end

    reaper.ImGui_PopStyleVar(ctx, pushes)

    if open then reaper.defer(Loop) end
end

reaper.ImGui_Attach(ctx, data.param_filter)

reaper.defer(Loop)
