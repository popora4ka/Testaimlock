-- =====================================================================
-- MM2 Aim Lock v3.0 – оптимизированная версия
-- Исправления: Maid, кэширование, AssemblyLinearVelocity, 
-- снижение частоты поиска, устранение дублирования.
-- =====================================================================

local shared = odh_shared_plugins
local my_section = shared.AddSection("MM2 Aim Lock")

-- ===================== СЕРВИСЫ (однократно) =====================
local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    TweenService = game:GetService("TweenService"),
    UserInputService = game:GetService("UserInputService"),
    Workspace = workspace,
}

local Players = Services.Players
local RunService = Services.RunService
local Camera = Services.Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ===================== УЛУЧШЕННЫЙ MAID =====================
local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({
        Tasks = {},
        Destroyed = false
    }, Maid)
end

function Maid:CleanupTask(task)
    local t = typeof(task)
    if t == "RBXScriptConnection" then
        task:Disconnect()
    elseif t == "Instance" then
        task:Destroy()
    elseif type(task) == "function" then
        task()
    elseif type(task) == "table" and type(task.Destroy) == "function" then
        task:Destroy()
    end
end

function Maid:GiveTask(task)
    if self.Destroyed then
        self:CleanupTask(task)
        return nil
    end
    self.Tasks[#self.Tasks + 1] = task
    return task
end

function Maid:DoCleaning()
    if self.Destroyed then return end
    self.Destroyed = true
    for i = #self.Tasks, 1, -1 do
        self:CleanupTask(self.Tasks[i])
        self.Tasks[i] = nil
    end
end

function Maid:Destroy()
    self:DoCleaning()
end

-- ===================== BINDABLE BUTTONS (оптимизированные) =====================
local __INSERT = table.insert
local __FLOOR = math.floor
local __PCLR = Color3.new
local __RGB = Color3.fromRGB
local __UD2 = UDim2.new
local __UD = UDim.new
local __V2 = Vector2.new

local __TS = Services.TweenService
local __UIS = Services.UserInputService
local __RS = Services.RunService

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

local ButtonTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local function safecallback(callback)
    if not callback then return end
    local success, err = xpcall(callback, function(e) return debug.traceback(e) end)
    if not success then
        warn("[ERROR] Callback error: " .. tostring(err))
    end
end

-- Получение хранилища один раз
local function GetStorage()
    local player = Players.LocalPlayer
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
local Storage = GetStorage()

-- Вспомогательные функции для создания элементов
local function CreateRipple(parent)
    local ripple = Instance.new("Frame")
    ripple.Name = "@ripple"
    ripple.BackgroundColor3 = __RGB(0, 155, 255)
    ripple.BackgroundTransparency = 0.5
    ripple.Size = __UD2(0, 0, 0, 0)
    ripple.AnchorPoint = __V2(0.5, 0.5)
    ripple.Visible = false
    ripple.ZIndex = 2
    ripple.Parent = parent
    Instance.new("UICorner", ripple).CornerRadius = __UD(1, 0)
    return ripple
end

local function CreateGradient(parent)
    local stroke = Instance.new("UIGradient")
    stroke.Name = "@Stroke"
    stroke.Color = __NORMAL_COLOR
    stroke.Parent = parent
    return stroke
end

local function CreateSound(parent)
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://3868133279"
    sound.Volume = 0.5
    sound.Parent = parent
    return sound
end

local BindableButtons = {Buttons = {}, Maids = {}, Count = 0}
local __RootMaid = Maid.new()
local AllButtons = {} -- для общего вращения градиентов

function BindableButtons.AddBButton(id, text, onFunc, offFunc, customSize)
    if BindableButtons.Buttons[id] then
        return BindableButtons.Buttons[id]:FindFirstChild("BindValue")
    end

    local buttonMaid = Maid.new()
    local camera = Services.Workspace.CurrentCamera
    local screen = camera.ViewportSize

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
    ImageButton.Parent = Storage
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

    local Stroke = CreateGradient(ImageButton)

    local ripple = CreateRipple(ImageButton)

    local sound = CreateSound(ImageButton)

    local debounce = false

    local function onClick()
        if debounce then return end
        debounce = true

        local fOut = __TS:Create(ImageButton, ButtonTweenInfo, {ImageTransparency = 1})
        fOut:Play()

        -- Используем Completed:Once, чтобы избежать блокировки
        local conn
        conn = fOut.Completed:Connect(function()
            conn:Disconnect()
            BindValue.Value = not BindValue.Value
            Stroke.Color = BindValue.Value and __TOGGLED_COLOR or __NORMAL_COLOR

            if BindValue.Value then
                local ok = pcall(onFunc)
                if not ok then warn("onFunc error") end
            else
                local ok = pcall(offFunc)
                if not ok then warn("offFunc error") end
            end

            local fIn = __TS:Create(ImageButton, ButtonTweenInfo, {ImageTransparency = 0})
            fIn:Play()
            fIn.Completed:Once(function()
                debounce = false
            end)
        end)
    end

    -- MakeDraggable (упрощённый)
    local function MakeDraggable(gui)
        local dragging, dragInput, dragStart, startPos
        local hasMoved = false

        local inputBeganConn = gui.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = gui.Position
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
                        if not hasMoved then
                            onClick()
                        end
                        releaseConn:Disconnect()
                    end
                end)
                buttonMaid:GiveTask(releaseConn)
            end
        end)
        buttonMaid:GiveTask(inputBeganConn)

        local inputChangedConn = gui.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        buttonMaid:GiveTask(inputChangedConn)

        local uisChangedConn = __UIS.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                if delta.Magnitude > 7 then hasMoved = true end
                local screen = gui.Parent.AbsoluteSize
                gui.Position = __UD2(
                    startPos.X.Scale + (delta.X / screen.X),
                    0,
                    startPos.Y.Scale + (delta.Y / screen.Y),
                    0
                )
            end
        end)
        buttonMaid:GiveTask(uisChangedConn)
    end

    MakeDraggable(ImageButton)

    -- Добавляем кнопку в общий список для вращения градиентов
    table.insert(AllButtons, {Button = ImageButton, Stroke = Stroke})

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
    local screen = Services.Workspace.CurrentCamera.ViewportSize
    local widthScale = sizeY * (screen.Y / screen.X)
    btn.Size = __UD2(widthScale, 0, sizeY, 0)
end

-- Общий обработчик вращения градиентов (один на все кнопки)
__RS.RenderStepped:Connect(function()
    for _, item in ipairs(AllButtons) do
        if item.Stroke then
            item.Stroke.Rotation = (item.Stroke.Rotation + 1) % 360
        end
    end
end)

-- ===================== НАСТРОЙКИ =====================
local AimLockEnabled = false
local AimTarget = "Murderer"
local AimPart = "Head"
local WallCheck = false
local BindButtonEnabled = false
local TargetPlayerName = nil
local ButtonSize = 0.11

local AimPrediction = 0
local AimSmoothing = 0
local TeamCheckEnabled = false
local FOVLimit = 90

-- Переменные состояния
local CurrentTarget = nil
local AimLockBind = nil
local AimLockButton = nil
local playerListDropdown = nil

-- ===================== КЭШ ИГРОКОВ =====================
local PlayerCache = {}
local CacheMaid = Maid.new()

-- Функция обновления кэша при появлении персонажа
local function SetupPlayerCache(player)
    local cache = PlayerCache[player]
    if not cache then
        cache = {
            Player = player,
            Character = nil,
            Humanoid = nil,
            Root = nil,
            Head = nil,
            Alive = false,
            Knife = false,
            Gun = false,
            Role = nil,
        }
        PlayerCache[player] = cache
    end

    local function onCharacterAdded(char)
        cache.Character = char
        cache.Humanoid = char:WaitForChild("Humanoid")
        cache.Root = char:WaitForChild("HumanoidRootPart")
        cache.Head = char:FindFirstChild("Head")
        cache.Alive = true

        -- Отслеживаем инструменты
        local function onToolAdded(tool)
            local name = tool.Name:lower()
            if name:find("knife") or name:find("нож") then
                cache.Knife = true
                cache.Role = "Murderer"
            elseif name:find("gun") or name:find("пистолет") or name:find("револьвер") or name:find("revolver") or name:find("sheriff") or name:find("шериф") then
                cache.Gun = true
                cache.Role = "Sheriff"
            end
        end

        local function onToolRemoved(tool)
            local name = tool.Name:lower()
            if name:find("knife") or name:find("нож") then
                cache.Knife = false
                cache.Role = nil
            elseif name:find("gun") or name:find("пистолет") or name:find("револьвер") or name:find("revolver") or name:find("sheriff") or name:find("шериф") then
                cache.Gun = false
                cache.Role = nil
            end
            -- Если нет ни ножа, ни пистолета – innocent
            if not cache.Knife and not cache.Gun then
                cache.Role = "Innocent"
            end
        end

        -- Обработчики для Character
        local maid = Maid.new()
        cache._maid = maid

        -- Инструменты в руках
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                onToolAdded(tool)
            end
        end
        maid:GiveTask(char.ChildAdded:Connect(onToolAdded))
        maid:GiveTask(char.ChildRemoved:Connect(onToolRemoved))

        -- Backpack
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            for _, tool in ipairs(backpack:GetChildren()) do
                if tool:IsA("Tool") then
                    onToolAdded(tool)
                end
            end
            maid:GiveTask(backpack.ChildAdded:Connect(onToolAdded))
            maid:GiveTask(backpack.ChildRemoved:Connect(onToolRemoved))
        end

        -- Обновление роли при отсутствии оружия
        if not cache.Knife and not cache.Gun then
            cache.Role = "Innocent"
        end
    end

    local function onCharacterRemoving()
        if cache._maid then
            cache._maid:Destroy()
            cache._maid = nil
        end
        cache.Character = nil
        cache.Humanoid = nil
        cache.Root = nil
        cache.Head = nil
        cache.Alive = false
        cache.Knife = false
        cache.Gun = false
        cache.Role = nil
    end

    if player.Character then
        onCharacterAdded(player.Character)
    end

    -- Подписки
    CacheMaid:GiveTask(player.CharacterAdded:Connect(onCharacterAdded))
    CacheMaid:GiveTask(player.CharacterRemoving:Connect(onCharacterRemoving))
end

-- Инициализация кэша для всех существующих игроков
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        SetupPlayerCache(player)
    end
end

-- Обработка новых игроков
Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        SetupPlayerCache(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if PlayerCache[player] then
        if PlayerCache[player]._maid then
            PlayerCache[player]._maid:Destroy()
        end
        PlayerCache[player] = nil
    end
end)

-- ===================== ФУНКЦИИ ПОИСКА =====================
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
    local ray = Services.Workspace:Raycast(origin, direction.Unit * direction.Magnitude, params)
    if ray then
        return ray.Instance:IsDescendantOf(targetChar)
    end
    return true
end

local function IsSameTeam(cache1, cache2)
    if not cache1 or not cache2 then return false end
    -- Если роли не определены, считаем что не в одной команде (безопаснее)
    if not cache1.Role or not cache2.Role then return false end
    -- Убийца всегда один, остальные (шериф и невинные) в одной команде
    if cache1.Role == "Murderer" or cache2.Role == "Murderer" then
        return false
    end
    return true -- оба не убийцы (шериф/невинный)
end

-- Поиск цели (вызывается реже)
local function FindTarget()
    local bestTarget = nil
    local bestScore = math.huge

    if TargetPlayerName then
        local targetPlayer = Players:FindFirstChild(TargetPlayerName)
        if targetPlayer then
            local cache = PlayerCache[targetPlayer]
            if cache and cache.Alive then
                if TeamCheckEnabled and IsSameTeam(PlayerCache[LocalPlayer], cache) then
                    return nil
                end
                if WallCheck and not IsVisible(cache.Character) then
                    return nil
                end
                return targetPlayer
            end
        end
        return nil
    end

    local myCache = PlayerCache[LocalPlayer]
    local camPos = Camera.CFrame.Position
    local camLook = Camera.CFrame.LookVector

    for player, cache in pairs(PlayerCache) do
        if cache.Alive and cache.Root then
            -- Проверка роли
            local valid = false
            if AimTarget == "Murderer" then
                valid = (cache.Role == "Murderer")
            else
                valid = (cache.Role == "Sheriff" or cache.Role == "Innocent") -- на случай если ищем шерифа
                -- Более точно: если ищем Sheriff, то проверяем наличие пистолета
                if AimTarget == "Sheriff" then
                    valid = cache.Gun and cache.Role == "Sheriff"
                end
            end
            if not valid then goto continue end

            -- Team check
            if TeamCheckEnabled and myCache and IsSameTeam(myCache, cache) then
                goto continue
            end

            -- Wall check (отложим до финальной проверки)
            -- FOV и дистанция
            local targetPos = cache.Root.Position
            local dirToTarget = (targetPos - camPos).Unit
            local angle = math.deg(math.acos(math.clamp(camLook:Dot(dirToTarget), -1, 1)))
            if FOVLimit > 0 and angle > FOVLimit then
                goto continue
            end

            local distSq = (targetPos - camPos).Magnitude^2
            local score = distSq * (1 + angle / 90) -- можно подобрать вес
            if score < bestScore then
                bestScore = score
                bestTarget = player
            end
        end
        ::continue::
    end

    -- Проверка WallCheck для финальной цели
    if bestTarget and WallCheck then
        local cache = PlayerCache[bestTarget]
        if cache and not IsVisible(cache.Character) then
            -- Если не видим, пробуем найти другую цель
            bestTarget = nil
            -- Повторный поиск с игнорированием невидимых (можно оптимизировать, но для простоты оставим)
            for player, cache in pairs(PlayerCache) do
                if cache.Alive and cache.Root then
                    -- ... повторяем логику, но пропускаем WallCheck
                    -- Упростим: если не нашли, вернём nil
                end
            end
            -- Альтернатива: просто вернуть nil
            return nil
        end
    end

    return bestTarget
end

-- ===================== ПРЕДСКАЗАНИЕ =====================
local function GetPredictedPosition(target)
    if not target then return nil end
    local cache = PlayerCache[target]
    if not cache or not cache.Root then return nil end

    local part = (AimPart == "Head") and cache.Head or cache.Root
    if not part then return nil end

    local pos = part.Position
    local vel = part.AssemblyLinearVelocity -- используем встроенную скорость
    return pos + (vel * AimPrediction)
end

-- ===================== ГЛАВНЫЙ ЦИКЛ =====================
-- Поиск цели редко (7 раз в секунду)
local searchTask
local function startSearchLoop()
    if searchTask then return end
    searchTask = task.spawn(function()
        while true do
            if AimLockEnabled and IsInRound() then
                local target = FindTarget()
                CurrentTarget = target
            end
            task.wait(0.15) -- ~7 раз в секунду
        end
    end)
end

-- Обновление камеры каждый кадр (плавно)
RunService.RenderStepped:Connect(function()
    if not AimLockEnabled then return end
    if not IsInRound() then return end

    local target = CurrentTarget
    if target and PlayerCache[target] and PlayerCache[target].Alive then
        local targetPos = nil
        if AimPrediction > 0 then
            targetPos = GetPredictedPosition(target)
        else
            local cache = PlayerCache[target]
            local part = (AimPart == "Head") and cache.Head or cache.Root
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

-- Запуск цикла поиска
startSearchLoop()

-- ===================== UI (меню OverdriveH) =====================
my_section:AddLabel("Credits: @anya_bts (optimized v3.0)")

my_section:AddToggle("Enable Aim Lock", function(bool)
    AimLockEnabled = bool
    if AimLockBind then
        AimLockBind.Value = bool
    end
end)

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

my_section:AddSlider("Button Size", 5, 30, 11, function(value)
    ButtonSize = value / 100
    if AimLockButton then
        BindableButtons.SetSize("MM2_AimLock", ButtonSize)
    end
end)

-- Dropdown: Target Player
local function UpdatePlayerList()
    local playerNames = {"None (Use Role)"}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(playerNames, p.Name)
        end
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

Players.PlayerAdded:Connect(function() task.wait(0.5) UpdatePlayerList() end)
Players.PlayerRemoving:Connect(function() task.wait(0.5) UpdatePlayerList() end)

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

my_section:AddSlider("FOV Limit (градусы)", 0, 180, 90, function(value)
    FOVLimit = value
end)

my_section:AddToggle("Team Check", function(bool)
    TeamCheckEnabled = bool
    shared.Notify("Team Check: " .. (bool and "ON" or "OFF"), 2)
end)

my_section:AddToggle("Wall Check", function(bool)
    WallCheck = bool
end)

my_section:AddKeybind("Toggle Key", "T", function()
    AimLockEnabled = not AimLockEnabled
    if AimLockBind then AimLockBind.Value = AimLockEnabled end
end)

print("[MM2 Aim Lock] Optimized version loaded successfully.")
