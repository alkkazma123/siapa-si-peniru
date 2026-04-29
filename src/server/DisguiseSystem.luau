--!nonstrict
-- Allows the Peniru to disguise as a nearby Warga: copies DisplayName, BodyColors,
-- HumanoidDescription (avatar appearance), and the overhead level tag.
-- Original appearance is restored on round end.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DisguiseSystem = {}

local OverheadManager
local DataManager
local Remotes

local originals: { [number]: {
    displayName: string,
    description: HumanoidDescription?,
    rigType: Enum.HumanoidRigType?,
} } = {}

local cooldowns: { [number]: number } = {}

local function getHumanoid(player: Player): Humanoid?
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function captureOriginal(player: Player)
    if originals[player.UserId] then return end
    local hum = getHumanoid(player)
    if not hum then return end
    local desc
    pcall(function()
        desc = hum:GetAppliedDescription()
    end)
    originals[player.UserId] = {
        displayName = player.DisplayName,
        description = desc,
        rigType = hum.RigType,
    }
end

local function findNearestTarget(peniru: Player, alivePlayers: { Player }, excludeUserIds: { [number]: boolean }): Player?
    local pchar = peniru.Character
    if not pchar then return nil end
    local pRoot = pchar:FindFirstChild("HumanoidRootPart")
    if not pRoot then return nil end

    local nearest, nearestDist = nil, math.huge
    for _, p in ipairs(alivePlayers) do
        if p ~= peniru and not excludeUserIds[p.UserId] then
            local c = p.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if r then
                local d = (r.Position - pRoot.Position).Magnitude
                if d < nearestDist then
                    nearestDist = d
                    nearest = p
                end
            end
        end
    end
    return nearest
end

function DisguiseSystem.tryDisguise(peniru: Player, alivePlayers: { Player }, excludeUserIds: { [number]: boolean })
    local now = os.clock()
    if (cooldowns[peniru.UserId] or 0) > now then
        return false, "Cooldown aktif"
    end
    local target = findNearestTarget(peniru, alivePlayers, excludeUserIds)
    if not target then
        return false, "Tidak ada target di sekitar"
    end

    captureOriginal(peniru)

    local hum = getHumanoid(peniru)
    local targetHum = getHumanoid(target)
    if not hum or not targetHum then
        return false, "Karakter tidak siap"
    end

    -- Copy display name
    pcall(function()
        peniru.DisplayName = target.DisplayName
    end)

    -- Copy avatar appearance
    local desc
    pcall(function()
        desc = targetHum:GetAppliedDescription():Clone()
    end)
    if desc then
        pcall(function()
            hum:ApplyDescription(desc)
        end)
    end

    -- Copy overhead level tag
    local profile = DataManager and DataManager.getProfile(target)
    local lvl = profile and profile.level or 1
    if OverheadManager then
        OverheadManager.applyDisguise(peniru, target.DisplayName, lvl)
    end

    cooldowns[peniru.UserId] = now + Config.DISGUISE_COOLDOWN

    if Remotes then
        Remotes.event("DisguiseUpdated"):FireAllClients(peniru, target)
    end
    return true, target
end

function DisguiseSystem.restore(player: Player)
    local data = originals[player.UserId]
    originals[player.UserId] = nil
    if not data then
        if OverheadManager then OverheadManager.refresh(player) end
        return
    end
    local hum = getHumanoid(player)
    pcall(function()
        player.DisplayName = data.displayName
    end)
    if hum and data.description then
        pcall(function()
            hum:ApplyDescription(data.description)
        end)
    end
    if OverheadManager then
        OverheadManager.refresh(player)
    end
    if Remotes then
        Remotes.event("DisguiseUpdated"):FireAllClients(player, nil)
    end
end

function DisguiseSystem.restoreAll()
    for userId, _ in pairs(originals) do
        local p = Players:GetPlayerByUserId(userId)
        if p then DisguiseSystem.restore(p) end
    end
    originals = {}
    cooldowns = {}
end

function DisguiseSystem.init(deps)
    OverheadManager = deps.OverheadManager
    DataManager     = deps.DataManager
    Remotes         = deps.Remotes
end

function DisguiseSystem.getCooldownEnd(player: Player): number
    return cooldowns[player.UserId] or 0
end

return DisguiseSystem
