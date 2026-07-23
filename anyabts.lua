-- MM2 Aim Lock v2.0 - FULLY FIXED
local shared = odh_shared_plugins
local my_section = shared.AddSection("MM2 Aim Lock")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LP = Players.LocalPlayer

-- ==================== FIXED MAID ====================
local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({_tasks = {}, _destroyed = false}, Maid)
end

function Maid:GiveTask(task)
    if self._destroyed then
        if typeof(task) == "RBXScriptConnection" then task:Disconnect()
        elseif typeof(task) == "Instance" then task:Destroy()
        elseif type(task) == "function" then task()
        elseif type(task) == "table" and type(task.Destroy) == "function" then task:Destroy() end
        return
    end
    table.insert(self._tasks, task)
    return task
end

function Maid:DoCleaning()
    if self._destroyed then return end
    self._destroyed = true
    for _, task in pairs(self._tasks) do
        if typeof(task) == "RBXScriptConnection" then task:Disconnect()
        elseif typeof(task) == "Instance" then task:Destroy()
        elseif type(task) == "function" then task()
        elseif type(task) == "table" and type(task.Destroy) == "function" then task:Destroy() end
    end
    self._tasks = {}
end

function Maid:Destroy()
    self:DoCleaning()
end

-- ==================== BINDABLE BUTTONS (OPTIMIZED) ====================
local BindableButtons = {
    Buttons = {},
    Maids = {},
    Count = 0,
    SHAPES = {
        [0] = "rbxassetid://86221076925479",
        [1] = "rbxassetid://96242665417546",
        [2] = "rbxassetid://97129189935336",
        [3] = "rbxassetid://76165862027868",
        [4] = "rbxassetid://125868092127496"
    }
}

function BindableButtons.Add(id, text, onFunc, offFunc, size)
    if BindableButtons.Buttons[id] then return end
    
    local maid = Maid.new()
    local camera = workspace.CurrentCamera
    local screen = camera.ViewportSize
    local sizeY = size or 0.11
    local widthScale = sizeY * (screen.Y / screen.X)
    
    local xPos = 0.1 + ((BindableButtons.Count % 8) * (widthScale + 0.005))
    local yPos = 0.9 - (math.floor(BindableButtons.Count / 8) * (sizeY + 0.015))
    
    local storage = LP:FindFirstChild("PlayerGui")
    if not storage then return end
    
    local sg = storage:FindFirstChild("@bindstorage") or Instance.new("ScreenGui")
    if not sg.Parent then
        sg.Name = "@bindstorage"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        pcall(function() sg.ScreenInsets = Enum.ScreenInsets.None end)
        sg.Parent = storage
    end
    
    local btn = Instance.new("ImageButton")
    btn.Name = id
    btn.Size = UDim2.new(widthScale, 0, sizeY, 0)
    btn.Position = UDim2.new(xPos, 0, yPos, 0)
    btn.AnchorPoint = Vector2.new(0.5, 0.5)
    btn.Image = BindableButtons.SHAPES[0]
    btn.BackgroundTransparency = 1
    btn.BorderSizePixel = 0
    btn.ClipsDescendants = false
    btn.AutoButtonColor = false
    btn.Parent = sg
    maid:GiveTask(btn)
    
    local bindVal = Instance.new("BoolValue", btn)
    bindVal.Name = "BindValue"
    
    local textLabel = Instance.new("TextLabel", btn)
    textLabel.Name = "@Text"
    textLabel.Size = UDim2.new(0.8, 0, 0.8, 0)
    textLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
    textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.Jura
    textLabel.Text = text
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.TextSize = 10
    textLabel.TextWrapped = true
    textLabel.ZIndex = 3
    
    local aspect = Instance.new("UIAspectRatioConstraint", btn)
    aspect.AspectRatio = 1
    aspect.AspectType = Enum.AspectType.ScaleWithParentSize
    
    local stroke = Instance.new("UIGradient", btn)
    stroke.Name = "@Stroke"
    stroke.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(0.133, 0.827, 0.494)),
        ColorSequenceKeypoint.new(0.6, Color3.new(0.231, 0.51, 0.498)),
        ColorSequenceKeypoint.new(1, Color3.new(0.502, 0.502, 0.502))
    })
    
    local ripple = Instance.new("Frame", btn)
    ripple.Name = "@ripple"
    ripple.BackgroundColor3 = Color3.new(0, 0.608, 1)
    ripple.BackgroundTransparency = 0.5
    ripple.Size = UDim2.new(0, 0, 0, 0)
    ripple.AnchorPoint = Vector2.new(0.5, 0.5)
    ripple.Visible = false
    ripple.ZIndex = 2
    Instance.new("UICorner", ripple).CornerRadius = UDim.new(1, 0)
    
    local sound = Instance.new("Sound", btn)
    sound.SoundId = "rbxassetid://3868133279"
    sound.Volume = 0.5
    
    local debounce = false
    local tInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
    local ts = game:GetService("TweenService")
    local uis = game:GetService("UserInputService")
    
    local function onClick()
        if debounce then return end
        debounce = true
        local fOut = ts:Create(btn, tInfo, {ImageTransparency = 1})
        fOut:Play()
        fOut.Completed:Wait()
        
        bindVal.Value = not bindVal.Value
        stroke.Color = bindVal.Value and ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(0.078, 0.078, 0.078)),
            ColorSequenceKeypoint.new(0.75, Color3.new(0.078, 0.078, 0.549)),
            ColorSequenceKeypoint.new(1, Color3.new(0.471, 0.157, 0.471))
        }) or ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(0.133, 0.827, 0.494)),
            ColorSequenceKeypoint.new(0.6, Color3.new(0.231, 0.51, 0.498)),
            ColorSequenceKeypoint.new(1, Color3.new(0.502, 0.502, 0.502))
        })
        
        if bindVal.Value then onFunc() else offFunc() end
        
        local fIn = ts:Create(btn, tInfo, {ImageTransparency = 0})
        fIn:Play()
        fIn.Completed:Wait()
        debounce = false
    end
    
    -- Drag logic
    local dragging, dragInput, dragStart, startPos, hasMoved
    maid:GiveTask(btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = btn.Position
            hasMoved = false
            sound:Play()
            
            local absPos = btn.AbsolutePosition
            ripple.Position = UDim2.new(0, input.Position.X - absPos.X, 0, input.Position.Y - absPos.Y)
            ripple.Size = UDim2.new(0, 0, 0, 0)
            ripple.BackgroundTransparency = 0.5
            ripple.Visible = true
            
            ts:Create(ripple, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 45, 0, 45),
                BackgroundTransparency = 1
            }):Play()
            
            local releaseConn
            releaseConn = uis.InputEnded:Connect(function(endInput)
                if endInput.UserInputType == input.UserInputType then
                    dragging = false
                    if not hasMoved then onClick() end
                    releaseConn:Disconnect()
                end
            end)
            maid:GiveTask(releaseConn)
        end
    end))
    
    maid:GiveTask(uis.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 7 then hasMoved = true end
            local screenSize = btn.Parent.AbsoluteSize
            btn.Position = UDim2.new(
                startPos.X.Scale + (delta.X / screenSize.X), 0,
                startPos.Y.Scale + (delta.Y / screenSize.Y), 0
            )
        end
    end))
    
    maid:GiveTask(RunService.RenderStepped:Connect(function()
        stroke.Rotation = (stroke.Rotation + 1) % 360
    end))
    
    BindableButtons.Buttons[id] = btn
    BindableButtons.Maids[id] = maid
    BindableButtons.Count = BindableButtons.Count + 1
    
    return bindVal, btn
end

function BindableButtons.SetSize(id, sizeY)
    local btn = BindableButtons.Buttons[id]
    if not btn then return end
    local screen = workspace.CurrentCamera.ViewportSize
    btn.Size = UDim2.new(sizeY * (screen.Y / screen.X), 0, sizeY, 0)
end

function BindableButtons.Delete(id)
    if BindableButtons.Maids[id] then
        BindableButtons.Maids[id]:Destroy()
        BindableButtons.Maids[id] = nil
        BindableButtons.Buttons[id] = nil
    end
end

-- ==================== CORE SETTINGS ====================
local settings = {
    enabled = false,
    targetPlayer = nil,
    targetRole = "Murderer",
    targetPart = "Head",
    wallCheck = false,
    teamCheck = false,
    prediction = 0,
    smoothing = 0,
    buttonSize = 0.11,
    showButton = false,
    burger = false,
    toggleKey = "T"
}

local bindVal, btnObj
local lastTargetPos, lastUpdateTime
local burgerSound, burgerInitialized

-- ==================== HELPER FUNCTIONS ====================
local function IsInRound()
    local char = LP.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local y = root.Position.Y
    return y >= 180 and y <= 380
end

local function IsVisible(targetChar)
    if not targetChar then return false end
    local part = targetChar:FindFirstChild(settings.targetPart)
    if not part then return false end
    
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LP.Character}
    
    local origin = Camera.CFrame.Position
    local dir = (part.Position - origin)
    local ray = workspace:Raycast(origin, dir.Unit * dir.Magnitude, params)
    
    if ray then
        return ray.Instance:IsDescendantOf(targetChar)
    end
    return true
end

local function HasTool(player, keywords)
    if not player.Character then return false end
    
    local function check(container)
        if not container then return false end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local name = item.Name:lower()
                for _, kw in ipairs(keywords) do
                    if name:find(kw) then return true end
                end
            end
        end
        return false
    end
    
    return check(player.Character) or check(player.Backpack)
end

local function IsMurderer(player)
    return HasTool(player, {"knife", "нож"})
end

local function IsSheriff(player)
    return HasTool(player, {"gun", "пистолет", "револьвер", "revolver", "sheriff", "шериф"})
end

local function IsSameTeam(p1, p2)
    if not p1 or not p2 then return false end
    return IsMurderer(p1) == IsMurderer(p2)
end

local function GetPredictedPosition(target)
    if not target or not target.Character then return nil end
    local part = target.Character:FindFirstChild(settings.targetPart)
    if not part then return nil end
    
    local currentPos = part.Position
    local now = tick()
    local velocity = Vector3.zero
    
    if lastTargetPos and lastUpdateTime > 0 then
        local dt = now - lastUpdateTime
        if dt > 0 then
            velocity = (currentPos - lastTargetPos) / dt
        end
    end
    
    lastTargetPos = currentPos
    lastUpdateTime = now
    
    return currentPos + (velocity * settings.prediction)
end

-- ==================== TARGET ACQUISITION ====================
local function FindTarget()
    local targetName = settings.targetPlayer
    
    if targetName then
        local target = Players:FindFirstChild(targetName)
        if target and target.Character then
            local hum = target.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                if settings.teamCheck and IsSameTeam(LP, target) then return nil end
                if settings.wallCheck and not IsVisible(target.Character) then return nil end
                return target
            end
        end
        return nil
    end
    
    local bestTarget, bestDist = nil, math.huge
    local checkFunc = settings.targetRole == "Murderer" and {"knife", "нож"} or {"gun", "пистолет", "револьвер", "revolver", "sheriff", "шериф"}
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP and player.Character then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                if settings.teamCheck and IsSameTeam(LP, player) then continue end
                if not HasTool(player, checkFunc) then continue end
                if settings.wallCheck and not IsVisible(player.Character) then continue end
                
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local dist = (Camera.CFrame.Position - root.Position).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        bestTarget = player
                    end
                end
            end
        end
    end
    
    return bestTarget
end

-- ==================== BURGER ====================
local function ShakeCamera(intensity, duration)
    local startTime = tick()
    task.spawn(function()
        while tick() - startTime < duration and settings.burger do
            local decay = 1 - ((tick() - startTime) / duration)
            local offset = Vector3.new(
                math.random(-100, 100) * intensity * decay / 100,
                math.random(-100, 100) * intensity * decay / 100,
                0
            )
            Camera.CFrame = Camera.CFrame * CFrame.new(offset)
            task.wait(0.01)
        end
    end)
end

-- ==================== UI SETUP ====================
my_section:AddLabel("Credits: @anya_bts (Optimized & Fixed)")
my_section:AddParagraph("MM2 Aim Lock", "Advanced aim lock with prediction & smoothing")

local function updatePlayerList()
    local names = {"None (Use Role)"}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then table.insert(names, p.Name) end
    end
    if dropdown then dropdown:Change(names) end
end

local dropdown

my_section:AddToggle("Enable Aim Lock", function(bool)
    settings.enabled = bool
    if bindVal then bindVal.Value = bool end
end)

my_section:AddToggle("Show Bind Button", function(bool)
    settings.showButton = bool
    if bool and not bindVal then
        bindVal, btnObj = BindableButtons.Add("MM2_AimLock", "AIM LOCK",
            function() settings.enabled = true; shared.Notify("Aim Lock: ON", 2) end,
            function() settings.enabled = false; shared.Notify("Aim Lock: OFF", 2) end,
            settings.buttonSize
        )
        if bindVal then
            bindVal.Changed:Connect(function(val) settings.enabled = val end)
            bindVal.Value = settings.enabled
        end
    elseif not bool and btnObj then
        if BindableButtons.Buttons["MM2_AimLock"] then
            BindableButtons.Buttons["MM2_AimLock"].Visible = false
        end
    end
end)

my_section:AddSlider("Button Size", 5, 30, 11, function(v)
    settings.buttonSize = v / 100
    if btnObj then BindableButtons.SetSize("MM2_AimLock", settings.buttonSize) end
end)

dropdown = my_section:AddDropdown("Target Player", {"None (Use Role)"}, function(sel)
    settings.targetPlayer = sel == "None (Use Role)" and nil or sel
end)
updatePlayerList()

Players.PlayerAdded:Connect(function() task.wait(0.5); updatePlayerList() end)
Players.PlayerRemoving:Connect(function() task.wait(0.5); updatePlayerList() end)

my_section:AddDropdown("Target Role", {"Murderer", "Sheriff"}, function(sel)
    settings.targetRole = sel
end)

my_section:AddDropdown("Target Part", {"Head", "Body"}, function(sel)
    settings.targetPart = sel == "Head" and "Head" or "HumanoidRootPart"
end)

my_section:AddSlider("Aim Prediction", 0, 100, 0, function(v)
    settings.prediction = v / 100
end)

my_section:AddSlider("Aim Smoothing", 0, 100, 0, function(v)
    settings.smoothing = v / 100
end)

my_section:AddToggle("Team Check", function(bool)
    settings.teamCheck = bool
    shared.Notify("Team Check: " .. (bool and "ON" or "OFF"), 2)
end)

my_section:AddToggle("Wall Check", function(bool)
    settings.wallCheck = bool
end)

my_section:AddKeybind("Toggle Key", "T", function()
    settings.enabled = not settings.enabled
    if bindVal then bindVal.Value = settings.enabled end
end)

my_section:AddToggle("Burger (very OP)", function(bool)
    if not burgerInitialized then
        burgerInitialized = true
        if bool then
            settings.burger = false
            shared.Notify("Burger ready. Toggle to activate.", 2)
        end
        return
    end
    
    settings.burger = bool
    
    if bool then
        local pg = LP:FindFirstChild("PlayerGui")
        if pg then
            if burgerSound then pcall(function() burgerSound:Destroy() end) end
            burgerSound = Instance.new("Sound")
            burgerSound.SoundId = "rbxassetid://138522344746615"
            burgerSound.Volume = 1
            burgerSound.Looped = true
            burgerSound.Parent = pg
            burgerSound:Play()
        end
        
        task.spawn(function()
            while settings.burger do
                ShakeCamera(2, 0.3)
                task.wait(0.1)
            end
        end)
        shared.Notify("🍔 BURGER MODE ACTIVATED 🍔", 3)
    else
        if burgerSound then
            pcall(function()
                burgerSound:Stop()
                burgerSound:Destroy()
            end)
            burgerSound = nil
        end
        shared.Notify("Burger mode deactivated :(", 2)
    end
end)

-- ==================== MAIN LOOP ====================
RunService.RenderStepped:Connect(function(dt)
    if not settings.enabled or not IsInRound() then return end
    
    local target = FindTarget()
    if not target or not target.Character then return end
    
    local targetPos
    if settings.prediction > 0 then
        targetPos = GetPredictedPosition(target)
    else
        local part = target.Character:FindFirstChild(settings.targetPart)
        targetPos = part and part.Position
    end
    
    if targetPos then
        local camPos = Camera.CFrame.Position
        local desired = CFrame.new(camPos, targetPos)
        
        if settings.smoothing > 0 then
            Camera.CFrame = Camera.CFrame:Lerp(desired, settings.smoothing)
        else
            Camera.CFrame = desired
        end
    end
end)

print("[MM2 Aim Lock] Loaded (FIXED)")
