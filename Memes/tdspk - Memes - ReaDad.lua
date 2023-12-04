-- @description ReaDad - Dad Jokes for REAPER
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @changelog
--   First version

response = reaper.ExecProcess("curl -s https://icanhazdadjoke.com/", 0)

response = string.sub(response, 2)

if response ~= nil then
  reaper.ShowMessageBox(response, "ReaDad", 0)
end
