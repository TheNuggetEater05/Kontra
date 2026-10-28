run_on_actor(getactors()[1], [[
    -- Services
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local UserInputService = game:GetService("UserInputService")
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")

    local CurrentCamera = workspace.CurrentCamera
    local LocalPlayer = Players.LocalPlayer

    -- Libraries
    local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"))()
    local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/addons/SaveManager.lua"))()
    local Toggles = UI.Toggles
    local Options = UI.Options
    local UILoaded = false

    SaveManager:SetLibrary(UI)
    SaveManager:SetFolder("KontraPoop")

    -- Modules
    local Entities = require(ReplicatedStorage.GameClient:WaitForChild("Entities"))
    local SkinManager = require(ReplicatedStorage.Shared.Managers.SkinManager)
    local WeaponConstructor = require(ReplicatedStorage.Shared.WeaponConstructor)

    local OriginalFuncs = {
        EntitiesFire = Entities.OnEntityCreated.Fire,
        WeaponConstructorNew = WeaponConstructor.new,
        WeaponConstructorRecoil = WeaponConstructor.Recoil,
        RecoilGet = getupvalue(WeaponConstructor.Recoil, 2).Get
    }

    local Hooks = {
        EntitiesFire = nil,
        WeaponConstructorNew = nil,
        WeaponConstructorRecoil = nil,
        RecoilGet = nil
    }

    local Connections = {}

    local EntityList = {
        Character = {},
        DroppedWeapon = {},
        Bomb = {},
        Grenade = {}
    }

    local Skins = {}

    local KSkins = {} do
        function KSkins.Populate(self)
            for _, klass in pairs(ReplicatedStorage.Shared.Managers.SkinManager:GetChildren()) do
                Skins[klass.Name] = {}
                for _, weapon in pairs(klass:GetChildren()) do
                    Skins[klass.Name][weapon.Name] = {}
                    local skins = require(weapon)

                    for name, skin in pairs(skins) do
                        table.insert(Skins[klass.Name][weapon.Name], name)
                    end
                end
            end
        end

        function KSkins:IsKnife(weapon: string)
            local Knives = {"CT Knife", "T Knife", "Balisong", "Bat", "Classic Roblox Sword", "Cleaver", "Jagdkommando", "Karambit", "Kukri", "Shadow Daggers"}

            return table.find(Knives, weapon) ~= nil
        end
    end

    local KPlayers = {} do
        function KPlayers:GetTeam(player: any)
            if not player or typeof(player) ~= "table" then return end
            if not player.Data then return end

            return tostring(player.Data["Team"])
        end

        function KPlayers:GetLocalTeam()
            return tostring(LocalPlayer:GetAttribute("Team"))
        end

        function KPlayers:GetName(player: any)
            if not player then return end
            return Players:GetNameFromUserIdAsync(player.UserId)
        end

        function KPlayers:GetUserId(player: any)
            if not player then return end
            return player.UserId
        end

        function KPlayers:CheckSameTeam(player: any)
            if not player then return end

            return KPlayers:GetLocalTeam() == KPlayers:GetTeam(player)
        end
    end

    local PlayersESP = {}

    local Visuals = {} do
        function Visuals:MakeESP(player: any)
            if PlayersESP[tostring(player.Identifier)] then
                Visuals:RemoveESP(player)
            end

            PlayersESP[tostring(player.Identifier)] = {}
            local Entry = PlayersESP[tostring(player.Identifier)]

            Entry.Drawings = {}
            Entry.Instances = {}
            Entry.Connection = nil
            Entry.Character = player.Model
            Entry.Clone = Instance.new("Model", workspace)
            Entry.Clone.Name = "Clone"
            Entry.PartMap = {}

            if Entry.Character and player.Model.Parent then
                local HL = Instance.new("Highlight")
                HL.Adornee = Entry.Character
                HL.OutlineTransparency = 1
                HL.FillTransparency = 0.2
                HL.Parent = Entry.Character
                HL.DepthMode = Enum.HighlightDepthMode.Occluded

                local HLOcc = Instance.new("Highlight")
                HLOcc.Adornee = Entry.Clone
                HLOcc.OutlineTransparency = 1
                HLOcc.FillTransparency = 0.2
                HLOcc.Parent = Entry.Clone
                HLOcc.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

                for _, descendant in pairs(Entry.Character:GetChildren()) do
                    if not descendant:IsA("BasePart") then continue end

                    local ClonePart = descendant:Clone()
                    ClonePart:ClearAllChildren()
                    ClonePart.Size *= 0.99
                    ClonePart.Parent = Entry.Clone
                    ClonePart.Anchored = true
                    ClonePart.CanCollide = false
                    ClonePart.CanTouch = false
                    ClonePart.CanQuery = false
                    ClonePart.Massless = true
                    
                    if ClonePart:IsA("MeshPart") then
                        ClonePart.TextureID = ""
                    end

                    Entry.PartMap[descendant] = ClonePart
                end

                Entry.Instances.HLVis = HL
                Entry.Instances.HLOcc = HLOcc

                local Box = Drawing.new("Square")
                local BoxOL = Drawing.new("Square")

                BoxOL.Color = Color3.new(0, 0, 0)
                BoxOL.Thickness = 3
                BoxOL.ZIndex = Box.ZIndex - 1

                local Name = Drawing.new("Text")
                Name.Text = KPlayers:GetName(player)
                Name.Center = true
                Name.Outline = true

                Entry.Drawings.Box = Box
                Entry.Drawings.BoxOL = BoxOL
                Entry.Drawings.Name = Name
            end

            Entry.Connection = RunService.RenderStepped:Connect(function()
                if not UILoaded then return end

                for original, cloned in pairs(Entry.PartMap) do
                    if original.Parent and cloned.Parent then
                        cloned.CFrame = original.CFrame
                    end
                end

                local VisHL = Entry.Instances.HLVis
                local OccHL = Entry.Instances.HLOcc

                local Box = Entry.Drawings.Box
                local BoxOL = Entry.Drawings.BoxOL
                local Name = Entry.Drawings.Name

                local GlobalEnabled = Toggles.global_players_esp.Value
                local ChamsEnabled = false
                local BoxEnabled = false
                local NameEnabled = false

                local Top, OnScreen = CurrentCamera:WorldToViewportPoint(player.Model.Head.CFrame.Position + Vector3.new(0, (player.Model.Head.Size.Y / 2), 0))
                local Bottom, OnScreen = CurrentCamera:WorldToViewportPoint(player.Model.LeftFoot.CFrame.Position - Vector3.new(0, (player.Model.LeftFoot.Size.Y / 2), 0))
                local Left, OnScreen = CurrentCamera:WorldToViewportPoint(player.Model.LeftUpperArm.CFrame.Position - Vector3.new((player.Model.LeftUpperArm.Size.X / 2), 0, 0))
                local Right, OnScreen = CurrentCamera:WorldToViewportPoint(player.Model.RightUpperArm.CFrame.Position - Vector3.new((player.Model.RightUpperArm.Size.X / 2), 0, 0))

                Top = Vector2.new(Top.X, Top.Y)
                Bottom = Vector2.new(Bottom.X, Bottom.Y)
                Left = Vector2.new(Left.X, Left.Y)
                Right = Vector2.new(Right.X, Right.Y)

                if OnScreen then
                    if KPlayers:CheckSameTeam(player) then
                        ChamsEnabled = Toggles.friendly_enabled.Value and Toggles.friendly_chams.Value
                        BoxEnabled = Toggles.friendly_enabled.Value and Toggles.friendly_box.Value
                        NameEnabled = Toggles.friendly_enabled.Value and Toggles.friendly_name.Value

                        VisHL.FillColor = Options.friendly_chams_vis.Value
                        VisHL.FillTransparency = Options.friendly_chams_vis.Transparency
                        OccHL.FillColor = Options.friendly_chams_occ.Value
                        OccHL.FillTransparency = Options.friendly_chams_occ.Transparency

                        Box.Color = Options.friendly_box_color.Value

                        Name.Color = Options.friendly_name_color.Value
                    else
                        ChamsEnabled = Toggles.enemy_enabled.Value and Toggles.enemy_chams.Value
                        BoxEnabled = Toggles.enemy_enabled.Value and Toggles.enemy_box.Value
                        NameEnabled = Toggles.enemy_enabled.Value and Toggles.enemy_name.Value

                        VisHL.FillColor = Options.enemy_chams_vis.Value
                        VisHL.FillTransparency = Options.enemy_chams_vis.Transparency
                        OccHL.FillColor = Options.enemy_chams_occ.Value
                        OccHL.FillTransparency = Options.enemy_chams_occ.Transparency

                        Box.Color = Options.enemy_box_color.Value

                        Name.Color = Options.enemy_name_color.Value
                    end

                    
                    Box.Size = Vector2.new(Box.Size.Y * 0.65, Bottom.Y - Top.Y + 8)
                    Box.Position = Vector2.new(Top.X - (Box.Size.X / 2), Top.Y - 8)

                    BoxOL.Position = Box.Position
                    BoxOL.Size = Box.Size

                    Name.Position = Box.Position + Vector2.new(Box.Size.X / 2, -Name.TextBounds.Y)
                end

                VisHL.Enabled = GlobalEnabled and ChamsEnabled
                OccHL.Enabled = GlobalEnabled and ChamsEnabled
                Box.Visible = GlobalEnabled and BoxEnabled
                BoxOL.Visible = GlobalEnabled and BoxEnabled
                Name.Visible = GlobalEnabled and NameEnabled
            end)
        end

        function Visuals:RemoveESP(player: any)
            local Entry = PlayersESP[tostring(player.Identifier)]
            if not Entry then return end

            if Entry.Connection then
                Entry.Connection:Disconnect()
            end

            for _, drawing in pairs(Entry.Drawings) do
                drawing:Destroy()
            end

            for _, instance in pairs(Entry.Instances) do
                instance:Destroy()
            end

            if Entry.Clone then
                Entry.Clone:Destroy()
                Entry.Clone = nil
                Entry.PartMap = {}
            end

            PlayersESP[tostring(player.Identifier)] = nil
        end
    end

    for _, player in pairs(Entities.GetAllCategoryEntities("Character")) do
        if typeof(player) ~= "table" then continue end

        EntityList.Character[player.Identifier] = player

        Visuals:MakeESP(player)
    end

    -- Signals
    Hooks.EntitiesFire = hookfunction(Entities.OnEntityCreated.Fire, function(self, entityType, identifier, result)
        if entityType == "Character" or entityType == "DroppedWeapon" or entityType == "Bomb" or entityType == "Grenade" then
            if self == Entities.OnEntityCreated then
                EntityList[entityType][identifier] = result

                -- setup ESP
                if entityType == "Character" then
                    Visuals:MakeESP(result)
                end
            elseif self == Entities.OnEntityDestroyed then
                EntityList[entityType][identifier] = nil

                -- remove ESP
                if entityType == "Character" then
                    Visuals:RemoveESP(result)
                end
            end
        end

        return Hooks.EntitiesFire(self, entityType, identifier, result)
    end)

    Hooks.WeaponConstructorNew = hookfunction(WeaponConstructor.new, function(...)
        local Args = {...}

        local Weapon = Args[1]

        if Toggles.skinchanger_enabled.Value then
            if KSkins:IsKnife(Weapon) then
                Weapon = Options.knife_model.Value
                Args[1] = Weapon
            end

            Args[4] = Options[`{Weapon}_skin`].Value
            Args[5] = "111-111-111-111"

            return Hooks.WeaponConstructorNew(table.unpack(Args))
        end
        
        return Hooks.WeaponConstructorNew(...)
    end)

    KSkins:Populate()

    local Window = UI:CreateWindow({
        Title = "KontraDick",
        Footer = "by Jaydenn"
    })

    local Tabs = {}
    Tabs.Visuals = Window:AddTab("Visual", "eye")
    do
        local PlayerGB = Tabs.Visuals:AddGroupbox({
            Name = "Players"
        })
        do
            local TeamsTB = PlayerGB:AddTabbox({})
            do
                local EnemyTab = TeamsTB:AddTab("Enemy")
                do
                    EnemyTab:AddToggle("enemy_enabled", {
                        Text = "Enabled"
                    })

                    local EnemySettings = EnemyTab:AddDependencyBox()

                    local ChamsToggle = EnemySettings:AddCheckbox("enemy_chams", {
                        Text = "Chams"
                    })

                    ChamsToggle:AddColorPicker("enemy_chams_vis", {
                        Title = "Visible",
                        Default = Color3.new(1, 0, 0),
                        Trasparency = 0,
                    })

                    ChamsToggle:AddColorPicker("enemy_chams_occ", {
                        Default = Color3.new(0, 1, 0),
                        Title = "Occluded",
                        Transparency = 0,
                    })

                    EnemySettings:AddCheckbox("enemy_box", {
                        Text = "Box"
                    }):AddColorPicker("enemy_box_color", {
                        Title = "Color",
                        Default = Color3.new(1, 1, 1)
                    })

                    EnemySettings:AddCheckbox("enemy_name", {
                        Text = "Name"
                    }):AddColorPicker("enemy_name_color", {
                        Title = "Color",
                        Default = Color3.new(1, 1, 1)
                    })

                    EnemySettings:SetupDependencies({
                        {Toggles.enemy_enabled, true}
                    })
                end

                local FriendlyTab = TeamsTB:AddTab("Friendly")
                do
                    FriendlyTab:AddToggle("friendly_enabled", {
                        Text = "Enabled"
                    })

                    local FriendlySettings = FriendlyTab:AddDependencyBox()

                    local ChamsToggle = FriendlySettings:AddCheckbox("friendly_chams", {
                        Text = "Chams"
                    })

                    ChamsToggle:AddColorPicker("friendly_chams_vis", {
                        Title = "Visible",
                        Default = Color3.new(0, 0, 1),
                        Transparency = 0,
                    })

                    ChamsToggle:AddColorPicker("friendly_chams_occ", {
                        Default = Color3.new(1, 0, 1),
                        Title = "Occluded",
                        Transparency = 0,
                    })

                    FriendlySettings:AddCheckbox("friendly_box", {
                        Text = "Box"
                    }):AddColorPicker("friendly_box_color", {
                        Title = "Color",
                        Default = Color3.new(1, 1, 1)
                    })

                    FriendlySettings:AddCheckbox("friendly_name", {
                        Text = "Name"
                    }):AddColorPicker("friendly_name_color", {
                        Title = "Color",
                        Default = Color3.new(1, 1, 1)
                    })

                    FriendlySettings:SetupDependencies({
                        {Toggles.friendly_enabled, true}
                    })
                end
            end

            PlayerGB:AddToggle("global_players_esp", {
                Text = "Enabled"
            })
        end
    end

    Tabs.SkinChanger = Window:AddTab("Skin changer", "paint-bucket")
    do
        local SkinChangerGB = Tabs.SkinChanger:AddGroupbox({
            Name = "Skin changer"
        })

        SkinChangerGB:AddToggle("skinchanger_enabled", {
            Text = "Enabled"
        })

        SkinChangerGB:AddDropdown("knife_model", {
            Text = "Knife model",
            Values = { "CT Knife", "T Knife", "Balisong", "Bat", "Classic Roblox Sword", "Cleaver", "Jagdkommando", "Karambit", "Kukri", "Shadow Daggers" },
            Default = "CT Knife"
        })

        local Alternate = false
        for klass, weapon in pairs(Skins) do
            local ClassGB = Tabs.SkinChanger:AddGroupbox({
                Name = klass,
                Side = Alternate and "Left" or "Right"
            })
            Alternate = not Alternate

            for weapon, skins in pairs(weapon) do
                ClassGB:AddDropdown(`{weapon}_skin`, {
                    Text = weapon,
                    Values = skins,
                    Default = table.find(skins, "Stock") or table.find(skins, "Vanilla")
                })
            end
        end
    end

    UILoaded = true

    Tabs.Combat = Window:AddTab("Combat", "crosshair")

    Tabs.Settings = Window:AddTab("Settings", "settings")
    SaveManager:BuildConfigSection(Tabs.Settings)

    UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Z then
            UILoaded = false

            for k, v in pairs(Hooks) do
                local OriginalFunc = OriginalFuncs[k]

                if isfunctionhooked(OriginalFunc) then
                    restorefunc(OriginalFunc)
                end
            end

            for k, v in pairs(Connections) do
                v:Disconnect()
            end

            for _, player in pairs(EntityList.Character) do
                Visuals:RemoveESP(player)
            end

            UI:Unload()
        end
    end)
]])
