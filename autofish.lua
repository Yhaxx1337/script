getgenv().AutoFishing = true
getgenv().AutoFishingRodName = "Other_FishingRod"

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local ToolEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ToolEvent")
local FishingEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("FishingEvent")
local platformPosition = Vector3.new(-155, 6, -223)

local fishingInProgress = false

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "交流群",
        Text = "QQ群: 1012488979",
        Duration = 8
    })
end)

local DeveloperName = "EpicKingSlayer"
local IsDeveloperPresent = false
task.spawn(function()
    while getgenv().AutoFishing do
        local hasDev = false
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name == DeveloperName then
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
        task.wait(3)
    end
end)

local function createPlatform()
    local existing = Workspace:FindFirstChild("FishingPlatform")
    if existing then return existing end
    local platform = Instance.new("Part")
    platform.Name = "FishingPlatform"
    platform.Size = Vector3.new(10, 1, 10)
    platform.Position = platformPosition
    platform.Anchored = true
    platform.Locked = true
    platform.Parent = Workspace
    return platform
end

local function teleportToPlatform()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = CFrame.new(platformPosition + Vector3.new(0, 3, 0))
end

local function findRod(container)
    local rodName = getgenv().AutoFishingRodName
    local rod = container:FindFirstChild(rodName)
    if rod and rod:IsA("Tool") then return rod end
    rod = container:FindFirstChildOfClass("Tool")
    if rod and rod.Name == rodName then return rod end
    return nil
end

local function getAndEquipRod()
    local char = player.Character
    if not char then return false end
    if findRod(char) then return true end
    local bp = player:FindFirstChild("Backpack")
    if bp then
        local rod = findRod(bp)
        if rod then
            rod.Parent = char
            return findRod(char) ~= nil
        end
    end
    return false
end

local function castRod()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local direction = hrp.CFrame.LookVector
    ToolEvent:FireServer("Activated", { force = 1, direction = direction })
end

FishingEvent.OnClientEvent:Connect(function(...)
    if getgenv().AutoFishing then
        ToolEvent:FireServer("Reward", { true })
        fishingInProgress = false
    end
end)

createPlatform()
teleportToPlatform()
task.wait(0.5)

task.spawn(function()
    while getgenv().AutoFishing do
        local char = player.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            if char:FindFirstChildOfClass("Humanoid"):GetState() == Enum.HumanoidStateType.Dead then
                task.wait(1)
                continue
            end
        end

        if not getAndEquipRod() then
            StarterGui:SetCore("SendNotification", {
                Title = "提示",
                Text = "没有鱼竿！请去制作一个鱼竿",
                Duration = 5
            })
            getgenv().AutoFishing = false
            break
        end

        fishingInProgress = true
        castRod()

        local timeout = os.clock() + 3
        while fishingInProgress and getgenv().AutoFishing do
            if os.clock() > timeout then
                fishingInProgress = false
                break
            end
            task.wait(0.1)
        end

        task.wait(0.05)
    end
end)
