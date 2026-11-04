-- ============================================================
-- ADVANCED ANTI-CHEAT
-- SERVER ONLY | ModuleScript
-- CFrame diff + EMA speed + Fly + Noclip + Spike pattern
-- ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local SecurityAudit     = require(script.Parent:WaitForChild("SecurityAudit"))
local PermissionService = require(script.Parent:WaitForChild("PermissionService"))

local AdvancedAntiCheat = {}

local CONFIG = {
    MAX_CFRAME_DELTA_PER_TICK = 30,
    CFRAME_SAMPLE_INTERVAL    = 0.1,
    SPEED_EMA_ALPHA           = 0.3,
    MAX_EMA_SPEED             = 25,
    GRAVITY                   = 196.2,
    FLY_VELOCITY_TOLERANCE    = 50,
    FLY_CONSECUTIVE_TICKS     = 15,
    NOCLIP_RAYCAST_DISTANCE   = 3,
    NOCLIP_VIOLATION_LIMIT    = 3,
    SPIKE_WINDOW              = 1.0,
    MAX_SPIKES_PER_WINDOW     = 5,
}

local playerData = {}

local function getData(player)
    playerData[player] = playerData[player] or {
        lastCFrame    = nil,
        lastPos       = nil,
        lastSample    = 0,
        emaSpeed      = 0,
        flyTicks      = 0,
        noclipHits    = 0,
        spikes        = {},
        violations    = 0,
        lastViolation = 0,
        lastNoclipCheck = 0,
    }
    return playerData[player]
end

local function flag(player, reason, severity)
    local data = getData(player)
    local now  = os.clock()

    if now - data.lastViolation > 60 then
        data.violations = math.max(0, data.violations - 1)
    end

    data.violations += (severity or 1)
    data.lastViolation = now

    SecurityAudit.Record(player, "ADV_ANTICHEAT",
        reason .. " | Violations: " .. data.violations)

    if data.violations >= 5 then
        warn("[ADV-AC] Kicking", player.Name)
        player:Kick("Anti-Cheat: Repeated violations detected")
    end
end

local function checkCFrame(player, char, data, now)
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local currentCFrame = root.CFrame
    if data.lastCFrame then
        local deltaPos = (currentCFrame.Position - data.lastCFrame.Position).Magnitude
        if deltaPos > CONFIG.MAX_CFRAME_DELTA_PER_TICK then
            table.insert(data.spikes, now)
            for i = #data.spikes, 1, -1 do
                if now - data.spikes[i] > CONFIG.SPIKE_WINDOW then
                    table.remove(data.spikes, i)
                end
            end
            if #data.spikes >= CONFIG.MAX_SPIKES_PER_WINDOW then
                flag(player, "CFrame teleport spike: " .. math.floor(deltaPos), 2)
                data.spikes = {}
            else
                flag(player, "CFrame delta: " .. math.floor(deltaPos), 1)
            end
        end
    end
    data.lastCFrame = currentCFrame
end

local function checkSpeedEMA(player, data, root, dt)
    if dt <= 0 then return end
    local pos = root.Position
    if data.lastPos then
        local dist         = (pos - data.lastPos).Magnitude
        local instantSpeed = dist / dt

        data.emaSpeed = data.emaSpeed * (1 - CONFIG.SPEED_EMA_ALPHA)
                      + instantSpeed * CONFIG.SPEED_EMA_ALPHA

        if data.emaSpeed > CONFIG.MAX_EMA_SPEED then
            flag(player, string.format("Speed EMA: %.1f", data.emaSpeed), 1)
            data.emaSpeed = 0
        end
    end
    data.lastPos = pos
end

local function checkFly(player, humanoid, root, data)
    local velY  = root.AssemblyLinearVelocity.Y
    local state = humanoid:GetState()

    local isAirborne = state == Enum.HumanoidStateType.Freefall
                    or state == Enum.HumanoidStateType.Jumping

    if not isAirborne
        and math.abs(velY) > CONFIG.FLY_VELOCITY_TOLERANCE
        and not humanoid.Sit
        and not humanoid:FindFirstChild("HumanoidSeat") then

        data.flyTicks += 1
        if data.flyTicks >= CONFIG.FLY_CONSECUTIVE_TICKS then
            flag(player, string.format("Fly (Y=%.1f, ticks=%d)", velY, data.flyTicks), 2)
            data.flyTicks = 0
        end
    else
        data.flyTicks = math.max(0, data.flyTicks - 1)
    end
end

local function checkNoclip(player, char, root, data, now)
    if now - data.lastNoclipCheck < 0.5 then return end
    data.lastNoclipCheck = now

    local direction = root.CFrame.LookVector
    local params    = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}
    params.IgnoreWater = true

    local result = workspace:Raycast(
        root.Position,
        direction * CONFIG.NOCLIP_RAYCAST_DISTANCE,
        params
    )

    if result and result.Instance and result.Instance.CanCollide then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
            local vel        = root.AssemblyLinearVelocity
            local forwardVel = vel:Dot(direction)
            if forwardVel > 5 then
                data.noclipHits += 1
                if data.noclipHits >= CONFIG.NOCLIP_VIOLATION_LIMIT then
                    flag(player, "Noclip detected", 2)
                    data.noclipHits = 0
                end
            end
        end
    end
end

local lastTick = os.clock()

RunService.Heartbeat:Connect(function()
    local now = os.clock()
    local dt  = now - lastTick
    lastTick  = now

    for _, player in ipairs(Players:GetPlayers()) do
        if PermissionService.GetRole(player) ~= "Player" then
            continue
        end

        local char = player.Character
        if not char then continue end

        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local root     = char:FindFirstChild("HumanoidRootPart")
        if not humanoid or not root or humanoid.Health <= 0 then continue end

        local data = getData(player)

        pcall(function()
            checkCFrame(player, char, data, now)
            checkSpeedEMA(player, data, root, dt)
        end)

        if now - data.lastSample >= CONFIG.CFRAME_SAMPLE_INTERVAL then
            data.lastSample = now
            pcall(function()
                checkFly(player, humanoid, root, data)
                checkNoclip(player, char, root, data, now)
            end)
        end
    end
end)

Players.PlayerRemoving:Connect(function(p) playerData[p] = nil end)

print("[ADV-AC] Advanced Anti-Cheat loaded")
return AdvancedAntiCheat
