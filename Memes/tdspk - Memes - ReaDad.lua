response = reaper.ExecProcess("curl -s https://icanhazdadjoke.com/", 0)

response = string.sub(response, 2)

if response ~= nil then
  reaper.ShowMessageBox(response, "Dad Joke", 0)
end
