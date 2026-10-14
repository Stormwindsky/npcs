-- Tell the server to send these files to the client
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

-- Include the shared file so the server can see it
include("shared.lua")

-- Send audio file to clients for download
resource.AddFile("sound/background_music.ogg")

-- Workshop ID registration
resource.AddWorkshop("2873868547")
resource.AddWorkshop("2878840758")

-- Tables to store player speed and jump tracking logic
local PlayerSpeeds = {}
local LastJumpTimes = {}

-- Function called every time a player spawns
function GM:PlayerSpawn(ply)
    ply:SetGravity(0.5)
    ply:SetMaxHealth(100)
    ply:SetWalkSpeed(350)
    ply:SetRunSpeed(350)
    
    ply:SetupHands()

    PlayerSpeeds[ply] = 350
    LastJumpTimes[ply] = CurTime()
end

-- Allow default flashlight usage (F Key)
function GM:PlayerSwitchFlashlight(ply, enabled)
    return true
end

-- Function to find a valid spawn position
local function FindSafeSpawnPosition()
    local players = player.GetAll()
    if #players == 0 then return nil end

    for i = 1, 15 do
        local randomPlayer = players[math.random(#players)]
        if not IsValid(randomPlayer) then continue end

        local angle = math.random() * 2 * math.pi
        local distance = math.random(600, 1500)
        local spawnPos = randomPlayer:GetPos() + Vector(math.cos(angle) * distance, math.sin(angle) * distance, 100)

        local tooClose = false
        for _, ply in ipairs(players) do
            if ply:GetPos():Distance(spawnPos) < 500 then
                tooClose = true
                break
            end
        end

        if not tooClose then
            local tr = util.TraceHull({
                start = spawnPos + Vector(0, 0, 50),
                endpos = spawnPos - Vector(0, 0, 200),
                mins = Vector(-16, -16, 0),
                maxs = Vector(16, 16, 72),
                mask = MASK_NPCWORLDSTATIC
            })

            if tr.Hit and not tr.StartSolid then
                return tr.HitPos + Vector(0, 0, 10)
            end
        end
    end

    return nil
end

-- Automatic spawn timer for 1 to 5 random NPCs / NextBots
timer.Create("AutoSpawnNextbots", 10, 0, function()
    local spawnCount = math.random(1, 5)
    local candidateClasses = {}

    -- 1. Classic NPCs from the spawn menu
    local npcList = list.Get("NPC")
    if npcList then
        for classname, _ in pairs(npcList) do
            table.insert(candidateClasses, classname)
        end
    end

    -- 2. NextBots and entities from all installed addons
    for classname, entTable in pairs(scripted_ents.GetList()) do
        local nameLower = string.lower(classname)
        if entTable.IsNextBot or string.StartWith(nameLower, "nextbot_") or string.find(nameLower, "bot") then
            if not string.find(nameLower, "joe") then
                table.insert(candidateClasses, classname)
            end
        end
    end

    if #candidateClasses == 0 then return end

    for i = 1, spawnCount do
        local spawnPos = FindSafeSpawnPosition()
        if spawnPos then
            local chosenClass = candidateClasses[math.random(#candidateClasses)]
            
            local ent = ents.Create(chosenClass)
            if IsValid(ent) then
                ent:SetPos(spawnPos)
                ent:Spawn()
                ent:Activate()
                
                -- Save spawn time for auto-cleanup after 5 minutes
                ent.SpawnTime = CurTime()
                
                if ent.StartNextbot then
                    ent:StartNextbot()
                end
            end
        end
    end
end)

-- Automatic despawn timer for NPCs after 5 minutes (300 seconds)
timer.Create("DespawnOldNPCs", 5, 0, function()
    local currentTime = CurTime()
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and (ent.IsNextBot and ent:IsNextBot() or ent:IsNPC()) then
            if ent.SpawnTime and (currentTime - ent.SpawnTime >= 300) then
                ent:Remove()
            end
        end
    end
end)

-- Movement physics handler (Sprinting, Jumping, Acceleration, Auto-bhop)
function GM:PlayerTick(ply, mv)
    if not IsValid(ply) or not ply:Alive() then return end

    local currentSpeed = PlayerSpeeds[ply] or 350
    local baseSpeed = 350
    local jogSpeed = 450  
    local maxSpeed = 650  
    local accelerationStep = 25 

    if ply:KeyDown(IN_JUMP) and ply:IsOnGround() then
        if not ply.JumpedThisFrame then
            local vel = ply:GetVelocity()
            vel.z = 260 
            ply:SetVelocity(vel)
            
            local startSpeed = math.max(currentSpeed, jogSpeed)
            PlayerSpeeds[ply] = math.min(startSpeed + accelerationStep, maxSpeed)
            LastJumpTimes[ply] = CurTime()
            
            ply.JumpedThisFrame = true
        end
    else
        ply.JumpedThisFrame = false
    end

    local velocity = ply:GetVelocity():Length2D()
    local isMoving = ply:KeyDown(IN_FORWARD) or ply:KeyDown(IN_BACK) or ply:KeyDown(IN_MOVELEFT) or ply:KeyDown(IN_MOVERIGHT)

    if isMoving and velocity < (currentSpeed * 0.4) and not ply:IsOnGround() then
        PlayerSpeeds[ply] = baseSpeed
    end

    if ply:IsOnGround() then
        if ply:KeyDown(IN_SPEED) and not ply:KeyDown(IN_JUMP) then
            if PlayerSpeeds[ply] < jogSpeed then
                PlayerSpeeds[ply] = math.min(PlayerSpeeds[ply] + 10, jogSpeed)
            elseif PlayerSpeeds[ply] > jogSpeed then
                PlayerSpeeds[ply] = math.max(PlayerSpeeds[ply] - 10, jogSpeed)
            end
        elseif CurTime() - LastJumpTimes[ply] > 2.0 and not ply:KeyDown(IN_SPEED) then
            if PlayerSpeeds[ply] > baseSpeed then
                PlayerSpeeds[ply] = math.max(PlayerSpeeds[ply] - 15, baseSpeed)
            end
        end
    end

    ply:SetWalkSpeed(PlayerSpeeds[ply])
    ply:SetRunSpeed(PlayerSpeeds[ply])
end

-- Data cleanup when a player disconnects
function GM:PlayerDisconnected(ply)
    PlayerSpeeds[ply] = nil
    LastJumpTimes[ply] = nil
end
