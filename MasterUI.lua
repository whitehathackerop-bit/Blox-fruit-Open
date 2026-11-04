-- ============================================================
-- MASTER UI — CLIENT
-- LocalScript | UI 6 Modules + Secure Teleport Client
-- ============================================================

local Players             = game:GetService("Players")
local CoreGui             = game:GetService("CoreGui")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

if CoreGui:FindFirstChild("MasterModularBloxUI") then
    CoreGui.MasterModularBloxUI:Destroy()
end

-- ============================================================
-- UI BUILD
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MasterModularBloxUI"
screenGui.Parent = CoreGui
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local mainFrame = Instance.new("Frame")
mainFrame.Size             = UDim2.new(0, 560, 0, 540)
mainFrame.Position         = UDim2.new(0.5, -280, 0.5, -270)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
mainFrame.BorderSizePixel  = 0
mainFrame.Active           = true
mainFrame.Draggable        = true
mainFrame.Parent           = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 14)

local topBar = Instance.new("Frame")
topBar.Size             = UDim2.new(1, 0, 0, 50)
topBar.BackgroundColor3 = Color3.fromRGB(24, 24, 35)
topBar.BorderSizePixel  = 0
topBar.Parent           = mainFrame
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 14)

local openLogo = Instance.new("TextLabel")
openLogo.Size             = UDim2.new(0, 70, 0, 32)
openLogo.Position         = UDim2.new(0, 15, 0, 9)
openLogo.BackgroundColor3 = Color3.fromRGB(0, 170, 100)
openLogo.Text             = "OPEN"
openLogo.TextColor3       = Color3.fromRGB(255, 255, 255)
openLogo.TextSize         = 14
openLogo.Font             = Enum.Font.GothamBold
openLogo.Parent           = topBar
Instance.new("UICorner", openLogo).CornerRadius = UDim.new(0, 6)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size                 = UDim2.new(1, -100, 1, 0)
titleLabel.Position             = UDim2.new(0, 95, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text                 = "BLOX FRUITS - SECURED MODULES"
titleLabel.TextColor3           = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize             = 13
titleLabel.Font                 = Enum.Font.GothamBold
titleLabel.TextXAlignment       = Enum.TextXAlignment.Left
titleLabel.Parent               = topBar

-- ============================================================
-- STATE
-- ============================================================
local connections       = {}
local godModeActive     = false
local auraActive        = false
local autoResetV4Active = false
local autoDodgeActive   = false
local fastFarmActive    = false
local auraInstance      = nil
local teleportBusy      = false
local currentToken      = nil
local lastClientTeleport = 0
local CLIENT_COOLDOWN   = 3

-- ============================================================
-- REMOTES
-- ============================================================
local teleportRemote    = ReplicatedStorage:WaitForChild("SecureTeleportRequest", 15)
local tokenRemote       = ReplicatedStorage:WaitForChild("SecurityTokenUpdate", 15)
local policyRemote      = ReplicatedStorage:WaitForChild("ModulePolicyRequest", 15)
local forceOffRemote    = ReplicatedStorage:WaitForChild("ModuleForceOff", 15)

if tokenRemote then
    tokenRemote.OnClientEvent:Connect(function(token, lifetime)
        currentToken = token
        print("[CLIENT] Token received, lifetime:", lifetime)
    end)
end

if forceOffRemote then
    forceOffRemote.OnClientEvent:Connect(function(moduleName)
        warn("[CLIENT] Server forced off:", moduleName)
    end)
end

local function notifyModule(moduleName, isActive)
    if not policyRemote then return end
    pcall(function()
        policyRemote:InvokeServer(moduleName, isActive)
    end)
end

-- ============================================================
-- TOGGLE HELPER
-- ============================================================
local function createModuleToggle(name, posY, callback)
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0, 520, 0, 44)
    btn.Position         = UDim2.new(0, 20, 0, posY)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    btn.Text             = name .. " [ OFF ]"
    btn.TextColor3       = Color3.fromRGB(180, 180, 180)
    btn.TextSize         = 13
    btn.Font             = Enum.Font.GothamSemibold
    btn.Parent           = mainFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text             = name .. (state and " [ ON ]" or " [ OFF ]")
        btn.BackgroundColor3 = state and Color3.fromRGB(0, 180, 110) or Color3.fromRGB(30, 30, 42)
        btn.TextColor3       = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
        callback(state)
    end)
end

-- ============================================================
-- 1. God Mode
-- ============================================================
createModuleToggle("1. God Mode", 65, function(on)
    notifyModule("GodMode", on)
    godModeActive = on
    for _, c in ipairs(connections) do
        if c.godMode then c.godMode:Disconnect() end
    end
    if not on then return end
    local function apply(char)
        local h = char:WaitForChild("Humanoid", 5)
        if not h then return end
        h.MaxHealth = math.huge
        h.Health    = math.huge
        h:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        table.insert(connections, {
            godMode = h.HealthChanged:Connect(function(n)
                if godModeActive and n < h.MaxHealth then
                    h.Health = h.MaxHealth
                end
            end)
        })
    end
    if player.Character then apply(player.Character) end
    table.insert(connections, { godMode = player.CharacterAdded:Connect(apply) })
end)

-- ============================================================
-- 2. Aura
-- ============================================================
local function applyAura(char)
    if not char or not char:FindFirstChild("Humanoid") then return end
    if auraInstance and auraInstance.Parent == char then return end
    if auraInstance then auraInstance:Destroy() end
    auraInstance = Instance.new("Highlight")
    auraInstance.Name              = "ModularAura"
    auraInstance.FillColor         = Color3.fromRGB(150, 0, 255)
    auraInstance.OutlineColor      = Color3.fromRGB(0, 255, 255)
    auraInstance.FillTransparency  = 0.4
    auraInstance.Parent            = char
end

createModuleToggle("2. Custom Aura", 118, function(on)
    notifyModule("CustomAura", on)
    auraActive = on
    if on then
        if player.Character then applyAura(player.Character) end
        player.CharacterAdded:Connect(function(c)
            if auraActive then task.wait(1); applyAura(c) end
        end)
    else
        if auraInstance then auraInstance:Destroy(); auraInstance = nil end
    end
end)

-- ============================================================
-- 3. Auto Reset & V4
-- ============================================================
createModuleToggle("3. Auto Reset & V4", 171, function(on)
    notifyModule("AutoResetV4", on)
    autoResetV4Active = on
    task.spawn(function()
        while autoResetV4Active do
            local char = player.Character
            if char and char:FindFirstChild("Humanoid") then
                local h = char.Humanoid
                local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                if remotes then
                    local commF = remotes:FindFirstChild("CommF_")
                    if commF then
                        pcall(function() commF:InvokeServer("ResetCharacter") end)
                        pcall(function() commF:InvokeServer("RaceV4") end)
                    end
                end
                if h.Health <= 0 or h.Health / h.MaxHealth < 0.1 then
                    pcall(function() player.Character:BreakJoints() end)
                end
            end
            task.wait(2)
        end
    end)
end)

-- ============================================================
-- 4. Auto Dodge
-- ============================================================
createModuleToggle("4. Auto Dodge", 224, function(on)
    notifyModule("AutoDodge", on)
    autoDodgeActive = on
    task.spawn(function()
        while autoDodgeActive do
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart")
                and char:FindFirstChild("Humanoid") then
                local h  = char.Humanoid
                local rp = char.HumanoidRootPart
                if h.Health > 0 then
                    local near, dist = nil, 50
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= player and p.Character then
                            local oc = p.Character
                            if oc:FindFirstChild("HumanoidRootPart")
                                and oc:FindFirstChild("Humanoid")
                                and oc.Humanoid.Health > 0 then
                                local d = (rp.Position - oc.HumanoidRootPart.Position).Magnitude
                                if d < dist then
                                    dist = d
                                    near = p
                                end
                            end
                        end
                    end
                    if near then
                        VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
                        task.wait(0.05)
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                        task.wait(0.25)
                    end
                end
            end
            task.wait(0.1)
        end
    end)
end)

-- ============================================================
-- 5. Hyper Warp
-- ============================================================
createModuleToggle("5. Hyper Warp", 277, function(on)
    notifyModule("HyperWarp", on)
    fastFarmActive = on
    task.spawn(function()
        while fastFarmActive do
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local rp = char.HumanoidRootPart
                local best, dist = nil, 500
                for _, obj in ipairs(workspace:GetDescendants()) do
                    local isT = false
                    local n = obj.Name:lower()
                    if obj:IsA("MeshPart") or obj:IsA("Part") then
                        if n:find("chest") or n:find("fruit") then
                            isT = true
                        end
                    end
                    if obj:IsA("Model")
                        and obj:FindFirstChild("Humanoid")
                        and obj:FindFirstChild("HumanoidRootPart") then
                        if obj.Humanoid.Health > 0 and obj ~= char then
                            isT = true
                        end
                    end
                    if isT and (obj:FindFirstChild("HumanoidRootPart") or obj:IsA("BasePart")) then
                        local pos = (obj:IsA("Model") and obj.HumanoidRootPart.Position) or obj.Position
                        local d   = (rp.Position - pos).Magnitude
                        if d < dist then
                            dist = d
                            best = obj
                        end
                    end
                end
                if best then
                    local cf
                    if best:IsA("Model") and best:FindFirstChild("HumanoidRootPart") then
                        cf = best.HumanoidRootPart.CFrame
                    elseif best:IsA("BasePart") then
                        cf = best.CFrame
                    end
                    if cf then rp.CFrame = cf * CFrame.new(0, 3, 0) end
                end
            end
            task.wait(0.5)
        end
    end)
end)

-- ============================================================
-- 6. Secure Teleport
-- ============================================================
local function isClientCooldownActive()
    return (os.clock() - lastClientTeleport) < CLIENT_COOLDOWN
end

local function RequestTeleport(name)
    if isClientCooldownActive() then
        return false, "รอ " .. math.ceil(CLIENT_COOLDOWN - (os.clock() - lastClientTeleport)) .. " วิ"
    end
    if teleportBusy then return false, "Busy" end
    if typeof(name) ~= "string" or #name < 1 or #name > 40 then return false, "Invalid" end
    if not player.Character then return false, "No character" end
    if not teleportRemote then return false, "Server not ready" end
    if not currentToken then return false, "No token yet" end

    teleportBusy = true
    lastClientTeleport = os.clock()
    local ok, approved, msg = pcall(function()
        return teleportRemote:InvokeServer(name, currentToken)
    end)
    teleportBusy = false
    if not ok then return false, "Communication error" end
    return approved == true, msg
end

local tpBtn = Instance.new("TextButton")
tpBtn.Size             = UDim2.new(0, 520, 0, 44)
tpBtn.Position         = UDim2.new(0, 20, 0, 330)
tpBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
tpBtn.Text             = "6. Secure Teleport → Spawn [ CLICK ]"
tpBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
tpBtn.TextSize         = 13
tpBtn.Font             = Enum.Font.GothamSemibold
tpBtn.Parent           = mainFrame
Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 8)

tpBtn.MouseButton1Click:Connect(function()
    local ok, msg = RequestTeleport("Spawn")
    tpBtn.Text = ok and "✅ Teleport สำเร็จ!" or ("❌ " .. tostring(msg))
    task.delay(2, function()
        tpBtn.Text = "6. Secure Teleport → Spawn [ CLICK ]"
    end)
end)

-- ============================================================
-- INFO + CLOSE
-- ============================================================
local info = Instance.new("TextLabel")
info.Size             = UDim2.new(0, 520, 0, 55)
info.Position         = UDim2.new(0, 20, 0, 383)
info.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
info.Text             = "ℹ️ ระบบความปลอดภัยครบ 15/15 — Auth + Token + Audit + Anti-Cheat"
info.TextColor3       = Color3.fromRGB(200, 200, 200)
info.TextSize         = 12
info.Font             = Enum.Font.Gotham
info.TextXAlignment   = Enum.TextXAlignment.Left
info.TextYAlignment   = Enum.TextYAlignment.Top
info.Parent           = mainFrame
Instance.new("UICorner", info).CornerRadius = UDim.new(0, 8)

local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0, 520, 0, 40)
closeBtn.Position         = UDim2.new(0, 20, 0, 448)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text             = "UNLOAD / CLOSE"
closeBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize         = 12
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.Parent           = mainFrame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

closeBtn.MouseButton1Click:Connect(function()
    godModeActive, auraActive     = false, false
    autoResetV4Active, autoDodgeActive, fastFarmActive = false, false, false
    if auraInstance then auraInstance:Destroy(); auraInstance = nil end
    for _, c in ipairs(connections) do
        for _, x in pairs(c) do
            if typeof(x) == "RBXScriptConnection" and x.Connected then
                x:Disconnect()
            end
        end
    end
    connections = {}
    screenGui:Destroy()
end)

-- ============================================================
-- HEARTBEAT
-- ============================================================
task.spawn(function()
    while true do
        task.wait(30)
        if teleportRemote then
            pcall(function()
                teleportRemote:InvokeServer("__heartbeat__", currentToken)
            end)
        end
    end
end)

print("[CLIENT] Master UI loaded")
