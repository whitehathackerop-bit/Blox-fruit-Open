-- ============================================================
-- PRODUCTION READINESS CHECK
-- SERVER | Script
-- ตรวจสอบว่าโครงสร้างครบก่อน deploy
-- ============================================================

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

task.wait(5)   -- รอให้ทุก Script โหลดก่อน

-- ============================================================
-- CHECKS
-- ============================================================
local checks = {
    -- ModuleScripts
    { "PermissionService",    ServerScriptService, "SecurityModules", "PermissionService",   "ModuleScript" },
    { "SecurityAudit",        ServerScriptService, "SecurityModules", "SecurityAudit",       "ModuleScript" },
    { "AntiCheat",            ServerScriptService, "SecurityModules", "AntiCheat",           "ModuleScript" },
    { "AdvancedAntiCheat",    ServerScriptService, "SecurityModules", "AdvancedAntiCheat",   "ModuleScript" },
    { "CryptoHelper",         ServerScriptService, "SecurityModules", "CryptoHelper",        "ModuleScript" },
    { "TokenService",         ServerScriptService, "SecurityModules", "TokenService",        "ModuleScript" },
    { "SessionGuard",         ServerScriptService, "SecurityModules", "SessionGuard",        "ModuleScript" },
    { "ModulePolicy",         ServerScriptService, "SecurityModules", "ModulePolicy",        "ModuleScript" },
    { "BanService",           ServerScriptService, "SecurityModules", "BanService",          "ModuleScript" },
    -- Scripts
    { "SecureTeleport",       ServerScriptService, nil, "SecureTeleport",        "Script" },
    { "SecurityAdmin",        ServerScriptService, nil, "SecurityAdmin",         "Script" },
    { "CronGuard",            ServerScriptService, nil, "CronGuard",             "Script" },
    -- Remotes
    { "TeleportRemote",       ReplicatedStorage,   nil, "SecureTeleportRequest", "RemoteFunction" },
    { "AdminRemote",          ReplicatedStorage,   nil, "SecurityAdminRequest",  "RemoteFunction" },
    { "TokenRemote",          ReplicatedStorage,   nil, "SecurityTokenUpdate",   "RemoteEvent"    },
    { "PolicyRemote",         ReplicatedStorage,   nil, "ModulePolicyRequest",   "RemoteFunction" },
    { "ForceOffRemote",       ReplicatedStorage,   nil, "ModuleForceOff",        "RemoteEvent"    },
}

local failures = 0

for _, item in ipairs(checks) do
    local name         = item[1]
    local parent       = item[2]
    local subfolder    = item[3]
    local objectName   = item[4]
    local expectedCls  = item[5]

    if subfolder then
        local sf = parent:FindFirstChild(subfolder)
        if not sf then
            failures += 1
            warn("[NOT READY]", name, "→ missing subfolder:", subfolder)
            continue
        end
        parent = sf
    end

    local obj = parent:FindFirstChild(objectName)
    if obj and obj.ClassName == expectedCls then
        print("[READY]", name)
    else
        failures += 1
        warn("[NOT READY]", name,
            "→ expected:", expectedCls,
            "got:", obj and obj.ClassName or "nil")
    end
end

-- ============================================================
-- DESTINATION CHECKS
-- ============================================================
local folder = workspace:FindFirstChild("SecureTeleportPoints")
if not folder or not folder:IsA("Folder") then
    failures += 1
    warn("[NOT READY] Destination folder missing")
else
    for _, name in ipairs({ "Spawn", "Village", "Forest", "AdminBase" }) do
        local part = folder:FindFirstChild(name)
        if part and part:IsA("BasePart") and part.Anchored then
            print("[READY] Destination:", name)
        else
            failures += 1
            warn("[NOT READY] Destination:", name)
        end
    end
end

-- ============================================================
-- SUMMARY
-- ============================================================
print("================================")
print("[PRODUCTION READINESS]")
print("Failures:", failures)

if failures == 0 then
    print("[READY] ✅ Structural checks passed")
else
    warn("[BLOCKED] ❌ Fix configuration errors")
end

print("================================")
