-- ============================================================
-- SELF TEST
-- STUDIO ONLY | Script
-- ตรวจสอบว่า Module / Remote / Destination ทำงานครบ
-- ============================================================

local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not RunService:IsStudio() then
    warn("[SELF TEST] Disabled outside Studio")
    return
end

local MODULES = script.Parent:FindFirstChild("SecurityModules") or script.Parent

local PermissionService = require(MODULES:WaitForChild("PermissionService"))
local SecurityAudit     = require(MODULES:WaitForChild("SecurityAudit"))

local passed, failed = 0, 0

local function test(name, fn)
    local ok, res = pcall(fn)
    if ok and res == true then
        passed += 1
        print("[PASS]", name)
    else
        failed += 1
        warn("[FAIL]", name, "→", tostring(res))
    end
end

-- ============================================================
-- MODULE CHECKS
-- ============================================================
test("PermissionService loaded", function()
    return typeof(PermissionService.GetRole) == "function"
        and typeof(PermissionService.IsAuthenticated) == "function"
        and typeof(PermissionService.Authorize) == "function"
end)

test("SecurityAudit loaded", function()
    return typeof(SecurityAudit.Record) == "function"
        and typeof(SecurityAudit.GetRecent) == "function"
end)

test("CryptoHelper loaded", function()
    local ok, C = pcall(require, MODULES:WaitForChild("CryptoHelper"))
    return ok and typeof(C.Sign) == "function"
        and typeof(C.VerifyTimedToken) == "function"
end)

test("TokenService loaded", function()
    local ok, T = pcall(require, MODULES:WaitForChild("TokenService"))
    return ok and typeof(T.Issue) == "function"
        and typeof(T.Validate) == "function"
end)

test("SessionGuard loaded", function()
    local ok, S = pcall(require, MODULES:WaitForChild("SessionGuard"))
    return ok and typeof(S.GetPlaytime) == "function"
        and typeof(S.RecordAction) == "function"
end)

test("ModulePolicy loaded", function()
    local ok, M = pcall(require, MODULES:WaitForChild("ModulePolicy"))
    return ok and typeof(M.Activate) == "function"
        and typeof(M.Deactivate) == "function"
end)

test("BanService loaded", function()
    local ok, B = pcall(require, MODULES:WaitForChild("BanService"))
    return ok and typeof(B.IsBanned) == "function"
        and typeof(B.Ban) == "function"
        and typeof(B.Unban) == "function"
end)

-- ============================================================
-- REMOTE CHECKS
-- ============================================================
local REQUIRED_REMOTES = {
    "SecureTeleportRequest",
    "SecurityAdminRequest",
    "SecurityTokenUpdate",
    "ModulePolicyRequest",
    "ModuleForceOff",
}

for _, name in ipairs(REQUIRED_REMOTES) do
    test("Remote: " .. name, function()
        return ReplicatedStorage:FindFirstChild(name) ~= nil
    end)
end

-- ============================================================
-- DESTINATION CHECKS
-- ============================================================
local folder = workspace:FindFirstChild("SecureTeleportPoints")
test("Destination folder", function()
    return folder ~= nil and folder:IsA("Folder")
end)

if folder then
    for _, name in ipairs({ "Spawn", "Village", "Forest", "AdminBase" }) do
        test("Destination: " .. name, function()
            local p = folder:FindFirstChild(name)
            return p and p:IsA("BasePart") and p.Anchored
        end)
    end
end

-- ============================================================
-- PLAYER CHECKS
-- ============================================================
local function testPlayer(p)
    test("Auth: " .. p.UserId, function()
        return PermissionService.IsAuthenticated(p)
    end)
    test("Role: " .. p.UserId, function()
        local r = PermissionService.GetRole(p)
        return r == "Player" or r == "Moderator" or r == "Admin"
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    testPlayer(p)
end

Players.PlayerAdded:Connect(function(p)
    task.wait(1)
    testPlayer(p)
end)

-- ============================================================
-- SUMMARY
-- ============================================================
task.wait(2)
print("================================")
print("[SELF TEST] PASSED:", passed, "FAILED:", failed)
print("================================")

SecurityAudit.Record(nil, "SELF_TEST_COMPLETED",
    "Passed: " .. passed .. ", Failed: " .. failed)
