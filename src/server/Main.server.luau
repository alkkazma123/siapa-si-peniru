--!nonstrict
-- Main server entry. Wires up all modules.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local serverFolder = script.Parent
local MapBuilder      = require(serverFolder:WaitForChild("MapBuilder"))
local DataManager     = require(serverFolder:WaitForChild("DataManager"))
local OverheadManager = require(serverFolder:WaitForChild("OverheadManager"))
local DisguiseSystem  = require(serverFolder:WaitForChild("DisguiseSystem"))
local GameManager     = require(serverFolder:WaitForChild("GameManager"))

print("[SiapaSiPeniru] Booting server modules...")

-- 1. Build the world programmatically.
local mapInfo = MapBuilder.build()

-- 2. Set CharacterAutoLoads to true (default) and override default spawn behavior
Players.CharacterAutoLoads = true
Players.RespawnTime = 1.5

-- 3. DataManager + Overhead
DataManager.startAutoSave()
OverheadManager.init(DataManager)

-- 4. Disguise system depends on Overhead + DataManager + Remotes
DisguiseSystem.init({
    OverheadManager = OverheadManager,
    DataManager     = DataManager,
    Remotes         = Remotes,
})

-- 5. Player connection handlers (data + spawn into lobby)
local function onCharacterAdded(player: Player, char: Model)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum and hum:IsA("Humanoid") then
        hum.WalkSpeed = 18
        hum.JumpPower = 50
    end
    -- Default spawn into lobby
    task.wait(0.1)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and GameManager.getState() == Config.STATES.LOBBY then
        hrp.CFrame = mapInfo.lobbyCFrame
    end
end

local function onPlayerAdded(player: Player)
    DataManager.onPlayerAdded(player)
    player.CharacterAdded:Connect(function(char)
        onCharacterAdded(player, char)
    end)
    if player.Character then
        onCharacterAdded(player, player.Character)
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
    DataManager.onPlayerRemoving(player)
end)
for _, p in ipairs(Players:GetPlayers()) do
    onPlayerAdded(p)
end

-- 6. Remote functions
Remotes.func("GetLeaderboard").OnServerInvoke = function(_player)
    return DataManager.getLeaderboard()
end
Remotes.func("GetMyData").OnServerInvoke = function(player)
    local p = DataManager.getProfile(player)
    if not p then return { coins = 0, xp = 0, level = 1 } end
    return { coins = p.coins, xp = p.xp, level = p.level, xpPerLevel = Config.XP_PER_LEVEL }
end
Remotes.func("GetGameState").OnServerInvoke = function(_player)
    return { state = GameManager.getState() }
end

-- 7. Run the game loop
GameManager.init({
    Remotes         = Remotes,
    DataManager     = DataManager,
    OverheadManager = OverheadManager,
    DisguiseSystem  = DisguiseSystem,
    mapInfo         = mapInfo,
})

print("[SiapaSiPeniru] Server ready.")
