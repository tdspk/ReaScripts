local title = reaper.JS_Localize("tdspk - UCS Toolkit", "common")
handle = reaper.JS_Window_Find(title, true)
if handle then
  reaper.JS_Window_SetFocus(handle)
  reaper.SetExtState("tdspk_ucstoolkit", "focus", "1", false)
end
