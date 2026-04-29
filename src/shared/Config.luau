--!nonstrict
-- Shared config for "Siapa Si Peniru"

local Config = {}

-- ROUND TIMINGS
Config.MIN_PLAYERS              = 3       -- minimum players to start a round
Config.LOBBY_COUNTDOWN          = 15      -- seconds in lobby before round (when min met)
Config.ROUND_DURATION_BASE      = 45      -- base round duration (30 to 60 range)
Config.ROUND_DURATION_PER_EXTRA = 5       -- +seconds per player above MIN_PLAYERS (clamped)
Config.ROUND_DURATION_MIN       = 30
Config.ROUND_DURATION_MAX       = 60
Config.VOTING_DURATION          = 20      -- seconds for voting phase
Config.REVEAL_DURATION          = 8       -- seconds to show reveal animation
Config.INTERMISSION             = 6       -- seconds between rounds

-- ROLES
Config.ROLE_PENIRU = "Peniru"
Config.ROLE_WARGA  = "Warga"

-- CAPTURE
Config.CAPTURE_RANGE     = 12     -- studs
Config.CAPTURE_COOLDOWN  = 8      -- seconds
Config.CAPTURE_KEY       = Enum.KeyCode.E

-- DISGUISE
Config.DISGUISE_COOLDOWN = 5
Config.DISGUISE_KEY      = Enum.KeyCode.Q

-- VOTE
Config.VOTE_KEY          = Enum.KeyCode.V

-- ECONOMY / LEVEL
Config.XP_PER_LEVEL       = 100
Config.XP_WIN_PENIRU      = 60
Config.XP_WIN_WARGA       = 40
Config.XP_LOSS            = 10
Config.COIN_WIN_PENIRU    = 50
Config.COIN_WIN_WARGA     = 35
Config.COIN_PARTICIPATION = 5

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

-- THEME (dark minimal)
Config.THEME = {
    BG          = Color3.fromRGB(15, 16, 22),
    BG_ALT      = Color3.fromRGB(22, 24, 32),
    SURFACE     = Color3.fromRGB(28, 31, 41),
    BORDER      = Color3.fromRGB(48, 52, 68),
    TEXT        = Color3.fromRGB(232, 234, 240),
    TEXT_DIM    = Color3.fromRGB(168, 172, 188),
    ACCENT      = Color3.fromRGB(120, 130, 255), -- main brand
    ACCENT_2    = Color3.fromRGB(64, 220, 200),
    DANGER      = Color3.fromRGB(255, 90, 110),
    WARN        = Color3.fromRGB(255, 200, 90),
    SUCCESS     = Color3.fromRGB(120, 230, 140),
    PENIRU      = Color3.fromRGB(255, 90, 110),
    WARGA       = Color3.fromRGB(120, 200, 255),
}

-- Names of remotes (auto-created in ReplicatedStorage.Shared.Remotes)
Config.REMOTES = {
    Events = {
        "StateChanged",      -- (state, payload)
        "RoleAssigned",      -- (role, info)
        "Notify",            -- (text, kind, duration)
        "VoteStart",         -- (candidates {Player})
        "VoteCast",          -- (target Player) [c->s]
        "VoteResult",        -- ({tally}, accusedPlayer, isPeniru, peniruPlayer)
        "TryCapture",        -- () [c->s]
        "TryDisguise",       -- () [c->s]
        "DisguiseUpdated",   -- (peniruPlayer, targetPlayer or nil)
        "Captured",          -- (player, by)
        "PlayCue",           -- (cueName, volume?)
        "TimerUpdate",       -- (label, secondsLeft)
        "WinAnnouncement",   -- (winningTeam, peniruPlayer)
        "AbilityUpdate",     -- ({captureCooldownEnd, disguiseCooldownEnd})
    },
    Functions = {
        "GetLeaderboard",    -- () -> {entries}
        "GetMyData",         -- () -> {coins, xp, level}
        "GetGameState",      -- () -> {state, alive, role?}
    },
}

-- Simple per-state constants
Config.STATES = {
    LOBBY        = "Lobby",
    COUNTDOWN    = "Countdown",
    ROUND        = "Round",
    VOTING       = "Voting",
    REVEAL       = "Reveal",
    INTERMISSION = "Intermission",
}

return Config
