cmd_id = reaper.NamedCommandLookup("_RS4ccf72a435f24a7de5c1c4329ef5e01b24471f60")
state = reaper.GetToggleCommandState(cmd_id)

reaper.SetToggleCommandState(0, cmd_id, state == 0 and 1 or 0)
