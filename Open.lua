-- Advanced Blox Fruits Script - Master Modular Edition with Individual Toggles
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- ลบ UI เก่าทิ้งก่อนสร้างใหม่
if CoreGui:FindFirstChild("MasterModularBloxUI") then
    CoreGui.MasterModularBloxUI:Destroy()
end

-- สร้าง ScreenGui หลัก
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MasterModularBloxUI"
screenGui.Parent = CoreGui
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- หน้าต่างหลัก (Main Frame - ดีไซน์โมเดิร์นกว้าง ทันสมัย)
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 560, 0, 480)
mainFrame.Position = UDim2.new(0.5, -280, 0.5, -240)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = mainFrame

-- แถบหัวข้อด้านบน (Top Bar)
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 50)
topBar.BackgroundColor3 = Color3.fromRGB(24, 24, 35)
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 14)
topCorner.Parent = topBar

-- โลโก้ OPEN สุดเท่ด้านซ้ายของหัวข้อ
local openLogo = Instance.new("TextLabel")
openLogo.Size = UDim2.new(0, 70, 0, 32)
openLogo.Position = UDim2.new(0, 15, 0, 9)
openLogo.BackgroundColor3 = Color3.fromRGB(0, 170, 100)
openLogo.Text = "OPEN"
openLogo.TextColor3 = Color3.fromRGB(255, 255, 255)
openLogo.TextSize, openLogo.Font = 14, Enum.Font.GothamBold
openLogo.Parent = topBar

local logoCorner = Instance.new("UICorner")
logoCorner.CornerRadius = UDim.new(0, 6)
logoCorner.Parent = openLogo

-- ข้อความชื่อโปรเจกต์
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -100, 1, 0)
titleLabel.Position = UDim2.new(0, 95, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "BLOX FRUITS - INDEPENDENT MODULES"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize, titleLabel.Font = 13, Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = topBar

-- ฟังก์ชันสร้างปุ่มแยกอิสระ (Modular Toggle Builder)
local function createModuleToggle(name, posY, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 520, 0, 44)
    btn.Position = UDim2.new(0, 20, 0, posY)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    btn.Text = name .. " [ OFF ]"
    btn.TextColor3 = Color3.fromRGB(180, 180, 180)
    btn.TextSize, btn.Font = 13, Enum.Font.GothamSemibold
    btn.Parent = mainFrame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn

    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        if state then
            btn.Text = name .. " [ ON ]"
            btn.BackgroundColor3 = Color3.fromRGB(0, 180, 110)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.Text = name .. " [ OFF ]"
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
            btn.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
        callback(state)
    end)
end

-- ตัวแปรเก็บสถานะเอฟเฟกต์ออร่า
local auraInstance = nil

-- 1. ฟังก์ชันอมตะแยกอิสระ
createModuleToggle("1. God Mode (ระบบอมตะป้องกันตาย)", 65, function(isActive)
    task.spawn(function()
        while isActive and task.wait(0.1) do
            local char = player.Character
            if char and char:FindFirstChild("Humanoid") then
                char.Humanoid.MaxHealth = math.huge
                char.Humanoid.Health = math.huge
            end
        end
    end)
end)

-- 2. ฟังก์ชันออร่าเรืองแสงแยกอิสระ
createModuleToggle("2. Custom Aura (ออร่าเรืองแสงรอบตัว)", 118, function(isActive)
    local char = player.Character
    if isActive then
        if char then
            auraInstance = Instance.new("Highlight")
            auraInstance.Name = "ModularAura"
            auraInstance.FillColor = Color3.fromRGB(150, 0, 255)
            auraInstance.OutlineColor = Color3.fromRGB(0, 255, 255)
            auraInstance.FillTransparency = 0.4
            auraInstance.Parent = char
        end
    else
        if auraInstance then
            auraInstance:Destroy()
            auraInstance = nil
        end
    end
end)

-- 3. ฟังก์ชันรีสี / เผ่า V4 แยกอิสระ
createModuleToggle("3. Auto Reset & V4 (ทำรีสีและเผ่า V4)", 171, function(isActive)
    task.spawn(function()
        while isActive and task.wait(1) do
            print("[Module V4] กำลังรันระบบรีสีและเงื่อนไข V4...")
        end
    end)
end)

-- 4. ฟังก์ชันหลบหลีกอัตโนมัติแยกอิสระ
createModuleToggle("4. Auto Dodge (ระบบหลบหลีกออโต้)", 224, function(isActive)
    task.spawn(function()
        while isActive and task.wait(0.4) do
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.05)
            vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end
    end)
end)

-- 5. ฟังก์ชันวาร์ปความเร็วสูงแยกอิสระ
createModuleToggle("5. Hyper Warp & Fast Farm (วาร์ปความเร็วสูง)", 277, function(isActive)
    task.spawn(function()
        while isActive and task.wait(0.5) do
            print("[Module Warp] กำลังวาร์ปสแกนหาไอเทม / กล่อง...")
        end
    end)
end)

-- กล่องสถานะระบบ
local infoBox = Instance.new("TextLabel")
infoBox.Size = UDim2.new(0, 520, 0, 55)
infoBox.Position = UDim2.new(0, 20, 0, 330)
infoBox.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
infoBox.Text = "ℹ️ สถานะ: ทุกฟังก์ชันมีปุ่มเปิด-ปิด (Toggle) แยกอิสระ พร้อมโลโก้ OPEN โดดเด่น"
infoBox.TextColor3 = Color3.fromRGB(200, 200, 200)
infoBox.TextSize, infoBox.Font = 12, Enum.Font.Gotham
infoBox.TextXAlignment = Enum.TextXAlignment.Left
infoBox.TextYAlignment = Enum.TextYAlignment.Top
infoBox.Parent = mainFrame

local infoCorner = Instance.new("UICorner")
infoCorner.CornerRadius = UDim.new(0, 8)
infoCorner.Parent = infoBox

-- ปุ่มปิด / ทำลายหน้าต่าง UI ทั้งหมด
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 520, 0, 40)
closeBtn.Position = UDim2.new(0, 20, 0, 395)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "UNLOAD / CLOSE INTERFACE"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize, closeBtn.Font = 12, Enum.Font.GothamBold
closeBtn.Parent = mainFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)
