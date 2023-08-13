-- @description This scripts enabled an LFO for the last touched parameter.
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @changelog
--   First version

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/tdspk - Modulation Box - Common Functions.lua')

param_base = "lfo.active"

set_modulation(param_base, "1")
