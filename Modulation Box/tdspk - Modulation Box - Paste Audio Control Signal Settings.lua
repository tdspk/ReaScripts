local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/tdspk - Modulation Box - Common Functions.lua')

ext_section = "tdspk_mbox"
ext_key = "acs_data"
param_base = ".acs."
local param_list = {"active","dir","strength","attack","release","dblo","dbhi","chan","stereo","x2","y2"}

paste_parameter_data(param_base, param_list, ext_section, ext_key)
