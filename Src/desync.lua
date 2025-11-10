local Desync = {
    Enabled = false,
    Method = "Velocity", -- "Velocity" | "CFrame" | "Hybrid"
    Settings = {
        Intensity = 15,        -- How far to desync (studs)
        WalkSpeed = 16,       -- Default walkspeed while desynced
        AutoDisable = true,   -- Disable when damaged
        AutoEnable = true,    -- Re-enable after disable timeout
        DisableTime = 1,      -- How long to stay disabled after damage
        LerpBack = true,      -- Smooth lerp back to real position when disabled
        LerpSpeed = 0.5,      -- Speed of lerp back to position
        Visualize = true,     -- Show fake character position
        RandomizeOffset = true, -- Randomize desync direction
        OffsetUpdateRate = 0.1, -- How often to change random offset
        ToggleKey = Enum.KeyCode.G, -- Key to toggle desync
    },
    Debug = {
        ShowStats = false,
        Warnings = true,
    }
}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local NetworkSettings = settings().Network
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

-- Variables
local LastPosition = RootPart.CFrame
local FakePosition = RootPart.CFrame
local DesyncOffset = Vector3.new()
local LastUpdateTime = tick()
local DisabledUntil = 0
local Connections = {}
local FakeChar = nil
local IsJumping = false

-- Cleanup old instance
if _G.UnloadDesync then
    _G.UnloadDesync()
end

-- Network spoofing setup
local function setupNetworkSpoofing()
    local oldIndex = nil
    oldIndex = hookmetamethod(game, "__index", function(self, key)
        if not checkcaller() and key == "SimulationRadius" then
            return 9e9
        end
        return oldIndex(self, key)
    end)

    NetworkSettings.IncomingReplicationLag = 0
end

-- Create fake character for visualization
local function createFakeCharacter()
    if FakeChar then FakeChar:Destroy() end
    FakeChar = Character:Clone()
    
    -- Clean up clone
    for _, v in pairs(FakeChar:GetDescendants()) do
        if v:IsA("BasePart") then
            v.Material = Enum.Material.ForceField
            v.Color = Color3.new(1, 0, 0)
            v.Transparency = 0.5
            v.CanCollide = false
        elseif v:IsA("Decal") or v:IsA("Texture") then
            v:Destroy()
        elseif v:IsA("Script") or v:IsA("LocalScript") then
            v:Destroy()
        end
    end
    
    -- Remove unnecessary parts
    local humanoid = FakeChar:FindFirstChild("Humanoid")
    if humanoid then humanoid:Destroy() end
    
    FakeChar.Parent = workspace
    return FakeChar
end

-- Update fake character position
local function updateFakeCharacter()
    if not FakeChar then return end
    for _, part in pairs(FakeChar:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CFrame = part.CFrame + DesyncOffset
        end
    end
end

-- Calculate random offset
local function updateRandomOffset()
    if not Desync.Settings.RandomizeOffset then return end
    if tick() - LastUpdateTime < Desync.Settings.OffsetUpdateRate then return end
    
    local angle = math.random() * math.pi * 2
    DesyncOffset = Vector3.new(
        math.cos(angle) * Desync.Settings.Intensity,
        0,
        math.sin(angle) * Desync.Settings.Intensity
    )
    LastUpdateTime = tick()
end

-- Main desync logic
local function applyDesync()
    if not Desync.Enabled or tick() < DisabledUntil then return end
    
    updateRandomOffset()
    
    -- Store real position
    LastPosition = RootPart.CFrame
    
    -- Apply desync based on method
    if Desync.Method == "Velocity" then
        -- Velocity-based desync
        RootPart.Velocity = Vector3.new(0, Humanoid.Jump and Desync.Settings.Intensity or 0, 0)
        RootPart.AssemblyLinearVelocity = Vector3.new(0, Humanoid.Jump and Desync.Settings.Intensity or 0, 0)
    elseif Desync.Method == "CFrame" then
        -- CFrame-based desync
        RootPart.CFrame = RootPart.CFrame + DesyncOffset
        RootPart.AssemblyLinearVelocity = Vector3.new()
    elseif Desync.Method == "Hybrid" then
        -- Hybrid method
        RootPart.CFrame = RootPart.CFrame + DesyncOffset * 0.5
        RootPart.Velocity = DesyncOffset.Unit * Desync.Settings.Intensity
    end
    
    -- Update visualization
    if Desync.Settings.Visualize then
        updateFakeCharacter()
    end
end

-- Handle character changes
local function onCharacterAdded(char)
    Character = char
    RootPart = Character:WaitForChild("HumanoidRootPart")
    Humanoid = Character:WaitForChild("Humanoid")
    LastPosition = RootPart.CFrame
    
    if Desync.Settings.Visualize then
        createFakeCharacter()
    end
end

-- Auto-disable on damage
local function onDamaged()
    if not Desync.Settings.AutoDisable then return end
    
    Desync.Enabled = false
    DisabledUntil = tick() + Desync.Settings.DisableTime
    
    -- Lerp back to real position
    if Desync.Settings.LerpBack then
        local startPos = RootPart.CFrame
        local endPos = LastPosition
        
        for i = 0, 1, Desync.Settings.LerpSpeed do
            if not Desync.Enabled then
                RootPart.CFrame = startPos:Lerp(endPos, i)
                task.wait()
            end
        end
    end
    
    -- Auto re-enable
    if Desync.Settings.AutoEnable then
        task.wait(Desync.Settings.DisableTime)
        Desync.Enabled = true
    end
end

-- Setup connections
Connections.CharacterAdded = LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
Connections.Damaged = Humanoid.HealthChanged:Connect(function(health)
    if health < Humanoid.Health then
        onDamaged()
    end
end)

-- Setup heartbeat update
Connections.Heartbeat = RunService.Heartbeat:Connect(function()
    if Desync.Enabled and Character and RootPart then
        applyDesync()
    end
end)

-- Setup toggle key
local UserInputService = game:GetService("UserInputService")
Connections.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Desync.Settings.ToggleKey then
        Desync.Enabled = not Desync.Enabled
        print("Desync: " .. (Desync.Enabled and "Enabled" or "Disabled"))
        
        -- Show/hide visualization
        if FakeChar then
            FakeChar.Parent = Desync.Enabled and workspace or nil
        elseif Desync.Enabled and Desync.Settings.Visualize then
            createFakeCharacter()
        end
    end
end)

-- Initialize if visualization is enabled
if Desync.Settings.Visualize then
    createFakeCharacter()
    -- Hide visualization initially since desync starts disabled
    if FakeChar then
        FakeChar.Parent = nil
    end
end

-- Public API
_G.Desync = Desync
_G.UnloadDesync = function()
    Desync.Enabled = false
    
    -- Cleanup connections
    for _, connection in pairs(Connections) do
        connection:Disconnect()
    end
    
    -- Remove fake character
    if FakeChar then
        FakeChar:Destroy()
    end
    
    -- Clear globals
    _G.Desync = nil
    _G.UnloadDesync = nil
end

-- Setup network spoofing
setupNetworkSpoofing()

-- Print info
print(string.format([[Desync loaded!
Method: %s
Intensity: %d studs
Auto Disable: %s
Visualization: %s]], 
Desync.Method,
Desync.Settings.Intensity,
tostring(Desync.Settings.AutoDisable),
tostring(Desync.Settings.Visualize)))

-- Usage example:
--[[
    -- Enable desync
    _G.Desync.Enabled = true
    
    -- Change method
    _G.Desync.Method = "Velocity" -- or "CFrame" or "Hybrid"
    
    -- Adjust settings
    _G.Desync.Settings.Intensity = 20
    _G.Desync.Settings.AutoDisable = false
    
    -- Unload completely
    _G.UnloadDesync()
]]