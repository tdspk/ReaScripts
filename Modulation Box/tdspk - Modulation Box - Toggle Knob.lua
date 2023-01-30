cmd_id = reaper.NamedCommandLookup("_RS03dd19cee57f8ae0a559c67fd127c6c318efb9ba")
state = reaper.GetToggleCommandState(cmd_id)

reaper.SetToggleCommandState(0, cmd_id, state == 0 and 1 or 0)
