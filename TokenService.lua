-- ============================================================
-- TOKEN SERVICE
-- SERVER ONLY | ModuleScript
-- ออก/ตรวจ Token ที่ลงนามด้วย CryptoHelper
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CryptoHelper = require(script.Parent:WaitForChild("CryptoHelper"))
local SecurityAudit = require(script.Parent:WaitForChild("SecurityAudit"))

local TokenService = {}

local TOKEN_LIFETIME = 60
local MAX_REUSE      = 3
local tokens         = {}

-- ============================================================
-- ISSUE / VALIDATE / REVOKE
-- ============================================================
function TokenService.Issue(player)
    if not player or not player:IsA("Player") then return nil end

    local payload = tostring(player.UserId) .. "|" .. os.time()
    local token, expiry = CryptoHelper.MakeTimedToken(payload, TOKEN_LIFETIME)

    tokens[player] = {
        token   = token,
        expires = expiry,
        uses    = 0,
    }
    return token
end

function TokenService.Validate(player, token)
    if typeof(token) ~= "string" then return false end

    local ok, payload = CryptoHelper.VerifyTimedToken(token)
    if not ok then return false end

    local prefix = tostring(player.UserId) .. "|"
    if payload:sub(1, #prefix) ~= prefix then
        return false
    end

    local data = tokens[player]
    if not data then return false end
    if os.clock() > (data.expires - TOKEN_LIFETIME) + TOKEN_LIFETIME then
        tokens[player] = nil
        return false
    end
    if data.token ~= token then return false end
    if data.uses >= MAX_REUSE then
        tokens[player] = nil
        return false
    end

    data.uses += 1
    return true
end

function TokenService.Revoke(player)
    tokens[player] = nil
end

function TokenService.Broadcast(player)
    local remote = ReplicatedStorage:FindFirstChild("SecurityTokenUpdate")
    if not remote then
        remote = Instance.new("RemoteEvent")
        remote.Name   = "SecurityTokenUpdate"
        remote.Parent = ReplicatedStorage
    end

    local data = tokens[player]
    if data then
        remote:FireClient(player, data.token, TOKEN_LIFETIME)
    end
end

-- ============================================================
-- AUTO ISSUE ON SPAWN
-- ============================================================
local function issueAndBroadcast(player)
    TokenService.Issue(player)
    TokenService.Broadcast(player)
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        issueAndBroadcast(player)
    end)
    if player.Character then
        issueAndBroadcast(player)
    end
end)

for _, p in ipairs(Players:GetPlayers()) do
    if p.Character then
        issueAndBroadcast(p)
    end
end

Players.PlayerRemoving:Connect(function(p)
    tokens[p] = nil
end)

print("[TOKEN] Service loaded")
return TokenService
