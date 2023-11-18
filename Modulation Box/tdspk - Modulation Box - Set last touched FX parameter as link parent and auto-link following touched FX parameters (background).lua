-- @description Set last touched FX parameter as link parent and auto-link following touched FX parameters (background)
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @noindex
-- @changelog
--   First version

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

_, _, section_id, cmd_id = reaper.get_action_context()
reaper.SetToggleCommandState(section_id, cmd_id, 1)
reaper.RefreshToolbar2(section_id, cmd_id)

function main()
    -- call other script to avoid redundancy
    dofile(script_path .. '/tdspk - Modulation Box - Link last touched FX parameter to link parent.lua')
    reaper.defer(main)
end

-- call other script to avoid redundancy
dofile(script_path .. '/tdspk - Modulation Box - Set last touched FX parameter as link parent.lua')
main()

function at_exit()
  reaper.SetToggleCommandState(section_id, cmd_id, 0)
  reaper.RefreshToolbar2(section_id, cmd_id)
end

reaper.atexit(at_exit)
