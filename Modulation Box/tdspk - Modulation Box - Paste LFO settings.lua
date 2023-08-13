-- @description Paste LFO settings
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

paste_parameter_data(param_base, param_list, ext_section, ext_key)
