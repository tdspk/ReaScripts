local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

ucs_file = script_path .. "data/UCS.csv"

--dofile(script_path .. "bin/ucs_toolkit.out")
dofile(script_path .. "source/tdspk - Library Tools - UCS Toolkit.lua")
