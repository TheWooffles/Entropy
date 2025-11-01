-- Enhanced Nametag/ESP Framework for Roblox
-- Place this in StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Configuration
local CONFIG = {
	Enabled = true,
	ShowDistance = true,
	ShowHealth = true,
	MaxDistance = 1000,
	MinDistance = 10, -- Distance where ESP is at max size
	BaseTextSize = 14,
	MaxTextSize = 20, -- Maximum text size when close
	MinTextSize = 8, -- Minimum text size when far
	TextColor = Color3.fromRGB(255, 255, 255),
	HealthBarEnabled = true,
	TeamCheck = true,
	ScaleWithDistance = true, -- Enable distance-based scaling
}

-- Storage for ESP objects
local ESPObjects = {}

-- Calculate scale factor based on distance
local function getScaleFactor(distance)
	if not CONFIG.ScaleWithDistance then return 1 end
	
	-- Inverse scaling: closer = bigger, farther = smaller
	local normalizedDistance = math.clamp(distance / CONFIG.MaxDistance, 0, 1)
	-- Use exponential curve for more natural scaling
	local scale = 1 - (normalizedDistance ^ 0.7) * 0.65
	return math.clamp(scale, 0.35, 1.5)
end

-- Create ESP for a character
local function createESP(player, character)
	if player == LocalPlayer then return end
	if ESPObjects[player] then return end
	
	-- Wait for Head instead of HumanoidRootPart for proper positioning
	local head = character:WaitForChild("Head", 5)
	local humanoid = character:WaitForChild("Humanoid", 5)
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
	if not head or not humanoid or not humanoidRootPart then return end
	
	-- Create BillboardGui attached to Head
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ESP_" .. player.Name
	billboard.Adornee = head
	billboard.Size = UDim2.new(0, 200, 0, 60)
	billboard.StudsOffset = Vector3.new(0, 2, 0) -- Position above head
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = head
	
	-- Container frame for proper centering
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.Position = UDim2.new(0, 0, 0, 0)
	container.BackgroundTransparency = 1
	container.Parent = billboard
	
	-- Name Label (centered)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.35, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.AnchorPoint = Vector2.new(0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.Name
	nameLabel.TextColor3 = CONFIG.TextColor
	nameLabel.TextSize = CONFIG.BaseTextSize
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.Parent = container
	
	-- Distance Label (centered)
	local distanceLabel = Instance.new("TextLabel")
	distanceLabel.Name = "DistanceLabel"
	distanceLabel.Size = UDim2.new(1, 0, 0.25, 0)
	distanceLabel.Position = UDim2.new(0, 0, 0.35, 0)
	distanceLabel.AnchorPoint = Vector2.new(0, 0)
	distanceLabel.BackgroundTransparency = 1
	distanceLabel.Text = "0 studs"
	distanceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	distanceLabel.TextSize = CONFIG.BaseTextSize - 2
	distanceLabel.Font = Enum.Font.Gotham
	distanceLabel.TextStrokeTransparency = 0.5
	distanceLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	distanceLabel.TextXAlignment = Enum.TextXAlignment.Center
	distanceLabel.Visible = CONFIG.ShowDistance
	distanceLabel.Parent = container
	
	-- Health Bar Background (centered)
	local healthBarBG = Instance.new("Frame")
	healthBarBG.Name = "HealthBarBG"
	healthBarBG.Size = UDim2.new(0.7, 0, 0.12, 0)
	healthBarBG.Position = UDim2.new(0.15, 0, 0.65, 0)
	healthBarBG.AnchorPoint = Vector2.new(0, 0)
	healthBarBG.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	healthBarBG.BackgroundTransparency = 0.3
	healthBarBG.BorderSizePixel = 0
	healthBarBG.Visible = CONFIG.HealthBarEnabled
	healthBarBG.Parent = container
	
	-- Health Bar Border
	local healthBarBorder = Instance.new("UIStroke")
	healthBarBorder.Color = Color3.fromRGB(255, 255, 255)
	healthBarBorder.Thickness = 1
	healthBarBorder.Transparency = 0.5
	healthBarBorder.Parent = healthBarBG
	
	-- Health Bar Fill
	local healthBar = Instance.new("Frame")
	healthBar.Name = "HealthBar"
	healthBar.Size = UDim2.new(1, 0, 1, 0)
	healthBar.Position = UDim2.new(0, 0, 0, 0)
	healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
	healthBar.BorderSizePixel = 0
	healthBar.Parent = healthBarBG
	
	-- Health Bar Corner
	local healthCorner = Instance.new("UICorner")
	healthCorner.CornerRadius = UDim.new(0, 2)
	healthCorner.Parent = healthBarBG
	
	local healthCorner2 = Instance.new("UICorner")
	healthCorner2.CornerRadius = UDim.new(0, 2)
	healthCorner2.Parent = healthBar
	
	-- Store ESP object
	ESPObjects[player] = {
		Billboard = billboard,
		Container = container,
		NameLabel = nameLabel,
		DistanceLabel = distanceLabel,
		HealthBar = healthBar,
		Character = character,
		Humanoid = humanoid,
		RootPart = humanoidRootPart,
		Head = head
	}
end

-- Remove ESP for a player
local function removeESP(player)
	if ESPObjects[player] then
		if ESPObjects[player].Billboard then
			ESPObjects[player].Billboard:Destroy()
		end
		ESPObjects[player] = nil
	end
end

-- Update ESP information
local function updateESP()
	if not CONFIG.Enabled then return end
	
	local camera = workspace.CurrentCamera
	local localChar = LocalPlayer.Character
	local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
	
	if not localRoot then return end
	
	for player, espData in pairs(ESPObjects) do
		if not player.Parent or not espData.Character.Parent then
			removeESP(player)
			continue
		end
		
		-- Team check
		if CONFIG.TeamCheck and player.Team == LocalPlayer.Team then
			espData.Billboard.Enabled = false
			continue
		end
		
		-- Distance check
		local distance = (localRoot.Position - espData.RootPart.Position).Magnitude
		if distance > CONFIG.MaxDistance then
			espData.Billboard.Enabled = false
			continue
		end
		
		espData.Billboard.Enabled = true
		
		-- Calculate and apply scale based on distance
		local scaleFactor = getScaleFactor(distance)
		local scaledTextSize = math.floor(CONFIG.BaseTextSize * scaleFactor)
		scaledTextSize = math.clamp(scaledTextSize, CONFIG.MinTextSize, CONFIG.MaxTextSize)
		
		-- Apply scaled text size
		espData.NameLabel.TextSize = scaledTextSize
		espData.DistanceLabel.TextSize = math.max(scaledTextSize - 2, CONFIG.MinTextSize)
		
		-- Scale the billboard size smoothly
		local scaledWidth = 200 * scaleFactor
		local scaledHeight = 60 * scaleFactor
		espData.Billboard.Size = UDim2.new(0, scaledWidth, 0, scaledHeight)
		
		-- Update distance
		if CONFIG.ShowDistance then
			espData.DistanceLabel.Text = string.format("%.0f studs", distance)
		end
		
		-- Update health bar
		if CONFIG.HealthBarEnabled and espData.Humanoid then
			local healthPercent = math.clamp(espData.Humanoid.Health / espData.Humanoid.MaxHealth, 0, 1)
			espData.HealthBar.Size = UDim2.new(healthPercent, 0, 1, 0)
			
			-- Color gradient from red to green
			local r = math.floor(math.clamp(255 * (1 - healthPercent) * 2, 0, 255))
			local g = math.floor(math.clamp(255 * healthPercent * 2, 0, 255))
			espData.HealthBar.BackgroundColor3 = Color3.fromRGB(r, g, 0)
		end
	end
end

-- Handle player added
local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		task.wait(0.5)
		createESP(player, character)
	end)
	
	if player.Character then
		createESP(player, player.Character)
	end
end

-- Handle player removed
local function onPlayerRemoving(player)
	removeESP(player)
end

-- Initialize for existing players
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- Connect events
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Update loop
RunService.RenderStepped:Connect(updateESP)

-- Enhanced API
_G.ESP = {
	Toggle = function(enabled)
		CONFIG.Enabled = enabled
		for _, espData in pairs(ESPObjects) do
			espData.Billboard.Enabled = enabled
		end
	end,
	
	SetMaxDistance = function(distance)
		CONFIG.MaxDistance = distance
	end,
	
	SetTeamCheck = function(enabled)
		CONFIG.TeamCheck = enabled
	end,
	
	SetScaling = function(enabled)
		CONFIG.ScaleWithDistance = enabled
	end,
	
	SetTextSize = function(size)
		CONFIG.BaseTextSize = size
	end,
	
	Refresh = function()
		for player, _ in pairs(ESPObjects) do
			removeESP(player)
		end
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character then
				createESP(player, player.Character)
			end
		end
	end,
	
	GetConfig = function()
		return CONFIG
	end
}

-- print("Enhanced ESP Framework Loaded!")
-- print("Commands:")
-- print("  _G.ESP.Toggle(false) - Disable ESP")
-- print("  _G.ESP.SetMaxDistance(500) - Set max render distance")
-- print("  _G.ESP.SetTeamCheck(true) - Only show enemies")
-- print("  _G.ESP.SetScaling(false) - Disable distance scaling")
-- print("  _G.ESP.SetTextSize(16) - Change base text size")