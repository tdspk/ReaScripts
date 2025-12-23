local ctx = reaper.ImGui_CreateContext("tdspk - Notes List")

local function Loop()
    reaper.ImGui_SetNextWindowSize(ctx, 0, 0, reaper.ImGui_Cond_Once())
    local visible, open = reaper.ImGui_Begin(ctx, "tdspk - Notes List", true)

    if visible then
        if reaper.ImGui_CollapsingHeader(ctx, "Project Notes", false) then
            local notes = reaper.GetSetProjectNotes(0, false, "")
            reaper.ImGui_Text(ctx, notes)
        end

        if reaper.ImGui_CollapsingHeader(ctx, "Media Items", false) then
            for i = 0, reaper.CountMediaItems(0) - 1 do
                local item = reaper.GetMediaItem(0, i)
                local rv, notes = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)

                if rv then
                    reaper.ImGui_Text(ctx, notes)
                end
            end
        end

        reaper.ImGui_End(ctx)
    end
    if open then
        reaper.defer(Loop)
    end
end


reaper.defer(Loop)

::eof::
