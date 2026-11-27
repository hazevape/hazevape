local run = function(func)
    func()
end

local cloneref = cloneref or function(obj)
    return obj
end

local playersService = cloneref(game:GetService("Players"))
local inputService = cloneref(game:GetService("UserInputService"))
local replicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local collectionService = cloneref(game:GetService("CollectionService"))
local httpService = cloneref(game:GetService("HttpService"))
local coreGui = cloneref(game:GetService("CoreGui"))
local tweenService = cloneref(game:GetService("TweenService"))
local runService = cloneref(game:GetService("RunService"))

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer

local haze = shared.haze
local entitylib = haze.Libraries.entity
local targetinfo = haze.Libraries.targetinfo
local sessioninfo = haze.Libraries.sessioninfo
local uipallet = haze.Libraries.uipallet
local tween = haze.Libraries.tween
local color = haze.Libraries.color
local prediction = haze.Libraries.prediction
local getcustomasset = haze.Libraries.getcustomasset

local ItemsRemotes = replicatedStorage
    :WaitForChild("Remotes")
    :WaitForChild("ItemsRemotes")

local BedFight = {
    SwordHit = ItemsRemotes:WaitForChild("SwordHit"),
    Equip = ItemsRemotes:WaitForChild("EquipTool")
}

local hazeEvents = setmetatable({}, {
    __index = function(self, index)
        self[index] = Instance.new("BindableEvent")
        return self[index]
    end
})

local function collection(tags, module, customadd, customremove)
    tags = typeof(tags) ~= "table" and {tags} or tags

    local objs = {}
    local connections = {}

    for _, tag in tags do
        table.insert(connections,
            collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
                if customadd then
                    customadd(objs, v, tag)
                else
                    table.insert(objs, v)
                end
            end)
        )

        table.insert(connections,
            collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
                if customremove then
                    customremove(objs, v, tag)
                    return
                end

                local index = table.find(objs, v)

                if index then
                    table.remove(objs, index)
                end
            end)
        )

        for _, v in collectionService:GetTagged(tag) do
            if customadd then
                customadd(objs, v, tag)
            else
                table.insert(objs, v)
            end
        end
    end

    local cleanFunc = function()
        for _, connection in connections do
            connection:Disconnect()
        end

        table.clear(connections)
        table.clear(objs)
    end

    if module then
        module:Clean(cleanFunc)
    end

    return objs, cleanFunc
end

local function notif(...)
    return haze:CreateNotification(...)
end

local function waitForChildOfType(obj, name, timeout, prop)
    local deadline = os.clock() + timeout

    repeat
        local result = prop and obj[name]
            or obj:FindFirstChildOfClass(name)

        if result then
            return result
        end

        task.wait()
    until os.clock() >= deadline

    return nil
end

local function getHealth(plr, humanoid)
    if plr then
        return plr:GetAttribute("Health") or humanoid.Health
    end

    return humanoid.Health
end

-- Entity library

run(function()
    entitylib.addPlayer = function(plr)
        if plr.Character then
            entitylib.refreshEntity(plr.Character, plr)
        end

        entitylib.PlayerConnections[plr] = {
            plr.CharacterAdded:Connect(function(char)
                entitylib.refreshEntity(char, plr)
            end),

            plr.CharacterRemoving:Connect(function(char)
                entitylib.removeEntity(char, plr == lplr)
            end)
        }
    end

    entitylib.addEntity = function(char, plr, teamfunc)
        if not char then
            return
        end

        entitylib.EntityThreads[char] = task.spawn(function()
            local hum = waitForChildOfType(
                char,
                "Humanoid",
                10
            )

            local root = hum and waitForChildOfType(
                hum,
                "RootPart",
                10,
                true
            )

            if hum and root then
                local entity = {
                    Connections = {},
                    Character = char,
                    Health = getHealth(plr, hum),
                    Head = char:FindFirstChild("Head") or root,
                    Humanoid = hum,
                    HumanoidRootPart = root,
                    HipHeight = hum.HipHeight + root.Size.Y / 2,
                    MaxHealth = hum.MaxHealth,
                    NPC = plr == nil,
                    Player = plr,
                    RootPart = root,
                    TeamCheck = teamfunc
                }

                if plr == lplr then
                    entity.GroundPosition = Vector3.zero
                    entitylib.character = entity
                    entitylib.isAlive = true

                    entitylib.Events.LocalAdded:Fire(entity)
                else
                    entity.Targetable = entitylib.targetCheck(entity)

                    for _, signal in entitylib.getUpdateConnections(entity) do
                        table.insert(
                            entity.Connections,
                            signal:Connect(function()
                                entity.Health = getHealth(plr, hum)
                                entity.MaxHealth = hum.MaxHealth

                                entitylib.Events.EntityUpdated:Fire(entity)
                            end)
                        )
                    end

                    table.insert(entitylib.List, entity)
                    entitylib.Events.EntityAdded:Fire(entity)
                end
            end

            entitylib.EntityThreads[char] = nil
        end)
    end

    entitylib.getUpdateConnections = function(ent)
        local signals = {
            ent.Humanoid.HealthChanged,
            ent.Humanoid:GetPropertyChangedSignal("MaxHealth")
        }

        if ent.Player then
            table.insert(
                signals,
                ent.Player:GetAttributeChangedSignal("Health")
            )
        end

        return signals
    end

entitylib.targetCheck = function(ent)
    if not ent or not ent.Character then
        return false
    end

    return ent.NPC
        and ent.Character.Name == "TestDummy"
        and ent.Health > 0
end

    entitylib.getEntityColor = function(ent)
        local plr = ent.Player

        if plr and plr.Team then
            return plr.TeamColor.Color
        end

        return nil
    end
end)

entitylib.start()

-- Remove unsupported modules

for _, name in {
    "Reach",
    "TriggerBot",
    "Disabler",
    "SilentAim",
    "AutoRejoin",
    "Rejoin",
    "ServerHop",
    "MurderMystery",
    "Killaura"
} do
    haze:Remove(name)
end

-- Studio combat test

run(function()
    local CombatTest
    local AttackRange
    local AttackInterval
    local ShowTarget
    local TargetColor

    local Highlight
    local Generation = 0

    local Container = workspace:WaitForChild("PlayersContainer")

    local SwordPriority = {
        "Emerald Sword",
        "Diamond Sword",
        "Iron Sword",
        "Stone Sword",
        "Wooden Sword"
    }

    local function getBestSword()
        local Inventory = lplr:FindFirstChild("Inventory")

        if not Inventory then
            return nil
        end

        for _, name in SwordPriority do
            if Inventory:FindFirstChild(name) then
                return name
            end
        end

        return nil
    end

    local function getTestTarget()
        local Character = lplr.Character

        local Root = Character
            and Character:FindFirstChild("HumanoidRootPart")

        local Target = Container:FindFirstChild("TestDummy")

        if not Root or not Target then
            return nil
        end

        if playersService:GetPlayerFromCharacter(Target) then
            return nil
        end

        local TargetRoot = Target:FindFirstChild("HumanoidRootPart")
        local Humanoid = Target:FindFirstChildOfClass("Humanoid")

        if not TargetRoot or not Humanoid then
            return nil
        end

        if Humanoid.Health <= 0 then
            return nil
        end

        local Distance = (Root.Position - TargetRoot.Position).Magnitude

        if Distance > AttackRange.Value then
            return nil
        end

        return Target
    end

    local function clearHighlight()
        if Highlight then
            Highlight:Destroy()
            Highlight = nil
        end
    end

    local function updateHighlight(Target)
        if not ShowTarget.Enabled or not Target then
            clearHighlight()
            return
        end

        if not Highlight then
            Highlight = Instance.new("Highlight")
            Highlight.Name = "CombatTestHighlight"
            Highlight.FillTransparency = 0.65
            Highlight.OutlineTransparency = 0
            Highlight.DepthMode = Enum.HighlightDepthMode.Occluded
            Highlight.Parent = workspace
        end

        local SelectedColor = Color3.fromHSV(
            TargetColor.Hue,
            TargetColor.Sat,
            TargetColor.Value
        )

        Highlight.FillColor = SelectedColor
        Highlight.OutlineColor = SelectedColor
        Highlight.Adornee = Target
    end

    CombatTest = haze.Categories.Blatant:CreateModule({
        Name = "CombatTest",

        Tooltip = "Tests combat against a Studio test dummy.",

        Function = function(callback)
            Generation += 1

            local CurrentGeneration = Generation

            if not callback then
                clearHighlight()
                return
            end

            task.spawn(function()
                while CombatTest.Enabled
                    and Generation == CurrentGeneration do

                    local Target = getTestTarget()
                    local Sword = getBestSword()

                    updateHighlight(Target)

                    if Target and Sword then
                        BedFight.Equip:FireServer(Sword)
                        BedFight.SwordHit:FireServer(Target, Sword)

                        print(
                            "[CombatTest]",
                            Target.Name,
                            Sword
                        )
                    end

                    task.wait(AttackInterval.Value)
                end

                if Generation == CurrentGeneration then
                    clearHighlight()
                end
            end)
        end
    })

    AttackRange = CombatTest:CreateSlider({
        Name = "Attack range",
        Min = 1,
        Max = 18,
        Default = 6,

        Suffix = function(value)
            return value == 1 and " stud" or " studs"
        end
    })

    AttackInterval = CombatTest:CreateSlider({
        Name = "Attack interval",
        Min = 0.1,
        Max = 2,
        Default = 0.5,
        Decimal = 100,

        Suffix = function()
            return "s"
        end
    })

    ShowTarget = CombatTest:CreateToggle({
        Name = "Show target",

        Function = function(callback)
            if TargetColor then
                TargetColor.Object.Visible = callback
            end

            if not callback then
                clearHighlight()
            end
        end
    })

    TargetColor = CombatTest:CreateColorSlider({
        Name = "Target color",
        DefaultOpacity = 0.5,
        Darker = true,
        Visible = false
    })
end)
