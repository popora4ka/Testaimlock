-- MM2 Murderer Aim Lock for Innocent/Sheriff
local shared = odh_shared_plugins
local my_section = shared.AddSection("anya_bts_AimLock")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Settings
local AimLockEnabled = false
local TargetPart = "Head"
local TargetPlayer = nil
local WallCheckEnabled = false
local BindableButtonEnabled = false
local TargetSheriff = false -- false = Murderer, true = Sheriff

-- Mobile button
local ScreenGui = Instance.new("ScreenGui")
local ToggleButton = Instance.new("TextButton")
local UICorner = Instance.new("UICorner")
local UIStroke = Instance.new("UIStroke")

ScreenGui.Parent = game.CoreGui
ScreenGui.Name = "anya_bts_AimLockGUI"

ToggleButton.Parent = ScreenGui
ToggleButton.Size = UDim2.new(0, 70, 0, 70)
ToggleButton.Position = UDim2.new(0.85, 0, 0.5, -35)
ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
ToggleButton.Text = "AIM\nLOCK"
ToggleButton.TextColor3 = Color3.new(1, 1, 1)
ToggleButton.TextSize = 13
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.BorderSizePixel = 0
ToggleButton.Active = true
ToggleButton.Draggable = true
ToggleButton.Visible = false

UICorner.Parent = ToggleButton
UICorner.CornerRadius = UDim.new(1, 0)

UIStroke.Parent = ToggleButton
UIStroke.Color = Color3.fromRGB(255, 255, 255)
UIStroke.Thickness = 2

ToggleButton.MouseButton1Click:Connect(function()
    AimLockEnabled = not AimLockEnabled
    if AimLockEnabled then
        UIStroke.Color = Color3.fromRGB(0, 255, 0)
        if not IsLocalInLobby() then
            TargetPlayer = FindTarget()
        end
    else
        UIStroke.Color = Color3.fromRGB(255, 255, 255)
        TargetPlayer = nil
    end
end)

-- Credits
my_section:AddLabel("Credits: anya_bts")

-- Description
my_section:AddParagraph("aim lock", "have ideas/bugs? ping me")

-- Toggle: Enable/Disable Aim Lock
my_section:AddToggle("Enable Aim Lock", function(bool)
    AimLockEnabled = bool
    if bool then
        UIStroke.Color = Color3.fromRGB(0, 255, 0)
        if not IsLocalInLobby() then
            TargetPlayer = FindTarget()
        end
    else
        UIStroke.Color = Color3.fromRGB(255, 255, 255)
        TargetPlayer = nil
    end
end)

-- Dropdown: Choose target role (Murderer or Sheriff)
my_section:AddDropdown("Target Role", {"Murderer", "Sheriff"}, function(selected)
    TargetSheriff = (selected == "Sheriff")
    TargetPlayer = nil -- reset target when switching
    if AimLockEnabled and not IsLocalInLobby() then
        TargetPlayer = FindTarget()
    end
end)

-- Toggle: Enable/Disable Bindable Button
my_section:AddToggle("Bindable Button", function(bool)
    BindableButtonEnabled = bool
    ToggleButton.Visible = bool
end)

-- Toggle: Enable/Disable Wall Check
my_section:AddToggle("Wall Check", function(bool)
    WallCheckEnabled = bool
    if WallCheckEnabled then
        shared.Notify("Wall Check enabled", 2)
    else
        shared.Notify("Wall Check disabled", 2)
    end
end)

-- Dropdown: Head or Body
local dropdown = my_section:AddDropdown("Target Part", {"Head", "Body"}, function(selected)
    TargetPart = selected
end)

-- Keybind: Toggle Aim Lock (default T)
my_section:AddKeybind("Toggle Key", "T", function()
    AimLockEnabled = not AimLockEnabled
    if AimLockEnabled then
        UIStroke.Color = Color3.fromRGB(0, 255, 0)
        if not IsLocalInLobby() then
            TargetPlayer = FindTarget()
        end
    else
        UIStroke.Color = Color3.fromRGB(255, 255, 255)
        TargetPlayer = nil
    end
end)

-- Check if local player is in lobby (Y 180-380 = round, else = lobby)
function IsLocalInLobby()
    local character = LocalPlayer.Character
    if not character then return true end
    
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return true end
    
    local y = root.Position.Y
    
    if y >= 180 and y <= 380 then
        return false -- Round
    end
    
    return true -- Lobby
end

-- Wall check: raycast from camera to target
function IsTargetVisible(target)
    if not target or not target.Character then return false end
    
    local targetPart = nil
    if TargetPart == "Head" then
        targetPart = target.Character:FindFirstChild("Head")
    elseif TargetPart == "Body" then
        targetPart = target.Character:FindFirstChild("HumanoidRootPart")
    end
    
    if not targetPart then return false end
    
    local cameraPos = Camera.CFrame.Position
    local targetPos = targetPart.Position
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local raycastResult = workspace:Raycast(cameraPos, (targetPos - cameraPos).Unit * (targetPos - cameraPos).Magnitude, raycastParams)
    
    if raycastResult then
        local hitInstance = raycastResult.Instance
        if hitInstance:IsDescendantOf(target.Character) then
            return true
        else
            return false
        end
    end
    
    return true
end

-- Check if player has a knife (Murderer)
local function HasKnife(player)
    if not player or not player.Character then return false end
    for _, item in ipairs(player.Character:GetChildren()) do
        if item:IsA("Tool") and (item.Name:lower():find("knife") or item.Name:lower():find("нож")) then
            return true
        end
    end
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and (item.Name:lower():find("knife") or item.Name:lower():find("нож")) then
                return true
            end
        end
    end
    return false
end

-- Check if player has a gun (Sheriff)
local function HasGun(player)
    if not player or not player.Character then return false end
    for _, item in ipairs(player.Character:GetChildren()) do
        if item:IsA("Tool") and (item.Name:lower():find("gun") or item.Name:lower():find("пистолет") or item.Name:lower():find("револьвер") or item.Name:lower():find("revolver")) then
            return true
        end
    end
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and (item.Name:lower():find("gun") or item.Name:lower():find("пистолет") or item.Name:lower():find("револьвер") or item.Name:lower():find("revolver")) then
                return true
            end
        end
    end
    return false
end

-- Find the Murderer (player with knife)
function FindMurderer()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 and HasKnife(player) then
                if WallCheckEnabled then
                    if IsTargetVisible(player) then
                        return player
                    end
                else
                    return player
                end
            end
        end
    end
    return nil
end

-- Find the Sheriff (player with gun)
function FindSheriff()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 and HasGun(player) then
                if WallCheckEnabled then
                    if IsTargetVisible(player) then
                        return player
                    end
                else
                    return player
                end
            end
        end
    end
    return nil
end

-- Pick target based on TargetSheriff flag
function FindTarget()
    if TargetSheriff then
        return FindSheriff()
    else
        return FindMurderer()
    end
end

-- Get target position
function GetTargetPosition(player)
    if not player or not player.Character then return nil end
    
    if TargetPart == "Head" then
        local head = player.Character:FindFirstChild("Head")
        if head then return head.Position end
    elseif TargetPart == "Body" then
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp.Position end
    end
    
    return nil
end

-- Check if current target still has the required weapon
local function IsValidTarget(player)
    if not player or not player.Character then return false end
    local hum = player.Character:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    
    if TargetSheriff then
        return HasGun(player)
    else
        return HasKnife(player)
    end
end

-- Main loop
RunService.RenderStepped:Connect(function()
    local inLobby = IsLocalInLobby()
    
    if inLobby then
        return
    end
    
    if not AimLockEnabled then return end
    
    if WallCheckEnabled and TargetPlayer then
        if not IsTargetVisible(TargetPlayer) then
            TargetPlayer = nil
        end
    end
    
    local validTarget = false
    if TargetPlayer and IsValidTarget(TargetPlayer) then
        if WallCheckEnabled then
            if IsTargetVisible(TargetPlayer) then
                validTarget = true
            end
        else
            validTarget = true
        end
    end
    
    if not validTarget then
        TargetPlayer = FindTarget()
    end
    
    if TargetPlayer then
        local targetPos = GetTargetPosition(TargetPlayer)
        if targetPos then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
        end
    end
end)

-- Reset target on respawn
LocalPlayer.CharacterAdded:Connect(function()
    TargetPlayer = nil
end)

print("Aim lock loaded")
