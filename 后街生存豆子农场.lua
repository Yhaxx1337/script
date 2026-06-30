local FactoryConfig = {
    Running = true,
    KeepTeleportLoop = nil,
    ScanRadius = 10,
    FirePrompt = fireproximityprompt
}
local Env = FactoryConfig

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

repeat task.wait() until Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("ScriptObjects")
repeat task.wait() until Workspace.Map.ScriptObjects:FindFirstChild("Factory")

local function waitForPath(root, ...)
    local node = root
    for _, name in ipairs({...}) do
        node = node:WaitForChild(name, 15)
        if not node then return nil end
    end
    return node
end

local BagPrompt = waitForPath(Workspace, "Map", "ScriptObjects", "Factory", "FactoryPrompts", "Bag", "FactoryPrompt")
local ConveyorPrompt = waitForPath(Workspace, "Map", "ScriptObjects", "Factory", "FactoryPrompts", "ConveyorPart", "FactoryPrompt")
local FactoryCraftEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("FactoryCraftEvent")
local AFKEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("AFKEvent")
local Light1 = waitForPath(Workspace, "Map", "ScriptObjects", "Factory", "FactoryConveyor", "Console", "Light1", "Part")
local Light2 = waitForPath(Workspace, "Map", "ScriptObjects", "Factory", "FactoryConveyor", "Console", "Light2", "Part")
local Repair1Prompt = waitForPath(Workspace, "Map", "ScriptObjects", "Factory", "FactoryConveyor", "Console", "Console1", "RepairPrompt")
local Repair2Prompt = waitForPath(Workspace, "Map", "ScriptObjects", "Factory", "FactoryConveyor", "Console", "Console2", "RepairPrompt")

local lastRepairTime = 0
local repairMoveDelay = 0
local isRepairing = false

local function checkClothing()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    if not playerGui then return false end
    local inventoryScreen = playerGui:WaitForChild("Inventory", 10)
    if not inventoryScreen then return false end
    local invFrame = inventoryScreen:WaitForChild("Inventory", 10)
    if not invFrame then return false end
    local skins = invFrame:WaitForChild("Skins", 10)
    if not skins then return false end
    return skins:FindFirstChild("BeanCo Executive Uniform") ~= nil
        or skins:FindFirstChild("BeanCo Standard Uniform") ~= nil
end

if not checkClothing() then
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "缺少服装",
            Text = "请去购买工厂工作服",
            Duration = 5
        })
    end)
    local rack = Workspace.Map.Environment:FindFirstChild("clothing rack")
    if rack and rack:IsA("BasePart") then
        HumanoidRootPart.CFrame = CFrame.new(rack.Position + Vector3.new(0, 3, 0))
    end
    return
end

local function checkBoard()
    local board = waitForPath(Workspace, "Map", "ScriptObjects", "Factory", "FactoryLeaderboard", "SurfaceGui", "Frame", "Items")
    if not board then return end
    local playerId = tostring(LocalPlayer.UserId)
    if not board:FindFirstChild(playerId) then
        local prompt = waitForPath(Workspace, "Map", "ScriptObjects", "Factory", "FactoryPrompts", "FactoryPart", "FactoryPrompt")
        if prompt then
            local promptPos
            if prompt.Parent:IsA("BasePart") then
                promptPos = prompt.Parent.Position
            elseif prompt.Parent:IsA("Attachment") then
                promptPos = prompt.Parent.WorldPosition
            else
                promptPos = Vector3.zero
            end
            HumanoidRootPart.CFrame = CFrame.new(promptPos + Vector3.new(0, 3, 0))
            task.wait(0.5)
            pcall(function()
                prompt.RequiresLineOfSight = false
                if Env.FirePrompt then
                    Env.FirePrompt(prompt)
                elseif fireproximityprompt then
                    fireproximityprompt(prompt)
                else
                    prompt:InputHoldBegin()
                    prompt:InputHoldEnd()
                end
            end)
            task.wait(1)
        end
    end
end
checkBoard()

local cachedEnvPart = nil
do
    local envFolder = Workspace.Map:FindFirstChild("Environment")
    if envFolder then
        envFolder.ChildAdded:Connect(function() cachedEnvPart = nil end)
        envFolder.ChildRemoved:Connect(function() cachedEnvPart = nil end)
    end
end

local function GetTargetEnvironmentPart()
    if cachedEnvPart and cachedEnvPart.Parent then return cachedEnvPart end
    local envFolder = Workspace.Map:FindFirstChild("Environment")
    if not envFolder then return nil end
    for _, child in ipairs(envFolder:GetChildren()) do
        if child:IsA("BasePart") then
            local texture = child:FindFirstChild("dd")
            if texture and (texture:IsA("Decal") or texture:IsA("Texture")) and texture.Texture == "rbxassetid://2173647056" then
                cachedEnvPart = child
                return child
            end
        end
    end
    return nil
end

local cachedInventoryFrame = nil
local function GetInventoryFrame()
    if cachedInventoryFrame and cachedInventoryFrame.Parent then return cachedInventoryFrame end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local inv = pg:FindFirstChild("Inventory")
    if not inv then return nil end
    local mainInv = inv:FindFirstChild("Inventory")
    if not mainInv then return nil end
    local frame = mainInv:FindFirstChild("Frame")
    cachedInventoryFrame = frame
    return frame
end

local cachedNpcFolder = nil
local function GetNpcFolder()
    if cachedNpcFolder and cachedNpcFolder.Parent then return cachedNpcFolder end
    cachedNpcFolder = Workspace.Map:FindFirstChild("NPC")
    return cachedNpcFolder
end

local _hasBag = false
local _hasBox = false

local function rebuildCharCache(char)
    if not char then return end
    _hasBag = char:FindFirstChild("Factory_Bag") ~= nil
    _hasBox = char:FindFirstChild("Factory_Box") ~= nil
    char.ChildAdded:Connect(function(c)
        if c.Name == "Factory_Bag" then _hasBag = true end
        if c.Name == "Factory_Box" then _hasBox = true end
    end)
    char.ChildRemoved:Connect(function(c)
        if c.Name == "Factory_Bag" then _hasBag = false end
        if c.Name == "Factory_Box" then _hasBox = false end
    end)
end

rebuildCharCache(Character)
LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    HumanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
    _hasBag = false
    _hasBox = false
    rebuildCharCache(newChar)
end)

local function hasFactoryBag() return _hasBag end
local function HasFactoryBox() return _hasBox end

local antiAFKAnimIds = {
    ["rbxassetid://85847905081093"] = true,
    ["rbxassetid://117926337619093"] = true
}

local function pressWTwice()
    for _ = 1, 2 do
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
        task.wait(0.1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
        task.wait(0.05)
    end
end

local function checkAndPressW()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local animId = track.Animation and track.Animation.AnimationId
        if animId and antiAFKAnimIds[animId] then
            pressWTwice()
            break
        end
    end
end

local function disableAFK()
    local afkRoot = Workspace:FindFirstChild("EpicKingSlayer")
    if afkRoot then
        local scriptObj = afkRoot:FindFirstChild("AFKScript")
        if scriptObj then
            pcall(function() scriptObj:Destroy() end)
        end
    end
    task.spawn(function()
        while Env.Running do
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    local animator = hum:FindFirstChildOfClass("Animator")
                    if animator then
                        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                            local name = track.Animation and track.Animation.Name
                            if name == "AFK_Start" or name == "AFK_Loop" then
                                track:Stop()
                            end
                        end
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end

disableAFK()
LocalPlayer.CharacterAdded:Connect(function(newChar)
    disableAFK()
end)

local function TeleportToPosition(TargetPosition)
    local Dis = (HumanoidRootPart.Position - TargetPosition).Magnitude
    if Dis < 4 then return end
    HumanoidRootPart.CFrame = CFrame.new(TargetPosition + Vector3.new(0, 1.5, 0))
    task.wait(0.15)
end

local function GetPromptWorldPosition(Prompt)
    local ParentInstance = Prompt.Parent
    if ParentInstance:IsA("BasePart") then
        return ParentInstance.Position
    elseif ParentInstance:IsA("Attachment") then
        return ParentInstance.WorldPosition
    end
    local AncestorPart = Prompt:FindFirstAncestorWhichIsA("BasePart")
    return AncestorPart and AncestorPart.Position or Vector3.zero
end

local function doFirePrompt(Prompt)
    if Env.FirePrompt then
        Env.FirePrompt(Prompt)
    elseif fireproximityprompt then
        fireproximityprompt(Prompt)
    else
        Prompt:InputHoldBegin()
        Prompt:InputHoldEnd()
    end
end

local function FastTrigger(Prompt)
    if not Prompt or not Prompt:IsA("ProximityPrompt") then return end
    Prompt.RequiresLineOfSight = false
    pcall(doFirePrompt, Prompt)
    task.wait(0.03)
    pcall(doFirePrompt, Prompt)
end

local function TriggerPrompt(Prompt)
    if not Prompt or not Prompt:IsA("ProximityPrompt") then return false end
    Prompt.RequiresLineOfSight = false
    pcall(doFirePrompt, Prompt)
    task.wait(0.3)
    return true
end

local function ParseToolAmount(TextLabel)
    if not TextLabel or not TextLabel.Text then return 0 end
    local num = string.match(TextLabel.Text, "x(%d+)")
    return tonumber(num) or 0
end

local function GetBeanCount()
    local frame = GetInventoryFrame()
    if not frame then return 0 end
    for _, child in ipairs(frame:GetChildren()) do
        if child.Name == "Trash_TinCan" then
            local amountLabel = child:FindFirstChild("toolAmount")
            if amountLabel and amountLabel:IsA("TextLabel") then
                return ParseToolAmount(amountLabel)
            end
        end
    end
    return 0
end

local function GetBeanData()
    local part = GetTargetEnvironmentPart()
    if not part then return 0, {} end
    local CenterPos = part.Position
    local radius = Env.ScanRadius

    local candidates = {}
    for _, Obj in ipairs(Workspace:GetDescendants()) do
        if Obj.Name == "Beans" and Obj:IsA("BasePart") then
            if Obj.AssemblyLinearVelocity.Magnitude >= 1.5 then continue end
            if Obj.AssemblyAngularVelocity.Magnitude >= 1.5 then continue end
            if (Obj.Position - CenterPos).Magnitude <= radius then
                local P = Obj:FindFirstChildOfClass("ProximityPrompt")
                if P and P.Name == "FactoryPrompt" then
                    table.insert(candidates, {obj = Obj, prompt = P})
                end
            end
        end
    end

    if #candidates == 0 then return 0, {} end

    task.wait()

    local BeanList = {}
    for _, c in ipairs(candidates) do
        local obj = c.obj
        if not obj or not obj.Parent then continue end
        if obj.AssemblyLinearVelocity.Magnitude >= 1.5 then continue end
        if obj.AssemblyAngularVelocity.Magnitude >= 1.5 then continue end
        table.insert(BeanList, c.prompt)
    end

    return #BeanList, BeanList
end

local function isLightRed(part)
    if not part then return false end
    local c = part.BrickColor.Color
    return math.round(c.R * 255) == 255
        and math.round(c.G * 255) == 0
        and math.round(c.B * 255) == 0
end

local function CheckMachineError()
    if isRepairing then return true end
    if os.clock() - lastRepairTime < 5 then return false end
    if not Light1 or not Light2 then return false end
    if isLightRed(Light1) then
        isRepairing = true
        if Env.KeepTeleportLoop then
            Env.KeepTeleportLoop:Disconnect()
            Env.KeepTeleportLoop = nil
        end
        TeleportToPosition(GetPromptWorldPosition(Repair1Prompt))
        if isLightRed(Light1) then
            TriggerPrompt(Repair1Prompt)
            task.wait(0.2)
            TriggerPrompt(Repair1Prompt)
        end
        lastRepairTime = os.clock()
        repairMoveDelay = os.clock() + 1.5
        task.wait(3)
        isRepairing = false
        return true
    end
    if isLightRed(Light2) then
        isRepairing = true
        if Env.KeepTeleportLoop then
            Env.KeepTeleportLoop:Disconnect()
            Env.KeepTeleportLoop = nil
        end
        TeleportToPosition(GetPromptWorldPosition(Repair2Prompt))
        if isLightRed(Light2) then
            TriggerPrompt(Repair2Prompt)
            task.wait(0.2)
            TriggerPrompt(Repair2Prompt)
        end
        lastRepairTime = os.clock()
        repairMoveDelay = os.clock() + 1.5
        task.wait(3)
        isRepairing = false
        return true
    end
    return false
end

local function DeliverBagToConveyor()
    if not ConveyorPrompt then return false end
    local ConveyPos = GetPromptWorldPosition(ConveyorPrompt)
    TeleportToPosition(ConveyPos)
    local delivered = false
    for i = 1, 15 do
        FastTrigger(ConveyorPrompt)
        task.wait(0.05)
        if not hasFactoryBag() then
            delivered = true
            break
        end
    end
    if not delivered then
        task.wait(0.2)
        TeleportToPosition(ConveyPos)
        for i = 1, 10 do
            FastTrigger(ConveyorPrompt)
            task.wait(0.05)
            if not hasFactoryBag() then
                delivered = true
                break
            end
        end
    end
    return delivered
end

local function RunFactoryStep()
    if CheckMachineError() then return end
    if not BagPrompt then return end
    if os.clock() < repairMoveDelay then
        task.wait(repairMoveDelay - os.clock())
    end

    if hasFactoryBag() then
        DeliverBagToConveyor()
        return
    end

    local BagPos = GetPromptWorldPosition(BagPrompt)
    TeleportToPosition(BagPos)
    pcall(doFirePrompt, BagPrompt)
    local waited = 0
    while not hasFactoryBag() and waited < 1.5 and Env.Running do
        task.wait(0.05)
        waited = waited + 0.05
    end
    if not hasFactoryBag() then
        TeleportToPosition(BagPos)
        pcall(doFirePrompt, BagPrompt)
        waited = 0
        while not hasFactoryBag() and waited < 1.0 and Env.Running do
            task.wait(0.05)
            waited = waited + 0.05
        end
    end
    if not Env.Running or not hasFactoryBag() then return end

    DeliverBagToConveyor()
end

local function GetVanAmount(van)
    local attachment = van and van:FindFirstChild("HumanoidRootPart") and van.HumanoidRootPart:FindFirstChild("Attachment")
    if not attachment then return 0 end
    local billboard = attachment:FindFirstChild("BillboardGui")
    if not billboard then return 0 end
    local newTool = billboard:FindFirstChild("newTool")
    if not newTool then return 0 end
    local amountLabel = newTool:FindFirstChild("toolAmount")
    if amountLabel and amountLabel:IsA("TextLabel") then
        return ParseToolAmount(amountLabel)
    end
    return 0
end

local function GetVanPrompts()
    local npcFolder = GetNpcFolder()
    if not npcFolder then return nil, nil end
    local van1 = npcFolder:FindFirstChild("Van1")
    local van2 = npcFolder:FindFirstChild("Van2")
    local amount1 = GetVanAmount(van1)
    local amount2 = GetVanAmount(van2)
    local bestVan = amount1 >= amount2 and van1 or van2
    local worstVan = amount1 < amount2 and van1 or van2
    local function getPrompt(van)
        if not van then return nil end
        local att = van.HumanoidRootPart and van.HumanoidRootPart:FindFirstChild("Attachment")
        return att and att:FindFirstChild("FactoryPrompt") or nil
    end
    return getPrompt(bestVan), getPrompt(worstVan)
end

local function InstantLoad(prompt)
    if not prompt then return end
    TeleportToPosition(GetPromptWorldPosition(prompt))
    task.wait(0.1)
    FastTrigger(prompt)
    task.wait(0.05)
    FastTrigger(prompt)
end

local function CollectMissingBeans()
    local collectedSet = {}
    local stuckTimer = 0
    local lastCount = GetBeanCount()
    local totalAttempts = 0
    local maxAttempts = 15

    while GetBeanCount() < 5 and totalAttempts < maxAttempts do
        local count, beans = GetBeanData()

        if count == 0 then
            task.wait(0.3)
            local groundCount2, _ = GetBeanData()
            if groundCount2 == 0 then
                break
            end
            continue
        end

        local target = nil
        for _, b in ipairs(beans) do
            local parent = b.Parent
            if parent and parent:IsA("BasePart") and not collectedSet[parent] then
                if parent:IsDescendantOf(Workspace) then
                    target = b
                    break
                end
            end
        end

        if not target then break end

        if not target.Parent or not target.Parent:IsDescendantOf(Workspace) then
            continue
        end

        local beanPos = target.Parent.Position
        TeleportToPosition(beanPos)
        FastTrigger(target)

        totalAttempts = totalAttempts + 1

        task.wait(0.05)
        if target.Parent and target.Parent:IsDescendantOf(Workspace) then
            collectedSet[target.Parent] = true
        else
            task.wait(0.1)
            continue
        end

        local newCount = GetBeanCount()
        if newCount == lastCount then
            stuckTimer = stuckTimer + 1
            if stuckTimer >= 4 then
                break
            end
        else
            stuckTimer = 0
            lastCount = newCount
        end
    end
end

local function CraftAndLoad()
    FactoryCraftEvent:FireServer()
    task.wait(1.0)
    local bestPrompt, worstPrompt = GetVanPrompts()
    InstantLoad(bestPrompt)
    if HasFactoryBox() then
        InstantLoad(worstPrompt)
    end
end

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "交流群",
        Text = "QQ群: 1012488979",
        Duration = 8
    })
end)

local DeveloperName = "EpicKingSlayer"
local IsDeveloperPresent = false
RunService.Heartbeat:Connect(function()
    local hasDev = false
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name == DeveloperName then
            hasDev = true
            break
        end
    end
    if hasDev and not IsDeveloperPresent then
        IsDeveloperPresent = true
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "开发者提示",
                Text = "你遇到了开发者！当前开发者在你的服务器",
                Duration = 5
            })
        end)
    elseif not hasDev and IsDeveloperPresent then
        IsDeveloperPresent = false
    end
end)

task.spawn(function()
    while task.wait(2) and Env.Running do
        AFKEvent:FireServer(true)
    end
end)

task.spawn(function()
    while Env.Running do
        checkAndPressW()
        task.wait(0.3)
    end
end)

task.spawn(function()
    while Env.Running do
        if not GetTargetEnvironmentPart() then
            task.wait(1)
            continue
        end
        if CheckMachineError() then
            task.wait(0.5)
            continue
        end

        local bagCount = GetBeanCount()
        local groundCount, _ = GetBeanData()

        if bagCount >= 5 then
            CraftAndLoad()
        elseif groundCount + bagCount >= 5 then
            CollectMissingBeans()
            if GetBeanCount() >= 5 then
                CraftAndLoad()
            end
        else
            RunFactoryStep()
        end
        task.wait()
    end
end)