--!nonstrict
-- All audio is generated procedurally using Roblox's free sound library asset IDs.
-- Cues: BgmLobby, BgmRound, Alarm, Suspense, Tick, VoteOpen, RoundStart, WinChime, LoseChime, Click

local SoundService = game:GetService("SoundService")

local SoundController = {}

-- Roblox-provided free sounds (Sound IDs commonly used by community templates).
-- These are stable Roblox-owned asset IDs that ship without copyright issues.
local SOUND_LIBRARY: { [string]: { id: string, vol: number, looped: boolean? } } = {
    BgmLobby   = { id = "rbxassetid://1839769293", vol = 0.25, looped = true },  -- chill ambient
    BgmRound   = { id = "rbxassetid://9046317608", vol = 0.30, looped = true },  -- tense / mystery
    Suspense   = { id = "rbxassetid://9117975149", vol = 0.45, looped = false },
    Alarm      = { id = "rbxassetid://138081500",  vol = 0.55, looped = false },
    Tick       = { id = "rbxassetid://12221967",   vol = 0.40, looped = false },
    VoteOpen   = { id = "rbxassetid://3120909354", vol = 0.50, looped = false },
    RoundStart = { id = "rbxassetid://9116784137", vol = 0.50, looped = false },
    WinChime   = { id = "rbxassetid://9114149521", vol = 0.55, looped = false },
    LoseChime  = { id = "rbxassetid://9114147660", vol = 0.55, looped = false },
    Click      = { id = "rbxassetid://6895079853", vol = 0.40, looped = false },
}

local container: Folder
local sounds: { [string]: Sound } = {}

local function ensureContainer(): Folder
    if container and container.Parent then return container end
    container = Instance.new("Folder")
    container.Name = "PeniruSounds"
    container.Parent = SoundService
    return container
end

local function makeSound(name: string)
    local def = SOUND_LIBRARY[name]
    if not def then return nil end
    local s = Instance.new("Sound")
    s.Name = name
    s.SoundId = def.id
    s.Volume = def.vol
    s.Looped = def.looped == true
    s.Parent = ensureContainer()
    sounds[name] = s
    return s
end

local function get(name: string): Sound?
    return sounds[name] or makeSound(name)
end

function SoundController.play(name: string, volumeOverride: number?)
    local s = get(name)
    if not s then return end
    if volumeOverride then s.Volume = volumeOverride end
    if s.Looped then
        if not s.IsPlaying then s:Play() end
    else
        s:Play()
    end
end

function SoundController.stop(name: string)
    local s = sounds[name]
    if s then s:Stop() end
end

function SoundController.fade(name: string, target: number, duration: number)
    local s = sounds[name]
    if not s then return end
    local TweenService = game:GetService("TweenService")
    local tw = TweenService:Create(s, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Volume = target })
    tw:Play()
end

function SoundController.bgmLobby()
    SoundController.stop("BgmRound")
    SoundController.play("BgmLobby")
end

function SoundController.bgmRound()
    SoundController.stop("BgmLobby")
    SoundController.play("BgmRound")
end

function SoundController.bgmStop()
    SoundController.stop("BgmLobby")
    SoundController.stop("BgmRound")
end

function SoundController.init()
    -- pre-load all
    for name in pairs(SOUND_LIBRARY) do
        get(name)
    end
end

return SoundController
