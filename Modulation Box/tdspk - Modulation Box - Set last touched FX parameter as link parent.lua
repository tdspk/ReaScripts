rv, track_nr, fx, param_id = reaper.GetLastTouchedFX()

if rv then
  data = fx .. ";" .. param_id

  reaper.SetExtState("tdspk_mbox", "link_parent", data, false)
end
