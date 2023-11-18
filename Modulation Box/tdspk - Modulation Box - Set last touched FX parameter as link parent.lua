-- @description Set last touched FX parameter as link parent
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @noindex

rv, track_nr, item, take, fx, param_id = reaper.GetTouchedOrFocusedFX(0) -- get last touched FX param

if rv then
  data = fx .. ";" .. param_id

  reaper.SetExtState("tdspk_mbox", "link_parent", data, false)
end
