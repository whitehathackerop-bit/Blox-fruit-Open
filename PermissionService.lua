-- ============================================================
-- PERMISSION SERVICE
-- SERVER ONLY | ModuleScript
-- ฐานของระบบทั้งหมด - จัดการ Role และ Permission
-- ============================================================

local Players = game:GetService("Players")

local PermissionService = {}

-- ============================================================
-- CONFIG — แก้ตรงนี้เพื่อกำหนดสิทธิ์
-- ============================================================
local ROLE_CONFIG = {
    -- ใส่ UserId ของคุณเองตรงนี้เพื่อเป็น Admin
    -- [123456789] = "Admin",
    -- [987654321] = "Moderator",
}

local GROUP_CONFIG = {
    -- GroupId = { [minRank] = "Role" }
    -- [12345678] = { [1] = "Player", [50] = "Moderator", [200] = "Admin" },
}

local ROLE_PERMISSIONS = {
    Player = {
        ["teleport.basic"]        = true,
        ["security.view_logs"]    = false,
        ["security.manage"]       = false,
        ["player.moderate"]       = false,
        ["teleport.hyper"]        = false,
        ["module.god"]            = false,
        ["module.autododge"]      = true,
        ["module.autoreset"]      = true,
        ["module.aura"]           = true,
    },
    Moderator = {
        ["teleport.basic"]        = true,
        ["security.view_logs"]    = true,
        ["security.manage"]       = false,
        ["player.moderate"]       = true,
        ["teleport.hyper"]        = true,
        ["module.god"]            = true,
        ["module.autododge"]      = true,
        ["module.autoreset"]      = true,
        ["module.aura"]           = true,
    },
    Admin = {
        ["teleport.basic"]        = true,
        ["security.view_logs"]    = true,
        ["security.manage"]       = true,
        ["player.moderate"]       = true,
        ["teleport.hyper"]        = true,
        ["module.god"]            = true,
        ["module.autododge"]      = true,
        ["module.autoreset"]      = true,
        ["module.aura"]           = true,
    },
}

local authenticated = {}
local roles         = {}

local function resolveRoleFromGroup(player)
    for groupId, rankMap in pairs(GROUP_CONFIG) do
        local success, rank = pcall(function()
            return player:GetRankInGroup(groupId)
        end)
        if success and rank and rank > 0 then
            local bestRank, bestRole = -1, nil
            for minRank, role in pairs(rankMap) do
                if rank >= minRank and minRank > bestRank then
                    bestRank = minRank
                    bestRole = role
                end
            end
            if bestRole then return bestRole end
        end
    end
    return nil
end

local function resolveRole(player)
    if not player or not player.Parent then return "Player" end
    if ROLE_CONFIG[player.UserId] then
        return ROLE_CONFIG[player.UserId]
    end
    local groupRole = resolveRoleFromGroup(player)
    if groupRole then return groupRole end
    return "Player"
end

function PermissionService.Authenticate(player)
    if not player or not player:IsA("Player") then return false end
    authenticated[player] = true
    roles[player]         = resolveRole(player)
    return true
end

function PermissionService.IsAuthenticated(player)
    return authenticated[player] == true
end

function PermissionService.GetRole(player)
    return roles[player] or "Player"
end

function PermissionService.HasPermission(player, permission)
    if not authenticated[player] then return false end
    if typeof(permission) ~= "string" then return false end
    local role = roles[player] or "Player"
    local perms = ROLE_PERMISSIONS[role]
    if not perms then return false end
    return perms[permission] == true
end

function PermissionService.Authorize(player, permission)
    if not PermissionService.IsAuthenticated(player) then
        return false, "Not authenticated"
    end
    if not PermissionService.HasPermission(player, permission) then
        return false, "Missing permission: " .. tostring(permission)
    end
    return true, "OK"
end

local function onPlayerAdded(player)
    PermissionService.Authenticate(player)
    print("[PERMISSION] Authenticated", player.UserId, "as", roles[player])
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
    onPlayerAdded(p)
end

Players.PlayerRemoving:Connect(function(player)
    authenticated[player] = nil
    roles[player]         = nil
end)

print("[PERMISSION] Service loaded")
return PermissionService
