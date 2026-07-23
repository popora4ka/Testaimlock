-- MM2 Aim Lock for OverdriveH - OPTIMIZED (no logic changes)
local shared = odh_shared_plugins
local my_section = shared.AddSection("MM2 Aim Lock")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ==================== LOCAL FAST REFERENCES ====================
local __INSERT = table.insert
local __FLOOR = math.floor
local __PCLR = Color3.new
local __RGB = Color3.fromRGB
local __UD2 = UDim2.new
local __UD = UDim.new
local __V2 = Vector2.new
local __TS = game:GetService("TweenService")
local __UIS = game:GetService("UserInputService")
local __RS = RunService
local __PLRS = Players
local __WS = workspace
local __CAM = Camera
local __HUGE = math.huge
local __TICK = tick
local __WAIT = task.wait
local __SPAWN = task.spawn

-- ==================== MAID (optimized) ====================
local Maid = {}
Maid.__index = Maid
function Maid.new() return setmetatable({_tasks = {}, _destroyed = false}, Maid) end
function Maid:GiveTask(task)
    if self._destroyed then
        if typeof(task) == "RBXScriptConnection" then task:Disconnect()
        elseif typeof(task) == "Instance" then task:Destroy()
        elseif type(task) == "function" then task()
        elseif type(task) == "table" and type(task.Destroy) == "function" then task:Destroy() end
        return
    end
    __INSERT(self._tasks, task)
    return task
end
function Maid:DoCleaning()
    if self._destroyed then return end
    self._destroyed = true
    for _, t in pairs(self._tasks) do
        if typeof(t) == "RBXScriptConnection" then t:Disconnect()
        elseif typeof(t) == "Instance" then t:Destroy()
        elseif type(t) == "function" then t()
        elseif type(t) == "table" and type(t.Destroy) == "function" then t:Destroy() end
    end
    self._tasks = {}
end
function Maid:Destroy() self:DoCleaning() end

-- ==================== BINDABLE BUTTONS ====================
local BindableButtons = {Buttons = {}, Maids = {}, Count = 0}
local __RootMaid = Maid.new()

local __SHAPES = {
    [0] = "rbxassetid://86221076925479",
    [1] = "rbxassetid://96242665417546",
    [2] = "rbxassetid://97129189935336",
    [3] = "rbxassetid://76165862027868",
    [4] = "rbxassetid://125868092127496"
}

local __NORMAL_COLOR = ColorSequence.new({
    ColorSequenceKeypoint.new(0, __PCLR(0.133333, 0.827451, 0.494118)),
    ColorSequenceKeypoint.new(0.6, __PCLR(0.231373, 0.509804, 0.498039)),
    ColorSequenceKeypoint.new(1, __PCLR(0.501961, 0.501961, 0.501961))
})

local __TOGGLED_COLOR = ColorSequence.new({
    ColorSequenceKeypoint.new(0, __PCLR(0.0784314, 0.0784314, 0.0784314)),
    ColorSequenceKeypoint.new(0.75, __PCLR(0.0784314, 0.0784314, 0.54902)),
    ColorSequenceKeypoint.new(1, __PCLR(0.470588, 0.156863, 0.470588))
})

local function safecallback(callback)
    if not callback then return end
    local success, err = xpcall(callback, function(e) return debug.traceback(e) end)
    if not success then
        warn("[ERROR] Fucker Something Went Wrong, Traceback: " .. tostring(err))
    end
end

local function GetStorage()
    local player = __PLRS.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local sg = playerGui:FindFirstChild("@bindstorage")
    if not sg then
        sg = Instance.new("ScreenGui")
        sg.Name = "@bindstorage"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        pcall(function() sg.ScreenInsets = Enum.ScreenInsets.None end)
        sg.Parent = playerGui
    end
    return sg
end

local function MakeDraggable(gui, maid, ripple, sound, clickFunc)
    local dragging, dragInput, dragStart, startPos
    local hasMoved = false
    
    maid:GiveTask(gui.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, gui.Position
            hasMoved = false
            sound:Play()
            local absPos = gui.AbsolutePosition
            ripple.Position = __UD2(0, input.Position.X - absPos.X, 0, input.Position.Y - absPos.Y)
            ripple.Size = __UD2(0, 0, 0, 0)
            ripple.BackgroundTransparency = 0.5
            ripple.Visible = true
            __TS:Create(ripple, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                Size = __UD2(0, 45, 0, 45),
                BackgroundTransparency = 1
            }):Play()

            local releaseConn
            releaseConn = __UIS.InputEnded:Connect(function(endInput)
                if endInput.UserInputType == input.UserInputType then
                    dragging = false
                    if not hasMoved then clickFunc() end
                    releaseConn:Disconnect()
                end
            end)
        end
    end))
    
    maid:GiveTask(gui.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))
    
    maid:GiveTask(__UIS.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            if delta.Magnitude > 7 then hasMoved = true end
            local screen = gui.Parent.AbsoluteSize
            gui.Position = __UD2(
                startPos.X.Scale + (delta.X / screen.X), 0,
                startPos.Y.Scale + (delta.Y / screen.Y), 0
            )
        end
    end))
end

function BindableButtons.AddBButton(id, text, onFunc, offFunc, customSize)
    if BindableButtons.Buttons[id] then
        return BindableButtons.Buttons[id]:FindFirstChild("BindValue")
    end
    
    local buttonMaid = Maid.new()
    local screen = __CAM.ViewportSize
    local buttonSizeY = customSize or 0.11
    local widthScale = buttonSizeY * (screen.Y / screen.X)
    
    local xPos = 0.1 + ((BindableButtons.Count % 8) * (widthScale + 0.005))
    local yPos = 0.9 - (__FLOOR(BindableButtons.Count / 8) * (buttonSizeY + 0.015))
    
    local ImageButton = Instance.new("ImageButton")
    ImageButton.Name = id
    ImageButton.Size = __UD2(widthScale, 0, buttonSizeY, 0)
    ImageButton.Position = __UD2(xPos, 0, yPos, 0)
    ImageButton.AnchorPoint = __V2(0.5, 0.5)
    ImageButton.Image = __SHAPES[0]
    ImageButton.BackgroundTransparency = 1
    ImageButton.BorderSizePixel = 0
    ImageButton.ClipsDescendants = false
    ImageButton.AutoButtonColor = false
    ImageButton.Parent = GetStorage()
    buttonMaid:GiveTask(ImageButton)

    local BindValue = Instance.new("BoolValue", ImageButton)
    BindValue.Name = "BindValue"

    local TextLabel = Instance.new("TextLabel", ImageButton)
    TextLabel.Name = "@Text"
    TextLabel.Size = __UD2(0.8, 0, 0.8, 0)
    TextLabel.Position = __UD2(0.5, 0, 0.5, 0)
    TextLabel.AnchorPoint = __V2(0.5, 0.5)
    TextLabel.BackgroundTransparency = 1
    TextLabel.Font = Enum.Font.Jura
    TextLabel.Text = text
    TextLabel.TextColor3 = __PCLR(1, 1, 1)
    TextLabel.TextSize = 10
    TextLabel.TextWrapped = true
    TextLabel.ZIndex = 3

    local Aspect = Instance.new("UIAspectRatioConstraint", ImageButton)
    Aspect.AspectRatio = 1
    Aspect.AspectType = Enum.AspectType.ScaleWithParentSize

    local Stroke = Instance.new("UIGradient", ImageButton)
    Stroke.Name = "@Stroke"
    Stroke.Color = __NORMAL_COLOR

    local ripple = Instance.new("Frame")
    ripple.Name = "@ripple"
    ripple.BackgroundColor3 = __RGB(0, 155, 255)
    ripple.BackgroundTransparency = 0.5
    ripple.Size = __UD2(0, 0, 0, 0)
    ripple.AnchorPoint = __V2(0.5, 0.5)
    ripple.Visible = false
    ripple.ZIndex = 2
    ripple.Parent = ImageButton
    Instance.new("UICorner", ripple).CornerRadius = __UD(1, 0)

    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://3868133279"
    sound.Volume = 0.5
    sound.Parent = ImageButton

    local debounce = false
    local tInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

    local function onClick()
        if debounce then return end
        debounce = true
        local fOut = __TS:Create(ImageButton, tInfo, {ImageTransparency = 1})
        fOut:Play()
        fOut.Completed:Wait()
        
        BindValue.Value = not BindValue.Value
        Stroke.Color = BindValue.Value and __TOGGLED_COLOR or __NORMAL_COLOR
        if BindValue.Value then safecallback(onFunc) else safecallback(offFunc) end
        
        local fIn = __TS:Create(ImageButton, tInfo, {ImageTransparency = 0})
        fIn:Play()
        fIn.Completed:Wait()
        debounce = false
    end

    MakeDraggable(ImageButton, buttonMaid, ripple, sound, onClick)
    buttonMaid:GiveTask(__RS.RenderStepped:Connect(function()
        Stroke.Rotation = (Stroke.Rotation + 1) % 360
    end))

    BindableButtons.Buttons[id] = ImageButton
    BindableButtons.Maids[id] = buttonMaid
    BindableButtons.Count = BindableButtons.Count + 1
    
    return BindValue, ImageButton
end

function BindableButtons.SetShape(id, shape)
    local btn = BindableButtons.Buttons[id]
    if btn and __SHAPES[shape] then
        btn.Image = __SHAPES[shape]
    end
end

function BindableButtons.DeleteBButton(id)
    if BindableButtons.Maids[id] then
        BindableButtons.Maids[id]:Destroy()
        BindableButtons.Maids[id] = nil
        BindableButtons.Buttons[id] = nil
    end
end

function BindableButtons.SetSize(id, sizeY)
    local btn = BindableButtons.Buttons[id]
    if not btn then return end
    local screen = __CAM.ViewportSize
    local widthScale = sizeY * (screen.Y / screen.X)
    btn.Size = __UD2(widthScale, 0, sizeY, 0)
end

-- ==================== AIM LOCK LOGIC ====================
local AimLockEnabled = false
local AimTarget = "Murderer"
local AimPart = "Head"
local WallCheck = false
local BindButtonEnabled = false
local AimLockBind = nil
local AimLockButton = nil
local TargetPlayerName = nil
local playerListDropdown = nil
local ButtonSize = 0.11

local AimPrediction = 0
local AimSmoothing = 0
local TeamCheckEnabled = false

local LastTargetPosition = nil
local LastUpdateTime = 0

-- ==================== UI ====================
my_section:AddLabel("Credits: @anya_bts")
my_section:AddParagraph("MM2 Aim Lock", "Advanced aim lock with prediction, smoothing, and team check.")

my_section:AddToggle("Enable Aim Lock", function(bool)
    AimLockEnabled = bool
    if AimLockBind then AimLockBind.Value = bool end
end)

my_section:AddToggle("Show Bind Button", function(bool)
    BindButtonEnabled = bool
    if bool then
        if not AimLockBind then
            AimLockBind, AimLockButton = BindableButtons.AddBButton(
                "MM2_AimLock", "AIM LOCK",
                function() AimLockEnabled = true; shared.Notify("Aim Lock: ON", 2) end,
                function() AimLockEnabled = false; shared.Notify("Aim Lock: OFF", 2) end,
                ButtonSize
            )
            AimLockBind.Changed:Connect(function(val) AimLockEnabled = val end)
            AimLockBind.Value = AimLockEnabled
        else
            local btn = BindableButtons.Buttons["MM2_AimLock"]
            if btn then btn.Visible = true end
        end
    else
        if AimLockBind then
            local btn = BindableButtons.Buttons["MM2_AimLock"]
            if btn then btn.Visible = false end
        end
    end
end)

my_section:AddSlider("Button Size", 5, 30, 11, function(value)
    ButtonSize = value / 100
    if AimLockButton then BindableButtons.SetSize("MM2_AimLock", ButtonSize) end
end)

local function UpdatePlayerList()
    local playerNames = {"None (Use Role)"}
    for _, player in ipairs(__PLRS:GetPlayers()) do
        if player ~= LocalPlayer then
            __INSERT(playerNames, player.Name)
        end
    end
    if playerListDropdown then
        playerListDropdown:Change(playerNames)
    end
end

playerListDropdown = my_section:AddDropdown("Target Player", {"None (Use Role)"}, function(selected)
    TargetPlayerName = (selected == "None (Use Role)" and nil) or selected
end)
UpdatePlayerList()

__SPAWN(function()
    while true do
        __WAIT(30)
        UpdatePlayerList()
    end
end)

__PLRS.PlayerAdded:Connect(function() __WAIT(1); UpdatePlayerList() end)
__PLRS.PlayerRemoving:Connect(function() __WAIT(1); UpdatePlayerList() end)

my_section:AddDropdown("Target Role", {"Murderer", "Sheriff"}, function(selected)
    AimTarget = selected
end)

my_section:AddDropdown("Target Part", {"Head", "Body"}, function(selected)
    AimPart = (selected == "Head") and "Head" or "HumanoidRootPart"
end)

my_section:AddSlider("Aim Prediction", 0, 100, 0, function(value)
    AimPrediction = value / 100
end)

my_section:AddSlider("Aim Smoothing", 0, 100, 0, function(value)
    AimSmoothing = value / 100
end)

my_section:AddToggle("Team Check", function(bool)
    TeamCheckEnabled = bool
    shared.Notify("Team Check: " .. (bool and "ON - Won't target teammates" or "OFF"), 2)
end)

my_section:AddToggle("Wall Check", function(bool)
    WallCheck = bool
end)

my_section:AddKeybind("Toggle Key", "T", function()
    AimLockEnabled = not AimLockEnabled
    if AimLockBind then AimLockBind.Value = AimLockEnabled end
end)

-- ==================== CORE FUNCTIONS (OPTIMIZED) ====================
local function IsInRound()
    local char = LocalPlayer.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local y = root.Position.Y
    return y >= 180 and y <= 380
end

-- Cached RaycastParams for performance
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

local function IsVisible(targetChar)
    if not targetChar then return false end
    local targetPart = targetChar:FindFirstChild(AimPart)
    if not targetPart then return false end
    
    -- Update filter each time (only LocalPlayer.Character)
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local origin = __CAM.CFrame.Position
    local dir = (targetPart.Position - origin)
    local ray = __WS:Raycast(origin, dir.Unit * dir.Magnitude, raycastParams)
    
    if ray then
        return ray.Instance:IsDescendantOf(targetChar)
    end
    return true
end

local function GetTool(player, keywords)
    if not player.Character then return nil end
    local function check(container)
        if not container then return nil end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local name = item.Name:lower()
                for _, kw in ipairs(keywords) do
                    if name:find(kw) then
                        return item
                    end
                end
            end
        end
        return nil
    end
    return check(player.Character) or check(player.Backpack)
end

local function IsSameTeam(player1, player2)
    if not player1 or not player2 then return false end
    local knifeKeywords = {"knife", "нож"}
    local p1HasKnife = (GetTool(player1, knifeKeywords) ~= nil)
    local p2HasKnife = (GetTool(player2, knifeKeywords) ~= nil)
    return p1HasKnife == p2HasKnife
end

local function FindTarget()
    if TargetPlayerName then
        local target = __PLRS:FindFirstChild(TargetPlayerName)
        if target and target.Character then
            local hum = target.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                if TeamCheckEnabled and IsSameTeam(LocalPlayer, target) then return nil end
                if WallCheck and not IsVisible(target.Character) then return nil end
                return target
            end
        end
        return nil
    end
    
    local knifeKeywords = {"knife", "нож"}
    local gunKeywords = {"gun", "пистолет", "револьвер", "revolver", "sheriff", "шериф"}
    local checkKeywords = (AimTarget == "Murderer") and knifeKeywords or gunKeywords
    local bestTarget = nil
    local bestDist = __HUGE
    local camPos = __CAM.CFrame.Position  -- single fetch per frame
    
    for _, player in ipairs(__PLRS:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                if TeamCheckEnabled and IsSameTeam(LocalPlayer, player) then
                    continue
                end
                if not GetTool(player, checkKeywords) then
                    continue
                end
                if WallCheck and not IsVisible(player.Character) then
                    continue
                end
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local dist = (camPos - root.Position).Magnitude
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

local function GetPredictedPosition(target, part)
    if not target or not target.Character then return nil end
    local targetPart = target.Character:FindFirstChild(part)
    if not targetPart then return nil end
    
    local currentPos = targetPart.Position
    local currentTime = __TICK()
    local velocity = Vector3.zero
    
    if LastTargetPosition and LastUpdateTime > 0 then
        local timeDelta = currentTime - LastUpdateTime
        if timeDelta > 0 then
            velocity = (currentPos - LastTargetPosition) / timeDelta
        end
    end
    
    LastTargetPosition = currentPos
    LastUpdateTime = currentTime
    
    return currentPos + (velocity * AimPrediction)
end

-- ==================== MAIN LOOP ====================
__RS.RenderStepped:Connect(function()
    if not AimLockEnabled then return end
    if not IsInRound() then return end
    
    local target = FindTarget()
    if not target or not target.Character then return end
    
    local targetPos
    if AimPrediction > 0 then
        targetPos = GetPredictedPosition(target, AimPart)
    else
        local part = target.Character:FindFirstChild(AimPart)
        targetPos = part and part.Position
    end
    
    if targetPos then
        local camPos = __CAM.CFrame.Position
        local desired = CFrame.new(camPos, targetPos)
        if AimSmoothing > 0 then
            __CAM.CFrame = __CAM.CFrame:Lerp(desired, AimSmoothing)
        else
            __CAM.CFrame = desired
        end
    end
end)

print("[MM2 Aim Lock] Loaded (Optimized)")
