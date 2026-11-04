-- ============================================================
-- SESSION GUARD
-- SERVER ONLY | ModuleScript
-- ติดตาม Session, Playtime, Action Consistency
-- ============================================================

local Players = game:GetService("Players")

local SecurityAudit     = require(script.Parent:WaitForChild("SecurityAudit"))
local PermissionService = require(script.Parent:WaitForChild("PermissionService"))

local SessionGuard = {}

local sessions = {}
local MAX_REASONABLE_PLAYTIME_FOR_ADMIN = 300

local function createSession(player)
    sessions[player] = {
        joinTime       = os.clock(),
        lastAction     = os.clock(),
        actionCount    = 0,
        suspiciousTime = 0,
        killedBy       = nil,
        flagged        = false,
    }
end

-- ============================================================
-- PUBLIC API
-- ============================================================
function SessionGuard.GetSession(player)
    return sessions[player]
end

function SessionGuard.GetPlaytime(player)
    local s = sessions[player]
    if not s then return 0 end
    return os.clock() - s.joinTime
end

function SessionGuard.RecordAction(player)
    local s = sessions[player]
    if not s then return end
    s.lastAction   = os.clock()
    s.actionCount += 1

    local playtime = os.clock() - s.joinTime
    if playtime < 30 and s.actionCount > 20 then
        SecurityAudit.Record(player, "RAPID_ACTION",
            "Count=" .. s.actionCount .. " in " .. math.floor(playtime) .. "s")
        s.suspiciousTime += 1
    end
end

function SessionGuard.IsPrivileged(player)
    if PermissionService.GetRole(player) == "Player" then
        return false
    end
    return SessionGuard.GetPlaytime(player) >= MAX_REASONABLE_PLAYTIME_FOR_ADMIN
end

function SessionGuard.Flag(player, reason)
    local s = sessions[player]
    if not s then return end
    s.flagged = true
    SecurityAudit.Record(player, "SESSION_FLAGGED", reason)
end

function SessionGuard.IsFlagged(player)
    local s = sessions[player]
    return s and s.flagged == true
end

-- ============================================================
-- AUTO CREATE + CLEANUP
-- ============================================================
local function onPlayerAdded(player)
    createSession(player)
    print("[SESSION] New session for", player.UserId)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
    createSession(p)
end

Players.PlayerRemoving:Connect(function(player)
    local s = sessions[player]
    if s then
        print("[SESSION] Ended", player.UserId,
            "Playtime:", math.floor(os.clock() - s.joinTime) .. "s",
            "Actions:", s.actionCount)
    end
    sessions[player] = nil
end)

print("[SESSION] Guard loaded")
return SessionGuard
