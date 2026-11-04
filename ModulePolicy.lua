-- ============================================================
-- MODULE POLICY
-- SERVER ONLY | ModuleScript
-- ตรวจสิทธิ์ Module + Force Timeout
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SecurityAudit     = require(script.Parent:WaitForChild("SecurityAudit"))
local PermissionService = require(script.Parent:WaitForChild("PermissionService"))

local ModulePolicy = {}

-- Module → Permission ที่ต้องมี
local MODULE_PERMISSIONS = {
    ["GodMode"]      = "module.god",
    ["HyperWarp"]    = "teleport.hyper",
    ["AutoDodge"]    = "module.autododge",
    ["AutoResetV4"]  = "module.autoreset",
    ["CustomAura"]   = "module.aura",
}

-- Module → ระยะเวลาสูงสุด (วิ)
local MODULE_MAX_DURATION = {
    ["GodMode"]   = 30,
    ["HyperWarp"] = 60,
}

local activeModules = {}

-- ============================================================
-- HELPERS
-- ============================================================
local function getForceOffRemote()
    local r = ReplicatedStorage:FindFirstChild("ModuleForceOff")
    if not r then
        r = Instance.new("RemoteEvent")
        r.Name   = "ModuleForceOff"
        r.Parent = ReplicatedStorage
    end
    return r
end

-- ============================================================
-- PUBLIC: ACTIVATE / DEACTIVATE
-- ============================================================
function ModulePolicy.Activate(player, moduleName)
    if typeof(moduleName) ~= "string" then
        return false, "INVALID_MODULE"
    end
    if not MODULE_PERMISSIONS[moduleName] then
        SecurityAudit.Record(player, "UNKNOWN_MODULE", moduleName)
        return false, "UNKNOWN_MODULE"
    end

    local requiredPerm = MODULE_PERMISSIONS[moduleName]
    if not PermissionService.HasPermission(player, requiredPerm) then
        SecurityAudit.Record(player, "MODULE_DENIED",
            moduleName .. " requires " .. requiredPerm)
        return false, "PERMISSION_DENIED"
    end

    activeModules[player] = activeModules[player] or {}
    activeModules[player][moduleName] = os.clock()

    SecurityAudit.Record(player, "MODULE_ACTIVATE", moduleName)
    return true, "OK"
end

function ModulePolicy.Deactivate(player, moduleName)
    if activeModules[player] and activeModules[player][moduleName] then
        activeModules[player][moduleName] = nil
        SecurityAudit.Record(player, "MODULE_DEACTIVATE", moduleName)
    end
end

function ModulePolicy.IsActive(player, moduleName)
    return activeModules[player]
        and activeModules[player][moduleName] ~= nil
end

-- ============================================================
-- TIMEOUT CHECKER
-- ============================================================
function ModulePolicy.CheckTimeouts()
    local now = os.clock()
    for player, modules in pairs(activeModules) do
        for name, start in pairs(modules) do
            local maxDur = MODULE_MAX_DURATION[name]
            if maxDur and (now - start) > maxDur then
                modules[name] = nil
                SecurityAudit.Record(player, "MODULE_TIMEOUT", name)

                local remote = getForceOffRemote()
                pcall(function()
                    remote:FireClient(player, name)
                end)
            end
        end
    end
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
task.spawn(function()
    while true do
        task.wait(5)
        local ok, err = pcall(ModulePolicy.CheckTimeouts)
        if not ok then
            SecurityAudit.Record(nil, "SECURITY_ERROR",
                "ModulePolicy loop: " .. tostring(err))
        end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    activeModules[p] = nil
end)

print("[POLICY] Module policy loaded")
return ModulePolicy
