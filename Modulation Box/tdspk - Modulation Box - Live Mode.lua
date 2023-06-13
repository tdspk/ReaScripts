function p(msg)
    reaper.ShowConsoleMsg(msg)
end

function main()
    -- Get last touched fx
    rv, track_nr, fx, param_base = reaper.GetLastTouchedFX()

    if rv then
        track = reaper.GetTrack(0, track_nr-1)
        reaper.SNM_AddTCPFXParm(track, fx, param_base)
    end

    reaper.defer(main)
    -- cleanup after exit
end

main()

