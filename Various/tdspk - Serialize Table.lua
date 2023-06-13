local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

function serialize (o)
  if type(o) == "number" then
    io.write(o)
  elseif type(o) == "string" then
    io.write(string.format("%q", o))
  elseif type(o) == "table" then
    io.write("{\n")
    for k,v in pairs(o) do
      io.write("  ", k, " = ")
      serialize(v)
      io.write(",\n")
    end
    io.write("}\n")
  else
    error("cannot serialize a " .. type(o))
  end
end

data = {
  [">Render Blocks"] = 
  {
    ["Pack + Name"] = "_RSfbceb6c12902c0f7fde704da17bf0a24a356cf52",
    ["Settings"] = "_RS2d95a289c8495b7081d24aa3fe4610f3e6f15a12"
  };
}

--serialize(data)

-- Open file for writing
local file = io.open(script_path .. "output.txt", "w")

-- Write string to file
file:write("Hello, world!")

-- Close file
file:close()
