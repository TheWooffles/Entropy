if _G.Entropy then
    local TempEntropy = _G.Entropy
    if TempEntropy.dev == true then
        _G.UnloadEntropy()
        return warn("Entropy | Development Mode ON")
    elseif TempEntropy.dev == false then
        if TempEntropy.loaded == true then
            return warn("Entropy | Already Loaded!")
        end
    end
end

local Entropy = {
    Mouselock = {
        Enabled    = false,
        TeamCheck  = true,
        WallCheck  = true,
        Keybind    = "RightBracket",
        TargetPart = "Head",
        Mode       = "Fov", -- "Fov" | "NoFov"
        Type       = "Mouse", -- "Mouse" | "Camera"
		Radius     = 70,
		Smoothness = 0.2,
        Prediction = 0,
    },

    drawings    = {},
    connections = {},
    hooks       = {},

    loaded = false
    dev    = false
}
_G.Entropy = Entropy

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

local function isPlayerAlive(player)
    if not player or not player.Character then return false end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

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
	if Entropy.MouseLock.Mode == "Fov" then
    	shortestDistance = Entropy.MouseLock.Radius
	elseif Entropy.MouseLock.Mode == "NoFov" then
		shortestDistance = math.huge
	end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isPlayerAlive(player) then
            
            if Entropy.MouseLock.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
                continue
            end
            
            local targetPart = player.Character:FindFirstChild(Entropy.MouseLock.TargetPart) or player.Character:FindFirstChild("Head")
            
            if targetPart then
                local partPos = targetPart.Position
                local screenPos, onScreen = Camera:WorldToScreenPoint(partPos)
                
                if onScreen then
                    local screenPosVec = Vector2.new(screenPos.X, screenPos.Y)
					MousePos = Vector2.new(LocalPlayer:GetMouse().X, LocalPlayer:GetMouse().Y)
                    local distanceFromMouse = (MousePos - screenPosVec).Magnitude
                    
                    if isTargetVisible(targetPart, player.Character) then
                        if distanceFromMouse < shortestDistance then
                            shortestDistance = distanceFromMouse
                            closestPlayer = player
                        end
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

Entropy.connections.MouseLock = RunService.RenderStepped:Connect(function()
    if UserInputService.MouseIcon not UserInputService.MouseIcon == 'http://www.roblox.com/asset?id=4882930015' then
        UserInputService.MouseIcon = 'http://www.roblox.com/asset?id=4882930015'
    end
    Entropy.drawings.Cursor.Radius = Entropy.MouseLock.Radius
    Entropy.drawings.Cursor.Position = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
    if not isPlayerAlive(LocalPlayer) then
        targetPlayer = nil
    end
    
    if Entropy.MouseLock.Enabled then
        local newTarget = getClosestPlayerToMouse()
        
        if newTarget and newTarget ~= targetPlayer then
            targetPlayer = newTarget
        elseif not newTarget and targetPlayer then
            targetPlayer = nil
        end
        
        if targetPlayer and targetPlayer.Character then
            local targetPart = targetPlayer.Character:FindFirstChild(Entropy.MouseLock.TargetPart) or targetPlayer.Character:FindFirstChild("Head")
            
            if targetPart then
                local partPos = targetPart.Position
                local screenPos, onScreen = Camera:WorldToScreenPoint(partPos)
                if onScreen then
                    local mousePos = Vector2.new(LocalPlayer:GetMouse().X, LocalPlayer:GetMouse().Y)
                    local targetPos = Vector2.new(screenPos.X, screenPos.Y)
					local Pos
					if Entropy.MouseLock.Smoothness == 1 then
						Pos = Vector2.new(screenPos.X, screenPos.Y)
					elseif Entropy.MouseLock.Smoothness < 1 then
						Pos = mousePos:Lerp(targetPos, math.clamp(Entropy.MouseLock.Smoothness, 0, 1))
					end
                    local delta = Pos - mousePos
                    mousemoverel(delta.X, delta.Y)
                end
            end
        end
    else
        targetPlayer = nil
    end
end)

Entropy.connections.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Entropy.MouseLock.Keybind then
        Entropy.MouseLock.Enabled = not Entropy.MouseLock.Enabled
		if Entropy.MouseLock.Enabled then
            if Entropy.MouseLock.Mode == "Fov" then
                Entropy.drawings.Cursor.Visible = true
            elseif Entropy.MouseLock.Mode == "NoFov" then
                Entropy.drawings.Cursor.Visible = false
            end
			print("Entropy | Locked")
		elseif not Entropy.MouseLock.Enabled then
			Entropy.drawings.Cursor.Visible = false
			print("Entropy | Unlocked")
		end
    end
end)

_G.UnloadEntropy = function()
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






































































































-- if _G.UnloadVantage then
--     _G.UnloadVantage()
-- end

-- --// Services & Variables
-- local Players          = game:GetService("Players")
-- local UserInputService = game:GetService("UserInputService")
-- local RunService       = game:GetService("RunService")
-- local LocalPlayer      = Players.LocalPlayer
-- local Camera           = workspace.CurrentCamera

-- --// Connections & States
-- drawings    = {}
-- connections = {}

-- --// Config
-- _G.Config = {
--     MouseLock = {
--         Enabled = false,
--         Keybind = Enum.KeyCode.LeftBracket,
--         TeamCheck = false,
--         WallCheck = false,
--         TargetPart = "Head",
-- 		Mode = "Fov", -- "Fov" | "NoFov"
--         Type = "Mouse", -- "Mouse" | "Camera"
-- 		Radius = 70,
-- 		Smoothness = 0.2
--     },
-- }

-- --// User Interface
-- drawings.Cursor = Drawing.new("Circle")
-- drawings.Cursor.Position = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
-- drawings.Cursor.Visible = false
-- drawings.Cursor.Radius = _G.Config.MouseLock.Radius
-- drawings.Cursor.Transparency = 0.5
-- drawings.Cursor.Thickness = 1
-- drawings.Cursor.Filled = false
-- drawings.Cursor.Color = Color3.fromRGB(255,255,255)

-- UserInputService.MouseIcon = 'http://www.roblox.com/asset?id=4882930015'

-- local function isPlayerAlive(player)
--     if not player or not player.Character then return false end
--     local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
--     return humanoid and humanoid.Health > 0
-- end

-- local function isTargetVisible(targetPart, targetCharacter)
--     if not _G.Config.MouseLock.WallCheck then
--         return true
--     end
    
--     if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Head") then
--         return false
--     end
    
--     local origin = Camera.CFrame.Position
--     local direction = (targetPart.Position - origin).Unit * (targetPart.Position - origin).Magnitude
    
--     local raycastParams = RaycastParams.new()
--     local filterList = {LocalPlayer.Character, targetCharacter}
    
--     for _, player in pairs(Players:GetPlayers()) do
--         if player.Character then
--             table.insert(filterList, player.Character)
--         end
--     end
    
--     raycastParams.FilterDescendantsInstances = filterList
--     raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
--     local rayResult = workspace:Raycast(origin, direction, raycastParams)
    
--     return rayResult == nil
-- end

-- local function getClosestPlayerToMouse()
--     local closestPlayer = nil
-- 	if _G.Config.MouseLock.Mode == "Fov" then
--     	shortestDistance = _G.Config.MouseLock.Radius
-- 	elseif _G.Config.MouseLock.Mode == "NoFov" then
-- 		shortestDistance = math.huge
-- 	end
		
    
--     for _, player in pairs(Players:GetPlayers()) do
--         if player ~= LocalPlayer and isPlayerAlive(player) then
            
--             if _G.Config.MouseLock.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
--                 continue
--             end
            
--             local targetPart = player.Character:FindFirstChild(_G.Config.MouseLock.TargetPart) or player.Character:FindFirstChild("Head")
            
--             if targetPart then
--                 local partPos = targetPart.Position
--                 local screenPos, onScreen = Camera:WorldToScreenPoint(partPos)
                
--                 if onScreen then
--                     local screenPosVec = Vector2.new(screenPos.X, screenPos.Y)
-- 					MousePos = Vector2.new(LocalPlayer:GetMouse().X, LocalPlayer:GetMouse().Y)
--                     local distanceFromMouse = (MousePos - screenPosVec).Magnitude
                    
--                     if isTargetVisible(targetPart, player.Character) then
--                         if distanceFromMouse < shortestDistance then
--                             shortestDistance = distanceFromMouse
--                             closestPlayer = player
--                         end
--                     end
--                 end
--             end
--         end
--     end
    
--     return closestPlayer
-- end

-- connections.MouseLock = RunService.RenderStepped:Connect(function()
--     drawings.Cursor.Radius = _G.Config.MouseLock.Radius
--     drawings.Cursor.Position = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
--     if not isPlayerAlive(LocalPlayer) then
--         targetPlayer = nil
--     end
    
--     if _G.Config.MouseLock.Enabled then
--         local newTarget = getClosestPlayerToMouse()
        
--         if newTarget and newTarget ~= targetPlayer then
--             targetPlayer = newTarget
--         elseif not newTarget and targetPlayer then
--             targetPlayer = nil
--         end
        
--         if targetPlayer and targetPlayer.Character then
--             local targetPart = targetPlayer.Character:FindFirstChild(_G.Config.MouseLock.TargetPart) or targetPlayer.Character:FindFirstChild("Head")
            
--             if targetPart then
--                 local partPos = targetPart.Position
--                 local screenPos, onScreen = Camera:WorldToScreenPoint(partPos)
--                 if onScreen then
--                     local mousePos = Vector2.new(LocalPlayer:GetMouse().X, LocalPlayer:GetMouse().Y)
--                     local targetPos = Vector2.new(screenPos.X, screenPos.Y)
-- 					local Pos
-- 					if _G.Config.MouseLock.Smoothness == 1 then
-- 						Pos = Vector2.new(screenPos.X, screenPos.Y)
-- 					elseif _G.Config.MouseLock.Smoothness < 1 then
-- 						Pos = mousePos:Lerp(targetPos, math.clamp(_G.Config.MouseLock.Smoothness, 0, 1))
-- 					end
--                     local delta = Pos - mousePos
--                     mousemoverel(delta.X, delta.Y)
--                 end
--             end
--         end
--     else
--         targetPlayer = nil
--     end
-- end)

-- connections.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
--     if gameProcessed then return end
--     if input.KeyCode == _G.Config.MouseLock.Keybind then
--         _G.Config.MouseLock.Enabled = not _G.Config.MouseLock.Enabled
-- 		if _G.Config.MouseLock.Enabled then
--             if _G.Config.MouseLock.Mode == "Fov" then
--                 drawings.Cursor.Visible = true
--             elseif _G.Config.MouseLock.Mode == "NoFov" then
--                 drawings.Cursor.Visible = false
--             end
-- 			print("[Vantage] :: Locked")
-- 		elseif not _G.Config.MouseLock.Enabled then
-- 			drawings.Cursor.Visible = false
-- 			print("[Vantage] :: Unlocked")
-- 		end
--     end
-- end)

-- _G.UnloadVantage = function()
--     for _, connection in pairs(connections) do
--         connection:Disconnect()
--     end
--     for _, drawing in pairs(drawings) do
--         drawing:Destroy()
--     end
-- 	UserInputService.MouseIcon = ''
--     print("[Vantage] :: Unloaded!")
-- end

-- print("[Vantage] :: loaded")
