--!nonstrict
-- Round state machine for "Siapa Si Peniru".
-- States: Lobby -> Countdown -> Round -> Voting -> Reveal -> Intermission -> Lobby...

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Util    = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"))

local GameManager = {}

local Remotes
local DataManager
local OverheadManager
local DisguiseSystem
local mapInfo

local state           = Config.STATES.LOBBY
local roles: { [number]: string } = {}            -- userId -> role
local alive: { [number]: boolean } = {}           -- userId -> alive (not captured/voted out)
local captured: { [number]: boolean } = {}        -- userId -> in prison
local captureCooldown: { [number]: number } = {}
local votes: { [number]: number } = {}            -- voter userId -> target userId
local voteOpen        = false
local roundStart      = 0
local roundDuration   = 0

----------------------------------------------------------------
-- helpers
----------------------------------------------------------------

local function broadcastState(payload)
    Remotes.event("StateChanged"):FireAllClients(state, payload or {})
end

local function notifyAll(text: string, kind: string?, dur: number?)
    Remotes.event("Notify"):FireAllClients(text, kind or "info", dur or 4)
end

local function notifyOne(player: Player, text: string, kind: string?, dur: number?)
    Remotes.event("Notify"):FireClient(player, text, kind or "info", dur or 4)
end

local function playCueAll(name: string, vol: number?)
    Remotes.event("PlayCue"):FireAllClients(name, vol or 0.5)
end

local function getAlivePlayers(): { Player }
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if alive[p.UserId] then table.insert(out, p) end
    end
    return out
end

local function teleportPlayer(player: Player, cf: CFrame)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = cf + Vector3.new(0, 4, 0)
    end
end

local function teleportAllToLobby()
    for _, p in ipairs(Players:GetPlayers()) do
        teleportPlayer(p, mapInfo.lobbyCFrame)
    end
end

local function teleportToCity(player: Player, idx: number)
    local list = mapInfo.citySpawns
    if #list == 0 then return end
    local cf = list[((idx - 1) % #list) + 1]
    teleportPlayer(player, cf)
end

local function teleportToPrison(player: Player)
    local list = mapInfo.prisonSpawns
    if #list == 0 then return end
    local cf = list[math.random(1, #list)]
    teleportPlayer(player, cf)
end

local function pushAbilityCooldowns(player: Player)
    Remotes.event("AbilityUpdate"):FireClient(player, {
        captureCooldownEnd = captureCooldown[player.UserId] or 0,
        disguiseCooldownEnd = DisguiseSystem.getCooldownEnd(player),
    })
end

local function broadcastAbilityCooldowns()
    for _, p in ipairs(Players:GetPlayers()) do
        pushAbilityCooldowns(p)
    end
end

----------------------------------------------------------------
-- capture
----------------------------------------------------------------

local function tryCapture(peniru: Player)
    if state ~= Config.STATES.ROUND then return end
    if roles[peniru.UserId] ~= Config.ROLE_PENIRU then return end
    if not alive[peniru.UserId] then return end
    local now = os.clock()
    if (captureCooldown[peniru.UserId] or 0) > now then return end

    local pchar = peniru.Character
    local pRoot = pchar and pchar:FindFirstChild("HumanoidRootPart")
    if not pRoot then return end

    -- Find nearest non-peniru alive player within range
    local target, dist = nil, math.huge
    for _, p in ipairs(getAlivePlayers()) do
        if p ~= peniru then
            local c = p.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if r then
                local d = (r.Position - pRoot.Position).Magnitude
                if d < dist and d <= Config.CAPTURE_RANGE then
                    dist = d
                    target = p
                end
            end
        end
    end
    if not target then
        notifyOne(peniru, "Tidak ada target dalam jangkauan", "warn", 2)
        return
    end

    captureCooldown[peniru.UserId] = now + Config.CAPTURE_COOLDOWN
    alive[target.UserId] = false
    captured[target.UserId] = true
    teleportToPrison(target)

    Remotes.event("Captured"):FireAllClients(target, peniru)
    notifyAll(("%s tertangkap dan dibawa ke penjara!"):format(target.DisplayName), "danger", 4)
    playCueAll("Alarm", 0.6)

    pushAbilityCooldowns(peniru)
end

----------------------------------------------------------------
-- voting
----------------------------------------------------------------

local function openVote()
    voteOpen = true
    votes = {}
    local candidates = getAlivePlayers()
    Remotes.event("VoteStart"):FireAllClients(candidates)
    playCueAll("VoteOpen", 0.7)
    notifyAll("Voting dimulai! Pilih siapa Si Peniru.", "info", 3)
    -- Camera zoom is triggered on the client when receiving VoteStart
end

local function closeVote()
    voteOpen = false
    -- tally
    local tally: { [number]: number } = {}
    for _, target in pairs(votes) do
        tally[target] = (tally[target] or 0) + 1
    end
    -- find max
    local accusedUserId, maxV = nil, -1
    local tied = false
    for uid, count in pairs(tally) do
        if count > maxV then
            maxV = count
            accusedUserId = uid
            tied = false
        elseif count == maxV then
            tied = true
        end
    end

    -- Build tally list with names for client display
    local tallyOut = {}
    for uid, count in pairs(tally) do
        local p = Players:GetPlayerByUserId(uid)
        table.insert(tallyOut, {
            userId = uid,
            name = p and p.DisplayName or ("?_" .. tostring(uid)),
            count = count,
        })
    end
    table.sort(tallyOut, function(a, b) return a.count > b.count end)

    local accusedPlayer = accusedUserId and Players:GetPlayerByUserId(accusedUserId) or nil
    local isPeniru = accusedPlayer and (roles[accusedPlayer.UserId] == Config.ROLE_PENIRU) or false
    local peniruPlayer = nil
    for uid, role in pairs(roles) do
        if role == Config.ROLE_PENIRU then
            peniruPlayer = Players:GetPlayerByUserId(uid)
            break
        end
    end

    if tied or not accusedPlayer then
        Remotes.event("VoteResult"):FireAllClients(tallyOut, nil, false, peniruPlayer)
        notifyAll("Voting seri / tidak ada suara — Peniru lolos.", "warn", 4)
    else
        Remotes.event("VoteResult"):FireAllClients(tallyOut, accusedPlayer, isPeniru, peniruPlayer)
        if isPeniru then
            notifyAll(("Warga benar! %s adalah Si Peniru."):format(accusedPlayer.DisplayName), "success", 5)
        else
            notifyAll(("Salah tebak! %s ternyata Warga."):format(accusedPlayer.DisplayName), "danger", 5)
        end
    end

    return isPeniru, peniruPlayer, accusedPlayer
end

----------------------------------------------------------------
-- rewards
----------------------------------------------------------------

local function awardWinners(wargaWin: boolean, peniruPlayer: Player?)
    for uid, role in pairs(roles) do
        local p = Players:GetPlayerByUserId(uid)
        if p then
            DataManager.addCoins(p, Config.COIN_PARTICIPATION)
            if role == Config.ROLE_PENIRU then
                if wargaWin then
                    DataManager.addXp(p, Config.XP_LOSS)
                else
                    DataManager.addXp(p, Config.XP_WIN_PENIRU)
                    DataManager.addCoins(p, Config.COIN_WIN_PENIRU)
                end
            else
                if wargaWin then
                    DataManager.addXp(p, Config.XP_WIN_WARGA)
                    DataManager.addCoins(p, Config.COIN_WIN_WARGA)
                else
                    DataManager.addXp(p, Config.XP_LOSS)
                end
            end
            OverheadManager.refresh(p)
        end
    end
end

----------------------------------------------------------------
-- state machine
----------------------------------------------------------------

local function setState(newState: string, payload: any?)
    state = newState
    broadcastState(payload)
end

local function resetRound()
    roles = {}
    alive = {}
    captured = {}
    votes = {}
    captureCooldown = {}
    voteOpen = false
    DisguiseSystem.restoreAll()
    teleportAllToLobby()
    broadcastAbilityCooldowns()
end

local function lobbyLoop()
    setState(Config.STATES.LOBBY)
    teleportAllToLobby()
    while #Players:GetPlayers() < Config.MIN_PLAYERS do
        Remotes.event("TimerUpdate"):FireAllClients(
            ("Menunggu pemain... (%d / %d)"):format(#Players:GetPlayers(), Config.MIN_PLAYERS), 0)
        task.wait(1)
    end
end

local function countdownLoop(): boolean
    setState(Config.STATES.COUNTDOWN)
    for t = Config.LOBBY_COUNTDOWN, 1, -1 do
        if #Players:GetPlayers() < Config.MIN_PLAYERS then
            notifyAll("Pemain kurang. Countdown dibatalkan.", "warn", 3)
            return false
        end
        Remotes.event("TimerUpdate"):FireAllClients("Mulai dalam", t)
        if t <= 5 then playCueAll("Tick", 0.5) end
        task.wait(1)
    end
    return true
end

local function assignRoles()
    local players = Players:GetPlayers()
    Util.shuffleInPlace(players)

    -- Pick 1 Peniru
    local peniruIdx = math.random(1, #players)
    for i, p in ipairs(players) do
        local role = (i == peniruIdx) and Config.ROLE_PENIRU or Config.ROLE_WARGA
        roles[p.UserId] = role
        alive[p.UserId] = true
        Remotes.event("RoleAssigned"):FireClient(p, role, {
            durationMin = Config.ROUND_DURATION_MIN,
            durationMax = Config.ROUND_DURATION_MAX,
            captureKey = Config.CAPTURE_KEY.Name,
            disguiseKey = Config.DISGUISE_KEY.Name,
        })
    end
end

local function spawnActiveAtCity()
    local i = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if roles[p.UserId] then
            i += 1
            teleportToCity(p, i)
        end
    end
end

local function checkPeniruWin(): boolean
    -- Peniru wins when only 1 non-Peniru is still alive (i.e. 1 survivor besides Peniru)
    local peniruAlive = 0
    local wargaAlive = 0
    for uid, role in pairs(roles) do
        if alive[uid] then
            if role == Config.ROLE_PENIRU then peniruAlive += 1
            else wargaAlive += 1 end
        end
    end
    return peniruAlive >= 1 and wargaAlive <= 1
end

local function roundLoop(): string
    -- Returns "captureWin" | "timeout"
    setState(Config.STATES.ROUND, { duration = roundDuration })
    playCueAll("RoundStart", 0.7)

    roundStart = os.clock()

    while os.clock() - roundStart < roundDuration do
        local left = roundDuration - (os.clock() - roundStart)
        Remotes.event("TimerUpdate"):FireAllClients("Sisa Waktu", left)
        if checkPeniruWin() then
            return "captureWin"
        end
        task.wait(1)
    end
    return "timeout"
end

local function votingLoop(): (boolean, Player?, Player?)
    setState(Config.STATES.VOTING, { duration = Config.VOTING_DURATION })
    openVote()
    for t = Config.VOTING_DURATION, 1, -1 do
        Remotes.event("TimerUpdate"):FireAllClients("Voting", t)
        task.wait(1)
    end
    return closeVote()
end

local function revealLoop(winningTeam: string, peniruPlayer: Player?)
    setState(Config.STATES.REVEAL, { winningTeam = winningTeam })
    Remotes.event("WinAnnouncement"):FireAllClients(winningTeam, peniruPlayer)
    playCueAll(winningTeam == "Warga" and "WinChime" or "LoseChime", 0.8)
    task.wait(Config.REVEAL_DURATION)
end

local function intermissionLoop()
    setState(Config.STATES.INTERMISSION)
    for t = Config.INTERMISSION, 1, -1 do
        Remotes.event("TimerUpdate"):FireAllClients("Ronde berikutnya", t)
        task.wait(1)
    end
end

----------------------------------------------------------------
-- main loop
----------------------------------------------------------------

local function gameLoop()
    while true do
        resetRound()
        lobbyLoop()
        local started = countdownLoop()
        if not started then
            continue
        end
        if #Players:GetPlayers() < Config.MIN_PLAYERS then
            continue
        end

        roundDuration = math.clamp(
            Config.ROUND_DURATION_BASE + Config.ROUND_DURATION_PER_EXTRA * math.max(0, #Players:GetPlayers() - Config.MIN_PLAYERS),
            Config.ROUND_DURATION_MIN, Config.ROUND_DURATION_MAX)

        assignRoles()
        spawnActiveAtCity()
        broadcastAbilityCooldowns()

        local outcome = roundLoop()

        if outcome == "captureWin" then
            -- Peniru wins by capturing enough Warga; skip vote
            local peniruPlayer
            for uid, role in pairs(roles) do
                if role == Config.ROLE_PENIRU then
                    peniruPlayer = Players:GetPlayerByUserId(uid)
                    break
                end
            end
            DisguiseSystem.restoreAll()
            awardWinners(false, peniruPlayer)
            revealLoop("Peniru", peniruPlayer)
        else
            -- timeout -> voting phase
            local isPeniruVoted, peniruPlayer, _accused = votingLoop()
            DisguiseSystem.restoreAll()
            if isPeniruVoted then
                awardWinners(true, peniruPlayer)
                revealLoop("Warga", peniruPlayer)
            else
                awardWinners(false, peniruPlayer)
                revealLoop("Peniru", peniruPlayer)
            end
        end

        intermissionLoop()
    end
end

----------------------------------------------------------------
-- public init / handlers
----------------------------------------------------------------

function GameManager.init(deps)
    Remotes         = deps.Remotes
    DataManager     = deps.DataManager
    OverheadManager = deps.OverheadManager
    DisguiseSystem  = deps.DisguiseSystem
    mapInfo         = deps.mapInfo

    -- Vote casting (client -> server)
    Remotes.event("VoteCast").OnServerEvent:Connect(function(player, target)
        if not voteOpen then return end
        if not roles[player.UserId] then return end
        if typeof(target) ~= "Instance" or not target:IsA("Player") then return end
        if not roles[target.UserId] then return end
        votes[player.UserId] = target.UserId
    end)

    -- Capture (client -> server)
    Remotes.event("TryCapture").OnServerEvent:Connect(function(player)
        tryCapture(player)
    end)

    -- Disguise (client -> server)
    Remotes.event("TryDisguise").OnServerEvent:Connect(function(player)
        if state ~= Config.STATES.ROUND then return end
        if roles[player.UserId] ~= Config.ROLE_PENIRU then return end
        if not alive[player.UserId] then return end
        local excludeUserIds = { [player.UserId] = true }
        local alivePlayers = getAlivePlayers()
        local ok, _ = DisguiseSystem.tryDisguise(player, alivePlayers, excludeUserIds)
        if ok then
            notifyOne(player, "Penyamaran aktif!", "success", 2)
        else
            notifyOne(player, "Tidak bisa menyamar saat ini.", "warn", 2)
        end
        pushAbilityCooldowns(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        roles[player.UserId] = nil
        alive[player.UserId] = nil
        captured[player.UserId] = nil
        captureCooldown[player.UserId] = nil
        votes[player.UserId] = nil
    end)

    task.spawn(gameLoop)
end

function GameManager.getState(): string
    return state
end

return GameManager
