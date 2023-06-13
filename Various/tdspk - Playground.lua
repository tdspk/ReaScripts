local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

file = io.open(script_path .. "dropdown.txt", "r")
--io.input(file)

count = 0
first_char = ""

for line in file:lines() do
 
  first_char = string.sub(line, 1, 1)
  if (first_char == "\t") then
    count = count +1
  end
end

io.close()
