--[[
    OXRP09 - ZERO LAG EDITION
    Mit funktionierenden Slidern für Jump Power und Fly Speed
]]

local player = game:GetService("Players").LocalPlayer
local uis = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")
local workspace = game:GetService("Workspace")

-- ===========================================
-- STANDARD KEYBINDS
-- ===========================================
local Keybinds = {
    Menu = Enum.KeyCode.F4,
    SafeZone = Enum.KeyCode.Q,
    Killswitch = Enum.KeyCode.F6,
    Fly = Enum.KeyCode.F
}

-- Aktive Features
local Features = {
    InstantPickup = false,
    VIPBypass = true,
    AntiRagdoll = true,
    JumpBoost = false,
    Fly = false,
    InfinityJump = false
}

-- Jump Boost Variablen
local jumpPowerValue = 100
local jumpSliderDragging = false

-- Fly Variablen
local flying = false
local flySpeed = 100
local flyConnection = nil
local flyBodyVelocity = nil
local flyBodyGyro = nil
local flySliderDragging = false

-- ===========================================
-- VIP BYPASS (OPTIMIERT)
-- ===========================================
local vipCache = {}
local lastVIPScan = 0
local vipScanInterval = 5

local function bypassAllVIP()
    local now = tick()
    if now - lastVIPScan < vipScanInterval then return end
    lastVIPScan = now
    
    local count = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and not vipCache[obj] then
            local nameLower = string.lower(obj.Name)
            local parentName = obj.Parent and string.lower(obj.Parent.Name) or ""
            
            if string.find(nameLower, "vip") or string.find(parentName, "vip") then
                obj.CanCollide = false
                obj.Transparency = 0.5
                vipCache[obj] = true
                count = count + 1
            end
        end
    end
end

task.spawn(function()
    while Features.VIPBypass do
        pcall(bypassAllVIP)
        task.wait(vipScanInterval)
    end
end)

-- ===========================================
-- SAFE ZONE TELEPORT
-- ===========================================
local SafeZoneFlyConn = nil
local IsSafeZoneFlying = false
local NoclipConn = nil

local TARGET_POS = Vector3.new(110.0, 3.2 + 5, 150.7)
local TARGET_CFRAME = CFrame.lookAt(TARGET_POS, TARGET_POS + Vector3.new(1, 0, 0))

local function enableNoclip()
    if NoclipConn then return end
    local function noCollide()
        local char = player.Character
        if not char then return end
        for _, part in char:GetDescendants() do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
    NoclipConn = runService.Stepped:Connect(noCollide)
end

local function disableNoclip()
    if NoclipConn then
        NoclipConn:Disconnect()
        NoclipConn = nil
    end
    local char = player.Character
    if char then
        for _, part in char:GetDescendants() do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

local function stopSafeZoneFly()
    IsSafeZoneFlying = false
    if SafeZoneFlyConn then
        SafeZoneFlyConn:Disconnect()
        SafeZoneFlyConn = nil
    end
    disableNoclip()
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
        end
    end
end

local function flyToCoords()
    if IsSafeZoneFlying then
        stopSafeZoneFly()
        task.wait(0.1)
    end

    local char = player.Character
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    hum.PlatformStand = true
    local oldWalk = hum.WalkSpeed
    local oldJump = hum.JumpPower
    hum.WalkSpeed = 16
    hum.JumpPower = 50

    enableNoclip()
    IsSafeZoneFlying = true

    local dist = (hrp.Position - TARGET_POS).Magnitude
    if dist < 40 then
        disableNoclip()
        hrp.CFrame = TARGET_CFRAME
        task.wait(0.15)
        stopSafeZoneFly()
        hum.WalkSpeed = oldWalk
        hum.JumpPower = oldJump
        return
    end

    local startPos = hrp.Position
    local rightOutPos = startPos + (hrp.CFrame.RightVector * 150) + Vector3.new(0, 35, 0)
    local rightOutCFrame = CFrame.lookAt(rightOutPos, rightOutPos + hrp.CFrame.RightVector)

    local phase = 1
    local phaseTime = 0

    SafeZoneFlyConn = runService.RenderStepped:Connect(function(dt)
        if not IsSafeZoneFlying or not hrp.Parent then return end

        phaseTime = phaseTime + dt

        if phase == 1 then
            local alpha = math.min(phaseTime / 1.5, 1)
            hrp.CFrame = hrp.CFrame:Lerp(rightOutCFrame, alpha)

            if alpha >= 0.999 then
                phase = 2
                phaseTime = 0
                disableNoclip()
            end
        elseif phase == 2 then
            local alpha2 = math.min(phaseTime / 1.5, 1)
            hrp.CFrame = rightOutCFrame:Lerp(TARGET_CFRAME, alpha2)

            if alpha2 >= 0.999 then
                hrp.CFrame = TARGET_CFRAME
                hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                IsSafeZoneFlying = false
                if SafeZoneFlyConn then
                    SafeZoneFlyConn:Disconnect()
                    SafeZoneFlyConn = nil
                end
                task.wait(0.1)
                stopSafeZoneFly()
                hum.WalkSpeed = oldWalk
                hum.JumpPower = oldJump
                return
            end
        end
    end)
end

-- ===========================================
-- FLY FUNKTION
-- ===========================================
local function startFly()
    if not player.Character then return end
    
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.PlatformStand = true
    end
    
    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    flyBodyVelocity.Parent = root
    
    flyBodyGyro = Instance.new("BodyGyro")
    flyBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    flyBodyGyro.P = 1e4
    flyBodyGyro.Parent = root
    
    flying = true
    
    flyConnection = runService.Heartbeat:Connect(function()
        if not player.Character or not root or not root.Parent then return end
        
        local moveDirection = Vector3.new(0, 0, 0)
        local speed = flySpeed
        
        if uis:IsKeyDown(Enum.KeyCode.W) then
            moveDirection = moveDirection + (root.CFrame.LookVector * speed)
        end
        if uis:IsKeyDown(Enum.KeyCode.S) then
            moveDirection = moveDirection - (root.CFrame.LookVector * speed)
        end
        if uis:IsKeyDown(Enum.KeyCode.A) then
            moveDirection = moveDirection - (root.CFrame.RightVector * speed)
        end
        if uis:IsKeyDown(Enum.KeyCode.D) then
            moveDirection = moveDirection + (root.CFrame.RightVector * speed)
        end
        if uis:IsKeyDown(Enum.KeyCode.Space) then
            moveDirection = moveDirection + Vector3.new(0, speed, 0)
        end
        if uis:IsKeyDown(Enum.KeyCode.LeftControl) then
            moveDirection = moveDirection - Vector3.new(0, speed, 0)
        end
        if uis:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveDirection = moveDirection * 3
        end
        
        flyBodyVelocity.Velocity = moveDirection
        flyBodyGyro.CFrame = root.CFrame
    end)
end

local function stopFly()
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    if flyBodyGyro then
        flyBodyGyro:Destroy()
        flyBodyGyro = nil
    end
    
    if player.Character then
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.PlatformStand = false
        end
    end
    
    flying = false
end

local function toggleFly()
    Features.Fly = not Features.Fly
    if Features.Fly then
        startFly()
    else
        stopFly()
    end
end

-- ===========================================
-- JUMP BOOST
-- ===========================================
runService.Heartbeat:Connect(function()
    if Features.JumpBoost and player.Character then
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.UseJumpPower = true
            humanoid.JumpPower = jumpPowerValue
        end
    end
end)

-- ===========================================
-- INFINITY JUMP
-- ===========================================
uis.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Space and Features.InfinityJump then
        if player.Character then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end)

-- ===========================================
-- KILLSWITCH
-- ===========================================
local killswitchActive = false

local function killswitch()
    if killswitchActive then return end
    killswitchActive = true
    
    local gui = game.CoreGui:FindFirstChild("OXRP09")
    if gui then gui:Destroy() end
    
    if player.Character then
        local hum = player.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
            hum.PlatformStand = false
        end
    end
    
    if flying then stopFly() end
    
    script:Destroy()
end

-- ===========================================
-- ANTI RAGDOLL
-- ===========================================
local StateConn = nil

local function disableRagdollStates(hum)
    if not hum then return end
    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    hum.PlatformStand = false
end

local function onCharacterAdded(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        disableRagdollStates(hum)
        
        if StateConn then StateConn:Disconnect() end
        StateConn = hum.StateChanged:Connect(function(old, new)
            if Features.AntiRagdoll and (new == Enum.HumanoidStateType.Ragdoll or 
                            new == Enum.HumanoidStateType.FallingDown or 
                            new == Enum.HumanoidStateType.Physics) then
                hum:ChangeState(Enum.HumanoidStateType.Running)
                hum.PlatformStand = false
            end
        end)
    end
end

if player.Character then
    onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- ===========================================
-- INSTANT PICKUP
-- ===========================================
local function refreshInstantPickup()
    if not Features.InstantPickup then return end
    for _, obj in pairs(game:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            obj.HoldDuration = 0
        end
    end
end

game.DescendantAdded:Connect(function(obj)
    if Features.InstantPickup and obj:IsA("ProximityPrompt") then
        obj.HoldDuration = 0
    end
end)

-- ===========================================
-- GUI MIT SLIDERN (KORRIGIERT)
-- ===========================================
local screenGui = Instance.new("ScreenGui")
local mainFrame = Instance.new("Frame")
local minimizeBtn = Instance.new("TextButton")
local title = Instance.new("TextLabel")
local tabContainer = Instance.new("Frame")
local contentContainer = Instance.new("ScrollingFrame")
local activeTab = "Movement"
local isMinimized = false

local colors = {
    bg = Color3.fromRGB(10, 10, 15),
    dark = Color3.fromRGB(20, 20, 25),
    medium = Color3.fromRGB(30, 30, 35),
    light = Color3.fromRGB(40, 40, 45),
    tabRed = Color3.fromRGB(255, 80, 80),
    titleBlue = Color3.fromRGB(80, 150, 255),
    tiktok = Color3.fromRGB(255, 0, 100),
    text = Color3.fromRGB(255, 255, 255),
    textDim = Color3.fromRGB(180, 180, 180)
}

screenGui.Name = "OXRP09"
screenGui.Parent = game.CoreGui
screenGui.Enabled = true
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Hauptframe
mainFrame.Parent = screenGui
mainFrame.BackgroundColor3 = colors.bg
mainFrame.BorderSizePixel = 0
mainFrame.Position = UDim2.new(0.5, -350, 0.5, -250)
mainFrame.Size = UDim2.new(0, 700, 0, 500)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.ClipsDescendants = true

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame

-- Minimize Button (außerhalb)
minimizeBtn.Parent = screenGui
minimizeBtn.BackgroundColor3 = colors.bg
minimizeBtn.BorderSizePixel = 0
minimizeBtn.Position = UDim2.new(0, 10, 0, 10)
minimizeBtn.Size = UDim2.new(0, 80, 0, 35)
minimizeBtn.Text = "OXRP09"
minimizeBtn.TextColor3 = colors.titleBlue
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 16
minimizeBtn.Visible = false
minimizeBtn.Draggable = true

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 8)
minCorner.Parent = minimizeBtn

minimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = false
    mainFrame.Visible = true
    minimizeBtn.Visible = false
end)

-- Title
title.Parent = mainFrame
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -100, 0, 50)
title.Position = UDim2.new(0, 20, 0, 5)
title.Text = "OXRP09"
title.TextColor3 = colors.titleBlue
title.Font = Enum.Font.GothamBold
title.TextSize = 28
title.TextXAlignment = Enum.TextXAlignment.Left

-- Minimize Button im Frame
local minFrameBtn = Instance.new("TextButton")
minFrameBtn.Parent = mainFrame
minFrameBtn.BackgroundColor3 = colors.medium
minFrameBtn.BorderSizePixel = 0
minFrameBtn.Size = UDim2.new(0, 30, 0, 30)
minFrameBtn.Position = UDim2.new(1, -40, 0, 15)
minFrameBtn.Text = "−"
minFrameBtn.TextColor3 = colors.tabRed
minFrameBtn.Font = Enum.Font.GothamBold
minFrameBtn.TextSize = 20

local minFrameCorner = Instance.new("UICorner")
minFrameCorner.CornerRadius = UDim.new(0, 6)
minFrameCorner.Parent = minFrameBtn

minFrameBtn.MouseButton1Click:Connect(function()
    isMinimized = true
    mainFrame.Visible = false
    minimizeBtn.Visible = true
end)

-- Tab Container
tabContainer.Parent = mainFrame
tabContainer.BackgroundColor3 = colors.dark
tabContainer.BorderSizePixel = 0
tabContainer.Position = UDim2.new(0, 20, 0, 60)
tabContainer.Size = UDim2.new(0, 150, 0, 400)

local tabCorner = Instance.new("UICorner")
tabCorner.CornerRadius = UDim.new(0, 6)
tabCorner.Parent = tabContainer

-- Content Container (Scrolling)
contentContainer.Parent = mainFrame
contentContainer.BackgroundColor3 = colors.dark
contentContainer.BorderSizePixel = 0
contentContainer.Position = UDim2.new(0, 190, 0, 60)
contentContainer.Size = UDim2.new(0, 490, 0, 400)
contentContainer.CanvasSize = UDim2.new(0, 0, 0, 800)
contentContainer.ScrollBarThickness = 6
contentContainer.ScrollBarImageColor3 = colors.medium
contentContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 6)
contentCorner.Parent = contentContainer

-- Status Text
local statusText = Instance.new("TextLabel")
statusText.Parent = mainFrame
statusText.BackgroundTransparency = 1
statusText.Size = UDim2.new(1, -20, 0, 20)
statusText.Position = UDim2.new(0, 10, 1, -25)
statusText.Text = "F4 = Menu | Q = Safe Zone | F = Fly"
statusText.TextColor3 = colors.textDim
statusText.Font = Enum.Font.Gotham
statusText.TextSize = 12
statusText.TextXAlignment = Enum.TextXAlignment.Left

-- ===========================================
-- SLIDER FUNKTION (KORRIGIERT)
-- ===========================================
local function createSlider(parent, name, value, min, max, yPos, callback)
    local frame = Instance.new("Frame")
    frame.Parent = parent
    frame.BackgroundColor3 = colors.medium
    frame.BorderSizePixel = 0
    frame.Position = UDim2.new(0, 20, 0, yPos)
    frame.Size = UDim2.new(0, 450, 0, 60)
    frame.Name = name .. "Slider"
    
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 6)
    frameCorner.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Parent = frame
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0, 200, 0, 20)
    label.Position = UDim2.new(0, 15, 0, 5)
    label.Text = name .. ": " .. value
    label.TextColor3 = colors.text
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Parent = frame
    valueLabel.BackgroundTransparency = 1
    valueLabel.Size = UDim2.new(0, 50, 0, 20)
    valueLabel.Position = UDim2.new(1, -65, 0, 5)
    valueLabel.Text = value
    valueLabel.TextColor3 = colors.tabRed
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 16
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    
    local sliderBg = Instance.new("Frame")
    sliderBg.Parent = frame
    sliderBg.BackgroundColor3 = colors.light
    sliderBg.Size = UDim2.new(0, 400, 0, 4)
    sliderBg.Position = UDim2.new(0, 15, 0, 35)
    sliderBg.BorderSizePixel = 0
    
    local sliderBgCorner = Instance.new("UICorner")
    sliderBgCorner.CornerRadius = UDim.new(1, 0)
    sliderBgCorner.Parent = sliderBg
    
    local sliderButton = Instance.new("TextButton")
    sliderButton.Parent = sliderBg
    sliderButton.BackgroundColor3 = colors.tabRed
    sliderButton.Size = UDim2.new(0, 16, 0, 16)
    sliderButton.Position = UDim2.new((value - min) / (max - min), -8, 0.5, -8)
    sliderButton.Text = ""
    sliderButton.BorderSizePixel = 0
    sliderButton.AutoButtonColor = false
    
    local sliderBtnCorner = Instance.new("UICorner")
    sliderBtnCorner.CornerRadius = UDim.new(1, 0)
    sliderBtnCorner.Parent = sliderButton
    
    local dragging = false
    local currentValue = value
    
    -- Maus-Events
    sliderButton.MouseButton1Down:Connect(function()
        dragging = true
    end)
    
    uis.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    local connection
    connection = uis.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mousePos = uis:GetMouseLocation()
            local sliderPos = sliderBg.AbsolutePosition.X
            local sliderSize = sliderBg.AbsoluteSize.X
            
            local relativeX = math.clamp(mousePos.X - sliderPos, 0, sliderSize)
            local percent = relativeX / sliderSize
            
            local newValue = math.floor(min + (percent * (max - min)))
            newValue = math.clamp(newValue, min, max)
            
            if newValue ~= currentValue then
                currentValue = newValue
                label.Text = name .. ": " .. newValue
                valueLabel.Text = newValue
                sliderButton.Position = UDim2.new(percent, -8, 0.5, -8)
                
                callback(newValue)
            end
        end
    end)
    
    return frame
end

-- ===========================================
-- TABS
-- ===========================================
local tabs = {"Movement", "Player", "Fly", "Social", "Keybinds"}
local tabY = 10
local contentY = 10

local function clearContentContainer()
    for _, child in pairs(contentContainer:GetChildren()) do
        child:Destroy()
    end
    contentY = 10
end

local function switchTab(tabName)
    activeTab = tabName
    clearContentContainer()
    
    if tabName == "Movement" then
        -- Jump Boost Toggle
        local jumpBtn = Instance.new("TextButton")
        jumpBtn.Parent = contentContainer
        jumpBtn.BackgroundColor3 = Features.JumpBoost and colors.tabRed or colors.medium
        jumpBtn.BorderSizePixel = 0
        jumpBtn.Size = UDim2.new(0, 450, 0, 40)
        jumpBtn.Position = UDim2.new(0, 20, 0, contentY)
        jumpBtn.Text = "Jump Boost: " .. (Features.JumpBoost and "ON" or "OFF")
        jumpBtn.TextColor3 = colors.text
        jumpBtn.Font = Enum.Font.Gotham
        jumpBtn.TextSize = 16
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = jumpBtn
        
        jumpBtn.MouseButton1Click:Connect(function()
            Features.JumpBoost = not Features.JumpBoost
            jumpBtn.Text = "Jump Boost: " .. (Features.JumpBoost and "ON" or "OFF")
            jumpBtn.BackgroundColor3 = Features.JumpBoost and colors.tabRed or colors.medium
        end)
        
        contentY = contentY + 50
        
        -- Jump Power Slider
        createSlider(contentContainer, "Jump Power", jumpPowerValue, 50, 200, contentY, function(value)
            jumpPowerValue = value
        end)
        
        contentY = contentY + 70
        
        -- Safe Zone Button
        local safeBtn = Instance.new("TextButton")
        safeBtn.Parent = contentContainer
        safeBtn.BackgroundColor3 = colors.medium
        safeBtn.BorderSizePixel = 0
        safeBtn.Size = UDim2.new(0, 450, 0, 40)
        safeBtn.Position = UDim2.new(0, 20, 0, contentY)
        safeBtn.Text = "Safe Zone (Q)"
        safeBtn.TextColor3 = colors.text
        safeBtn.Font = Enum.Font.Gotham
        safeBtn.TextSize = 16
        
        local safeCorner = Instance.new("UICorner")
        safeCorner.CornerRadius = UDim.new(0, 6)
        safeCorner.Parent = safeBtn
        
        safeBtn.MouseButton1Click:Connect(function()
            task.spawn(flyToCoords)
        end)
        
        contentY = contentY + 50
        
        -- Infinity Jump Toggle
        local infinityBtn = Instance.new("TextButton")
        infinityBtn.Parent = contentContainer
        infinityBtn.BackgroundColor3 = Features.InfinityJump and colors.tabRed or colors.medium
        infinityBtn.BorderSizePixel = 0
        infinityBtn.Size = UDim2.new(0, 450, 0, 40)
        infinityBtn.Position = UDim2.new(0, 20, 0, contentY)
        infinityBtn.Text = "Infinity Jump: " .. (Features.InfinityJump and "ON" or "OFF")
        infinityBtn.TextColor3 = colors.text
        infinityBtn.Font = Enum.Font.Gotham
        infinityBtn.TextSize = 16
        
        local infCorner = Instance.new("UICorner")
        infCorner.CornerRadius = UDim.new(0, 6)
        infCorner.Parent = infinityBtn
        
        infinityBtn.MouseButton1Click:Connect(function()
            Features.InfinityJump = not Features.InfinityJump
            infinityBtn.Text = "Infinity Jump: " .. (Features.InfinityJump and "ON" or "OFF")
            infinityBtn.BackgroundColor3 = Features.InfinityJump and colors.tabRed or colors.medium
        end)
        
        contentY = contentY + 50
        
    elseif tabName == "Player" then
        -- VIP Bypass Toggle
        local vipBtn = Instance.new("TextButton")
        vipBtn.Parent = contentContainer
        vipBtn.BackgroundColor3 = Features.VIPBypass and colors.tabRed or colors.medium
        vipBtn.BorderSizePixel = 0
        vipBtn.Size = UDim2.new(0, 450, 0, 40)
        vipBtn.Position = UDim2.new(0, 20, 0, contentY)
        vipBtn.Text = "VIP Bypass: " .. (Features.VIPBypass and "ON" or "OFF")
        vipBtn.TextColor3 = colors.text
        vipBtn.Font = Enum.Font.Gotham
        vipBtn.TextSize = 16
        
        local vipCorner = Instance.new("UICorner")
        vipCorner.CornerRadius = UDim.new(0, 6)
        vipCorner.Parent = vipBtn
        
        vipBtn.MouseButton1Click:Connect(function()
            Features.VIPBypass = not Features.VIPBypass
            vipBtn.Text = "VIP Bypass: " .. (Features.VIPBypass and "ON" or "OFF")
            vipBtn.BackgroundColor3 = Features.VIPBypass and colors.tabRed or colors.medium
            if Features.VIPBypass then
                bypassAllVIP()
            end
        end)
        
        contentY = contentY + 50
        
        -- Anti Ragdoll Toggle
        local antiBtn = Instance.new("TextButton")
        antiBtn.Parent = contentContainer
        antiBtn.BackgroundColor3 = Features.AntiRagdoll and colors.tabRed or colors.medium
        antiBtn.BorderSizePixel = 0
        antiBtn.Size = UDim2.new(0, 450, 0, 40)
        antiBtn.Position = UDim2.new(0, 20, 0, contentY)
        antiBtn.Text = "Anti Ragdoll: " .. (Features.AntiRagdoll and "ON" or "OFF")
        antiBtn.TextColor3 = colors.text
        antiBtn.Font = Enum.Font.Gotham
        antiBtn.TextSize = 16
        
        local antiCorner = Instance.new("UICorner")
        antiCorner.CornerRadius = UDim.new(0, 6)
        antiCorner.Parent = antiBtn
        
        antiBtn.MouseButton1Click:Connect(function()
            Features.AntiRagdoll = not Features.AntiRagdoll
            antiBtn.Text = "Anti Ragdoll: " .. (Features.AntiRagdoll and "ON" or "OFF")
            antiBtn.BackgroundColor3 = Features.AntiRagdoll and colors.tabRed or colors.medium
        end)
        
        contentY = contentY + 50
        
        -- Instant Pickup Toggle
        local instantBtn = Instance.new("TextButton")
        instantBtn.Parent = contentContainer
        instantBtn.BackgroundColor3 = Features.InstantPickup and colors.tabRed or colors.medium
        instantBtn.BorderSizePixel = 0
        instantBtn.Size = UDim2.new(0, 450, 0, 40)
        instantBtn.Position = UDim2.new(0, 20, 0, contentY)
        instantBtn.Text = "Instant Pickup: " .. (Features.InstantPickup and "ON" or "OFF")
        instantBtn.TextColor3 = colors.text
        instantBtn.Font = Enum.Font.Gotham
        instantBtn.TextSize = 16
        
        local instCorner = Instance.new("UICorner")
        instCorner.CornerRadius = UDim.new(0, 6)
        instCorner.Parent = instantBtn
        
        instantBtn.MouseButton1Click:Connect(function()
            Features.InstantPickup = not Features.InstantPickup
            instantBtn.Text = "Instant Pickup: " .. (Features.InstantPickup and "ON" or "OFF")
            instantBtn.BackgroundColor3 = Features.InstantPickup and colors.tabRed or colors.medium
            if Features.InstantPickup then
                refreshInstantPickup()
            end
        end)
        
        contentY = contentY + 50
        
    elseif tabName == "Fly" then
        -- Fly Toggle
        local flyBtn = Instance.new("TextButton")
        flyBtn.Parent = contentContainer
        flyBtn.BackgroundColor3 = Features.Fly and colors.tabRed or colors.medium
        flyBtn.BorderSizePixel = 0
        flyBtn.Size = UDim2.new(0, 450, 0, 40)
        flyBtn.Position = UDim2.new(0, 20, 0, contentY)
        flyBtn.Text = "Fly Mode: " .. (Features.Fly and "ON" or "OFF")
        flyBtn.TextColor3 = colors.text
        flyBtn.Font = Enum.Font.Gotham
        flyBtn.TextSize = 16
        
        local flyCorner = Instance.new("UICorner")
        flyCorner.CornerRadius = UDim.new(0, 6)
        flyCorner.Parent = flyBtn
        
        flyBtn.MouseButton1Click:Connect(function()
            toggleFly()
            flyBtn.Text = "Fly Mode: " .. (Features.Fly and "ON" or "OFF")
            flyBtn.BackgroundColor3 = Features.Fly and colors.tabRed or colors.medium
        end)
        
        contentY = contentY + 50
        
        -- Fly Speed Slider
        createSlider(contentContainer, "Fly Speed", flySpeed, 10, 500, contentY, function(value)
            flySpeed = value
        end)
        
        contentY = contentY + 70
        
        -- Info Text
        local infoText = Instance.new("TextLabel")
        infoText.Parent = contentContainer
        infoText.BackgroundTransparency = 1
        infoText.Size = UDim2.new(0, 450, 0, 60)
        infoText.Position = UDim2.new(0, 20, 0, contentY)
        infoText.Text = "W/S = Vor/Zurück\nA/D = Links/Rechts\nSpace/Ctrl = Auf/Ab\nShift = 3x Speed"
        infoText.TextColor3 = colors.textDim
        infoText.Font = Enum.Font.Gotham
        infoText.TextSize = 12
        infoText.TextWrapped = true
        infoText.TextXAlignment = Enum.TextXAlignment.Left
        
        contentY = contentY + 70
        
    elseif tabName == "Social" then
        -- TikTok Text
        local tiktokText = Instance.new("TextLabel")
        tiktokText.Parent = contentContainer
        tiktokText.BackgroundTransparency = 1
        tiktokText.Size = UDim2.new(0, 450, 0, 30)
        tiktokText.Position = UDim2.new(0, 20, 0, contentY)
        tiktokText.Text = "🎵 TikTok: @oxrp09"
        tiktokText.TextColor3 = colors.tiktok
        tiktokText.Font = Enum.Font.GothamBold
        tiktokText.TextSize = 20
        
        contentY = contentY + 40
        
        -- Follow Text
        local followText = Instance.new("TextLabel")
        followText.Parent = contentContainer
        followText.BackgroundTransparency = 1
        followText.Size = UDim2.new(0, 450, 0, 30)
        followText.Position = UDim2.new(0, 20, 0, contentY)
        followText.Text = "❤️ We would appreciate a follow! ❤️"
        followText.TextColor3 = colors.tabRed
        followText.Font = Enum.Font.Gotham
        followText.TextSize = 16
        
        contentY = contentY + 50
        
        -- Link Text
        local linkText = Instance.new("TextLabel")
        linkText.Parent = contentContainer
        linkText.BackgroundColor3 = colors.medium
        linkText.Size = UDim2.new(0, 450, 0, 40)
        linkText.Position = UDim2.new(0, 20, 0, contentY)
        linkText.Text = "https://www.tiktok.com/@oxrp09"
        linkText.TextColor3 = colors.titleBlue
        linkText.Font = Enum.Font.Gotham
        linkText.TextSize = 12
        linkText.TextWrapped = true
        
        local linkCorner = Instance.new("UICorner")
        linkCorner.CornerRadius = UDim.new(0, 6)
        linkCorner.Parent = linkText
        
        contentY = contentY + 50
        
        -- Copy Button
        local copyBtn = Instance.new("TextButton")
        copyBtn.Parent = contentContainer
        copyBtn.BackgroundColor3 = colors.tiktok
        copyBtn.BorderSizePixel = 0
        copyBtn.Size = UDim2.new(0, 450, 0, 50)
        copyBtn.Position = UDim2.new(0, 20, 0, contentY)
        copyBtn.Text = "📋 COPY LINK"
        copyBtn.TextColor3 = colors.text
        copyBtn.Font = Enum.Font.GothamBold
        copyBtn.TextSize = 18
        
        local copyCorner = Instance.new("UICorner")
        copyCorner.CornerRadius = UDim.new(0, 6)
        copyCorner.Parent = copyBtn
        
        copyBtn.MouseButton1Click:Connect(function()
            pcall(function()
                setclipboard("https://www.tiktok.com/@oxrp09")
            end)
            copyBtn.Text = "✓ COPIED!"
            task.wait(1)
            copyBtn.Text = "📋 COPY LINK"
        end)
        
        contentY = contentY + 60
        
    elseif tabName == "Keybinds" then
        local binds = {
            {"Menu Toggle", "F4"},
            {"Safe Zone", "Q"},
            {"Killswitch", "F6"},
            {"Fly Toggle", "F"},
            {"Fly Boost", "Shift"},
            {"Infinity Jump", "Space (hold)"}
        }
        
        for _, bind in ipairs(binds) do
            local bindFrame = Instance.new("Frame")
            bindFrame.Parent = contentContainer
            bindFrame.BackgroundColor3 = colors.medium
            bindFrame.BorderSizePixel = 0
            bindFrame.Position = UDim2.new(0, 20, 0, contentY)
            bindFrame.Size = UDim2.new(0, 450, 0, 35)
            
            local bindCorner = Instance.new("UICorner")
            bindCorner.CornerRadius = UDim.new(0, 6)
            bindCorner.Parent = bindFrame
            
            local bindLabel = Instance.new("TextLabel")
            bindLabel.Parent = bindFrame
            bindLabel.BackgroundTransparency = 1
            bindLabel.Size = UDim2.new(0, 300, 0, 35)
            bindLabel.Position = UDim2.new(0, 15, 0, 0)
            bindLabel.Text = bind[1]
            bindLabel.TextColor3 = colors.text
            bindLabel.Font = Enum.Font.Gotham
            bindLabel.TextSize = 14
            bindLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            local bindKey = Instance.new("TextLabel")
            bindKey.Parent = bindFrame
            bindKey.BackgroundColor3 = colors.light
            bindKey.Size = UDim2.new(0, 100, 0, 25)
            bindKey.Position = UDim2.new(1, -115, 0, 5)
            bindKey.Text = bind[2]
            bindKey.TextColor3 = colors.tabRed
            bindKey.Font = Enum.Font.GothamBold
            bindKey.TextSize = 14
            
            local keyCorner = Instance.new("UICorner")
            keyCorner.CornerRadius = UDim.new(0, 4)
            keyCorner.Parent = bindKey
            
            contentY = contentY + 45
        end
    end
    
    contentContainer.CanvasSize = UDim2.new(0, 0, 0, contentY + 20)
end

-- Tabs erstellen
for i, tabName in ipairs(tabs) do
    local tab = Instance.new("TextButton")
    tab.Parent = tabContainer
    tab.BackgroundColor3 = tabName == activeTab and colors.medium or colors.dark
    tab.BorderSizePixel = 0
    tab.Size = UDim2.new(0, 120, 0, 35)
    tab.Position = UDim2.new(0, 15, 0, tabY)
    tab.Text = tabName
    tab.TextColor3 = tabName == activeTab and colors.tabRed or colors.textDim
    tab.Font = Enum.Font.Gotham
    tab.TextSize = 16
    tab.TextXAlignment = Enum.TextXAlignment.Left
    
    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 4)
    tabCorner.Parent = tab
    
    tab.MouseButton1Click:Connect(function()
        activeTab = tabName
        switchTab(tabName)
        
        for _, child in pairs(tabContainer:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = colors.dark
                child.TextColor3 = colors.textDim
            end
        end
        tab.BackgroundColor3 = colors.medium
        tab.TextColor3 = colors.tabRed
    end)
    
    tabY = tabY + 45
end

-- Initial Tab laden
switchTab("Movement")

-- ===========================================
-- HOTKEY VERARBEITUNG
-- ===========================================
uis.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Keybinds.Menu then
        if isMinimized then
            isMinimized = false
            mainFrame.Visible = true
            minimizeBtn.Visible = false
        else
            screenGui.Enabled = not screenGui.Enabled
        end
    end
    
    if input.KeyCode == Keybinds.SafeZone then
        task.spawn(flyToCoords)
    end
    
    if input.KeyCode == Keybinds.Killswitch then
        killswitch()
    end
    
    if input.KeyCode == Keybinds.Fly then
        toggleFly()
    end
end)