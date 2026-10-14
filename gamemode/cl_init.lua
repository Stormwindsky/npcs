include("shared.lua")

local bgMusic = nil

local function InitBackgroundMusic()
    if bgMusic then 
        bgMusic:Stop()
        bgMusic = nil 
    end

    -- Full path to the audio file in your gamemode
    sound.PlayFile("gamemodes/npcs/gamemode/sound/background_music.ogg", "noblock noplay", function(station, errCode, errStr)
        if IsValid(station) then
            bgMusic = station
            bgMusic:SetVolume(0.4)
            bgMusic:Play()
            
            -- Automatic loop
            hook.Add("Think", "CheckBackgroundMusicLoop", function()
                if IsValid(bgMusic) then
                    if bgMusic:GetState() == GMOD_CHANNEL_STOPPED then
                        bgMusic:SetTime(0)
                        bgMusic:Play()
                    end
                else
                    hook.Remove("Think", "CheckBackgroundMusicLoop")
                end
            end)
            
            print("[Gamemode] Background music started successfully!")
        else
            print("[Gamemode] Audio playback error: " .. tostring(errStr) .. " (Code: " .. tostring(errCode) .. ")")
        end
    end)
end

hook.Add("InitPostEntity", "StartGamemodeMusicDelay", function()
    timer.Simple(2.0, function()
        InitBackgroundMusic()
    end)
end)

hook.Add("ShutDown", "StopGamemodeMusic", function()
    if IsValid(bgMusic) then
        bgMusic:Stop()
    end
end)
