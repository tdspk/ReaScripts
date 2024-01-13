function ToMinutesAndSeconds(seconds)
  seconds = math.floor(seconds)
  local minutes = math.floor(seconds / 60)
  local remainingSeconds = seconds % 60
  return string.format("%02d:%02d", minutes, remainingSeconds)
end

rv, marker_count, region_count = reaper.CountProjectMarkers(0)

captions = ""

for i=0, marker_count + region_count -1 do
  rv, isrgn, pos, _, name = reaper.EnumProjectMarkers2(0, i)
  local time = ToMinutesAndSeconds(pos)
  captions = string.format("%s %s %s\n", captions, time, name)
end

reaper.ClearConsole()
reaper.ShowConsoleMsg(captions)
