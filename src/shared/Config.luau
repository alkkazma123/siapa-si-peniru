--!nonstrict
-- Shared config for "Siapa Si Peniru"

local Config = {}

-- ROUND TIMINGS
Config.MIN_PLAYERS              = 3
Config.LOBBY_COUNTDOWN          = 15
Config.ROUND_DURATION_BASE      = 45
Config.ROUND_DURATION_PER_EXTRA = 5
Config.ROUND_DURATION_MIN       = 30
Config.ROUND_DURATION_MAX       = 60
Config.ROUND_EXTENSION          = 30   -- after a wrong vote, give this many seconds back to round
Config.VOTING_DURATION          = 25   -- a bit longer to allow chat discussion
Config.REVEAL_DURATION          = 8
Config.INTERMISSION             = 6

-- ROLES
Config.ROLE_PENIRU = "Peniru"
Config.ROLE_WARGA  = "Warga"
Config.ROLE_JOKER  = "Joker"  -- chaotic 3rd-faction; wins if voted out
Config.ROLE_ANGEL  = "Angel"  -- sub-role of Warga, picked at random per round

-- ROLE COUNTS
Config.JOKER_PER_ROUND  = 1   -- requires MIN_PLAYERS >= 4 to spawn; auto-skips otherwise
Config.JOKER_MIN_PLAYERS = 4  -- min players in round before a Joker is added

-- WALK SPEEDS
Config.WALK_SPEED_BASE  = 18
Config.WALK_SPEED_FLASH = 34
Config.JUMP_POWER       = 50

-- ABILITY: CAPTURE (Peniru)
Config.CAPTURE_RANGE     = 12
Config.CAPTURE_COOLDOWN  = 10
Config.CAPTURE_KEY       = Enum.KeyCode.E

-- ABILITY: DISGUISE (Peniru)
Config.DISGUISE_COOLDOWN = 18
Config.DISGUISE_DURATION = 15
Config.DISGUISE_KEY      = Enum.KeyCode.Q
Config.DISGUISE_PICK_RANGE = 0  -- 0 = no range, can pick anyone alive (full list)

-- ABILITY: FLASH (Peniru)
Config.FLASH_DURATION    = 5
Config.FLASH_COOLDOWN    = 30
Config.FLASH_KEY         = Enum.KeyCode.F

-- ABILITY: HACKER (Peniru)
Config.HACKER_DURATION   = 4
Config.HACKER_COOLDOWN   = 35
Config.HACKER_KEY        = Enum.KeyCode.H

-- ABILITY: VOTE
Config.VOTE_KEY          = Enum.KeyCode.V

-- WARGA / ANGEL
Config.ANGEL_PER_ROUND   = 1   -- 1 random Warga becomes Angel each round
Config.ANGEL_SHIELD_CHARGES = 1

-- ECONOMY / LEVEL
Config.XP_PER_LEVEL       = 100
Config.XP_WIN_PENIRU      = 60
Config.XP_WIN_WARGA       = 40
Config.XP_WIN_JOKER       = 90
Config.XP_LOSS            = 10
Config.COIN_WIN_PENIRU    = 80
Config.COIN_WIN_WARGA     = 55
Config.COIN_WIN_JOKER     = 120
Config.COIN_PARTICIPATION = 8

-- GLOBAL LEADERBOARD
Config.LEADERBOARD_KEY    = "GlobalLevel_v1"
Config.LEADERBOARD_TOP    = 25

-- WORLD
Config.LOBBY_CENTER       = Vector3.new(0, 8, 0)
Config.LOBBY_RADIUS       = 60
Config.CITY_CENTER        = Vector3.new(400, 8, 0)
Config.CITY_RADIUS        = 220
Config.PRISON_CENTER      = Vector3.new(800, 8, 0)
Config.PRISON_RADIUS      = 30
Config.SPAWN_HEIGHT       = 6

-- OVERHEAD
Config.OVERHEAD_MAX_DISTANCE = 35  -- studs; only visible from this close

-- CAMERA
Config.CAMERA_MAX_ZOOM   = 28      -- studs; cannot zoom out further (anti map-cheese)
Config.CAMERA_MIN_ZOOM   = 0.5

-- CHAT
Config.VOTE_CHAT_MAX_LEN = 140

-- THEME (dark minimal)
Config.THEME = {
    BG          = Color3.fromRGB(15, 16, 22),
    BG_ALT      = Color3.fromRGB(22, 24, 32),
    SURFACE     = Color3.fromRGB(28, 31, 41),
    SURFACE_ALT = Color3.fromRGB(36, 40, 54),
    BORDER      = Color3.fromRGB(48, 52, 68),
    TEXT        = Color3.fromRGB(232, 234, 240),
    TEXT_DIM    = Color3.fromRGB(168, 172, 188),
    ACCENT      = Color3.fromRGB(120, 130, 255),
    ACCENT_2    = Color3.fromRGB(64, 220, 200),
    DANGER      = Color3.fromRGB(255, 90, 110),
    WARN        = Color3.fromRGB(255, 200, 90),
    SUCCESS     = Color3.fromRGB(120, 230, 140),
    PENIRU      = Color3.fromRGB(255, 90, 110),
    WARGA       = Color3.fromRGB(120, 200, 255),
    JOKER       = Color3.fromRGB(220, 110, 255),
    ANGEL       = Color3.fromRGB(255, 220, 130),
    GOLD        = Color3.fromRGB(255, 200, 90),
}

-- SHOP CATALOG. Ability-only (skin items removed by user request).
--   kind = "ability" : unlocks a Peniru ability (Flash / Hacker)
-- All items persist via DataStore (owned[id] = true)
Config.SHOP = {
    -- PENIRU ABILITIES (unlockable, one-time purchase)
    { id = "ability_flash",  name = "Skill: Flash",    kind = "ability", role = "Peniru", price = 600,  color = Color3.fromRGB(255, 200, 90),
      desc = "Lari super cepat 5 detik. [F]" },
    { id = "ability_hacker", name = "Skill: Hacker",   kind = "ability", role = "Peniru", price = 900,  color = Color3.fromRGB(64, 220, 200),
      desc = "ESP: outline semua warga 4 detik. [H]" },
}

-- Ability item ids (used by GameManager to gate)
Config.ABILITY_FLASH_ID  = "ability_flash"
Config.ABILITY_HACKER_ID = "ability_hacker"

-- Names of remotes (auto-created in ReplicatedStorage.Shared.Remotes)
Config.REMOTES = {
    Events = {
        "StateChanged",
        "RoleAssigned",       -- (role, info)
        "Notify",             -- (text, kind, dur)
        "VoteStart",
        "VoteCast",
        "VoteResult",
        "TryCapture",
        "TryDisguise",         -- ()  client asks to start disguise
        "DisguisePickerOpen",  -- (candidates) server -> peniru: open picker UI
        "DisguisePick",        -- (targetPlayer) client -> server: chosen target
        "TryFlash",
        "TryHacker",
        "DisguiseUpdated",
        "Captured",
        "PlayCue",
        "TimerUpdate",
        "WinAnnouncement",
        "AbilityUpdate",      -- (cooldowns table)
        "ShieldUsed",         -- (angelPlayer, peniruPlayer)
        "FlashApplied",       -- (player, durationLeft)
        "HackerVision",       -- (positions {{name, pos}}, durationLeft)
        "ShopChanged",        -- ({owned = {...}, equipped = {Peniru=, Warga=}})
        "PurchaseResult",     -- (success, message, itemId)
        "VoteChatSend",       -- client -> server: (text)
        "VoteChatBroadcast",  -- server -> all: (senderName, text)  role intentionally NOT sent
    },
    Functions = {
        "GetLeaderboard",
        "GetMyData",
        "GetGameState",
        "GetShopState",       -- () -> {catalog, owned, equipped, coins}
        "PurchaseItem",       -- (itemId) -> {success, message}
        "EquipItem",          -- (itemId) -> {success, message}
    },
}

Config.STATES = {
    LOBBY        = "Lobby",
    COUNTDOWN    = "Countdown",
    ROUND        = "Round",
    VOTING       = "Voting",
    REVEAL       = "Reveal",
    INTERMISSION = "Intermission",
}

return Config
