function p(msg)
    reaper.ShowConsoleMsg(msg)
end

debug_last_param = ""

params = {}
has_changed = false
current_param = ""
found = false

cmd_knob = reaper.NamedCommandLookup("_RS03dd19cee57f8ae0a559c67fd127c6c318efb9ba")
cmd_env = reaper.NamedCommandLookup("_RS4ccf72a435f24a7de5c1c4329ef5e01b24471f60")
cmd_mod = reaper.NamedCommandLookup("_RS6438423f00e98db07b9fe432c906da02f7dd0e9f")

-- Get last touched fx
rv, track_nr, fx, param = reaper.GetLastTouchedFX()

if rv then
    -- Check if the knob option is enabled and set the knob variable accordingly
    knob = reaper.GetToggleCommandState(cmd_knob) == 1 and true or false

    -- Check if the env option is enabled and set the variable accordingly
    env = reaper.GetToggleCommandState(cmd_env) == 1 and true or false

    mod = reaper.GetToggleCommandState(cmd_mod) == 1 and true or false

    -- only continue if one of the options is activated
    if (knob or env or mod) then
        if knob then
            ret = reaper.SNM_AddTCPFXParm(track, fx, param) --adds an knob to the TCP
        end

        if env then
            reaper.Main_OnCommand(41142, 0) -- Shows Envelope for Track
        end

        if mod then
            reaper.Main_OnCommand(41143, 0) -- FX: Show parameter modulation/link for last touched FX parameter
        end
    end
end
-- cleanup after exit

