-- https://www.roblox.com/games/111862336710239/Backstreet-Survival
-- Update: 2026-06-29

if getgenv().AutoShovelFarm then
    return
end
getgenv().AutoShovelFarm = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local SellRemoteFunction = ReplicatedStorage.Events:WaitForChild("SellFunc")
local ToolEvent = ReplicatedStorage.Events:WaitForChild("ToolEvent")
local SellNonPlayerCharacter = Workspace:WaitForChild("Map"):WaitForChild("ScriptObjects"):WaitForChild("TrashSell"):WaitForChild("TrashSellNPC")
local TrashTriggerFolder = Workspace:WaitForChild("Map"):WaitForChild("ScriptObjects"):WaitForChild("TrashTriggers"):WaitForChild("Shovel")
local IsSelling = false

local DeveloperName = "EpicKingSlayer"
local IsDeveloperPresent = false

local RarityPriority = {
    "Mythic",
    "Legendary",
    "Epic",
    "Rare"
}

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "交流群",
        Text = "QQ群: 1012488979",
        Duration = 8
    })
end)

local function isBackpackFull()
    local currentInventory = LocalPlayer:GetAttribute("Inventory")
    local maxInventory = LocalPlayer:GetAttribute("InventoryMax")
    if not currentInventory or not maxInventory then
        return false
    end
    return currentInventory >= maxInventory
end

local function getShovelTool(container)
    for _, tool in ipairs(container:GetChildren()) do
        if tool:IsA("Tool") and string.find(tool.Name, "Shovel_") then
            return tool
        end
    end
    return nil
end

local function executeAutoSellAndReturn()
    if IsSelling then
        return
    end
    IsSelling = true
    pcall(function()
        local Character = LocalPlayer.Character
        if not Character then
            return
        end
        local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
        if not HumanoidRootPart then
            return
        end
        local OriginalCFrame = HumanoidRootPart.CFrame
        local TargetPart = SellNonPlayerCharacter:FindFirstChild("HumanoidRootPart") or SellNonPlayerCharacter.PrimaryPart
        if TargetPart then
            HumanoidRootPart.CFrame = TargetPart.CFrame + Vector3.new(0, 2, 0)
        end
        task.wait(0.3)
        local Backpack = LocalPlayer.Backpack
        local EquippedTool = Character:FindFirstChildWhichIsA("Tool")
        if EquippedTool then
            EquippedTool.Parent = Backpack
        end
        local SellPayload = {
            Type = "Trash"
        }
        for _, Tool in ipairs(Backpack:GetChildren()) do
            if Tool:IsA("Tool") and Tool:GetAttribute("TYPE") == "Trash" then
                local ItemName = string.split(Tool.Name, "_")[2]
                local ItemAmount = Tool:GetAttribute("amount") or 1
                if ItemName and ItemAmount > 0 then
                    SellPayload[ItemName] = (SellPayload[ItemName] or 0) + ItemAmount
                end
            end
        end
        if next(SellPayload) then
            SellRemoteFunction:InvokeServer("Sell", SellPayload)
        end
        task.wait(0.3)
        HumanoidRootPart.CFrame = OriginalCFrame
    end)
    IsSelling = false
end

local function getTrashCount(triggerPart, rarity)
    local TrashGui = triggerPart:FindFirstChild("TrashGui")
    if not TrashGui then
        return 0
    end
    local TextLabel = TrashGui:FindFirstChild(rarity)
    if not TextLabel or not TextLabel:IsA("TextLabel") then
        return 0
    end
    local countString = string.match(TextLabel.Text, ": (%d+)")
    return tonumber(countString) or 0
end

local function findBestTrashTarget()
    local TriggerParts = TrashTriggerFolder:GetChildren()
    for _, rarity in ipairs(RarityPriority) do
        for _, part in ipairs(TriggerParts) do
            if part:IsA("BasePart") then
                local count = getTrashCount(part, rarity)
                if count > 0 then
                    return part
                end
            end
        end
    end
    return nil
end

LocalPlayer:GetAttributeChangedSignal("Inventory"):Connect(function()
    if isBackpackFull() then
        executeAutoSellAndReturn()
    end
end)

task.spawn(function()
    while task.wait(1) do
        if isBackpackFull() and not IsSelling then
            executeAutoSellAndReturn()
        end
    end
end)

if LocalPlayer:GetAttribute("Inventory") and LocalPlayer:GetAttribute("InventoryMax") then
    if isBackpackFull() then
        executeAutoSellAndReturn()
    end
end

task.spawn(function()
    while getgenv().AutoShovelFarm do
        task.wait(0.05)
        if IsSelling then
            continue
        end
        local Character = LocalPlayer.Character
        if not Character then
            continue
        end
        local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
        if not HumanoidRootPart then
            continue
        end
        
        local TargetPart = findBestTrashTarget()
        if not TargetPart then
            continue
        end
        
        local targetPosition = TargetPart.Position
        local rootPosition = HumanoidRootPart.Position
        local deltaX = targetPosition.X - rootPosition.X
        local deltaZ = targetPosition.Z - rootPosition.Z
        local horizontalDistance = math.sqrt(deltaX * deltaX + deltaZ * deltaZ)
        
        if horizontalDistance > 3 then
            HumanoidRootPart.CFrame = CFrame.new(targetPosition.X, targetPosition.Y + 2, targetPosition.Z)
        end
        
        local EquippedShovel = getShovelTool(Character)
        if not EquippedShovel then
            local BackpackShovel = getShovelTool(LocalPlayer.Backpack)
            if BackpackShovel then
                BackpackShovel.Parent = Character
                task.wait(0.05)
            else
                continue
            end
        end
        
        ToolEvent:FireServer("Activated", true)
    end
end)

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