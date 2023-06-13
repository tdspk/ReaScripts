local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

file = io.open(script_path .. "dropdown.txt", "r")

count = 0
first_char = ""
level = 0
prev_line = ""
menu_items = ""

for line in file:lines() do
  menu_items = menu_items .. select(1, line:gsub("\t", "")) .. "|"
end

io.close()

function traverse_data(table)
  for k, v in pairs(table) do
    menu_items = menu_items .. k .. "|"
    if (string.sub(k, 1, 1) == ">") then
      traverse_data(v)
    else
      counter = counter + 1
      mapped_actions[counter] = v
    end
  end
end



gfx.init("MENU", 0, 0)

gfx.x = gfx.mouse_x
gfx.y = gfx.mouse_y

data = {
  [">Render Blocks"] = 
  {
    ["Pack + Name"] = "_RSfbceb6c12902c0f7fde704da17bf0a24a356cf52",
    ["Settings"] = "_RS2d95a289c8495b7081d24aa3fe4610f3e6f15a12"
  };
}

--menu_items = ""
--mapped_actions = {}
--counter = 0
--traverse_data(data)

input = gfx.showmenu(menu_items)

if (input ~= 0) then
  --command = mapped_actions[input]
  --id = reaper.NamedCommandLookup(command)
  --reaper.Main_OnCommand(id, 0)
end
