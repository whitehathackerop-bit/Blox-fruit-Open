-- ============================================================
-- SECURE TELEPORT — SERVER
-- มี Auth + Token + Audit + Cooldown + Rate Limit + Anti-Cheat
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local MODULES = script.Parent:FindFirstChild("SecurityModules") or script.Parent

local PermissionService  = require(MODULES:WaitForChild("PermissionService"))
local SecurityAudit      = require(MODULES:WaitForChild("SecurityAudit"))
local TokenService       = require(MODULES:WaitForChild("TokenService"))
local ModulePolicy       = require(MODULES:WaitForChild("ModulePolicy"))
local SessionGuard       = require(MODULES:WaitForChild("SessionGuard"))

-- เรียก AntiCheat + AdvancedAntiCheat ให้เริ่มทำงานอัตโนมัติ
require(MODULES:WaitForChild("AntiCheat"))
require(MODULES:WaitForChild("AdvancedAntiCheat"))

local CONFIG = {
    TELEPORT_COOLDOWN     = 3,
    REQUEST_INTERVAL      = 0.5,
    MAX_TELEPORT_DISTANCE = 2000,
    MAX_HORIZONTAL_SPEED  = 85,
    MOVEMENT_TOLERANCE    = 15,
    MOVEMENT_LOG_COOLDOWN = 5,
    ENABLE_MOVEMENT_AUDIT = true,
}

-- ============================================================
-- DESTINATIONS
-- ============================================================
local DESTINATIONS = workspace:FindFirstChild("SecureTeleportPoints")
if not (DESTINATIONS and DESTINATIONS:IsA("Folder")) then
    DESTINATIONS = Instance.new("Folder")
    DESTINATIONS.Name   = "SecureTeleportPoints"
    DESTINATIONS.Parent = workspace

    local defaults = {
        Spawn     = Vector3.new(0,    5,   0),
        Village   = Vector3.new(100,  5,   0),
        Forest    = Vector3.new(-100, 5,   0),
        AdminBase = Vector3.new(0,    50, 200),
    }
    for name, pos in pairs(defaults) do
        local p = Instance.new("Part")
        p.Name         = name
        p.Anchored     = true
        p.Size         = Vector3.new(6, 1, 6)
        p.Position     = pos
        p.Transparency = 1
        p.CanCollide   = false
        p.Parent       = DESTINATIONS
    end
    warn("[SECURITY] Created SecureTeleportPoints (4 destinations)")
end

-- ============================================================
-- REMOTES
-- ============================================================
local remote = ReplicatedStorage:FindFirstChild("SecureTeleportRequest")
if remote then
    assert(remote:IsA("RemoteFunction"), "Remote type conflict")
else
    remote = Instance.new("RemoteFunction")
    remote.Name   = "SecureTeleportRequest"
    remote.Parent = ReplicatedStorage
end

-- Module Policy Remote
local policyRemote = ReplicatedStorage:FindFirstChild("ModulePolicyRequest")
if not policyRemote then
    policyRemote = Instance.new("RemoteFunction")
    policyRemote.Name   = "ModulePolicyRequest"
    policyRemote.Parent = ReplicatedStorage
end

-- ============================================================
-- STATE
-- ============================================================
local playerState = {}

local function getState(player)
    playerState[player] = playerState[player] or {
        lastRequest     = 0,
        lastTeleport    = 0,
        lastPosition    = nil,
        lastSample      = 0,
        lastMovementLog = 0,
        character       = nil,
    }
    return playerState[player]
end

local function isFiniteNumber(v)
    return typeof(v) == "number" and v == v and math.abs(v) < math.huge
end

local function isValidCharacter(player)
    local character = player.Character
    if not character then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root     = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 then return nil end
    if not root or not root:IsA("BasePart") then return nil end
    return character, humanoid, root
end

local function getDestination(name)
    if typeof(name) ~= "string" or #name < 1 or #name > 40 then
        return nil
    end
    local d = DESTINATIONS:FindFirstChild(name)
    if not d or not d:IsA("BasePart") or not d.Anchored then return nil end
    local p = d.Position
    if not (isFiniteNumber(p.X) and isFiniteNumber(p.Y) and isFiniteNumber(p.Z)) then
        return nil
    end
    return d
end

local function performTeleport(player, destination)
    local character, humanoid, root = isValidCharacter(player)
    if not character then return false, "Character unavailable" end

    local state = getState(player)
    if (root.Position - destination.Position).Magnitude > CONFIG.MAX_TELEPORT_DISTANCE then
        return false, "Destination too far"
    end

    local targetCFrame = destination.CFrame * CFrame.new(0, 3, 0)
    local ok, err = pcall(function()
        if player.Character ~= character then error("Character changed") end
        if humanoid.Health <= 0 then error("Character dead") end
        character:PivotTo(targetCFrame)
        root.AssemblyLinearVelocity  = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)

    if not ok then
        SecurityAudit.Record(player, "SECURITY_ERROR", "Teleport failed: " .. tostring(err))
        return false, "Teleport failed"
    end

    state.lastTeleport = os.clock()
    state.lastPosition = root.Position
    state.lastSample   = os.clock()
    return true, "Teleport approved"
end

-- ============================================================
-- TELEPORT REMOTE HANDLER
-- ============================================================
remote.OnServerInvoke = function(player, destinationName, token)
    -- Heartbeat
    if destinationName == "__heartbeat__" then
        return true, "alive"
    end

    if not player or player.Parent ~= Players then
        return false, "Invalid player"
    end

    -- [1] Auth
    if not PermissionService.IsAuthenticated(player) then
        SecurityAudit.Record(player, "AUTHENTICATION_FAILED", "Teleport")
        return false, "AUTHENTICATION_FAILED"
    end

    -- [2] Token
    if not TokenService.Validate(player, token) then
        SecurityAudit.Record(player, "INVALID_TOKEN", "Teleport")
        return false, "INVALID_TOKEN"
    end

    -- [3] Basic permission
    if not PermissionService.HasPermission(player, "teleport.basic") then
        SecurityAudit.Record(player, "PERMISSION_DENIED", "teleport.basic")
        return false, "PERMISSION_DENIED"
    end

    local state = getState(player)
    local now   = os.clock()

    -- [4] Rate limit
    if now - state.lastRequest < CONFIG.REQUEST_INTERVAL then
        SecurityAudit.Record(player, "INVALID_REQUEST", "Teleport rate limit")
        return false, "Request rate limited"
    end
    state.lastRequest = now

    -- [5] Cooldown
    if now - state.lastTeleport < CONFIG.TELEPORT_COOLDOWN then
        return false, "Teleport cooldown"
    end

    -- [6] Destination
    local destination = getDestination(destinationName)
    if not destination then
        SecurityAudit.Record(player, "INVALID_REQUEST",
            "Bad destination: " .. tostring(destinationName))
        return false, "Invalid destination"
    end

    -- [7] Hyper destinations
    if destination.Name == "AdminBase"
        and not PermissionService.HasPermission(player, "teleport.hyper") then
        SecurityAudit.Record(player, "PERMISSION_DENIED", "teleport.hyper -> AdminBase")
        return false, "PERMISSION_DENIED"
    end

    SessionGuard.RecordAction(player)

    local success, message = performTeleport(player, destination)
    if success then
        SecurityAudit.Record(player, "TELEPORT_APPROVED", destination.Name)
    end
    return success, message
end

-- ============================================================
-- MODULE POLICY HANDLER
-- ============================================================
policyRemote.OnServerInvoke = function(player, moduleName, isActive)
    if not PermissionService.IsAuthenticated(player) then
        return false, "AUTHENTICATION_FAILED"
    end

    SessionGuard.RecordAction(player)

    if isActive then
        return ModulePolicy.Activate(player, moduleName)
    else
        ModulePolicy.Deactivate(player, moduleName)
        return true, "OK"
    end
end

-- ============================================================
-- MOVEMENT AUDIT
-- ============================================================
RunService.Heartbeat:Connect(function()
    if not CONFIG.ENABLE_MOVEMENT_AUDIT then return end
    local now = os.clock()
    for _, player in ipairs(Players:GetPlayers()) do
        local state = getState(player)
        local character, _, root = isValidCharacter(player)
        if not character then
            state.character    = nil
            state.lastPosition = nil
            continue
        end
        if state.character ~= character then
            state.character    = character
            state.lastPosition = root.Position
            state.lastSample   = now
            continue
        end
        if not state.lastPosition then
            state.lastPosition = root.Position
            state.lastSample   = now
            continue
        end
        local elapsed = now - state.lastSample
        if elapsed < 0.25 then continue end
        local d  = root.Position - state.lastPosition
        local hd = Vector3.new(d.X, 0, d.Z).Magnitude
        local allowed = CONFIG.MAX_HORIZONTAL_SPEED * elapsed + CONFIG.MOVEMENT_TOLERANCE
        if hd > allowed and now - state.lastMovementLog > CONFIG.MOVEMENT_LOG_COOLDOWN then
            SecurityAudit.Record(player, "MOVEMENT_ANOMALY",
                string.format("Dist=%.1f Elapsed=%.2f", hd, elapsed))
            state.lastMovementLog = now
        end
        state.lastPosition = root.Position
        state.lastSample   = now
    end
end)

Players.PlayerRemoving:Connect(function(p) playerState[p] = nil end)

print("[SECURITY] Secure Teleport loaded")
