-- ============================================================
-- CRON GUARD
-- SERVER | Script
-- Self-Healing: ตรวจ Remote + Auth ทุก 60 วิ
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MODULES = script.Parent:FindFirstChild("SecurityModules") or script.Parent

local SecurityAudit     = require(MODULES:WaitForChild("SecurityAudit"))
local PermissionService = require(MODULES:WaitForChild("PermissionService"))

-- ============================================================
-- CONFIG
-- ============================================================
local REQUIRED_REMOTES = {
    { name = "SecureTeleportRequest",  class = "RemoteFunction" },
    { name = "SecurityAdminRequest",   class = "RemoteFunction" },
    { name = "ModulePolicyRequest",    class = "RemoteFunction" },
    { name = "SecurityTokenUpdate",    class = "RemoteEvent"    },
    { name = "ModuleForceOff",         class = "RemoteEvent"    },
}

local CHECK_INTERVAL = 60

-- ============================================================
-- CHECK 1: Remote Integrity + Self-Heal
-- ============================================================
local function checkRemotes()
    local healed = 0
    for _, info in ipairs(REQUIRED_REMOTES) do
        local r = ReplicatedStorage:FindFirstChild(info.name)
        if not r or not r:IsA(info.class) then
            warn("[CRON] Missing/Incorrect Remote:", info.name, "expected:", info.class)
            SecurityAudit.Record(nil, "CRON_MISSING_REMOTE", info.name)

            -- Self-heal: สร้างคืน
            if r then
                pcall(function() r:Destroy() end)
            end
            local newRemote = Instance.new(info.class)
            newRemote.Name   = info.name
            newRemote.Parent = ReplicatedStorage
            healed += 1
        end
    end
    return healed
end

-- ============================================================
-- CHECK 2: Player Authentication
-- ============================================================
local function checkPlayers()
    local reauth = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if not PermissionService.IsAuthenticated(player) then
            warn("[CRON] Player not authenticated:", player.UserId)
            PermissionService.Authenticate(player)
            SecurityAudit.Record(player, "CRON_REAUTH", "Re-authenticated")
            reauth += 1
        end
    end
    return reauth
end

-- ============================================================
-- CHECK 3: Audit Log Size Warning
-- ============================================================
local function checkLogSize()
    local count = SecurityAudit.Count()
    if count >= 450 then
        SecurityAudit.Record(nil, "CRON_LOG_WARNING",
            "Log nearly full: " .. count .. "/500")
    end
    return count
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
task.spawn(function()
    -- รอให้ Remote ถูกสร้างก่อน
    task.wait(10)

    while true do
        local ok, err = pcall(function()
            local healed  = checkRemotes()
            local reauth  = checkPlayers()
            local logSize = checkLogSize()

            if healed > 0 or reauth > 0 then
                SecurityAudit.Record(nil, "CRON_HEALED",
                    "Remotes=" .. healed .. " Reauth=" .. reauth)
            else
                SecurityAudit.Record(nil, "CRON_HEALTHY",
                    "Log=" .. logSize .. "/500")
            end
        end)

        if not ok then
            SecurityAudit.Record(nil, "CRON_ERROR", tostring(err))
        end

        task.wait(CHECK_INTERVAL)
    end
end)

print("[CRON] Guard loaded")
