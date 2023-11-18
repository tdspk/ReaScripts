-- @description Enable LFO for last touched FX parameter
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @noindex
-- @changelog
--   First version

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/tdspk - Modulation Box - Common Functions.lua')

param_base = "lfo.active"

set_modulation(param_base, "1")
