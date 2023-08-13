-- @description Set last touched FX parameter as link parent
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @changelog
--   First version

rv, track_nr, fx, param_id = reaper.GetLastTouchedFX()

if rv then
  data = fx .. ";" .. param_id

  reaper.SetExtState("tdspk_mbox", "link_parent", data, false)
end
