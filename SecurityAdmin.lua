-- ============================================================
-- SECURITY ADMIN HANDLER — SERVER
-- ดู Log / Kick / Ban / Unban (ต้องมี Permission)
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MODULES = script.Parent:FindFirstChild("SecurityModules") or script.Parent

local PermissionService = require(MODULES:WaitForChild("PermissionService"))
local SecurityAudit     = require(MODULES:WaitForChild("SecurityAudit"))
local BanService        = require(MODULES:WaitForChild("BanService"))

-- Remote
local remote = ReplicatedStorage:FindFirstChild("SecurityAdminRequest")
if remote then
    assert(remote:IsA("RemoteFunction"), "Remote type conflict")
else
    remote = Instance.new("RemoteFunction")
    remote.Name   = "SecurityAdminRequest"
    remote.Parent = ReplicatedStorage
end

local requestTimes = {}
local INTERVAL     = 1

-- ============================================================
-- HELPERS
-- ============================================================
local function authorize(player, permission)
    if not PermissionService.IsAuthenticated(player) then
        return false
    end
    local allowed, reason = PermissionService.Authorize(player, permission)
    if not allowed then
        SecurityAudit.Record(player, "PERMISSION_DENIED", reason)
        return false
    end
    return true
end

local function isValidUserId(id)
    return typeof(id) == "number" and id > 0 and id % 1 == 0
end

-- ============================================================
-- HANDLER
-- ============================================================
local function handleRequest(player, action, targetUserId)
    if not PermissionService.IsAuthenticated(player) then
        return false, "AUTHENTICATION_FAILED"
    end

    local now  = os.clock()
    local last = requestTimes[player] or 0
    if now - last < INTERVAL then
        SecurityAudit.Record(player, "INVALID_REQUEST", "Admin rate limit")
        return false, "RATE_LIMITED"
    end
    requestTimes[player] = now

    if typeof(action) ~= "string" or #action > 40 then
        return false, "INVALID_ACTION"
    end

    -- ============================================================
    -- view_logs
    -- ============================================================
    if action == "view_logs" then
        if not authorize(player, "security.view_logs") then
            return false, "PERMISSION_DENIED"
        end
        SecurityAudit.Record(player, "ADMIN_VIEW_LOGS", "Requested recent logs")
        return true, SecurityAudit.GetRecent(50)
    end

    -- ============================================================
    -- ต้องมี security.manage ขึ้นไป
    -- ============================================================
    if not authorize(player, "security.manage") then
        return false, "PERMISSION_DENIED"
    end

    -- ============================================================
    -- kick_player
    -- ============================================================
    if action == "kick_player" then
        if not isValidUserId(targetUserId) then
            return false, "INVALID_TARGET"
        end
        if targetUserId == player.UserId then
            return false, "CANNOT_TARGET_SELF"
        end
        local target = Players:GetPlayerByUserId(targetUserId)
        if not target then
            return false, "TARGET_NOT_FOUND"
        end
        if not authorize(player, "player.moderate") then
            return false, "PERMISSION_DENIED"
        end
        SecurityAudit.Record(player, "ADMIN_KICK", "Target: " .. targetUserId)
        target:Kick("Removed by administrator.")
        return true, "PLAYER_KICKED"
    end

    -- ============================================================
    -- ban_player
    -- ============================================================
    if action == "ban_player" then
        if not isValidUserId(targetUserId) then
            return false, "INVALID_TARGET"
        end
        if targetUserId == player.UserId then
            return false, "CANNOT_TARGET_SELF"
        end
        if not authorize(player, "player.moderate") then
            return false, "PERMISSION_DENIED"
        end
        local ok, msg = BanService.Ban(targetUserId, "Admin action", 86400, player)
        SecurityAudit.Record(player, "ADMIN_BAN", "Target: " .. targetUserId)
        return ok, msg
    end

    -- ============================================================
    -- unban_player
    -- ============================================================
    if action == "unban_player" then
        if not isValidUserId(targetUserId) then
            return false, "INVALID_TARGET"
        end
        if not authorize(player, "player.moderate") then
            return false, "PERMISSION_DENIED"
        end
        return BanService.Unban(targetUserId)
    end

    -- ============================================================
    -- is_banned
    -- ============================================================
    if action == "is_banned" then
        if not isValidUserId(targetUserId) then
            return false, "INVALID_TARGET"
        end
        local banned, reason = BanService.IsBanned(targetUserId)
        return true, { banned = banned, reason = reason }
    end

    return false, "UNKNOWN_ACTION"
end

-- ============================================================
-- REMOTE HANDLER
-- ============================================================
remote.OnServerInvoke = function(player, action, targetUserId)
    local ok, result, message = pcall(handleRequest, player, action, targetUserId)
    if not ok then
        SecurityAudit.Record(player, "SECURITY_ERROR", tostring(result))
        return false, "INTERNAL_ERROR"
    end
    return result, message
end

Players.PlayerRemoving:Connect(function(p)
    requestTimes[p] = nil
end)

print("[SECURITY] Admin handler loaded")
