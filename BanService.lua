-- ============================================================
-- BAN SERVICE
-- SERVER ONLY | ModuleScript
-- Persistent Ban ด้วย DataStore + In-Memory Cache
-- ============================================================

local Players          = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local SecurityAudit = require(script.Parent:WaitForChild("SecurityAudit"))

local BanService = {}

local BAN_STORE = DataStoreService:GetDataStore("SecurityBanList_v1")
local CACHE     = {}
local CACHE_TTL = 300

-- ============================================================
-- INTERNAL
-- ============================================================
local function loadBan(userId)
    local cached = CACHE[userId]
    if cached and (os.time() - cached.cachedAt) < CACHE_TTL then
        return cached
    end

    local ok, data = pcall(function()
        return BAN_STORE:GetAsync(tostring(userId))
    end)

    if not ok then
        warn("[BAN] DataStore read failed:", userId)
        return nil
    end

    if data then
        data.cachedAt = os.time()
        CACHE[userId] = data
    end
    return data
end

local function saveBan(userId, data)
    local ok, err = pcall(function()
        BAN_STORE:SetAsync(tostring(userId), data)
    end)
    if not ok then
        warn("[BAN] DataStore write failed:", userId, err)
        return false
    end
    data.cachedAt = os.time()
    CACHE[userId] = data
    return true
end

-- ============================================================
-- PUBLIC API
-- ============================================================
function BanService.IsBanned(userId)
    local data = loadBan(userId)
    if not data then return false, nil end
    if not data.banned then return false, nil end

    if data.expires and data.expires > 0 and os.time() > data.expires then
        data.banned = false
        saveBan(userId, data)
        return false, nil
    end

    return true, data.reason or "No reason provided"
end

function BanService.Ban(userId, reason, durationSeconds, bannedBy)
    if typeof(userId) ~= "number" or userId <= 0 then
        return false, "INVALID_USERID"
    end

    local data = {
        banned   = true,
        reason   = tostring(reason or "Banned"):sub(1, 200),
        bannedAt = os.time(),
        expires  = durationSeconds and (os.time() + durationSeconds) or 0,
        bannedBy = (bannedBy and bannedBy.UserId) or 0,
    }

    if not saveBan(userId, data) then
        return false, "STORE_FAILED"
    end

    SecurityAudit.Record(nil, "BAN_ADDED",
        "UserId=" .. userId .. " Reason=" .. data.reason)

    local target = Players:GetPlayerByUserId(userId)
    if target then
        target:Kick("Banned: " .. data.reason)
    end

    return true, "BANNED"
end

function BanService.Unban(userId)
    local data = loadBan(userId)
    if not data then return false, "NOT_FOUND" end
    data.banned = false
    if not saveBan(userId, data) then
        return false, "STORE_FAILED"
    end
    SecurityAudit.Record(nil, "BAN_REMOVED", "UserId=" .. userId)
    return true, "UNBANNED"
end

function BanService.ClearCache(userId)
    CACHE[userId] = nil
end

-- ============================================================
-- AUTO KICK ON JOIN
-- ============================================================
Players.PlayerAdded:Connect(function(player)
    local banned, reason = BanService.IsBanned(player.UserId)
    if banned then
        task.wait(1)
        player:Kick("Banned: " .. tostring(reason))
        SecurityAudit.Record(player, "BANNED_JOIN", reason)
    end
end)

print("[BAN] Service loaded")
return BanService
