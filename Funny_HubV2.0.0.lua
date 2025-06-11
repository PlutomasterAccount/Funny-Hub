local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local defaultJumpPower = 50
if LocalPlayer.Character then
    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        defaultJumpPower = humanoid.JumpPower
    end
end
local currentJumpPower = defaultJumpPower

if setclipboard then
    setclipboard("https://discord.gg/79FmBBqvx8")
end

local ESPEnabled = false
local ESPTeams = {}
local ESPSettings = {}

local teamColors = {
    Killers = Color3.fromRGB(255, 0, 0),
    Survivors = Color3.fromRGB(0, 255, 0),
    Spectating = Color3.fromRGB(128, 128, 128),
}

local espBoxes = {}

local function CreateESPBox(color)
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = color
    box.Thickness = 1
    box.Filled = false

    local outline = Drawing.new("Square")
    outline.Visible = false
    outline.Color = Color3.new(0, 0, 0)
    outline.Thickness = 3
    outline.Filled = false

    local label = Drawing.new("Text")
    label.Visible = false
    label.Size = 13
    label.Center = true
    label.Outline = true
    label.Font = 2
    label.Color = color

    return box, outline, label
end

local function RemoveESP(key)
    local e = espBoxes[key]
    if e then
        e.conn:Disconnect()
        e.box:Remove()
        e.outline:Remove()
        e.label:Remove()
        espBoxes[key] = nil
    end
end

local function IsInTable(tbl, val)
    for _, v in pairs(tbl) do
        if v == val then return true end
    end
    return false
end

local function GetPlayerFromCharacter(character)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == character then
            return p
        end
    end
    return nil
end

local function GetTitlePrefix(team)
    if team == "Killers" then
        return "Killer"
    elseif team == "Survivors" then
        return "Survivor"
    elseif team == "Spectating" then
        return "Spectating"
    else
        return "Player"
    end
end

local function GetESPText(player, team, hp, dist, settings)
    local prefix = GetTitlePrefix(team)
    local oneHit = (team == "Survivors" and hp <= 20 and IsInTable(settings, "Show if One Hit"))
    local showHealth = IsInTable(settings, "View Health")
    local showDist = IsInTable(settings, "View Distance")

    if oneHit then
        if showHealth and showDist then
            return ("%s: %s | Health: %d | Distance: %d [ONE HIT] [%s]"):format(prefix, player.Name, hp, dist, prefix)
        elseif showHealth then
            return ("%s: %s | Health: %d [ONE HIT] [%s]"):format(prefix, player.Name, hp, prefix)
        elseif showDist then
            return ("%s: %s | Distance: %d [ONE HIT] [%s]"):format(prefix, player.Name, dist, prefix)
        else
            return ("%s: %s [ONE HIT] [%s]"):format(prefix, player.Name, prefix)
        end
    else
        if showHealth and showDist then
            return ("%s: %s | Health: %d | Distance: %d [%s]"):format(prefix, player.Name, hp, dist, prefix)
        elseif showHealth then
            return ("%s: %s | Health: %d [%s]"):format(prefix, player.Name, hp, prefix)
        elseif showDist then
            return ("%s: %s | Distance: %d [%s]"):format(prefix, player.Name, dist, prefix)
        else
            return ("%s: %s [%s]"):format(prefix, player.Name, prefix)
        end
    end
end

local function TrackCharacter(key, character, team)
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return end

    local box, outline, label = CreateESPBox(teamColors[team] or Color3.new(1,1,1))

    local conn
    conn = RunService.RenderStepped:Connect(function()
        if not character or not character.Parent or not root or not humanoid then
            RemoveESP(key)
            return
        end

        local player = GetPlayerFromCharacter(character)
        if not player then
            RemoveESP(key)
            return
        end

        if not ESPEnabled or not IsInTable(ESPTeams, team) then
            box.Visible = false
            outline.Visible = false
            label.Visible = false
            return
        end

        local pos, onscreen = Camera:WorldToViewportPoint(root.Position)
        if onscreen then
            local localChar = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local dist = localChar and math.floor((localChar.Position - root.Position).Magnitude) or 0
            local hp = math.floor(humanoid.Health)

            local labelText = GetESPText(player, team, hp, dist, ESPSettings)

            local scale = 1 / (pos.Z * math.tan(math.rad(Camera.FieldOfView * 0.5)) * 2) * 1000
            local width, height = math.floor(4.5 * scale), math.floor(6 * scale)
            local x, y = math.floor(pos.X - width / 2), math.floor(pos.Y - height / 2)

            local boxColor = (team == "Survivors" and hp <= 20 and IsInTable(ESPSettings, "Show if One Hit")) and Color3.fromRGB(189, 144, 23) or (teamColors[team] or Color3.new(1,1,1))

            box.Size = Vector2.new(width, height)
            box.Position = Vector2.new(x, y)
            box.Color = boxColor
            box.Visible = true

            outline.Size = box.Size
            outline.Position = box.Position
            outline.Visible = true

            label.Position = Vector2.new(x + width / 2, y - 14)
            label.Text = labelText
            label.Color = boxColor
            label.Visible = true
        else
            box.Visible = false
            outline.Visible = false
            label.Visible = false
        end
    end)

    espBoxes[key] = {
        box = box,
        outline = outline,
        label = label,
        conn = conn
    }
end

local function UpdateESP()
    local currentKeys = {}

    local playersFolder = workspace:FindFirstChild("Players")
    if playersFolder then
        for _, teamFolder in ipairs(playersFolder:GetChildren()) do
            if IsInTable(ESPTeams, teamFolder.Name) then
                for _, character in ipairs(teamFolder:GetChildren()) do
                    local key = teamFolder.Name .. "_" .. tostring(character)
                    currentKeys[key] = true
                    if not espBoxes[key] then
                        TrackCharacter(key, character, teamFolder.Name)
                    end
                end
            end
        end
    end

    for key in pairs(espBoxes) do
        if not currentKeys[key] then
            RemoveESP(key)
        end
    end
end

local function getGameFolderName()
    local placeId = tostring(game.PlaceId)
    local gameId = tostring(game.GameId)
    if placeId == "7009799230" then
        return "Pressure Wash Simulator"
    elseif placeId == "119208928703288" then
        return "Obby But You Lose FPS"
    elseif gameId == "6331902150" and placeId == "18687417158" then
        return "Forsaken"
    else
        return "Unknown Game"
    end
end

local folderName = getGameFolderName()

local Window = Fluent:CreateWindow({
    Title = "Funny Hub V2",
    SubTitle = "By Funny Hub Devs | Plutomaster & Cipher",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})
local Tabs = {
    OBYLF = nil,
    Washing = nil,
    LocalPlayer = nil,
    Visuals = nil,
    Farming = nil,
    World = nil,
    Settings = nil,
    Supported = nil,
    DiscordServer = nil
}

local AutoWinLoop
local VelocityLoop
local AutoWinActive = false
local StageSlider

local function startVelocityLoop()
    if VelocityLoop then VelocityLoop:Disconnect() end
    VelocityLoop = RunService.Heartbeat:Connect(function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.Velocity = Vector3.new(0,0,0)
            LocalPlayer.Character.HumanoidRootPart.RotVelocity = Vector3.new(0,0,0)
        end
    end)
end

local function stopVelocityLoop()
    if VelocityLoop then
        VelocityLoop:Disconnect()
        VelocityLoop = nil
    end
end

-- Obby But You Lose FPS
if tostring(game.PlaceId) == "119208928703288" then
    local setTargetFPS = ReplicatedStorage:FindFirstChild("shared/network@GlobalEvents") and ReplicatedStorage["shared/network@GlobalEvents"]:FindFirstChild("setTargetFPS")
    Tabs.OBYLF = Window:AddTab({ Title = "Obby But You Lose FPS", Icon = "gamepad" })

    Tabs.OBYLF:AddToggle("AntiFpsLossToggle", {
        Title = "Anti FPS Loss",
        Description = "Forces 120 FPS constantly to prevent FPS drop",
        Default = false
    }):OnChanged(function(state)
        if state then
            AutoWinActive = false
            if setTargetFPS then
                AutoWinLoop = RunService.RenderStepped:Connect(function()
                    firesignal(setTargetFPS.OnClientEvent, 120)
                end)
            end
        else
            if AutoWinLoop then AutoWinLoop:Disconnect() AutoWinLoop = nil end
        end
    end)

    local rebirthed = false
    local connStage, connChar

    local function tryRebirth()
        local angel = workspace:FindFirstChild("Map")
            and workspace.Map:FindFirstChild("Finish2")
            and workspace.Map.Finish2:FindFirstChild("RebirthAngel")
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if angel and hrp then
            hrp.CFrame = angel.CFrame + Vector3.new(0, 3, 0)
            task.wait(0.15)
            ReplicatedStorage["shared/network@GlobalFunctions"].tryRebirth:FireServer(0)
            rebirthed = true
        end
    end

    local function onStageChanged()
        local stage = LocalPlayer:FindFirstChild("leaderstats")
            and LocalPlayer.leaderstats:FindFirstChild("Stage")
        if not stage then return end
        local v = stage.Value
        if v >= 120 and not rebirthed then
            tryRebirth()
        elseif v < 10 then
            rebirthed = false
        end
    end

    local AutoWinToggle = Tabs.OBYLF:AddToggle("AutoWinToggle", {
        Title = "Auto Win",
        Description = "Auto Teleports you on the Checkpoints",
        Default = false
    })

    AutoWinToggle:OnChanged(function(state)
        AutoWinActive = state
        if state then
            AutoWinLoop = RunService.Heartbeat:Connect(function()
                local checkpoints = workspace:FindFirstChild("Checkpoints")
                local stageStat = LocalPlayer:FindFirstChild("leaderstats") and LocalPlayer.leaderstats:FindFirstChild("Stage")
                if not checkpoints or not stageStat then return end
                local stage = tonumber(stageStat.Value)
                local nextStage = tostring(stage + 1)
                local nextCheckpoint = checkpoints:FindFirstChild(nextStage)
                if nextCheckpoint and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    LocalPlayer.Character.HumanoidRootPart.CFrame = nextCheckpoint.CFrame + Vector3.new(0, 1.5, 0)
                end
            end)
            startVelocityLoop()
            if StageSlider then
                StageSlider:SetDisabled(true)
            end
        else
            if AutoWinLoop then AutoWinLoop:Disconnect() AutoWinLoop = nil end
            stopVelocityLoop()
            if StageSlider then
                StageSlider:SetDisabled(false)
            end
        end
    end)

    Tabs.OBYLF:AddToggle("AutoRebirthToggle", {
        Title = "Auto Rebirth",
        Description = "Rebirths at Stage 120, auto resets",
        Default = false
    }):OnChanged(function(on)
        if on then
            local stats = LocalPlayer:WaitForChild("leaderstats")
            local stage = stats:WaitForChild("Stage")
            connStage = stage:GetPropertyChangedSignal("Value"):Connect(onStageChanged)
            connChar  = LocalPlayer.CharacterAdded:Connect(function() rebirthed = false end)
            onStageChanged()
        else
            if connStage then connStage:Disconnect() connStage = nil end
            if connChar  then connChar:Disconnect()  connChar  = nil end
        end
    end)

    Tabs.OBYLF:AddButton({
        Title = "Next Stage",
        Description = "Teleports you to the next checkpoint once",
        Callback = function()
            local checkpoints = workspace:FindFirstChild("Checkpoints")
            local stageStat = LocalPlayer:FindFirstChild("leaderstats") and LocalPlayer.leaderstats:FindFirstChild("Stage")
            if not checkpoints or not stageStat then return end
            local stage = tonumber(stageStat.Value)
            local nextStage = tostring(stage + 1)
            local nextCheckpoint = checkpoints:FindFirstChild(nextStage)
            if nextCheckpoint and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = nextCheckpoint.CFrame + Vector3.new(0, 1.5, 0)
            end
        end
    })

    StageSlider = Tabs.OBYLF:AddSlider("StageSlider", {
        Title = "Stage Teleport",
        Description = "Slide to teleport and unlock stages up to the selected one (0-120)",
        Min = 0,
        Max = 120,
        Default = 0,
        Rounding = 1
    })

    local function updateSliderToCurrentStage()
        local stageStat = LocalPlayer:FindFirstChild("leaderstats") and LocalPlayer.leaderstats:FindFirstChild("Stage")
        if not stageStat then return end
        local currentStage = tonumber(stageStat.Value)
        if StageSlider and not AutoWinActive then
            StageSlider:SetValue(currentStage)
        end
    end

    StageSlider:OnChanged(function(value)
        if AutoWinActive then return end
        local checkpoints = workspace:FindFirstChild("Checkpoints")
        local stageStat = LocalPlayer:FindFirstChild("leaderstats") and LocalPlayer.leaderstats:FindFirstChild("Stage")
        if not checkpoints or not stageStat then return end

        local targetStage = math.clamp(math.floor(value), 0, 120)
        local currentStage = tonumber(stageStat.Value)
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        if targetStage > currentStage then
            for i = currentStage + 1, targetStage do
                local checkpoint = checkpoints:FindFirstChild(tostring(i))
                if checkpoint then
                    hrp.CFrame = checkpoint.CFrame + Vector3.new(0, 1.5, 0)
                    task.wait(0.15)
                end
            end
        else
            local checkpoint = checkpoints:FindFirstChild(tostring(targetStage))
            if checkpoint then
                hrp.CFrame = checkpoint.CFrame + Vector3.new(0, 1.5, 0)
            end
        end
    end)

    local connStageValueChange
    local stats = LocalPlayer:WaitForChild("leaderstats")
    local stage = stats:WaitForChild("Stage")
    connStageValueChange = stage:GetPropertyChangedSignal("Value"):Connect(updateSliderToCurrentStage)

    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        updateSliderToCurrentStage()
    end

    LocalPlayer.CharacterAdded:Connect(function()
        rebirthed = false
        task.wait(1)
        updateSliderToCurrentStage()
    end)
end

-- Pressure Wash Simulator
if tostring(game.PlaceId) == "7009799230" then
    Tabs.Washing = Window:AddTab({ Title = "Pressure Wash Simulator", Icon = "droplet" })

    Tabs.Washing:AddButton({
        Title = "Infinite Cash",
        Description = "Gives you infinite Cash (Clean Dirt or Rejoin To Collect)",
        Callback = function()
            ReplicatedStorage.Remotes.SurfaceCompleted:FireServer(math.huge, math.huge)
        end
    })

    Tabs.Washing:AddButton({
        Title = "Infinite Dirt",
        Description = "Gives infinite dirt instantly",
        Callback = function()
            ReplicatedStorage.Remotes.ClientFrameData:FireServer(math.huge, true, true, math.huge)
        end
    })

    local TankConnection
    Tabs.Washing:AddToggle("AutoFillTank", {
        Title = "Auto Fill Tank",
        Description = "Auto Refills the Tank",
        Default = false
    }):OnChanged(function(state)
        if state then
            if TankConnection then TankConnection:Disconnect() end
            TankConnection = RunService.Heartbeat:Connect(function()
                ReplicatedStorage.Remotes.RefillRemote:FireServer(true)
            end)
        else
            if TankConnection then TankConnection:Disconnect() TankConnection = nil end
            ReplicatedStorage.Remotes.RefillRemote:FireServer(false)
        end
    end)

    local CleaningConnection
    Tabs.Washing:AddToggle("AutoCleanToggle", {
        Title = "Auto Clean",
        Description = "Auto Cleans the Area for you really fast",
        Default = false
    }):OnChanged(function(state)
        if state then
            if CleaningConnection then CleaningConnection:Disconnect() end
            CleaningConnection = RunService.Heartbeat:Connect(function()
                for _ = 1, 10 do
                    ReplicatedStorage.Remotes.SurfaceCompleted:FireServer(1e50, math.random(1, 100))
                end
            end)
        else
            if CleaningConnection then CleaningConnection:Disconnect() CleaningConnection = nil end
        end
    end)
end

if folderName == "Forsaken" then
    Tabs.LocalPlayer    = Window:AddTab({ Title = "LocalPlayer",   Icon = "user" })
    Tabs.Visuals        = Window:AddTab({ Title = "Visuals",       Icon = "monitor" })
    Tabs.Farming        = Window:AddTab({ Title = "Farming",       Icon = "dollar-sign" })
    Tabs.World          = Window:AddTab({ Title = "World",         Icon = "align-horizontal-justify-center" })
end

Tabs.Settings          = Window:AddTab({ Title = "Settings",       Icon = "settings" })
Tabs.DiscordServer     = Window:AddTab({ Title = "Discord Server", Icon = "discord" })

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("FluentScriptHub/Funny Hub V2/" .. folderName)
SaveManager:SetFolder("FluentScriptHub/Funny Hub V2/" .. folderName)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Tabs.DiscordServer:AddButton({
    Title = "Discord Server",
    Description = "Copy's the discord server.",
    Callback = function()
        if setclipboard then
            setclipboard("https://discord.gg/79FmBBqvx8")
        end
    end,
    Tooltip = ""
})

if Tabs.Settings.AddLabel then
    Tabs.Settings:AddLabel("Settings tab initialized.")
end

Fluent:Notify({
    Title = "Funny Hub V2",
    Content = "Script loaded.\n\nSupported Games:\n- Pressure Wash Simulator\n- Obby But You Lose FPS\n- Forsaken",
    Duration = 600
})

SaveManager:LoadAutoloadConfig()

if folderName == "Forsaken" then
    local ESPToggle = Tabs.Visuals:AddToggle("ESPEnabled", {
        Title = "Enable ESP",
        Default = false
    })

    local TeamDropdown = Tabs.Visuals:AddDropdown("ESPTeams", {
        Title = "ESP Teams",
        Values = {"Killers", "Survivors", "Spectating"},
        Multi = true,
        Default = {}
    })

    local SettingsDropdown = Tabs.Visuals:AddDropdown("ESPSettings", {
        Title = "ESP Settings",
        Values = {"View Health", "View Distance", "Show if One Hit"},
        Multi = true,
        Default = {}
    })

    ESPToggle:OnChanged(function(val)
        ESPEnabled = val
        if not ESPEnabled then
            for k in pairs(espBoxes) do
                RemoveESP(k)
            end
        end
    end)

    TeamDropdown:OnChanged(function(vals)
        ESPTeams = {}
        for team, enabled in pairs(vals) do
            if enabled then
                table.insert(ESPTeams, team)
            end
        end
        
        for key, esp in pairs(espBoxes) do
            local team = key:match("^(%a+)_")
            if team and not IsInTable(ESPTeams, team) then
                RemoveESP(key)
            end
        end
    end)

    SettingsDropdown:OnChanged(function(vals)
        ESPSettings = {}
        for setting, enabled in pairs(vals) do
            if enabled then
                table.insert(ESPSettings, setting)
            end
        end
    end)
end

local Sprinting = ReplicatedStorage:WaitForChild("Systems"):WaitForChild("Character"):WaitForChild("Game"):WaitForChild("Sprinting")
local stamina = require(Sprinting)

local RemoteEvent = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("RemoteEvent")

local originalValues = {
    MaxStamina = stamina.MaxStamina,
    MinStamina = stamina.MinStamina,
    StaminaGain = stamina.StaminaGain,
    StaminaLoss = stamina.StaminaLoss,
    SprintSpeed = stamina.SprintSpeed,
    StaminaLossDisabled = stamina.StaminaLossDisabled,
}

local sprintSpeed = originalValues.SprintSpeed
local infiniteStamina = false

if Tabs.LocalPlayer then
    local InfiniteStaminaToggle = Tabs.LocalPlayer:AddToggle("InfiniteStaminaToggle", {
        Title = "Infinite Stamina",
        Description = ""
    })
    InfiniteStaminaToggle:OnChanged(function(state)
        infiniteStamina = state
    end)

    local SpamFootstepsToggle = Tabs.LocalPlayer:AddToggle("SpamFootstepsToggle", {
        Title = "Spam Footsteps",
        Description = ""
    })

    Tabs.LocalPlayer:AddSlider("SprintSpeedSlider", {
        Title = "Sprint Speed",
        Description = "Sets Ur Sprinting Speed",
        Min = 26,
        Max = 37,
        Default = originalValues.SprintSpeed,
        Rounding = 1
    }):OnChanged(function(value)
        sprintSpeed = value
    end)

    local JumpPowerSlider = Tabs.LocalPlayer:AddSlider("JumpPowerSlider", {
        Title = "Jump Power",
        Description = "Sets Ur JumpPower (Only Works Ingame)",
        Min = 0,
        Max = 100,
        Default = 0,
        Rounding = 0
    })

    JumpPowerSlider:OnChanged(function(value)
        currentJumpPower = value
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.JumpPower = value
            end
        end
    end)

    Tabs.LocalPlayer:AddButton({
        Title = "Get 2 Badges",
        Description = "Gives you 2 badges",
        Callback = function()
            RemoteEvent:FireServer("UnlockAchievement", "ILoveCats")
            RemoteEvent:FireServer("UnlockAchievement", "MeetBrandon")
        end
    })
end

if Tabs.Farming then
    Tabs.Farming:AddButton({
        Title = "Auto Complete Generator",
        Description = "Auto Completes Generator Closest to you When you're inside of the UI (Only press once or you'll get kicked)",
        Callback = function()
            local plr = game.Players.LocalPlayer
            local uis = game:GetService("UserInputService")
            local proximityPromptService = game:GetService("ProximityPromptService")
            local gens = workspace.Map.Ingame.Map

            local stop = false

            uis.InputBegan:Connect(function(input, gameProcessed)
                if gameProcessed then return end
                if input.KeyCode == Enum.KeyCode.W or
                   input.KeyCode == Enum.KeyCode.A or
                   input.KeyCode == Enum.KeyCode.S or
                   input.KeyCode == Enum.KeyCode.D or
                   input.KeyCode == Enum.KeyCode.Space then
                    stop = true
                end
            end)

            local function findPrompt(instance)
                if instance:IsA("ProximityPrompt") then
                    return instance
                end
                for _, child in ipairs(instance:GetDescendants()) do
                    if child:IsA("ProximityPrompt") then
                        return child
                    end
                end
                return nil
            end

            local function findClosestGenerator()
                local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then return nil end

                local closestGen = nil
                local minDistance = math.huge

                for _, gen in ipairs(gens:GetChildren()) do
                    if gen.Name == "Generator" and gen.Progress.Value < 100 then
                        local mainPart = gen:FindFirstChild("Main")
                        if mainPart then
                            local distance = (hrp.Position - mainPart.Position).Magnitude
                            if distance < minDistance then
                                minDistance = distance
                                closestGen = gen
                            end
                        end
                    end
                end

                return closestGen
            end

            local function fixGen(gen)
                if not gen or gen.Progress.Value >= 100 then return false end

                local prompt = findPrompt(gen) or (gen.Main and gen.Main:FindFirstChild("Prompt"))
                if not prompt then return false end

                prompt.HoldDuration = 0
                prompt.RequiresLineOfSight = false
                prompt.MaxActivationDistance = 99999

                local remote = gen:FindFirstChild("Remotes") and gen.Remotes:FindFirstChild("RE")
                if not remote then return false end

                local function tryTriggerPrompt()
                    pcall(function()
                        prompt:InputHoldBegin()
                        task.wait()
                        prompt:InputHoldEnd()
                    end)
                    pcall(function()
                        prompt:Trigger()
                    end)
                    pcall(function()
                        proximityPromptService:PromptTriggered(prompt, plr)
                    end)
                end

                while gen.Progress.Value < 100 and not stop do
                    tryTriggerPrompt()
                    pcall(function()
                        remote:FireServer()
                    end)
                    task.wait(1.5)
                end

                return gen.Progress.Value >= 100
            end

            local closestGen = findClosestGenerator()
            if closestGen then
                fixGen(closestGen)
            end
        end
    })

    Tabs.Farming:AddButton({
        Title = "Teleport to a random generator",
        Description = "Teleports you to a random generator in the map",
        Callback = function()
            local player = game.Players.LocalPlayer
            local character = player.Character or player.CharacterAdded:Wait()
            local rootPart = character:WaitForChild("HumanoidRootPart")

            local generatorsFolder = workspace:WaitForChild("Map"):WaitForChild("Ingame"):WaitForChild("Map")
            local generators = {}

            if not _G.LastGenerator then
                _G.LastGenerator = nil
            end

            for _, obj in pairs(generatorsFolder:GetChildren()) do
                if obj.Name:match("Generator") and obj:IsA("Model") then
                    table.insert(generators, obj)
                end
            end

            local function isPositionClear(position)
                local region = Region3.new(position - Vector3.new(1, 3, 1), position + Vector3.new(1, 3, 1))
                local partsInRegion = workspace:FindPartsInRegion3WithIgnoreList(region, {character}, 10)
                for _, part in pairs(partsInRegion) do
                    if part.CanCollide then
                        return false
                    end
                end
                return true
            end

            local filteredGenerators = {}
            for _, gen in ipairs(generators) do
                if gen ~= _G.LastGenerator then
                    table.insert(filteredGenerators, gen)
                end
            end

            if #filteredGenerators == 0 then
                filteredGenerators = generators
            end

            if #filteredGenerators > 0 then
                local targetGenerator = filteredGenerators[math.random(1, #filteredGenerators)]
                local part = targetGenerator.PrimaryPart or targetGenerator:FindFirstChild("HumanoidRootPart") or targetGenerator:FindFirstChildWhichIsA("BasePart")
                if part then
                    local positions = {
                        part.Position + part.CFrame.LookVector * 5 + Vector3.new(0, 3, 0),
                        part.Position - part.CFrame.LookVector * 5 + Vector3.new(0, 3, 0),
                        part.Position + part.CFrame.RightVector * 5 + Vector3.new(0, 3, 0),
                        part.Position - part.CFrame.RightVector * 5 + Vector3.new(0, 3, 0)
                    }
                    local finalPos = nil
                    for _, pos in ipairs(positions) do
                        if isPositionClear(pos) then
                            finalPos = pos
                            break
                        end
                    end
                    if not finalPos then
                        finalPos = part.Position + Vector3.new(0, 5, 0)
                    end
                    rootPart.CFrame = CFrame.new(finalPos, part.Position)
                    _G.LastGenerator = targetGenerator
                end
            end
        end
    })
end

local function applyInfiniteStamina()
    stamina.MaxStamina = 100
    stamina.MinStamina = -20
    stamina.StaminaGain = 100
    stamina.StaminaLoss = 5
    stamina.StaminaLossDisabled = true
end

local function setupTeamChangeMonitor()
    local playersFolder = workspace:WaitForChild("Players")
    for _, folder in ipairs(playersFolder:GetChildren()) do
        folder.ChildAdded:Connect(function(child)
            if child:IsA("Model") and child.Name == LocalPlayer.Name then
                if Tabs.LocalPlayer and Tabs.LocalPlayer.InfiniteStaminaToggle and Tabs.LocalPlayer.InfiniteStaminaToggle.Value then
                    applyInfiniteStamina()
                end
            end
        end)
    end
end
setupTeamChangeMonitor()

RunService.RenderStepped:Connect(function()
    if infiniteStamina then
        applyInfiniteStamina()
    else
        stamina.MaxStamina = originalValues.MaxStamina
        stamina.MinStamina = originalValues.MinStamina
        stamina.StaminaGain = originalValues.StaminaGain
        stamina.StaminaLoss = originalValues.StaminaLoss
        stamina.StaminaLossDisabled = originalValues.StaminaLossDisabled
    end

    stamina.SprintSpeed = sprintSpeed

    if Tabs.LocalPlayer and Tabs.LocalPlayer.SpamFootstepsToggle and Tabs.LocalPlayer.SpamFootstepsToggle.Value then
        for _ = 1, 5 do
            ReplicatedStorage.Modules.Network.UnreliableRemoteEvent:FireServer("FootstepPlayed", 1)
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function(character)
    local humanoid = character:WaitForChild("Humanoid")
    humanoid.JumpPower = currentJumpPower
end)

if LocalPlayer.Character then
    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.JumpPower = currentJumpPower
    end
end

Tabs.Supported = Window:AddTab({ Title = "Supported Games", Icon = "list" })

Tabs.Supported:AddButton({
    Title = "Pressure Wash Simulator",
    Description = "Click to teleport",
    Callback = function()
        TeleportService:Teleport(7009799230)
    end
})

Tabs.Supported:AddButton({
    Title = "Obby But You Lose FPS",
    Description = "Click to teleport",
    Callback = function()
        TeleportService:Teleport(119208928703288)
    end
})

Tabs.Supported:AddButton({
    Title = "Forsaken",
    Description = "Click to Teleport",
    Callback = function()
        TeleportService:Teleport(18687417158)
    end
})

if folderName == "Forsaken" then
    task.spawn(function()
        while true do
            if ESPEnabled then
                UpdateESP()
            else
                for k in pairs(espBoxes) do
                    RemoveESP(k)
                end
            end
            task.wait(0.1)
        end
    end)
end
