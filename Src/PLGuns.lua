-- Unload previous instance if exists
if _G.UnloadRespawnGunScript then
    _G.UnloadRespawnGunScript()
end

--// Services & Variables
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

-- Weapon giver positions
local WeaponGivers = {
    AK47 = CFrame.new(-922.312683, 91.2782822, 2051.95361, -0.173624277, 0, 0.984811902, 0, 1, 0, -0.984811902, 0, -0.173624277),
    Remington = CFrame.new(820.298584, 97.8500061, 2217.39624, 1, 0, 0, 0, 1, 0, 0, 0, 1)
}

local connections = {}
local isTeleporting = false

--// Anti-Kick Teleport Function
local function SafeTeleport(targetCFrame, callback)
    if isTeleporting then return end
    isTeleporting = true
    
    local character = LocalPlayer.Character
    if not character then 
        isTeleporting = false
        return 
    end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    
    if not hrp or not humanoid then 
        isTeleporting = false
        return 
    end
    
    -- Save original position
    local originalCFrame = hrp.CFrame
    
    -- Disable character physics temporarily
    local originalWalkSpeed = humanoid.WalkSpeed
    humanoid.WalkSpeed = 0
    
    -- Use PivotTo for smoother teleport (less detectable)
    task.wait(0.1) -- Small delay to appear more natural
    character:PivotTo(targetCFrame)
    
    -- Wait for pickup
    task.wait(0.3) -- Increased wait time for weapon pickup
    
    -- Return to original position
    character:PivotTo(originalCFrame)
    task.wait(0.1)
    
    -- Restore movement
    humanoid.WalkSpeed = originalWalkSpeed
    
    if callback then callback() end
    
    isTeleporting = false
end

--// Get Weapons Function
local function GetWeapons()
    -- Get AK47
    SafeTeleport(WeaponGivers.AK47, function()
        -- print("Entropy Guns | AK47 acquired")
    end)
    
    -- Wait between weapon pickups to avoid detection
    task.wait(1)
    
    -- Uncomment to also get Remington
    SafeTeleport(WeaponGivers.Remington, function()
        -- print("Entropy Guns | Remington acquired")
    end)
end

--// Character Respawn Handler
local function OnCharacterAdded(character)
    local hrp = character:WaitForChild("HumanoidRootPart", 10)
    if not hrp then return end
    
    -- Wait for character to fully load
    task.wait(1)
    
    GetWeapons()
end

--// Setup connections
if LocalPlayer.Character then
    OnCharacterAdded(LocalPlayer.Character)
end

table.insert(connections, LocalPlayer.CharacterAdded:Connect(OnCharacterAdded))

--// Manual trigger (optional - press 'G' key)
table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.G then
        -- print("Entropy Guns | Manual weapon grab triggered")
        GetWeapons()
    end
end))

--// Unload function
_G.UnloadRespawnGunScript = function()
    for _, connection in pairs(connections) do
        connection:Disconnect()
    end
    connections = {}
    isTeleporting = false
    -- print("Entropy Guns | Unloaded!")
end

-- print("Entropy Guns | Loaded successfully")
-- print("Entropy Guns | Press 'G' to manually grab weapons")

local namecall
namecall = hookmetamethod(game, "__namecall",
function(self,...)
    local method = getnamecallmethod()
    if method == "GetAttributes" then
        local result = namecall(self, ...)
        result.AutoFire = true
        result.MaxAmmo = 100
        result.Range = 200
        result.Spread = 0
        -- print(self," | Modded")
        return result
    end
    return namecall(self, ...)
end)