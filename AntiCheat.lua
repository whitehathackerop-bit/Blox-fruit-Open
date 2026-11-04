-- ============================================================
-- ANTI-CHEAT MODULE
-- SERVER ONLY | ModuleScript
-- ตรวจ WalkSpeed / Fly / Noclip / Teleport Hack
-- ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local SecurityAudit     = require(script.Parent:WaitForChild("SecurityAudit"))
local PermissionService = require(script.Parent:WaitForChild("PermissionService"))

local AntiCheat = {}

local CONFIG = {
    MAX_WALKSPEED       = 20,
    MAX_JUMPPOWER       = 60,
    WALKSPEED_TOLERANCE = 3,
    JUMP_TOLERANCE      = 5,
    FLY_SPEED_THRESHOLD = 100,
    FLY_TIME_THRESHOLD  = 2.0,
    NOCLIP_SAMPLE_TIME  = 0.5,
    TELEPORT_DISTANCE   = 500,
    CHECK_INTERVAL      = 0.5,
    ENABLED             = true,
}

local playerData = {}

local function getData(player)
    playerData[player] = playerData[player] or {
        lastPos     = nil,
        lastSample  = 0,
        flyTime     = 0,
        lastCheck   = 0,
        violations  = 0,
    }
    return playerData[player]
end

local function flagViolation(player, reason)
    local data = getData(player)
    data.violations += 1

    SecurityAudit.Record(player, "ANTICHEAT_VIOLATION",
        reason .. " (#" .. data.violations .. ")")

    if data.violations >= 3 then
        warn("[ANTICHEAT] Kicking", player.Name, "for repeated violations")
        player:Kick("Anti-Cheat: Multiple violations detected")
    end
end

local function checkPlayer(player)
    local data = getData(player)
    local char = player.Character
    if not char then return end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root     = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then return end
    if humanoid.Health <= 0 then return end

    local isStaff = PermissionService.GetRole(player) ~= "Player"

    if not isStaff then
        if humanoid.WalkSpeed > CONFIG.MAX_WALKSPEED + CONFIG.WALKSPEED_TOLERANCE then
            flagViolation(player, "WalkSpeed: " .. math.floor(humanoid.WalkSpeed))
            humanoid.WalkSpeed = 16
        end
        if humanoid.JumpPower > CONFIG.MAX_JUMPPOWER + CONFIG.JUMP_TOLERANCE then
            flagViolation(player, "JumpPower: " .. math.floor(humanoid.JumpPower))
            humanoid.JumpPower = 50
        end
    end

    local vel    = root.AssemblyLinearVelocity
    local speedY = math.abs(vel.Y)

    if speedY > CONFIG.FLY_SPEED_THRESHOLD
        and humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
        data.flyTime += CONFIG.CHECK_INTERVAL
        if data.flyTime >= CONFIG.FLY_TIME_THRESHOLD then
            flagViolation(player, "Fly detected (Y=" .. math.floor(speedY) .. ")")
            data.flyTime = 0
        end
    else
        data.flyTime = 0
    end

    local now = os.clock()
    if data.lastPos and (now - data.lastSample) < 1.5 then
        local dist = (root.Position - data.lastPos).Magnitude
        if dist > CONFIG.TELEPORT_DISTANCE then
            flagViolation(player, "Suspicious jump: " .. math.floor(dist) .. " studs")
        end
    end
    data.lastPos    = root.Position
    data.lastSample = now

    local state = humanoid:GetState()
    if state == Enum.HumanoidStateType.Flying
        or state == Enum.HumanoidStateType.PlatformStanding then
        if not char:FindFirstChild("HumanoidSeat") and not humanoid.Sit then
            flagViolation(player, "Invalid state: " .. tostring(state))
        end
    end
end

RunService.Heartbeat:Connect(function()
    if not CONFIG.ENABLED then return end
    local now = os.clock()
    for _, player in ipairs(Players:GetPlayers()) do
        local data = getData(player)
        if now - data.lastCheck >= CONFIG.CHECK_INTERVAL then
            data.lastCheck = now
            local ok, err = pcall(checkPlayer, player)
            if not ok then
                SecurityAudit.Record(player, "SECURITY_ERROR",
                    "AntiCheat: " .. tostring(err))
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(p) playerData[p] = nil end)

print("[ANTICHEAT] Module loaded")
return AntiCheat
