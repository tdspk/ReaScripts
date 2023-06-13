local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/tdspk - Modulation Box - Common Functions.lua')

param_base = "acs.active"

set_modulation(param_base, "1")
