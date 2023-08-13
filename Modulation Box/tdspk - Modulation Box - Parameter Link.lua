local info = debug.getinfo(1, 'S');
script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]

dofile(script_path .. '/tdspk - Modulation Box - Components.lua')

track = reaper.GetTrack(0, 0)
fx = 1
a = reaper.TrackFX_SetNamedConfigParm(track, 1, "param.0.plink.active", "1")
b = reaper.TrackFX_SetNamedConfigParm(track, 1, "param.0.plink.effect", 0)
c = reaper.TrackFX_SetNamedConfigParm(track, 1, "param.0.plink.param", 0)

ctx = reaper.ImGui_CreateContext("Parameter Link")

IDLE = 0
LEAD = 1
FOLLOWER = 2

plink = {
  lead = nil,
  followers = {},
  select_mode = 0
}

mbox = {
  param_name = ""
}

lead_clicked = 0
follow_clicked = 0

function myWindow()
  if reaper.ImGui_Button(ctx, "Select Lead") then
    lead_clicked = lead_clicked + 1
    follow_clicked = 0
  end

  select_mode = IDLE

  if lead_clicked & 1 ~= 0 then
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_Text(ctx, "Select any param you want boy")
    select_mode = LEAD
  end

  if select_mode == LEAD then
    QueryLiveFxInfo()

    if not lead then
      plink.lead = {}
    end
    
    plink.lead["track"] = mbox.track
    plink.lead["track_name"] = mbox.track_name
    plink.lead["fx_id"] = mbox.fx_id
    plink.lead["param_id"] = mbox.param_id
  end

  if plink.lead then
    reaper.ImGui_Text(ctx, "Lead: " .. plink.lead.track_name .. "-" .. plink.lead.fx_id .. "-" .. plink.lead.param_id)
  end

  if reaper.ImGui_Button(ctx, "Select Follow") then
    follow_clicked = follow_clicked + 1
    lead_clicked = 0
  end

  if follow_clicked & 1 ~= 0 then
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_Text(ctx, "Select any param you want gurl")
    select_mode = FOLLOW
  end

  if select_mode == FOLLOW then
    QueryLiveFxInfo()
    
    rv = reaper.TrackFX_SetNamedConfigParm(mbox.track, mbox.fx_id, "param." .. mbox.param_id, ".plink.active", "1")
    rv = reaper.TrackFX_SetNamedConfigParm(mbox.track, mbox.fx_id, "param." .. mbox.param_id, ".plink.effect", plink.lead.fx_id)
    rv = reaper.TrackFX_SetNamedConfigParm(mbox.track, mbox.fx_id, "param." .. mbox.param_id, ".plink.param", plink.lead.param_id)
    
    table.insert(plink.followers, {mbox.track_name, mbox.fx_name, mbox.param_name})
  end

  reaper.ImGui_Text(ctx, "Follow: " .. mbox.param_name)

end

function loop()
  reaper.ImGui_SetNextWindowSize(ctx, 400, 400)
  local visible, open = reaper.ImGui_Begin(ctx, "Parameter Link", true)
  if visible then
    myWindow()
    reaper.ImGui_End(ctx)
  end

  if open then
    reaper.defer(loop)
  end
end

--loop()
