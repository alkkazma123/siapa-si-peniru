--!nonstrict
-- Main client entry. Wires UI + Sound + Camera + Remote events.

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config  = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local clientFolder = script.Parent
local UIBuilder       = require(clientFolder:WaitForChild("UIBuilder"))
local SoundController = require(clientFolder:WaitForChild("SoundController"))
local CameraController = require(clientFolder:WaitForChild("CameraController"))

local player = Players.LocalPlayer

----------------------------------------------------------------
-- boot UI + sounds
----------------------------------------------------------------

local ui = UIBuilder.build()
SoundController.init()
SoundController.bgmLobby()
UIBuilder.setLobbyVisible(true)

local localRole: string? = nil

----------------------------------------------------------------
-- profile / stats refresh
----------------------------------------------------------------

local function refreshMyData()
    task.spawn(function()
        local ok, data = pcall(function()
            return Remotes.func("GetMyData"):InvokeServer()
        end)
        if ok and data then
            UIBuilder.setStats(data)
        end
    end)
end

local function refreshLeaderboard()
    task.spawn(function()
        local ok, entries = pcall(function()
            return Remotes.func("GetLeaderboard"):InvokeServer()
        end)
        if ok and entries then
            UIBuilder.populateLeaderboard(entries)
        end
    end)
end

refreshMyData()

----------------------------------------------------------------
-- input handling
----------------------------------------------------------------

local function fireCapture()
    if localRole ~= Config.ROLE_PENIRU then return end
    Remotes.event("TryCapture"):FireServer()
    SoundController.play("Click", 0.4)
end

local function fireDisguise()
    if localRole ~= Config.ROLE_PENIRU then return end
    Remotes.event("TryDisguise"):FireServer()
    SoundController.play("Click", 0.4)
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Config.CAPTURE_KEY then
        fireCapture()
    elseif input.KeyCode == Config.DISGUISE_KEY then
        fireDisguise()
    end
end)

ui.captureBtn.MouseButton1Click:Connect(fireCapture)
ui.disguiseBtn.MouseButton1Click:Connect(fireDisguise)
ui.voteBtn.MouseButton1Click:Connect(function()
    -- Just visually scroll into view; the vote overlay is full-screen
    SoundController.play("Click", 0.4)
end)

ui.leaderboardBtn.MouseButton1Click:Connect(function()
    SoundController.play("Click", 0.4)
    if UIBuilder.toggleLeaderboard() then
        refreshLeaderboard()
    end
end)

----------------------------------------------------------------
-- remote handlers
----------------------------------------------------------------

Remotes.event("StateChanged").OnClientEvent:Connect(function(state, payload)
    UIBuilder.setState(state)
    if state == Config.STATES.LOBBY then
        SoundController.bgmLobby()
        UIBuilder.setRole(nil)
        localRole = nil
        UIBuilder.setActionButtons(nil, false)
        UIBuilder.setLobbyVisible(true)
        CameraController.restore()
    elseif state == Config.STATES.COUNTDOWN then
        UIBuilder.setLobbyVisible(true)
    elseif state == Config.STATES.ROUND then
        SoundController.bgmRound()
        UIBuilder.setLobbyVisible(false)
        UIBuilder.setActionButtons(localRole, false)
        CameraController.restore()
    elseif state == Config.STATES.VOTING then
        UIBuilder.setActionButtons(localRole, true)
        SoundController.play("Suspense", 0.5)
        CameraController.zoomVoting()
    elseif state == Config.STATES.REVEAL then
        UIBuilder.setActionButtons(localRole, false)
        UIBuilder.closeVote()
    elseif state == Config.STATES.INTERMISSION then
        UIBuilder.setLobbyVisible(true)
        CameraController.restore()
        refreshMyData()
    end
end)

Remotes.event("RoleAssigned").OnClientEvent:Connect(function(role, info)
    localRole = role
    UIBuilder.setRole(role)
    UIBuilder.setActionButtons(role, false)
    UIBuilder.showRoleReveal(role, info)
    SoundController.play(role == Config.ROLE_PENIRU and "Suspense" or "RoundStart", 0.5)
    CameraController.flashFOV()
end)

Remotes.event("Notify").OnClientEvent:Connect(function(text, kind, dur)
    UIBuilder.notify(text, kind, dur)
end)

Remotes.event("TimerUpdate").OnClientEvent:Connect(function(label, seconds)
    UIBuilder.setTimer(label, seconds or 0)
end)

Remotes.event("VoteStart").OnClientEvent:Connect(function(candidates)
    UIBuilder.openVote(candidates, function(target)
        Remotes.event("VoteCast"):FireServer(target)
        UIBuilder.notify("Vote terkirim: " .. target.DisplayName, "info", 2.5)
    end)
end)

Remotes.event("VoteResult").OnClientEvent:Connect(function(tally, accusedPlayer, isPeniru, peniruPlayer)
    UIBuilder.closeVote()
    local accusedName = accusedPlayer and accusedPlayer.DisplayName or nil
    UIBuilder.showVoteResult(tally, accusedName, isPeniru)
    if accusedPlayer and accusedPlayer.Character then
        CameraController.zoomReveal(accusedPlayer.Character)
    end
end)

Remotes.event("WinAnnouncement").OnClientEvent:Connect(function(winningTeam, peniruPlayer)
    local name = peniruPlayer and peniruPlayer.DisplayName or nil
    UIBuilder.showWinAnnouncement(winningTeam, name)
    SoundController.play(winningTeam == "Warga" and "WinChime" or "LoseChime", 0.7)
    if peniruPlayer and peniruPlayer.Character then
        CameraController.zoomReveal(peniruPlayer.Character)
    end
    -- Refresh stats after rewards
    task.delay(1, refreshMyData)
end)

Remotes.event("Captured").OnClientEvent:Connect(function(captive, by)
    if captive == player then
        UIBuilder.notify("Kamu tertangkap!", "danger", 4)
        SoundController.play("Alarm", 0.7)
        CameraController.flashFOV()
    end
end)

Remotes.event("PlayCue").OnClientEvent:Connect(function(name, vol)
    SoundController.play(name, vol)
end)

Remotes.event("AbilityUpdate").OnClientEvent:Connect(function(payload)
    UIBuilder.setAbilityCooldowns(payload.captureCooldownEnd, payload.disguiseCooldownEnd)
end)

Remotes.event("DisguiseUpdated").OnClientEvent:Connect(function(peniruPlayer, targetPlayer)
    if targetPlayer then
        if peniruPlayer == player then
            UIBuilder.notify("Penyamaran sebagai " .. targetPlayer.DisplayName, "success", 3)
        end
    end
end)

----------------------------------------------------------------
-- per-frame ticks
----------------------------------------------------------------

RunService.RenderStepped:Connect(function()
    UIBuilder.tickCooldowns()
end)

-- Periodic leaderboard refresh while panel is open
task.spawn(function()
    while true do
        task.wait(30)
        if ui.leaderboardPanel and ui.leaderboardPanel.Visible then
            refreshLeaderboard()
        end
    end
end)

print("[SiapaSiPeniru] Client ready.")
