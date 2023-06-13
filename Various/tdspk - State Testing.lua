function p(msg)
  reaper.ShowConsoleMsg(msg)
end

-- Circle buffer of last x touched parameters
size = 3
params = {}
-- this needs to run in background

rv, track, fx, param_base = reaper.GetLastTouchedFX()
table.insert(params, {track, fx, params})

if (rv) then
  
end
