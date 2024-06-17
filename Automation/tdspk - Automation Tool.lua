--@description Automation Tool
--@version 0.1pre1
--@author Tadej Supukovic (tdspk)
--@about
--  # Automation Tool
--@links
--  Website https://www.tdspkaudio.com
--@donation
--  https://ko-fi.com/tdspkaudio
--  https://coindrop.to/tdspkaudio
--@provides
--  [main] .
-- @changelog
--  Implement envelopes for global and track settings

local ctx = reaper.ImGui_CreateContext('tdspk - Automation Tool')

is_global = true
sel_track = nil
current_change_count = 0


global_env_states = {
    ["Volume"] = false,
    ["Pan"] = false,
    ["Mute"] = false,
    ["S Volume"] = { false, "P_ENV:<VOLENV" },
    ["S Pan"] = { false, "P_ENV:<PANENV" },
    ["S Mute"] = { false, "P_ENV:<MUTEENV" }
}

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

function GetGlobalEnvStates()
    local envelopes = {}
    for k, v in pairs(envelopes) do
        envelopes[k] = 0
    end
    local track_count = reaper.CountTracks(0)

    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)

        for k, v in pairs(envelopes) do
            local env = reaper.GetTrackEnvelopeByName(track, k)

            local br_env = reaper.BR_EnvAlloc(env, false)

            local active, visible, armed, inLane, laneHeight, defaultShape, minValue, maxValue, centerValue, env_type, faderScaling, automationItemsOptions =
                reaper.BR_EnvGetProperties(br_env)

            if armed then envelopes[k] = envelopes[k] + 1 end

            reaper.BR_EnvFree(br_env, true)
        end
    end

    for k, v in pairs(envelopes) do
        global_env_states[k] = v >= track_count / 2
    end
end

function SetEnvState(env, is_armed)
    local br_env = reaper.BR_EnvAlloc(env, false)

    local active, visible, armed, inLane, laneHeight, defaultShape, minValue, maxValue, centerValue, env_type, faderScaling, automationItemsOptions =
        reaper.BR_EnvGetProperties(br_env)

    reaper.BR_EnvSetProperties(br_env, active, visible, is_armed, inLane, laneHeight,
        defaultShape,
        faderScaling)

    reaper.BR_EnvFree(br_env, true)
end

function ToggleTrackEnvelope(track, name)
    local env_state = global_env_states[name]
    local env = reaper.GetTrackEnvelopeByName(track, name)
    SetEnvState(env, env_state)
end

function ToggleSendEnvelope(track, name)
    local env_state = global_env_states[name][1]
    local name = global_env_states[name][2]
    local num_sends = reaper.GetTrackNumSends(track, 0)

    for i = 0, num_sends - 1 do
        local env = reaper.GetTrackSendInfo_Value(track, 0, i, name)
        local br_env = reaper.BR_EnvAlloc(env, false)
        SetEnvState(env, env_state)
    end
end

function EnvelopeButton(name)
    if not global_env_states[name] then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), color.transparent)
    else
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),
            reaper.ImGui_GetStyleColor(ctx, reaper.ImGui_Col_Button()))
    end

    if reaper.ImGui_Button(ctx, name, 100) then
        -- iterate all tracks and arm / disarm volume automation
        global_env_states[name] = not global_env_states[name]

        if is_global then
            for i = 0, reaper.CountTracks(0) - 1 do
                local track = reaper.GetTrack(0, i)
                ToggleTrackEnvelope(track, name)
            end
        elseif not is_global and sel_track then
            ToggleTrackEnvelope(sel_track, name)
        end
    end

    reaper.ImGui_PopStyleColor(ctx, 1)
end

function SendEnvelopeButton(name)
    if not global_env_states[name] then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), color.transparent)
    else
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),
            reaper.ImGui_GetStyleColor(ctx, reaper.ImGui_Col_Button()))
    end

    if reaper.ImGui_Button(ctx, name, 100) then
        -- iterate all tracks and arm / disarm volume automation
        global_env_states[name][1] = not global_env_states[name][1]

        if is_global then
            for i = 0, reaper.CountTracks(0) - 1 do
                local track = reaper.GetTrack(0, i)
                ToggleSendEnvelope(track, name)
            end
        elseif not is_global and sel_track then
            ToggleSendEnvelope(sel_track, name)
        end
    end

    reaper.ImGui_PopStyleColor(ctx, 1)
end

function Loop()
    local visible, open = reaper.ImGui_Begin(ctx, 'Automation Tool', true)
    if visible then
        local change_count = reaper.GetProjectStateChangeCount(0)
        if current_change_count ~= change_count then
            sel_track = reaper.GetSelectedTrack(0, 0)
            current_change_count = change_count
        end

        reaper.ImGui_Text(ctx, "Mode")
        reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)

        if reaper.ImGui_SmallButton(ctx, is_global and "Global" or "Track") then
            is_global = not is_global
            sel_track = reaper.GetSelectedTrack(0, 0)
        end

        if is_global then
            reaper.ImGui_Text(ctx, "")
        else
            if sel_track then
                local rv, track_name = reaper.GetTrackName(sel_track)
                reaper.ImGui_Text(ctx, "Track: " .. track_name)
            end
        end

        reaper.ImGui_Text(ctx, "Envelopes")

        reaper.ImGui_BeginGroup(ctx)
        EnvelopeButton("Volume")
        EnvelopeButton("Pan")
        EnvelopeButton("Mute")
        reaper.ImGui_EndGroup(ctx)

        reaper.ImGui_SameLine(ctx, 0, style.item_spacing_x)

        reaper.ImGui_BeginGroup(ctx)
        SendEnvelopeButton("S Volume")
        SendEnvelopeButton("S Pan")
        SendEnvelopeButton("S Mute")
        reaper.ImGui_EndGroup(ctx)

        reaper.ImGui_End(ctx)
    end

    if open then reaper.defer(Loop) end
end

GetGlobalEnvStates()

reaper.defer(Loop)
