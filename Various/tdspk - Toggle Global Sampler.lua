-- @description Toggle Global Sampler
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @changelog
--   First version

master = reaper.GetMasterTrack(0);

-- Get FX Count and iterate to find Global Sampler
count = reaper.TrackFX_GetCount(master);
sampler_found = false
sampler_index = -1

sampler_name = "JS: Global Sampler";

for i = 0, count - 1, 1 do
  rv, fx_name = reaper.TrackFX_GetFXName(master, i)

  if (fx_name == sampler_name)
  then
    sampler_found = true
    sampler_index = i
    break;
  end
end

if (sampler_found) then
  state = reaper.TrackFX_GetEnabled(master, sampler_index)
  state = not state;
  reaper.TrackFX_SetEnabled(master, sampler_index, state)

  _, _, _, script_id = reaper.get_action_context()
  toggle_state = state == true and 1 or 0
  reaper.SetToggleCommandState(0, script_id, toggle_state)
  reaper.RefreshToolbar2(0, script_id)
else
  reaper.ShowMessageBox("Global Sampler not loaded!\nPlease insert it into the Master Track to make this toggle work!",
    "Global Sampler not found", 0)
end
