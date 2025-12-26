local ctx = reaper.ImGui_CreateContext("tdspk - Notes List")

data = {
  items = {},
  update = -1
}

local function UnselectMediaItems()
  for i = 0, reaper.CountMediaItems(0) - 1 do
    local item = reaper.GetMediaItem(0, i)
    reaper.SetMediaItemSelected(item, false)
  end
end

local function CacheItems()
  local items = {}

  for i = 0, reaper.CountMediaItems(0) - 1 do
    local item = reaper.GetMediaItem(0, i)
    items[i + 1] = item
  end

  return items
end

local function Loop()
  reaper.ImGui_SetNextWindowSize(ctx, 500, 500, reaper.ImGui_Cond_Once())
  local visible, open = reaper.ImGui_Begin(ctx, "tdspk - Notes List", true)

  if visible then
    if reaper.GetProjectStateChangeCount(0) ~= data.update then
      data.items = CacheItems()
      data.update = reaper.GetProjectStateChangeCount(0)
    end

    if reaper.ImGui_CollapsingHeader(ctx, "Project Notes", false) then
      local notes = reaper.GetSetProjectNotes(0, false, "")
      reaper.ImGui_Text(ctx, notes)
    end

    if #data.items > 0 then
      if reaper.ImGui_CollapsingHeader(ctx, ("Media Items (%d)"):format(#data.items), false) then
        for i = 1, #data.items do
          local item = data.items[i]
          local rv, notes = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)

          if rv and notes ~= "" then
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), 1)

            local sel = reaper.ImGui_Selectable(ctx, ("%s##%d"):format(notes, i), false)
            if sel then
              UnselectMediaItems()
              reaper.SetMediaItemSelected(item, true)
              local itempos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
              reaper.SetEditCurPos2(0, itempos, true, false)
              reaper.UpdateArrange()
            end

            if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
              UnselectMediaItems()
              reaper.SetMediaItemSelected(item, true)
              reaper.Main_OnCommand(40850, 0) -- Item: Show notes for items...
              reaper.UpdateArrange()
            end
          end
        end
      end
    end

    reaper.ImGui_End(ctx)
  end
  if open then
    reaper.defer(Loop)
  end
end

data.items = CacheItems()

reaper.defer(Loop)

::eof::
