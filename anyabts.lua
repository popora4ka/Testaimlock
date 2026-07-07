-- MM2 Aim Lock for OverdriveH
local shared = odh_shared_plugins
local my_section = shared.AddSection("MM2 Aim Lock")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Settings
local AimLockEnabled = false
local AimTarget = "Murderer" -- "Murderer" or "Sheriff"
local AimPart = "Head" -- "Head" or "HumanoidRootPart"
local WallCheck = false
local UseKeybind = true
local KeybindKey = "T"

-- Mobile button
local ScreenGui = Instance.new("ScreenGui")
local AimButton = Instance.new("TextButton")
local ButtonCorner = Instance.new("UICorner")
local ButtonStroke = Instance.new("UIStroke")

ScreenGui.Parent = game.CoreGui
ScreenGui.Name = "MM2AimLock_UI"

AimButton.Parent = ScreenGui
AimButton.Size = UDim2.new(0, 70, 0, 70)
AimButton.Position = UDim2.new(0.85, 0, 0.45, 0)
AimButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
AimButton.Text = "AIM\nOFF"
AimButton.TextColor3 = Color3.fromRGB(255, 80, 80)
AimButton.TextSize = 12
AimButton.Font = Enum.Font.GothamBold
AimButton.BorderSizePixel = 0
AimButton.Active = true
AimButton.Draggable = true
AimButton.Visible = false

ButtonCorner.Parent = AimButton
ButtonCorner.CornerRadius = UDim.new(1, 0)

ButtonStroke.Parent = AimButton
ButtonStroke.Color = Color3.fromRGB(255, 80, 80)
ButtonStroke.Thickness = 2

-- Button click handler
AimButton.MouseButton1Click:Connect(function()
    AimLockEnabled = not AimLockEnabled
    UpdateButtonState()
end)

function UpdateButtonState()
    if AimLockEnabled then
        AimButton.Text = "AIM\nON"
        AimButton.TextColor3 = Color3.fromRGB(80, 255, 80)
        ButtonStroke.Color = Color3.fromRGB(80, 255, 80)
    else
        AimButton.Text = "AIM\nOFF"
        AimButton.TextColor3 = Color3.fromRGB(255, 80, 80)
        ButtonStroke.Color = Color3.fromRGB(255, 80, 80)
    end
end

-- Credits
my_section:AddLabel("Credits: @anya_bts")

-- Description
my_section:AddParagraph("MM2 Aim Lock", "Auto-aim for Innocent role. Locks camera onto selected target.")

-- Toggle: Enable Aim Lock
my_section:AddToggle("Enable Aim Lock", function(bool)
    AimLockEnabled = bool
    UpdateButtonState()
end)

-- Dropdown: Target Role
my_section:AddDropdown("Target Role", {"Murderer", "Sheriff"}, function(selected)
    AimTarget = selected
end)

-- Dropdown: Target Part
my_section:AddDropdown("Target Part", {"Head", "Body"}, function(selected)
    if selected == "Head" then
        AimPart = "Head"
    else
        AimPart = "HumanoidRootPart"
    end
end)

-- Toggle: Wall Check
my_section:AddToggle("Wall Check", function(bool)
    WallCheck = bool
end)

-- Toggle: Show Mobile Button
my_section:AddToggle("Show Mobile Button", function(bool)
    AimButton.Visible = bool
end)

-- Keybind
my_section:AddKeybind("Toggle Key", "T", function()
    AimLockEnabled = not AimLockEnabled
    UpdateButtonState()
end)

-- Check if player is in game round
local function IsInRound()
    local char = LocalPlayer.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local y = root.Position.Y
    return (y >= 180 and y <= 380)
end

-- Raycast wall check
local function IsVisible(targetChar)
    if not targetChar then return false end
    
    local targetPart = targetChar:FindFirstChild(AimPart)
    if not targetPart then return false end
    
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin)
    local ray = workspace:Raycast(origin, direction.Unit * direction.Magnitude, params)
    
    if ray then
        return ray.Instance:IsDescendantOf(targetChar)
    end
    return true
end

-- Get tool from character or backpack
local function GetTool(player, keywords)
    if not player.Character then return nil end
    
    local function check(container)
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
    
    return check(player.Character) or (player.Backpack and check(player.Backpack))
end

-- Find target based on role
local function FindTarget()
    local knifeKeywords = {"knife", "нож"}
    local gunKeywords = {"gun", "пистолет", "револьвер", "revolver", "sheriff", "шериф"}
    
    local bestTarget = nil
    local bestDistance = math.huge
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                
                local valid = false
                if AimTarget == "Murderer" then
                    valid = GetTool(player, knifeKeywords) ~= nil
                else
                    valid = GetTool(player, gunKeywords) ~= nil
                end
                
                if valid then
                    if WallCheck and not IsVisible(player.Character) then
                        continue
                    end
                    
                    local root = player.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        local dist = (Camera.CFrame.Position - root.Position).Magnitude
                        if dist < bestDistance then
                            bestDistance = dist
                            bestTarget = player
                        end
                    end
                end
            end
        end
    end
    
    return bestTarget
end

-- Main aim loop
RunService.RenderStepped:Connect(function()
    if not AimLockEnabled then return end
    if not IsInRound() then return end
    
    local target = FindTarget()
    
    if target and target.Character then
        local part = target.Character:FindFirstChild(AimPart)
        if part then
            local lookAt = CFrame.new(Camera.CFrame.Position, part.Position)
            Camera.CFrame = lookAt
        end
    end
end)

-- Cleanup on death
LocalPlayer.CharacterAdded:Connect(function(char)
    -- Nothing needed, FindTarget handles nil characters
end)

print("[MM2 Aim Lock] Loaded successfully")
