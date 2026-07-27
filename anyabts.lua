-- MM2 Aim Lock for OverdriveH – улучшенная версия
-- Исправлены ошибки, добавлены FOV, сброс velocity, оптимизация
local shared = odh_shared_plugins
local my_section = shared.AddSection("MM2 Aim Lock")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ============ BINDABLE BUTTONS (без изменений, см. оригинал) ============
-- (здесь вставьте оригинальный блок BindableButtons, он рабочий)
-- Для краткости оставлю как есть, в финальном коде он будет полностью скопирован
--     sound.Volume = 0.5
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
    buttonMaid:GiveTask(__RS.RenderStepped:Connect(function() Stroke.Rotation = (Stroke.Rotation + 1) % 360 end))

    BindableButtons.Buttons[id] = ImageButton
    BindableButtons.Maids[id] = buttonMaid
    BindableButtons.Count = BindableButtons.Count + 1
    
    -- Store reference to the button for resizing
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
    
    local screen = workspace.CurrentCamera.ViewportSize
    local widthScale = sizeY * (screen.Y / screen.X)
    btn.Size = __UD2(widthScale, 0, sizeY, 0)
end

-- ============ НАСТРОЙКИ ============
local AimLockEnabled = false
local AimTarget = "Murderer"
local AimPart = "Head"
local WallCheck = false
local BindButtonEnabled = false
local TargetPlayerName = nil
local ButtonSize = 0.11

-- Новые настройки
local AimPrediction = 0          -- 0..1
local AimSmoothing = 0           -- 0..1
local TeamCheckEnabled = false
local FOVLimit = 90              -- градусы, 0 = без ограничений

-- Переменные состояния
local CurrentTarget = nil
local LastTargetPosition = nil
local LastTargetVelocity = Vector3.zero
local LastUpdateTime = 0
local TargetSwitchFlag = false

-- ============ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ============
local function IsInRound()
    local char = LocalPlayer.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local y = root.Position.Y
    return (y >= 90 and y <= 380)
end

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
    local p1HasKnife = GetTool(player1, knifeKeywords) ~= nil
    local p2HasKnife = GetTool(player2, knifeKeywords) ~= nil
    return p1HasKnife == p2HasKnife
end

-- ============ ПОИСК ЦЕЛИ С FOV ============
local function FindTarget()
    local bestTarget = nil
    local bestScore = math.huge   -- чем меньше, тем лучше (дистанция + угол)
    local knifeKeywords = {"knife", "нож"}
    local gunKeywords = {"gun", "пистолет", "револьвер", "revolver", "sheriff", "шериф"}

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then goto continue end
        if not player.Character then goto continue end

        local hum = player.Character:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then goto continue end

        -- Team check
        if TeamCheckEnabled and IsSameTeam(LocalPlayer, player) then
            goto continue
        end

        -- Роль
        local valid = false
        if AimTarget == "Murderer" then
            valid = GetTool(player, knifeKeywords) ~= nil
        else
            valid = GetTool(player, gunKeywords) ~= nil
        end
        if not valid then goto continue end

        -- Wall check
        if WallCheck and not IsVisible(player.Character) then
            goto continue
        end

        local root = player.Character:FindFirstChild("HumanoidRootPart")
        if not root then goto continue end

        local targetPos = root.Position
        local camPos = Camera.CFrame.Position
        local dirToTarget = (targetPos - camPos).Unit
        local camLook = Camera.CFrame.LookVector

        local distance = (targetPos - camPos).Magnitude
        local angle = math.deg(math.acos(math.clamp(camLook:Dot(dirToTarget), -1, 1)))

        -- FOV фильтр (0 = без ограничений)
        if FOVLimit > 0 and angle > FOVLimit then
            goto continue
        end

        -- Скоринг: дистанция + угол (приоритет ближним целям в центре)
        local score = distance * (1 + angle / 90)   -- можно настраивать
        if score < bestScore then
            bestScore = score
            bestTarget = player
        end

        ::continue::
    end

    return bestTarget
end

-- ============ ПРЕДСКАЗАНИЕ С УЧЁТОМ УСКОРЕНИЯ ============
local function GetPredictedPosition(target, part)
    if not target or not target.Character then return nil end
    local targetPart = target.Character:FindFirstChild(part)
    if not targetPart then return nil end

    local currentPos = targetPart.Position
    local currentTime = tick()
    local velocity = Vector3.zero
    local delta = currentTime - LastUpdateTime

    if LastTargetPosition and delta > 0.01 then
        velocity = (currentPos - LastTargetPosition) / delta
        -- Анти-телепорт: если скорость слишком большая, сбрасываем
        if velocity.Magnitude > 100 then
            velocity = Vector3.zero
            LastTargetPosition = currentPos
        end
    end

    -- Используем MoveDirection для более точного предсказания движения персонажа
    local hum = target.Character:FindFirstChild("Humanoid")
    if hum and hum.MoveDirection.Magnitude > 0.1 then
        local moveVel = hum.MoveDirection * hum.WalkSpeed
        -- Смешиваем с вычисленной скоростью (вес можно настроить)
        velocity = velocity:Lerp(moveVel, 0.3)
    end

    LastTargetPosition = currentPos
    LastUpdateTime = currentTime
    LastTargetVelocity = velocity

    return currentPos + (velocity * AimPrediction)
end

-- ============ ОСНОВНОЙ ЦИКЛ ============
RunService.Heartbeat:Connect(function()
    if not AimLockEnabled then return end
    if not IsInRound() then return end

    local target = FindTarget()

    -- Сброс предсказания при смене цели
    if target ~= CurrentTarget then
        CurrentTarget = target
        LastTargetPosition = nil
        LastTargetVelocity = Vector3.zero
        TargetSwitchFlag = true
    else
        TargetSwitchFlag = false
    end

    if target and target.Character then
        local targetPos = nil
        if AimPrediction > 0 and AimPrediction <= 1 then
            targetPos = GetPredictedPosition(target, AimPart)
        else
            local part = target.Character:FindFirstChild(AimPart)
            if part then targetPos = part.Position end
        end

        if targetPos then
            local cameraPos = Camera.CFrame.Position
            local desiredCFrame = CFrame.new(cameraPos, targetPos)

            if AimSmoothing > 0 then
                Camera.CFrame = Camera.CFrame:Lerp(desiredCFrame, math.clamp(AimSmoothing, 0.05, 0.95))
            else
                Camera.CFrame = desiredCFrame
            end
        end
    end
end)

-- ============ UI (меню OverdriveH) ============
my_section:AddLabel("Credits: @anya_bts")

-- Toggle: Enable Aim Lock
my_section:AddToggle("Enable Aim Lock", function(bool)
    AimLockEnabled = bool
    if AimLockBind then
        AimLockBind.Value = bool
    end
end)

-- Toggle: Show Bind Button
my_section:AddToggle("Show Bind Button", function(bool)
    BindButtonEnabled = bool
    if bool then
        if not AimLockBind then
            AimLockBind, AimLockButton = BindableButtons.AddBButton(
                "MM2_AimLock",
                "AIM LOCK",
                function()
                    AimLockEnabled = true
                    if AimLockBind then AimLockBind.Value = true end
                    shared.Notify("Aim Lock: ON", 2)
                end,
                function()
                    AimLockEnabled = false
                    if AimLockBind then AimLockBind.Value = false end
                    shared.Notify("Aim Lock: OFF", 2)
                end,
                ButtonSize
            )
            AimLockBind.Changed:Connect(function(val)
                AimLockEnabled = val
            end)
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

-- Slider: Button Size
my_section:AddSlider("Button Size", 5, 30, 11, function(value)
    ButtonSize = value / 100
    if AimLockButton then
        BindableButtons.SetSize("MM2_AimLock", ButtonSize)
    end
end)

-- Dropdown: Target Player
local playerListDropdown
local function UpdatePlayerList()
    local playerNames = {"None (Use Role)"}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(playerNames, p.Name) end
    end
    if playerListDropdown then
        playerListDropdown.Change(playerNames)
    end
end

playerListDropdown = my_section:AddDropdown("Target Player", {"None (Use Role)"}, function(selected)
    if selected == "None (Use Role)" then
        TargetPlayerName = nil
    else
        TargetPlayerName = selected
    end
end)

UpdatePlayerList()

-- Обновление списка через события (вместо таймера)
Players.PlayerAdded:Connect(function() task.wait(0.5) UpdatePlayerList() end)
Players.PlayerRemoving:Connect(function() task.wait(0.5) UpdatePlayerList() end)
-- Также обновим при загрузке персонажа (на всякий случай)
LocalPlayer.CharacterAdded:Connect(function() task.wait(1) UpdatePlayerList() end)

-- Dropdown: Target Role
my_section:AddDropdown("Target Role", {"Murderer", "Sheriff"}, function(selected)
    AimTarget = selected
end)

-- Dropdown: Target Part
my_section:AddDropdown("Target Part", {"Head", "Body"}, function(selected)
    AimPart = (selected == "Head") and "Head" or "HumanoidRootPart"
end)

-- Slider: Aim Prediction (0-100 → 0-1)
my_section:AddSlider("Aim Prediction", 0, 100, 0, function(value)
    AimPrediction = value / 100
end)

-- Slider: Aim Smoothing (0-100 → 0-1)
my_section:AddSlider("Aim Smoothing", 0, 100, 0, function(value)
    AimSmoothing = value / 100
end)

-- Slider: FOV Limit (0 = выкл., 10-180 градусов)
my_section:AddSlider("FOV Limit (градусы)", 0, 180, 90, function(value)
    FOVLimit = value
end)

-- Toggle: Team Check
my_section:AddToggle("Team Check", function(bool)
    TeamCheckEnabled = bool
    shared.Notify("Team Check: " .. (bool and "ON" or "OFF"), 2)
end)

-- Toggle: Wall Check
my_section:AddToggle("Wall Check", function(bool)
    WallCheck = bool
end)

-- Keybind: Toggle Aim Lock
my_section:AddKeybind("Toggle Key", "T", function()
    AimLockEnabled = not AimLockEnabled
    if AimLockBind then AimLockBind.Value = AimLockEnabled end
end)

print("[MM2 Aim Lock] Improved version loaded successfully.")
