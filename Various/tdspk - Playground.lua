tracks = {}
tracks["a"] = {}
table.insert(tracks["a"], {1, 2, 3})
table.insert(tracks["a"], {4, 5, 6})
  for k, v in pairs(mbox.tracks) do
    reaper.ImGui_Text(ctx, k .. " - " .. v[1])
  end
