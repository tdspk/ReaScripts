cmd_id = reaper.NamedCommandLookup("_RS6438423f00e98db07b9fe432c906da02f7dd0e9f")
state = reaper.GetToggleCommandState(cmd_id)

reaper.SetToggleCommandState(0, cmd_id, state == 0 and 1 or 0)
