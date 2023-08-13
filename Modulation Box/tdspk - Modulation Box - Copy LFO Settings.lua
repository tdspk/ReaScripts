-- @description This script copies the LFO settings of the last touched parameter in an ExtState.
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @changelog
--   First version

local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/tdspk - Modulation Box - Common Functions.lua')

ext_section = "tdspk_mbox"
ext_key = "lfo_data"
param_base = ".lfo."
local param_list = {"active","dir","phase","speed","strength","temposync","free","shape"}

copy_parameter_data(param_base, param_list, ext_section, ext_key)
