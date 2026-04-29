--!nonstrict
-- Persists per-player Coins/XP/Level via DataStore (best-effort).
-- Maintains an OrderedDataStore for the global Level leaderboard.
-- Sets up leaderstats so the in-game playerlist shows Coins / Level.

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DataManager = {}

local PROFILE_STORE
local LB_STORE
local ok, store = pcall(function()
    return DataStoreService:GetDataStore("PeniruProfiles_v1")
end)
if ok then PROFILE_STORE = store end

local ok2, store2 = pcall(function()
    return DataStoreService:GetOrderedDataStore(Config.LEADERBOARD_KEY)
end)
if ok2 then LB_STORE = store2 end

local cache: {
    [number]: {
        coins: number,
        xp: number,
        level: number,
        owned: { [string]: boolean },
        equipped: { [string]: string },  -- role -> itemId
        dirty: boolean,
    }
} = {}

local function defaultProfile()
    local owned = {}
    -- All players start with default skins owned.
    for _, item in ipairs(Config.SHOP) do
        if item.price == 0 then owned[item.id] = true end
    end
    return {
        coins = 0,
        xp = 0,
        level = 1,
        owned = owned,
        equipped = {
            Peniru = Config.DEFAULT_SKINS.Peniru,
            Warga  = Config.DEFAULT_SKINS.Warga,
        },
        dirty = false,
    }
end

local function safeLoad(userId: number)
    if not PROFILE_STORE then return defaultProfile() end
    local success, data = pcall(function()
        return PROFILE_STORE:GetAsync("u_" .. userId)
    end)
    if success and type(data) == "table" then
        local profile = defaultProfile()
        profile.coins = tonumber(data.coins) or 0
        profile.xp    = tonumber(data.xp) or 0
        profile.level = tonumber(data.level) or 1
        if type(data.owned) == "table" then
            for k, v in pairs(data.owned) do
                if v then profile.owned[k] = true end
            end
        end
        if type(data.equipped) == "table" then
            if type(data.equipped.Peniru) == "string" then profile.equipped.Peniru = data.equipped.Peniru end
            if type(data.equipped.Warga)  == "string" then profile.equipped.Warga  = data.equipped.Warga end
        end
        return profile
    end
    return defaultProfile()
end

local function safeSave(userId: number, profile)
    if not PROFILE_STORE then return end
    pcall(function()
        PROFILE_STORE:UpdateAsync("u_" .. userId, function(_)
            return {
                coins = profile.coins,
                xp = profile.xp,
                level = profile.level,
                owned = profile.owned,
                equipped = profile.equipped,
            }
        end)
    end)
    if LB_STORE then
        pcall(function()
            LB_STORE:SetAsync(tostring(userId), profile.level * 100000 + profile.xp)
        end)
    end
    profile.dirty = false
end

local function setupLeaderstats(player: Player, profile)
    local existing = player:FindFirstChild("leaderstats")
    if existing then existing:Destroy() end
    local ls = Instance.new("Folder")
    ls.Name = "leaderstats"
    ls.Parent = player

    local coinsVal = Instance.new("IntValue")
    coinsVal.Name = "Coins"
    coinsVal.Value = profile.coins
    coinsVal.Parent = ls

    local levelVal = Instance.new("IntValue")
    levelVal.Name = "Level"
    levelVal.Value = profile.level
    levelVal.Parent = ls

    local xpVal = Instance.new("IntValue")
    xpVal.Name = "XP"
    xpVal.Value = profile.xp
    xpVal.Parent = ls
end

local function syncLeaderstats(player: Player)
    local profile = cache[player.UserId]
    if not profile then return end
    local ls = player:FindFirstChild("leaderstats")
    if not ls then return end
    if ls:FindFirstChild("Coins") then ls.Coins.Value = profile.coins end
    if ls:FindFirstChild("Level") then ls.Level.Value = profile.level end
    if ls:FindFirstChild("XP")    then ls.XP.Value    = profile.xp end
end

function DataManager.onPlayerAdded(player: Player)
    local profile = safeLoad(player.UserId)
    cache[player.UserId] = profile
    setupLeaderstats(player, profile)
end

function DataManager.onPlayerRemoving(player: Player)
    local profile = cache[player.UserId]
    if profile and profile.dirty then
        safeSave(player.UserId, profile)
    end
    cache[player.UserId] = nil
end

function DataManager.getProfile(player: Player)
    return cache[player.UserId]
end

function DataManager.addXp(player: Player, amount: number)
    local p = cache[player.UserId]
    if not p then return end
    p.xp = math.max(0, p.xp + amount)
    while p.xp >= Config.XP_PER_LEVEL do
        p.xp -= Config.XP_PER_LEVEL
        p.level += 1
    end
    p.dirty = true
    syncLeaderstats(player)
end

function DataManager.addCoins(player: Player, amount: number)
    local p = cache[player.UserId]
    if not p then return end
    p.coins = math.max(0, p.coins + amount)
    p.dirty = true
    syncLeaderstats(player)
end

function DataManager.getLeaderboard(): { { name: string, level: number, xp: number, userId: number } }
    if not LB_STORE then return {} end
    local ok3, page = pcall(function()
        return LB_STORE:GetSortedAsync(false, Config.LEADERBOARD_TOP)
    end)
    if not ok3 or not page then return {} end
    local current = page:GetCurrentPage()
    local out = {}
    for _, entry in ipairs(current) do
        local userId = tonumber(entry.key)
        if userId then
            local val = entry.value or 0
            local level = math.floor(val / 100000)
            local xp = val % 100000
            local name = "Player_" .. tostring(userId)
            local nameOk, nameRes = pcall(function()
                return Players:GetNameFromUserIdAsync(userId)
            end)
            if nameOk and nameRes then name = nameRes end
            table.insert(out, { name = name, level = level, xp = xp, userId = userId })
        end
    end
    return out
end

-- Shop helpers --

local function findShopItem(itemId: string)
    for _, it in ipairs(Config.SHOP) do
        if it.id == itemId then return it end
    end
    return nil
end

function DataManager.getShopState(player: Player)
    local p = cache[player.UserId]
    if not p then
        return { owned = {}, equipped = {}, coins = 0, catalog = Config.SHOP }
    end
    return {
        owned = p.owned,
        equipped = p.equipped,
        coins = p.coins,
        catalog = Config.SHOP,
    }
end

function DataManager.purchase(player: Player, itemId: string): (boolean, string)
    local p = cache[player.UserId]
    if not p then return false, "Profile not loaded" end
    local item = findShopItem(itemId)
    if not item then return false, "Item tidak ditemukan" end
    if p.owned[itemId] then return false, "Sudah dimiliki" end
    if p.coins < item.price then
        return false, "Coin tidak cukup"
    end
    p.coins = p.coins - item.price
    p.owned[itemId] = true
    p.dirty = true
    syncLeaderstats(player)
    return true, "Berhasil membeli " .. item.name
end

function DataManager.equip(player: Player, itemId: string): (boolean, string)
    local p = cache[player.UserId]
    if not p then return false, "Profile not loaded" end
    local item = findShopItem(itemId)
    if not item then return false, "Item tidak ditemukan" end
    if not p.owned[itemId] then return false, "Belum dimiliki" end
    if item.role ~= "Peniru" and item.role ~= "Warga" then
        return false, "Slot tidak valid"
    end
    p.equipped[item.role] = itemId
    p.dirty = true
    return true, "Berhasil dipakai"
end

function DataManager.getEquippedSkin(player: Player, roleName: string)
    local p = cache[player.UserId]
    if not p then return nil end
    local id = p.equipped[roleName] or Config.DEFAULT_SKINS[roleName]
    return findShopItem(id)
end

function DataManager.startAutoSave()
    task.spawn(function()
        while true do
            task.wait(60)
            for userId, profile in pairs(cache) do
                if profile.dirty then
                    safeSave(userId, profile)
                end
            end
        end
    end)
end

return DataManager
