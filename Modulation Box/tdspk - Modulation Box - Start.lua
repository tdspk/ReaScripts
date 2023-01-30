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

function create_entry(track_nr, fx, param, knob, env)
    --[[
  entry = {}

  entry["track"] = track_nr
  entry["fx"] = fx 
  entry["param"] = param
  --entry["knob"] = knob
  --entry["env"] = env
  
  ]]
    return track_nr .. "," .. fx .. "," .. param
end

function main()
    -- Get last touched fx
    rv, track_nr, fx, param = reaper.GetLastTouchedFX()

    if rv then
        -- check if the selected param has changed, otherwise skip this pass
        entry = create_entry(track_nr, fx, param, knob, env)

        if current_param ~= entry then
            current_param = entry

            -- Check if the knob option is enabled and set the knob variable accordingly
            knob = reaper.GetToggleCommandState(cmd_knob) == 1 and true or false

            -- Check if the env option is enabled and set the variable accordingly
            env = reaper.GetToggleCommandState(cmd_env) == 1 and true or false

            mod = reaper.GetToggleCommandState(cmd_mod) == 1 and true or false

            -- only continue if one of the options is activated
            if (knob or env or mod) then
                track = reaper.GetTrack(0, track_nr - 1)

                -- Check if the entry is already in the table
                found = false

                for k, v in ipairs(params) do
                    if v == entry then
                        -- skip this pass if found
                        found = true
                    end
                end

                if not found then
                    -- add to params if not in table
                    table.insert(params, entry)

                    if knob then
                        ret = reaper.SNM_AddTCPFXParm(track, fx, param) --adds an knob to the TCP
                    end

                    if env then
                        reaper.GetFXEnvelope(track, fx, param, true)
                    end

                    if mod then
                        reaper.Main_OnCommand(41143, 0) -- FX: Show parameter modulation/link for last touched FX parameter
                    end
                end
            end
        end
    end

    reaper.defer(main)
    -- cleanup after exit
end

function exit()
    params = {}
    current_param = ""
end

reaper.atexit(exit)
main()

