-- @description Toggle TCP Knob Visibility When Adding Modulators
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @noindex

-- get state from ExtState
ext_section = "tdspk_mbox"
ext_key = "tcp_toggle"

state = reaper.GetExtState(ext_section, ext_key)
new_state = ""

if (state ~= "1") then
  new_state = 1
else
  new_state = 0
end

a, a, a, cmd_id = reaper.get_action_context()
reaper.SetToggleCommandState(0, cmd_id, new_state)
reaper.SetExtState(ext_section, ext_key, new_state, false)
