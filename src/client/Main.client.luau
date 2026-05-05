--!nonstrict
-- Main client entry. Wires UI + Sound + Camera + Remote events.

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")
local TextChatService   = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config  = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local clientFolder = script.Parent
local UIBuilder       = require(clientFolder:WaitForChild("UIBuilder"))
local SoundController = require(clientFolder:WaitForChild("SoundController"))
local CameraController = require(clientFolder:WaitForChild("CameraController"))

local player = Players.LocalPlayer

----------------------------------------------------------------
-- disable Roblox built-in chat (game uses custom vote chat only)
----------------------------------------------------------------

task.spawn(function()
    -- Hide legacy chat coregui
    for _ = 1, 5 do
        local ok = pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
        end)
        if ok then break end
        task.wait(0.5)
    end
    -- Disable TextChatService channels (modern chat)
    pcall(function()
        for _, child in ipairs(TextChatService:GetDescendants()) do
            if child:IsA("TextChannel") then
                child:Destroy()
            end
        end
    end)
    -- Stop any future channels from being added
    pcall(function()
        TextChatService.DescendantAdded:Connect(function(d)
            if d:IsA("TextChannel") then
                pcall(function() d:Destroy() end)
            end
        end)
    end)
end)

----------------------------------------------------------------
-- camera zoom limit (anti map-cheese)
----------------------------------------------------------------

player.CameraMaxZoomDistance = Config.CAMERA_MAX_ZOOM
player.CameraMinZoomDistance = Config.CAMERA_MIN_ZOOM
-- Re-apply when respawning, since some Studio defaults can override
player.CharacterAdded:Connect(function()
    task.wait(0.1)
    player.CameraMaxZoomDistance = Config.CAMERA_MAX_ZOOM
    player.CameraMinZoomDistance = Config.CAMERA_MIN_ZOOM
end)

----------------------------------------------------------------
-- boot UI + sounds
----------------------------------------------------------------

local ui = UIBuilder.build()
SoundController.init()
SoundController.bgmLobby()
UIBuilder.setLobbyVisible(true)

-- Loading screen sequence: animate progress, then dismiss + show rules popup once
task.spawn(function()
    local steps = { 0.15, 0.35, 0.6, 0.85, 1.0 }
    for _, p in ipairs(steps) do
        UIBuilder.setLoadingProgress(p)
        task.wait(0.4)
    end
    UIBuilder.dismissLoading()
    task.wait(0.6)
    UIBuilder.showRules()
end)

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

local function fireFlash()
    if localRole ~= Config.ROLE_PENIRU then return end
    Remotes.event("TryFlash"):FireServer()
    SoundController.play("Click", 0.4)
end

local function fireHacker()
    if localRole ~= Config.ROLE_PENIRU then return end
    Remotes.event("TryHacker"):FireServer()
    SoundController.play("Click", 0.4)
end

-- Map number keys 1-9 to Enum.KeyCode for vote shortcuts
local NUM_KEYCODES: { [Enum.KeyCode]: number } = {
    [Enum.KeyCode.One]   = 1,
    [Enum.KeyCode.Two]   = 2,
    [Enum.KeyCode.Three] = 3,
    [Enum.KeyCode.Four]  = 4,
    [Enum.KeyCode.Five]  = 5,
    [Enum.KeyCode.Six]   = 6,
    [Enum.KeyCode.Seven] = 7,
    [Enum.KeyCode.Eight] = 8,
    [Enum.KeyCode.Nine]  = 9,
}

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Config.CAPTURE_KEY then
        fireCapture()
    elseif input.KeyCode == Config.DISGUISE_KEY then
        fireDisguise()
    elseif input.KeyCode == Config.FLASH_KEY then
        fireFlash()
    elseif input.KeyCode == Config.HACKER_KEY then
        fireHacker()
    end
    -- Vote shortcut: 1-9 picks the i-th candidate while voting overlay is open
    local idx = NUM_KEYCODES[input.KeyCode]
    if idx and UIBuilder.isVoteOpen() then
        UIBuilder.voteByIndex(idx)
    end
end)

ui.captureBtn.MouseButton1Click:Connect(fireCapture)
ui.disguiseBtn.MouseButton1Click:Connect(fireDisguise)
if ui.flashBtn  then ui.flashBtn.MouseButton1Click:Connect(fireFlash) end
if ui.hackerBtn then ui.hackerBtn.MouseButton1Click:Connect(fireHacker) end
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
-- shop + rules buttons
----------------------------------------------------------------

local function refreshShop()
    task.spawn(function()
        local ok, shopState = pcall(function()
            return Remotes.func("GetShopState"):InvokeServer()
        end)
        if ok and shopState then
            UIBuilder.populateShop(shopState, {
                onPurchase = function(itemId)
                    Remotes.func("PurchaseItem"):InvokeServer(itemId)
                end,
                onEquip = function(itemId)
                    Remotes.func("EquipItem"):InvokeServer(itemId)
                end,
            })
        end
    end)
end

if ui.shopBtn then
    ui.shopBtn.MouseButton1Click:Connect(function()
        SoundController.play("Click", 0.4)
        UIBuilder.openShop()
        refreshShop()
    end)
end
if ui.rulesBtn then
    ui.rulesBtn.MouseButton1Click:Connect(function()
        SoundController.play("Click", 0.4)
        UIBuilder.showRules()
    end)
end

Remotes.event("ShopChanged").OnClientEvent:Connect(function(shopState)
    UIBuilder.populateShop(shopState, {
        onPurchase = function(itemId)
            Remotes.func("PurchaseItem"):InvokeServer(itemId)
        end,
        onEquip = function(itemId)
            Remotes.func("EquipItem"):InvokeServer(itemId)
        end,
    })
    refreshMyData()
end)

Remotes.event("PurchaseResult").OnClientEvent:Connect(function(ok, msg, _itemId)
    UIBuilder.notify(msg or (ok and "Berhasil!" or "Gagal"), ok and "success" or "warn", 3)
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

Remotes.event("VoteResult").OnClientEvent:Connect(function(tally, accusedPlayer, isPeniru, peniruPlayer, outcome)
    UIBuilder.closeVote()
    local accusedName = accusedPlayer and accusedPlayer.DisplayName or nil
    UIBuilder.showVoteResult(tally, accusedName, isPeniru, outcome)
    if accusedPlayer and accusedPlayer.Character then
        CameraController.zoomReveal(accusedPlayer.Character)
    end
end)

----------------------------------------------------------------
-- disguise picker (server -> client -> server)
----------------------------------------------------------------

Remotes.event("DisguisePickerOpen").OnClientEvent:Connect(function(candidates)
    SoundController.play("Click", 0.4)
    UIBuilder.openDisguisePicker(candidates, function(target)
        Remotes.event("DisguisePick"):FireServer(target)
    end)
end)

----------------------------------------------------------------
-- custom vote chat (Among-Us style)
----------------------------------------------------------------

local function parseVoteShortcut(text: string): Player?
    -- Match "(vote name)" - case insensitive, allow spaces
    local _, _, name = string.find(text, "^%s*%(%s*[Vv][Oo][Tt][Ee]%s+([^%)]+)%)%s*$")
    if not name then return nil end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil end
    local lower = name:lower()
    -- Match candidate by Name or DisplayName, case-insensitive
    for _, p in ipairs(UIBuilder.getVoteCandidates()) do
        if p.Name:lower() == lower or p.DisplayName:lower() == lower then
            return p
        end
    end
    return nil
end

local voteChatInput = ui.voteChatInput
if voteChatInput then
    voteChatInput.FocusLost:Connect(function(enterPressed)
        if not enterPressed then return end
        local text = voteChatInput.Text or ""
        voteChatInput.Text = ""
        if #text == 0 then return end
        -- Auto-vote shortcut
        local target = parseVoteShortcut(text)
        if target and UIBuilder.isVoteOpen() then
            Remotes.event("VoteCast"):FireServer(target)
            UIBuilder.notify("Vote (chat): " .. target.DisplayName, "info", 2.5)
        end
        -- Always broadcast the message so others can see the discussion
        Remotes.event("VoteChatSend"):FireServer(text)
    end)
end

Remotes.event("VoteChatBroadcast").OnClientEvent:Connect(function(senderName, text, role)
    UIBuilder.appendVoteChat(senderName, text, role)
end)

Remotes.event("WinAnnouncement").OnClientEvent:Connect(function(winningTeam, peniruPlayer)
    local name = peniruPlayer and peniruPlayer.DisplayName or nil
    UIBuilder.showWinAnnouncement(winningTeam, name)
    local cue = "LoseChime"
    if winningTeam == Config.ROLE_WARGA or winningTeam == Config.ROLE_JOKER then
        cue = "WinChime"
    end
    SoundController.play(cue, 0.7)
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
    UIBuilder.setAbilityCooldowns(payload)
end)

Remotes.event("FlashApplied").OnClientEvent:Connect(function(duration)
    UIBuilder.notify(("⚡ Flash aktif %ds!"):format(duration or 0), "info", 2)
    CameraController.flashFOV()
end)

Remotes.event("HackerVision").OnClientEvent:Connect(function(playerList, duration)
    UIBuilder.showHackerVision(playerList or {}, duration or 0)
end)

Remotes.event("ShieldUsed").OnClientEvent:Connect(function(angelPlayer, peniruPlayer)
    if angelPlayer == player then
        UIBuilder.notify("🛡️ Shield kamu menahan capture dari " .. (peniruPlayer and peniruPlayer.DisplayName or "Peniru") .. "!", "success", 4)
        SoundController.play("WinChime", 0.5)
    elseif peniruPlayer == player then
        UIBuilder.notify("🛡️ Shield Angel terpakai! Capture gagal.", "warn", 4)
        SoundController.play("Alarm", 0.4)
    end
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
