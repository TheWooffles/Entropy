if _G.UnloadEntropy then
    _G.UnloadEntropy()
end

local Entropy = {
    MouseLock = {
        Enabled     = false,
        TeamCheck   = true,
        WallCheck   = true,
        Keybind     = Enum.KeyCode.LeftBracket,
        TargetPart  = "Head",
        Mode        = "Fov", -- "Fov" | "Target"
        Type        = "Mouse", -- "Mouse" | "Camera"
        Radius      = 70,
        Smoothness  = 0.3,
        Prediction  = 0.165,
        JumpOffset  = 0.2,
        TargetLock  = {
            Enabled = false,
            SwitchKey = Enum.KeyCode.V,
            UnlockKey = Enum.KeyCode.X,
            MaxTargets = 5,
            PrioritizeDistance = true,
            IgnoreTransparency = false,
        },
        Smoothing = {
            Enabled = true,
            Acceleration = 0.115,
            Deceleration = 0.175,
            MaxSpeed = 15,
        },
    },
    Whitelist = {
        Enabled = true,
        Players = {"ggtm"}, -- Add display names here (case-sensitive)
        Friends = false, -- Auto-whitelist friends
    },


    drawings    = {},
    connections = {},
    hooks       = {},

    loaded = false,
    dev    = false,
}
_G.Entropy = Entropy
loadstring(game:HttpGet('https://raw.githubusercontent.com/TheWooffles/Entropy/main/Src/Esp.lua'))()
--// Services & Variables
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera

--// User Interface
Entropy.drawings.Cursor = Drawing.new("Circle")
Entropy.drawings.Cursor.Position = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
Entropy.drawings.Cursor.Visible = false
Entropy.drawings.Cursor.Radius = Entropy.MouseLock.Radius
Entropy.drawings.Cursor.Transparency = 0.5
Entropy.drawings.Cursor.Thickness = 1
Entropy.drawings.Cursor.Filled = false
Entropy.drawings.Cursor.Color = Color3.fromRGB(255,255,255)

UserInputService.MouseIcon = 'http://www.roblox.com/asset?id=4882930015'

local function isPlayerAlive(player)
    if not player or not player.Character then return false end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function getPredictedPosition(targetPart, player)
    local position = targetPart.Position
    local velocity = targetPart.AssemblyLinearVelocity or Vector3.new(0, 0, 0)
    local predictionTime = Entropy.MouseLock.Prediction
    
    -- Advanced prediction with jump detection
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Jump then
        position = position + Vector3.new(0, Entropy.MouseLock.JumpOffset, 0)
    end
    
    -- Velocity-based prediction with acceleration
    local acceleration = velocity - (targetPart.lastVelocity or velocity)
    targetPart.lastVelocity = velocity
    
    return position + (velocity * predictionTime) + (acceleration * (predictionTime * 0.5))
end

local function isWhitelisted(player)
    if not Entropy.Whitelist.Enabled then return false end
    
    -- Check friends if enabled
    if Entropy.Whitelist.Friends and player:IsFriendsWith(LocalPlayer.UserId) then
        return true
    end
    
    -- Check whitelist
    for _, whitelistedName in ipairs(Entropy.Whitelist.Players) do
        if player.DisplayName == whitelistedName or player.Name == whitelistedName then
            return true
        end
    end
    return false
end

-- Smooth movement with acceleration/deceleration
local smoothing = {
    currentSpeed = Vector2.new(),
    targetSpeed = Vector2.new(),
    lastDelta = Vector2.new(),
}

local function smoothAim(current, target)
    if not Entropy.MouseLock.Smoothing.Enabled then
        return target
    end
    
    local delta = target - current
    local acceleration = Entropy.MouseLock.Smoothing.Acceleration
    local deceleration = Entropy.MouseLock.Smoothing.Deceleration
    local maxSpeed = Entropy.MouseLock.Smoothing.MaxSpeed
    
    -- Update target speed
    smoothing.targetSpeed = delta.Unit * math.min(delta.Magnitude, maxSpeed)
    
    -- Apply acceleration/deceleration
    local speedDelta = smoothing.targetSpeed - smoothing.currentSpeed
    if speedDelta.Magnitude > 0 then
        smoothing.currentSpeed = smoothing.currentSpeed + speedDelta.Unit * math.min(speedDelta.Magnitude, acceleration)
    else
        smoothing.currentSpeed = smoothing.currentSpeed:Lerp(Vector2.new(), deceleration)
    end
    
    return current + smoothing.currentSpeed
end

-- Target management for lock mode
local targetManager = {
    targets = {},
    currentIndex = 1,
    lastSwitch = 0,
    
    addTarget = function(self, player)
        if #self.targets >= Entropy.MouseLock.TargetLock.MaxTargets then return end
        table.insert(self.targets, player)
        self:sortTargets()
    end,
    
    removeTarget = function(self, player)
        for i, target in ipairs(self.targets) do
            if target == player then
                table.remove(self.targets, i)
                if self.currentIndex > #self.targets then
                    self.currentIndex = 1
                end
                break
            end
        end
    end,
    
    getCurrentTarget = function(self)
        return self.targets[self.currentIndex]
    end,
    
    switchTarget = function(self)
        if #self.targets == 0 then return end
        if tick() - self.lastSwitch < 0.2 then return end -- Prevent too rapid switching
        
        self.currentIndex = self.currentIndex % #self.targets + 1
        self.lastSwitch = tick()
        return self.targets[self.currentIndex]
    end,
    
    sortTargets = function(self)
        if Entropy.MouseLock.TargetLock.PrioritizeDistance then
            table.sort(self.targets, function(a, b)
                if not a.Character or not b.Character then return false end
                local aRoot = a.Character:FindFirstChild("HumanoidRootPart")
                local bRoot = b.Character:FindFirstChild("HumanoidRootPart")
                if not aRoot or not bRoot then return false end
                
                return (aRoot.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude <
                       (bRoot.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
            end)
        end
    end,
    
    clear = function(self)
        self.targets = {}
        self.currentIndex = 1
    end
}

local function isTargetVisible(targetPart, targetCharacter)
    if not Entropy.MouseLock.WallCheck then
        return true
    end
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Head") then
        return false
    end
    
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit * (targetPart.Position - origin).Magnitude
    
    local raycastParams = RaycastParams.new()
    local filterList = {LocalPlayer.Character, targetCharacter}
    
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character then
            table.insert(filterList, player.Character)
        end
    end
    
    raycastParams.FilterDescendantsInstances = filterList
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local rayResult = workspace:Raycast(origin, direction, raycastParams)
    
    return rayResult == nil
end

local function getClosestPlayerToMouse()
    local closestPlayer = nil
    local shortestDistance = (Entropy.MouseLock.Mode == "Fov") and Entropy.MouseLock.Radius or math.huge
    
    -- If in target lock mode and we have a current target, prioritize them
    if Entropy.MouseLock.Mode == "Target" and Entropy.MouseLock.TargetLock.Enabled then
        local currentTarget = targetManager:getCurrentTarget()
        if currentTarget and isPlayerAlive(currentTarget) and not isWhitelisted(currentTarget) then
            return currentTarget
        end
    end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isPlayerAlive(player) then
            if isWhitelisted(player) then continue end
            if Entropy.MouseLock.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then continue end
            
            local targetPart = player.Character:FindFirstChild(Entropy.MouseLock.TargetPart) or player.Character:FindFirstChild("Head")
            if not targetPart then continue end
            
            -- Visibility check with transparency handling
            if not Entropy.MouseLock.TargetLock.IgnoreTransparency then
                local transparent = false
                for _, part in pairs(player.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Transparency > 0.9 then
                        transparent = true
                        break
                    end
                end
                if transparent then continue end
            end
            
            local predictedPos = getPredictedPosition(targetPart, player)
            local screenPos, onScreen = Camera:WorldToScreenPoint(predictedPos)
            
            if onScreen then
                local screenPosVec = Vector2.new(screenPos.X, screenPos.Y)
                local mousePos = Vector2.new(LocalPlayer:GetMouse().X, LocalPlayer:GetMouse().Y)
                local distanceFromMouse = (mousePos - screenPosVec).Magnitude
                
                if isTargetVisible(targetPart, player.Character) then
                    -- In Target mode, add valid targets to the manager
                    if Entropy.MouseLock.Mode == "Target" then
                        targetManager:addTarget(player)
                    end
                    
                    if distanceFromMouse < shortestDistance then
                        shortestDistance = distanceFromMouse
                        closestPlayer = player
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

local lastFrameTime = tick()
local frameDelta = 0

Entropy.connections.MouseLock = RunService.RenderStepped:Connect(function()
    -- Delta time calculation for smooth animations
    local currentTime = tick()
    frameDelta = currentTime - lastFrameTime
    lastFrameTime = currentTime
    
    -- Update FOV circle
    Entropy.drawings.Cursor.Radius = Entropy.MouseLock.Radius
    Entropy.drawings.Cursor.Position = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
    
    -- Clear target if local player dies
    if not isPlayerAlive(LocalPlayer) then
        targetPlayer = nil
        targetManager:clear()
        return
    end
    
    if Entropy.MouseLock.Enabled then
        local newTarget = getClosestPlayerToMouse()
        
        -- Target management
        if Entropy.MouseLock.Mode == "Target" then
            if newTarget and not table.find(targetManager.targets, newTarget) then
                targetManager:addTarget(newTarget)
            end
            newTarget = targetManager:getCurrentTarget()
        end
        
        -- Update current target
        if newTarget and newTarget ~= targetPlayer then
            targetPlayer = newTarget
            -- Reset smoothing when switching targets
            smoothing.currentSpeed = Vector2.new()
            smoothing.lastDelta = Vector2.new()
        elseif not newTarget and targetPlayer then
            targetPlayer = nil
            targetManager:clear()
        end
        
        -- Aim at target
        if targetPlayer and targetPlayer.Character then
            local targetPart = targetPlayer.Character:FindFirstChild(Entropy.MouseLock.TargetPart) or targetPlayer.Character:FindFirstChild("Head")
            
            if targetPart then
                local predictedPos = getPredictedPosition(targetPart, targetPlayer)
                local screenPos, onScreen = Camera:WorldToScreenPoint(predictedPos)
                
                if onScreen then
                    local mousePos = Vector2.new(LocalPlayer:GetMouse().X, LocalPlayer:GetMouse().Y)
                    local targetPos = Vector2.new(screenPos.X, screenPos.Y)
                    local finalPos
                    
                    -- Apply smoothing based on mode and settings
                    if Entropy.MouseLock.Mode == "Target" then
                        -- Target mode uses advanced smoothing with acceleration
                        finalPos = smoothAim(mousePos, targetPos)
                    else
                        -- FOV mode uses simple lerp smoothing
                        if Entropy.MouseLock.Smoothness == 1 then
                            finalPos = targetPos
                        else
                            finalPos = mousePos:Lerp(targetPos, math.clamp(Entropy.MouseLock.Smoothness, 0, 1))
                        end
                    end
                    
                    -- Apply mouse movement
                    local delta = finalPos - mousePos
                    mousemoverel(delta.X, delta.Y)
                    
                    -- Update visual feedback (you could add hit markers, target indicators etc. here)
                    if Entropy.MouseLock.Mode == "Target" then
                        Entropy.drawings.Cursor.Color = Color3.fromRGB(255, 50, 50)
                    else
                        Entropy.drawings.Cursor.Color = Color3.fromRGB(255, 255, 255)
                    end
                end
            end
        end
    else
        targetPlayer = nil
        targetManager:clear()
    end
end)

Entropy.connections.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Main toggle
    if input.KeyCode == Entropy.MouseLock.Keybind then
        Entropy.MouseLock.Enabled = not Entropy.MouseLock.Enabled
        
        if Entropy.MouseLock.Enabled then
            -- Show/hide cursor based on mode
            if Entropy.MouseLock.Mode == "Fov" then
                Entropy.drawings.Cursor.Visible = true
            elseif Entropy.MouseLock.Mode == "Target" then
                Entropy.drawings.Cursor.Visible = Entropy.MouseLock.TargetLock.Enabled
            end
            print("Entropy | Locked (" .. Entropy.MouseLock.Mode .. " Mode)")
        else
            Entropy.drawings.Cursor.Visible = false
            targetManager:clear()
            print("Entropy | Unlocked")
        end
    end
    
    -- Target lock controls (only in Target mode)
    if Entropy.MouseLock.Mode == "Target" and Entropy.MouseLock.Enabled then
        -- Target switching
        if input.KeyCode == Entropy.MouseLock.TargetLock.SwitchKey then
            local newTarget = targetManager:switchTarget()
            if newTarget then
                print("Entropy | Switched target to: " .. newTarget.Name)
            end
        end
        
        -- Target unlock
        if input.KeyCode == Entropy.MouseLock.TargetLock.UnlockKey then
            targetManager:clear()
            targetPlayer = nil
            print("Entropy | Target cleared")
        end
    end
end)

_G.UnloadEntropy = function()
    _G.ESP.Unload()
    for _, connection in pairs(Entropy.connections) do
        connection:Disconnect()
    end
    for _, drawing in pairs(Entropy.drawings) do
        drawing:Destroy()
    end
	UserInputService.MouseIcon = ''
    print("Entropy | Unloaded!")
end

Entropy.loaded = true
print("Entropy | Loaded!")
