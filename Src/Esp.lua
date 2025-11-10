-- Enhanced Nametag/ESP Framework for Roblox
-- Place this in StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace and workspace.CurrentCamera

-- Sense-style Drawing-based ESP
-- Features: 2D box, name, distance, health bar, tracer, team check, distance scaling

local CONFIG = {
	Enabled = true,
	Box = true,
	Name = true,
	Tracer = false,
	ShowDistance = true,
	ShowHealth = true,
	MaxDistance = 1000,
	MinDistance = 10,
	BaseTextSize = 14,
	ScaleWithDistance = true,
	TeamCheck = true,
	Outline = true,
	Font = 2, -- Drawing font (SystemFont=1, Franke=2 etc. varies by runtime)
	SmoothLerp = true, -- Enable smooth position transitions
	LerpSpeed = 0.3, -- Lower = smoother but slower
	UpdateRate = 10, -- Updates per second (higher = more responsive but more CPU)
}

local hasDrawing = pcall(function() return Drawing and Drawing.new end)
local ESPObjects = {}
local Connections = {} -- Store connections for cleanup
local LastUpdate = 0 -- Time tracking for update rate limiting
local CachedPlayers = {} -- Cache player data

local function safeNew(typeName)
	if not hasDrawing then return nil end
	local ok, obj = pcall(function() return Drawing.new(typeName) end)
	if ok then return obj end
	return nil
end

local function teamColor(player)
	if CONFIG.TeamCheck and LocalPlayer and player.Team == LocalPlayer.Team then
		return Color3.fromRGB(180, 180, 180)
	end
	-- enemies default color
	return Color3.fromRGB(255, 80, 80)
end

-- Lerp helper for smooth transitions
local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerpVector2(a, b, t)
    return Vector2.new(
        lerp(a.X, b.X, t),
        lerp(a.Y, b.Y, t)
    )
end

local function getScaleFactor(distance)
	if not CONFIG.ScaleWithDistance then return 1 end
	local normalized = math.clamp(distance / CONFIG.MaxDistance, 0, 1)
	local scale = 1 - (normalized ^ 0.7) * 0.65
	return math.clamp(scale, 0.35, 1.2)
end

local function createDrawingSet(player)
	local set = {}
	set.BoxOutline = safeNew("Square")
	set.Box = safeNew("Square")
	set.Tracer = safeNew("Line")
	set.Name = safeNew("Text")
	set.Health = safeNew("Square")
	set.HealthBG = safeNew("Square")
	set.Distance = safeNew("Text")

	-- initialize safe defaults
	if set.Box then
		set.Box.Filled = false
		set.Box.Transparency = 1
		set.Box.Thickness = 1
	end
	if set.BoxOutline then
		set.BoxOutline.Filled = false
		set.BoxOutline.Transparency = 1
		set.BoxOutline.Thickness = 3
	end
	if set.Tracer then
		set.Tracer.Thickness = 1
		set.Tracer.Transparency = 1
	end
	if set.Name then
		set.Name.Center = true
		set.Name.Outline = CONFIG.Outline
		set.Name.Size = CONFIG.BaseTextSize
		set.Name.Color = Color3.fromRGB(255,255,255)
	end
	if set.Distance then
		set.Distance.Center = true
		set.Distance.Outline = CONFIG.Outline
		set.Distance.Size = CONFIG.BaseTextSize - 2
		set.Distance.Color = Color3.fromRGB(200,200,200)
	end
	if set.Health then
		set.Health.Filled = true
		set.Health.Transparency = 1
	end
	if set.HealthBG then
		set.HealthBG.Filled = true
		set.HealthBG.Transparency = 0.6
		set.HealthBG.Color = Color3.fromRGB(0,0,0)
	end

	return set
end

local function removeESP(player)
	local data = ESPObjects[player]
	if not data then return end
	if hasDrawing then
		for k,v in pairs(data.Drawings or {}) do
			if v and v.Visible ~= nil then
				pcall(function() v.Visible = false end)
				pcall(function() v:Remove() end)
			end
		end
	end
	ESPObjects[player] = nil
end

local function createESP(player, character)
	if player == LocalPlayer then return end
	if ESPObjects[player] then return end
	if not character then return end

	local head = character:FindFirstChild("Head")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
	if not head or not humanoid or not root then return end

	local data = {}
	data.Player = player
	data.Character = character
	data.Head = head
	data.Root = root
	data.Humanoid = humanoid
	data.Drawings = createDrawingSet(player)

	ESPObjects[player] = data
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(char)
		task.wait(0.4)
		createESP(player, char)
	end)
	if player.Character then
		createESP(player, player.Character)
	end
end

local function onPlayerRemoving(player)
	removeESP(player)
end

-- Project a world position to screen and return x,y, onScreen
local function toScreen(pos)
	if not Camera then Camera = workspace.CurrentCamera end
	if not Camera then return 0,0,false end
	local p, onScreen = Camera:WorldToViewportPoint(pos)
	return Vector2.new(p.X, p.Y), onScreen
end

local function updateESP()
    if not CONFIG.Enabled then
        -- hide all drawings when disabled
        for _, data in pairs(ESPObjects) do
            for _, d in pairs(data.Drawings or {}) do
                if d and d.Visible ~= nil then pcall(function() d.Visible = false end) end
            end
        end
        return
    end

    local localChar = LocalPlayer and LocalPlayer.Character
    local localRoot = localChar and (localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Torso"))
    if not localRoot or not Camera then return end
    
    -- Cache camera position for performance
    local cameraPos = Camera.CFrame.Position

	for player, data in pairs(ESPObjects) do
		if not player or not player.Parent or not data.Character or not data.Character.Parent then
			removeESP(player)
			continue
		end

		-- team check
		if CONFIG.TeamCheck and player.Team == LocalPlayer.Team then
			for _, d in pairs(data.Drawings) do if d and d.Visible ~= nil then d.Visible = false end end
			continue
		end

        local cache = CachedPlayers[player]
        if not cache then
            cache = {
                lastPos = Vector3.new(),
                lastScale = 1,
                smoothPos = Vector2.new(),
                smoothScale = 1
            }
            CachedPlayers[player] = cache
        end

        local headPos = data.Head and data.Head.Position or data.Root.Position
        local rootPos = data.Root.Position
        
        -- Use distance from camera for better depth perception
        local distance = (cameraPos - rootPos).Magnitude
        if distance > CONFIG.MaxDistance then
            for _, d in pairs(data.Drawings) do if d and d.Visible ~= nil then d.Visible = false end end
            continue
        end

        local screenTop, topOn = toScreen(headPos + Vector3.new(0, 0.6, 0))
        local screenBottom, bottomOn = toScreen(rootPos - Vector3.new(0, 1, 0))
        local onScreen = topOn or bottomOn

        -- Smooth position transitions
        if CONFIG.SmoothLerp and cache.lastPos ~= Vector3.new() then
            screenTop = lerpVector2(cache.smoothPos, screenTop, CONFIG.LerpSpeed)
            cache.smoothPos = screenTop
        else
            cache.smoothPos = screenTop
        end
        cache.lastPos = rootPos

        local color = teamColor(player)
        local scale = getScaleFactor(distance)
        
        -- Smooth scale transitions
        if CONFIG.SmoothLerp then
            scale = lerp(cache.smoothScale, scale, CONFIG.LerpSpeed)
            cache.smoothScale = scale
        else
            cache.smoothScale = scale
        end

		-- estimate box dimensions
		local height = math.max(10, math.abs(bottomOn and screenBottom.Y or 0 - (topOn and screenTop.Y or 0)))
		local width = math.max(6, height * 0.6)
		local boxPos = Vector2.new((screenTop.X + (screenBottom.X or screenTop.X)) / 2 - width/2, (screenTop.Y))

		-- Box Outline
		local boxOutline = data.Drawings.BoxOutline
		if boxOutline then
			boxOutline.Visible = onScreen
			boxOutline.Size = Vector2.new(width + 6, height + 6)
			boxOutline.Position = boxPos - Vector2.new(3, 3)
			boxOutline.Color = Color3.new(0,0,0)
			boxOutline.Thickness = 3
		end

		-- Box
		local box = data.Drawings.Box
		if box then
			box.Visible = onScreen
			box.Size = Vector2.new(width, height)
			box.Position = boxPos
			box.Color = color
			box.Thickness = 1
		end

		-- Name
		local nameText = data.Drawings.Name
		if nameText then
			nameText.Visible = onScreen and CONFIG.Name
			nameText.Position = Vector2.new(boxPos.X + width/2, boxPos.Y - (12 * scale))
			nameText.Text = player.Name
			nameText.Size = CONFIG.BaseTextSize * scale
			nameText.Color = Color3.fromRGB(255,255,255)
			nameText.Font = CONFIG.Font
		end

		-- Distance
		local distText = data.Drawings.Distance
		if distText then
			distText.Visible = onScreen and CONFIG.ShowDistance
			distText.Position = Vector2.new(boxPos.X + width/2, boxPos.Y + height + (2 * scale))
			distText.Text = string.format("%.0f studs", distance)
			distText.Size = math.max(10, (CONFIG.BaseTextSize - 2) * scale)
			distText.Color = Color3.fromRGB(200,200,200)
			distText.Font = CONFIG.Font
		end

		-- Health bar (left side)
		local healthBG = data.Drawings.HealthBG
		local health = data.Drawings.Health
		if healthBG and health then
			healthBG.Visible = onScreen and CONFIG.ShowHealth
			health.Visible = onScreen and CONFIG.ShowHealth
			local hbW = math.max(3, width * 0.08)
			local hbH = math.max(4, height)
			local hbX = boxPos.X - hbW - 4
			local hbY = boxPos.Y
			healthBG.Position = Vector2.new(hbX, hbY)
			healthBG.Size = Vector2.new(hbW, hbH)
			healthBG.Color = Color3.fromRGB(0,0,0)

			local hpPercent = 1
			if data.Humanoid and data.Humanoid.MaxHealth > 0 then
				hpPercent = math.clamp(data.Humanoid.Health / data.Humanoid.MaxHealth, 0, 1)
			end
			health.Position = Vector2.new(hbX, hbY + (hbH * (1 - hpPercent)))
			health.Size = Vector2.new(hbW, hbH * hpPercent)
			-- gradient approximation
			local r = math.clamp(255 * (1 - hpPercent) * 2, 0, 255)
			local g = math.clamp(255 * hpPercent * 2, 0, 255)
			health.Color = Color3.fromRGB(r, g, 0)
		end

		-- Tracer (to bottom center)
		local tracer = data.Drawings.Tracer
		if tracer then
			tracer.Visible = onScreen and CONFIG.Tracer
			local screenSize = Camera and Vector2.new(Camera.ViewportSize.X, Camera.ViewportSize.Y) or Vector2.new(0,0)
			tracer.From = Vector2.new(screenSize.X/2, screenSize.Y)
			tracer.To = Vector2.new(boxPos.X + width/2, boxPos.Y + height)
			tracer.Color = color
		end
	end
end

-- Connect players and store connections for cleanup
local function init()
    for _, p in ipairs(Players:GetPlayers()) do
        onPlayerAdded(p)
        CachedPlayers[p] = {
            lastPos = Vector3.new(),
            lastScale = 1,
            smoothPos = Vector2.new(),
            smoothScale = 1
        }
    end
    
    table.insert(Connections, Players.PlayerAdded:Connect(function(p)
        onPlayerAdded(p)
        CachedPlayers[p] = {
            lastPos = Vector3.new(),
            lastScale = 1,
            smoothPos = Vector2.new(),
            smoothScale = 1
        }
    end))
    
    table.insert(Connections, Players.PlayerRemoving:Connect(function(p)
        onPlayerRemoving(p)
        CachedPlayers[p] = nil
    end))

    -- Throttled update based on CONFIG.UpdateRate
    table.insert(Connections, RunService.RenderStepped:Connect(function()
        local now = os.clock()
        if now - LastUpdate >= (1 / CONFIG.UpdateRate) then
            LastUpdate = now
            pcall(updateESP)
        end
    end))
end

-- Cleanup function to remove all traces of ESP
local function cleanup()
    -- Disconnect all connections
    for _, connection in ipairs(Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(Connections)
    
    -- Remove all ESP objects
    for player, _ in pairs(ESPObjects) do
        removeESP(player)
    end
    table.clear(ESPObjects)
    
    -- Clear caches
    table.clear(CachedPlayers)
    Camera = nil
end

-- Initialize
init()

-- Public API with improved performance and unload capability
_G.ESP = _G.ESP or {}

-- Core functions
_G.ESP.Toggle = function(enabled)
    CONFIG.Enabled = enabled
    if not enabled then
        -- Hide all drawings when disabled but don't destroy
        for _, data in pairs(ESPObjects) do
            for _, d in pairs(data.Drawings or {}) do
                if d and d.Visible ~= nil then 
                    pcall(function() d.Visible = false end)
                end
            end
        end
    end
end

-- Performance settings
_G.ESP.SetUpdateRate = function(rate)
    CONFIG.UpdateRate = math.clamp(rate, 1, 144)
end

_G.ESP.SetSmoothing = function(enabled, speed)
    CONFIG.SmoothLerp = enabled
    if speed then
        CONFIG.LerpSpeed = math.clamp(speed, 0.1, 1)
    end
end

-- Visual settings
_G.ESP.SetMaxDistance = function(d) CONFIG.MaxDistance = d end
_G.ESP.SetTeamCheck = function(b) CONFIG.TeamCheck = b end
_G.ESP.SetScaling = function(b) CONFIG.ScaleWithDistance = b end
_G.ESP.SetTextSize = function(s) CONFIG.BaseTextSize = s end
_G.ESP.ToggleBox = function(b) CONFIG.Box = b end
_G.ESP.ToggleName = function(b) CONFIG.Name = b end
_G.ESP.ToggleTracer = function(b) CONFIG.Tracer = b end

-- Maintenance functions
_G.ESP.Refresh = function()
    for p,_ in pairs(ESPObjects) do removeESP(p) end
    table.clear(CachedPlayers)
    for _,p in ipairs(Players:GetPlayers()) do 
        onPlayerAdded(p)
        CachedPlayers[p] = {
            lastPos = Vector3.new(),
            lastScale = 1,
            smoothPos = Vector2.new(),
            smoothScale = 1
        }
    end
end

_G.ESP.Unload = function()
    cleanup()
    _G.ESP = nil
end

print(string.format("Sense-style ESP loaded (Drawing: %s, UpdateRate: %d fps, Smooth: %s)", 
    tostring(hasDrawing), CONFIG.UpdateRate, tostring(CONFIG.SmoothLerp)))