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
local roles: { [number]: string } = {}            -- userId -> base role (Peniru / Warga / Joker)
local subroles: { [number]: string } = {}         -- userId -> Angel (only)
local alive: { [number]: boolean } = {}           -- userId -> alive
local captured: { [number]: boolean } = {}        -- userId -> in prison
local shields: { [number]: number } = {}          -- userId -> remaining shield charges
local captureCooldown: { [number]: number } = {}
local flashCooldown: { [number]: number } = {}
local hackerCooldown: { [number]: number } = {}
local flashActiveUntil: { [number]: number } = {}
local hackerActiveUntil: { [number]: number } = {}
local votes: { [number]: number } = {}
local peniruVoidFell = false   -- set true when Peniru falls into the void → Warga win
local peniruKilledByDetektif = false  -- detektif correctly killed Peniru → Warga win
local voteOpen        = false
local roundStart      = 0
local roundDuration   = 0
local roundEnd        = 0  -- absolute os.clock() deadline of current round
local nextMeetingAt   = math.huge  -- absolute os.clock() of next auto meeting

-- Missions
local missionAssignments: { [number]: { [string]: boolean } } = {}  -- userId -> {stationId = doneBool}
local missionTotal = 0
local missionDoneCount = 0

-- Detektif kill usage tracking (one shot per round)
local detektifUsed: { [number]: boolean } = {}

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
        captureCooldownEnd  = captureCooldown[player.UserId] or 0,
        disguiseCooldownEnd = DisguiseSystem.getCooldownEnd(player),
        flashCooldownEnd    = flashCooldown[player.UserId] or 0,
        hackerCooldownEnd   = hackerCooldown[player.UserId] or 0,
        flashActiveUntil    = flashActiveUntil[player.UserId] or 0,
        hackerActiveUntil   = hackerActiveUntil[player.UserId] or 0,
        shieldCharges       = shields[player.UserId] or 0,
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

-- Common imprison path. Used by capture and by void-fall.
-- cause: "capture" | "void"
local function imprison(player: Player, by: Player?, cause: string)
    if not roles[player.UserId] then return end
    if not alive[player.UserId] then return end
    alive[player.UserId] = false
    captured[player.UserId] = true
    teleportToPrison(player)
    Remotes.event("Captured"):FireAllClients(player, by)
    if cause == "void" then
        notifyAll(("%s jatuh ke void dan dibawa ke penjara!"):format(player.DisplayName), "danger", 4)
    else
        notifyAll(("%s tertangkap dan dibawa ke penjara!"):format(player.DisplayName), "danger", 4)
    end
    playCueAll("Alarm", 0.6)
end

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

    -- Apply cooldown immediately (whether shielded or not — capture attempt is a real action)
    captureCooldown[peniru.UserId] = now + Config.CAPTURE_COOLDOWN

    -- Shield check (Angel)
    if (shields[target.UserId] or 0) > 0 then
        shields[target.UserId] = shields[target.UserId] - 1
        Remotes.event("ShieldUsed"):FireAllClients(target, peniru)
        notifyOne(target, "🛡️ Shield kamu terpakai! Capture ditahan.", "success", 4)
        notifyOne(peniru, "🛡️ Shield Angel terpakai! Capture gagal.", "warn", 4)
        playCueAll("Suspense", 0.4)
        pushAbilityCooldowns(peniru)
        pushAbilityCooldowns(target)
        return
    end

    imprison(target, peniru, "capture")
    pushAbilityCooldowns(peniru)
end

----------------------------------------------------------------
-- flash (Peniru speed boost)
----------------------------------------------------------------

local function tryFlash(peniru: Player)
    if state ~= Config.STATES.ROUND then return end
    if roles[peniru.UserId] ~= Config.ROLE_PENIRU then return end
    if not alive[peniru.UserId] then return end
    if not DataManager.owns(peniru, Config.ABILITY_FLASH_ID) then
        notifyOne(peniru, "⚡ Beli skill Flash di shop dulu!", "warn", 3)
        return
    end
    local now = os.clock()
    if (flashCooldown[peniru.UserId] or 0) > now then return end

    local hum = peniru.Character and peniru.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    flashCooldown[peniru.UserId]   = now + Config.FLASH_COOLDOWN
    flashActiveUntil[peniru.UserId] = now + Config.FLASH_DURATION
    hum.WalkSpeed = Config.WALK_SPEED_FLASH
    Remotes.event("FlashApplied"):FireClient(peniru, Config.FLASH_DURATION)
    notifyOne(peniru, "⚡ Flash aktif!", "info", 2)
    Remotes.event("PlayCue"):FireClient(peniru, "Tick", 0.7)

    task.delay(Config.FLASH_DURATION, function()
        local h = peniru.Character and peniru.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = Config.WALK_SPEED_BASE end
        flashActiveUntil[peniru.UserId] = 0
        if alive[peniru.UserId] then pushAbilityCooldowns(peniru) end
    end)
    pushAbilityCooldowns(peniru)
end

----------------------------------------------------------------
-- hacker (Peniru sees Warga locations briefly)
----------------------------------------------------------------

local function tryHacker(peniru: Player)
    if state ~= Config.STATES.ROUND then return end
    if roles[peniru.UserId] ~= Config.ROLE_PENIRU then return end
    if not alive[peniru.UserId] then return end
    if not DataManager.owns(peniru, Config.ABILITY_HACKER_ID) then
        notifyOne(peniru, "💻 Beli skill Hacker di shop dulu!", "warn", 3)
        return
    end
    local now = os.clock()
    if (hackerCooldown[peniru.UserId] or 0) > now then return end

    hackerCooldown[peniru.UserId]    = now + Config.HACKER_COOLDOWN
    hackerActiveUntil[peniru.UserId] = now + Config.HACKER_DURATION

    -- Build list of alive Warga (we send player refs; client applies Highlight ESP)
    local wargaList: { Player } = {}
    for _, p in ipairs(getAlivePlayers()) do
        if roles[p.UserId] == Config.ROLE_WARGA and p ~= peniru then
            table.insert(wargaList, p)
        end
    end

    Remotes.event("HackerVision"):FireClient(peniru, wargaList, Config.HACKER_DURATION)
    notifyOne(peniru, "💻 Hacker aktif! Lokasi warga terdeteksi.", "info", 2)
    Remotes.event("PlayCue"):FireClient(peniru, "Suspense", 0.5)

    task.delay(Config.HACKER_DURATION, function()
        hackerActiveUntil[peniru.UserId] = 0
        if alive[peniru.UserId] then pushAbilityCooldowns(peniru) end
    end)
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
    notifyAll("Voting dimulai! Pilih siapa Si Peniru. (Cuma yang masih hidup yg bisa vote)", "info", 3)
    -- Camera zoom is triggered on the client when receiving VoteStart
end

-- Returns: outcome, peniruPlayer, accusedPlayer
--   outcome: "peniru" | "joker" | "wrong" | "skip" (tied / no vote)
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
    local accusedRole   = accusedPlayer and roles[accusedPlayer.UserId] or nil
    local peniruPlayer = nil
    for uid, role in pairs(roles) do
        if role == Config.ROLE_PENIRU then
            peniruPlayer = Players:GetPlayerByUserId(uid)
            break
        end
    end

    local outcome: string
    if tied or not accusedPlayer then
        outcome = "skip"
        -- send isPeniru=false so client UI shows neutral / wrong-vote message
        Remotes.event("VoteResult"):FireAllClients(tallyOut, nil, false, peniruPlayer, "skip")
        notifyAll("Voting seri / tidak ada suara — ronde lanjut.", "warn", 4)
    elseif accusedRole == Config.ROLE_PENIRU then
        outcome = "peniru"
        Remotes.event("VoteResult"):FireAllClients(tallyOut, accusedPlayer, true, peniruPlayer, "peniru")
        notifyAll(("Warga benar! %s adalah Si Peniru."):format(accusedPlayer.DisplayName), "success", 5)
    elseif accusedRole == Config.ROLE_JOKER then
        outcome = "joker"
        Remotes.event("VoteResult"):FireAllClients(tallyOut, accusedPlayer, false, peniruPlayer, "joker")
        notifyAll(("%s ternyata Joker — Joker menang!"):format(accusedPlayer.DisplayName), "warn", 5)
    else
        outcome = "wrong"
        Remotes.event("VoteResult"):FireAllClients(tallyOut, accusedPlayer, false, peniruPlayer, "wrong")
        notifyAll(("Salah tebak! %s ternyata Warga — ronde lanjut."):format(accusedPlayer.DisplayName), "danger", 5)
    end

    return outcome, peniruPlayer, accusedPlayer
end

----------------------------------------------------------------
-- rewards
----------------------------------------------------------------

-- winningTeam: "Peniru" | "Warga" | "Joker"  (Detektif is part of the Warga team)
local function awardWinners(winningTeam: string)
    for uid, role in pairs(roles) do
        local p = Players:GetPlayerByUserId(uid)
        if p then
            DataManager.addCoins(p, Config.COIN_PARTICIPATION)
            -- Detektif is treated as Warga side for win/loss purposes.
            local effectiveRole = (role == Config.ROLE_DETEKTIF) and Config.ROLE_WARGA or role
            local won = (effectiveRole == winningTeam)
            if won then
                if effectiveRole == Config.ROLE_PENIRU then
                    DataManager.addXp(p, Config.XP_WIN_PENIRU)
                    DataManager.addCoins(p, Config.COIN_WIN_PENIRU)
                elseif effectiveRole == Config.ROLE_JOKER then
                    DataManager.addXp(p, Config.XP_WIN_JOKER)
                    DataManager.addCoins(p, Config.COIN_WIN_JOKER)
                else
                    DataManager.addXp(p, Config.XP_WIN_WARGA)
                    DataManager.addCoins(p, Config.COIN_WIN_WARGA)
                end
            else
                DataManager.addXp(p, Config.XP_LOSS)
            end
            OverheadManager.refresh(p)
        end
    end
    -- Persist after each round so a server crash doesn't wipe the round's rewards.
    if DataManager.saveAll then
        task.spawn(DataManager.saveAll)
    end
end

----------------------------------------------------------------
-- state machine
----------------------------------------------------------------

local function setState(newState: string, payload: any?)
    state = newState
    broadcastState(payload)
end

-- Skins removed: GameManager no longer mutates player visuals.
local function applySkin(_player: Player, _role: string) end

local function resetWalkSpeeds()
    for _, p in ipairs(Players:GetPlayers()) do
        local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        if h then
            h.WalkSpeed = Config.WALK_SPEED_BASE
            h.JumpPower = Config.JUMP_POWER
        end
    end
end

local function resetRound()
    roles = {}
    subroles = {}
    alive = {}
    captured = {}
    shields = {}
    votes = {}
    captureCooldown = {}
    flashCooldown = {}
    hackerCooldown = {}
    flashActiveUntil = {}
    hackerActiveUntil = {}
    voteOpen = false
    peniruVoidFell = false
    peniruKilledByDetektif = false
    missionAssignments = {}
    missionTotal = 0
    missionDoneCount = 0
    detektifUsed = {}
    DisguiseSystem.restoreAll()
    resetWalkSpeeds()
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

    -- Decide whether we add a Joker / Detektif this round (needs enough players)
    local addJoker = (#players >= Config.JOKER_MIN_PLAYERS) and (Config.JOKER_PER_ROUND > 0)
    local addDetektif = (#players >= Config.DETEKTIF_MIN_PLAYERS) and (Config.DETEKTIF_PER_ROUND > 0)

    local jokerIdx, detektifIdx = nil, nil
    if addJoker then
        repeat
            jokerIdx = math.random(1, #players)
        until jokerIdx ~= peniruIdx
    end
    if addDetektif then
        repeat
            detektifIdx = math.random(1, #players)
        until detektifIdx ~= peniruIdx and detektifIdx ~= jokerIdx
    end

    local wargaList: { Player } = {}
    for i, p in ipairs(players) do
        local role: string
        if i == peniruIdx then
            role = Config.ROLE_PENIRU
        elseif jokerIdx and i == jokerIdx then
            role = Config.ROLE_JOKER
        elseif detektifIdx and i == detektifIdx then
            role = Config.ROLE_DETEKTIF
        else
            role = Config.ROLE_WARGA
        end
        roles[p.UserId] = role
        alive[p.UserId] = true
        if role == Config.ROLE_WARGA then
            table.insert(wargaList, p)
        end
    end

    -- Pick Angel sub-role from Warga
    local angelSet: { [number]: boolean } = {}
    if #wargaList > 0 then
        for k = 1, math.min(Config.ANGEL_PER_ROUND, #wargaList) do
            local idx = math.random(1, #wargaList)
            local angel = table.remove(wargaList, idx)
            subroles[angel.UserId] = Config.ROLE_ANGEL
            shields[angel.UserId] = Config.ANGEL_SHIELD_CHARGES
            angelSet[angel.UserId] = true
        end
    end

    -- Notify each player of their role
    for _, p in ipairs(players) do
        local role = roles[p.UserId]
        local sub = subroles[p.UserId]
        Remotes.event("RoleAssigned"):FireClient(p, role, {
            durationMin = Config.ROUND_DURATION_MIN,
            durationMax = Config.ROUND_DURATION_MAX,
            captureKey = Config.CAPTURE_KEY.Name,
            disguiseKey = Config.DISGUISE_KEY.Name,
            flashKey = Config.FLASH_KEY.Name,
            hackerKey = Config.HACKER_KEY.Name,
            detektifKey = Config.DETEKTIF_KEY.Name,
            voteKey = Config.VOTE_KEY.Name,
            subRole = sub,
            shieldCharges = shields[p.UserId] or 0,
        })
        applySkin(p, role)
        pushAbilityCooldowns(p)
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
    -- Peniru wins when alive Warga + Detektif count <= 1.
    -- Joker is independent and not counted.
    local goodAlive = 0
    for uid, role in pairs(roles) do
        if alive[uid] and (role == Config.ROLE_WARGA or role == Config.ROLE_DETEKTIF) then
            goodAlive += 1
        end
    end
    return goodAlive <= 1
end

local function checkMissionsComplete(): boolean
    return missionTotal > 0 and missionDoneCount >= missionTotal
end

----------------------------------------------------------------
-- missions (assignment + completion)
----------------------------------------------------------------

local function broadcastMissionProgress()
    local pct = 0
    if missionTotal > 0 then
        pct = math.floor((missionDoneCount / missionTotal) * 100 + 0.5)
    end
    Remotes.event("MissionProgress"):FireAllClients(pct, missionDoneCount, missionTotal)
end

local function assignMissions()
    missionAssignments = {}
    missionTotal = 0
    missionDoneCount = 0

    local stations = mapInfo and mapInfo.missionStations or {}
    if #stations == 0 then return end

    for _, p in ipairs(Players:GetPlayers()) do
        local role = roles[p.UserId]
        -- Only Warga + Detektif get missions (Peniru / Joker do not).
        if role == Config.ROLE_WARGA or role == Config.ROLE_DETEKTIF then
            -- Pick MISSIONS_PER_PLAYER unique stations
            local pool = {}
            for _, s in ipairs(stations) do table.insert(pool, s) end
            Util.shuffleInPlace(pool)
            local n = math.min(Config.MISSIONS_PER_PLAYER, #pool)

            local myList = {}
            local mine: { [string]: boolean } = {}
            for i = 1, n do
                local st = pool[i]
                mine[st.id] = false  -- false = pending, true = done
                missionTotal += 1
                table.insert(myList, { id = st.id, name = st.name, pos = st.pos })
            end
            missionAssignments[p.UserId] = mine
            Remotes.event("MissionAssigned"):FireClient(p, myList)
        end
    end
    broadcastMissionProgress()
end

local function onMissionTriggered(player: Player, stationId: string)
    if state ~= Config.STATES.ROUND then return end
    if not roles[player.UserId] then return end
    if not alive[player.UserId] then return end
    local mine = missionAssignments[player.UserId]
    if not mine then return end
    if mine[stationId] == nil then
        -- Station exists but isn't assigned to this player. Silently ignore.
        return
    end
    if mine[stationId] == true then return end  -- already done
    mine[stationId] = true
    missionDoneCount += 1
    Remotes.event("MissionDone"):FireClient(player, stationId)
    notifyOne(player, "Misi selesai!", "success", 1.5)
    broadcastMissionProgress()
end

----------------------------------------------------------------
-- detektif (kill ability)
----------------------------------------------------------------

local function tryDetektifKill(detektif: Player, target: Player)
    if state ~= Config.STATES.ROUND and state ~= Config.STATES.VOTING then return end
    if roles[detektif.UserId] ~= Config.ROLE_DETEKTIF then return end
    if not alive[detektif.UserId] then return end
    if detektifUsed[detektif.UserId] then
        notifyOne(detektif, "Kekuatan Detektif sudah dipakai ronde ini.", "warn", 3)
        return
    end
    if not target or typeof(target) ~= "Instance" or not target:IsA("Player") then return end
    if target.UserId == detektif.UserId then return end
    if not roles[target.UserId] then return end
    if not alive[target.UserId] then return end

    detektifUsed[detektif.UserId] = true
    local targetRole = roles[target.UserId]
    local correct = (targetRole == Config.ROLE_PENIRU)
    Remotes.event("DetektifResult"):FireAllClients(detektif, target, correct)

    if correct then
        -- Detektif killed Peniru → Warga + Detektif menang
        alive[target.UserId] = false
        teleportToPrison(target)
        peniruKilledByDetektif = true
        notifyAll(("🔍 Detektif %s membunuh Peniru! Warga menang!"):format(detektif.DisplayName), "success", 5)
        playCueAll("WinChime", 0.7)
    else
        -- Wrong target → Detektif sendiri masuk penjara
        notifyAll(("🔍 Detektif %s salah orang! Detektif masuk penjara."):format(detektif.DisplayName), "danger", 5)
        playCueAll("Alarm", 0.6)
        imprison(detektif, nil, "wrong")
    end
end

-- Round loop. Returns:
--   "captureWin"   : Peniru cleaned out warga (alive warga+detektif <= 1)
--   "peniruVoid"   : Peniru fell into the void → Warga win
--   "peniruKilled" : Detektif correctly killed Peniru → Warga win
--   "missionWin"   : All assigned missions complete → Warga win
--   "meeting"      : Auto meeting interval reached → caller should run votingLoop, then loop back
--   "timeout"      : Timer expired without resolution → go to final voting
-- Uses module-level `roundEnd` (absolute deadline) and `nextMeetingAt`.
local function roundLoop(): string
    setState(Config.STATES.ROUND, { duration = math.max(0, roundEnd - os.clock()) })
    playCueAll("RoundStart", 0.5)

    while os.clock() < roundEnd do
        local left = roundEnd - os.clock()
        Remotes.event("TimerUpdate"):FireAllClients("Sisa Waktu", left)
        if peniruVoidFell then return "peniruVoid" end
        if peniruKilledByDetektif then return "peniruKilled" end
        if checkPeniruWin() then return "captureWin" end
        if checkMissionsComplete() then return "missionWin" end
        if os.clock() >= nextMeetingAt then return "meeting" end
        task.wait(1)
    end
    return "timeout"
end

local function votingLoop()
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
    local cue = "WinChime"
    if winningTeam == Config.ROLE_PENIRU then cue = "LoseChime" end
    playCueAll(cue, 0.8)
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

local function findPeniru(): Player?
    for uid, role in pairs(roles) do
        if role == Config.ROLE_PENIRU then
            return Players:GetPlayerByUserId(uid)
        end
    end
    return nil
end

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
        assignMissions()
        spawnActiveAtCity()
        broadcastAbilityCooldowns()

        -- Set absolute round deadline + first auto-meeting trigger.
        roundStart = os.clock()
        roundEnd = roundStart + roundDuration
        nextMeetingAt = roundStart + Config.MEETING_FIRST_DELAY

        -- Round/Vote ping-pong: a wrong vote sends us back to ROUND.
        -- Peniru-only-wins-by-capture is enforced by checkPeniruWin().
        local resolved = false
        while not resolved do
            local outcome = roundLoop()

            if outcome == "captureWin" then
                local peniruPlayer = findPeniru()
                DisguiseSystem.restoreAll()
                awardWinners(Config.ROLE_PENIRU)
                revealLoop(Config.ROLE_PENIRU, peniruPlayer)
                resolved = true
            elseif outcome == "peniruVoid" or outcome == "peniruKilled" or outcome == "missionWin" then
                local peniruPlayer = findPeniru()
                DisguiseSystem.restoreAll()
                awardWinners(Config.ROLE_WARGA)
                revealLoop(Config.ROLE_WARGA, peniruPlayer)
                resolved = true
            elseif outcome == "meeting" then
                -- Auto meeting: pause round, run a vote, then return to ROUND.
                Remotes.event("MeetingCalled"):FireAllClients("auto")
                notifyAll("Rapat darurat! Voting otomatis dimulai.", "warn", 3)
                playCueAll("Suspense", 0.5)
                local voteOutcome, peniruPlayer, _ = votingLoop()
                DisguiseSystem.restoreAll()

                if voteOutcome == "peniru" then
                    awardWinners(Config.ROLE_WARGA)
                    revealLoop(Config.ROLE_WARGA, peniruPlayer)
                    resolved = true
                elseif voteOutcome == "joker" then
                    awardWinners(Config.ROLE_JOKER)
                    revealLoop(Config.ROLE_JOKER, peniruPlayer)
                    resolved = true
                else
                    -- Wrong / skip: schedule next meeting, return to ROUND
                    notifyAll("Vote tidak menemukan Peniru — ronde lanjut!", "warn", 3)
                    nextMeetingAt = os.clock() + Config.MEETING_INTERVAL
                end
            else
                -- "timeout": final voting phase (round timer ran out)
                local voteOutcome, peniruPlayer, _accused = votingLoop()
                DisguiseSystem.restoreAll()

                if voteOutcome == "peniru" then
                    awardWinners(Config.ROLE_WARGA)
                    revealLoop(Config.ROLE_WARGA, peniruPlayer)
                    resolved = true
                elseif voteOutcome == "joker" then
                    awardWinners(Config.ROLE_JOKER)
                    revealLoop(Config.ROLE_JOKER, peniruPlayer)
                    resolved = true
                else
                    -- "wrong" or "skip": game continues, extend round timer
                    notifyAll("Vote tidak menemukan Peniru — ronde lanjut!", "warn", 4)
                    roundEnd = os.clock() + Config.ROUND_EXTENSION
                    nextMeetingAt = os.clock() + Config.MEETING_INTERVAL
                end
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

    -- Vote casting (client -> server). ONLY alive in-round players may vote.
    -- target == Player        → vote that player
    -- target == "skip" or nil → cast a skip vote (uid 0)
    Remotes.event("VoteCast").OnServerEvent:Connect(function(player, target)
        if not voteOpen then return end
        if not roles[player.UserId] then return end
        if not alive[player.UserId] then
            notifyOne(player, "Kamu tidak bisa vote (di lobby/penjara).", "warn", 2)
            return
        end
        if target == nil or target == "skip" or target == false then
            votes[player.UserId] = 0  -- skip sentinel
            return
        end
        if typeof(target) ~= "Instance" or not target:IsA("Player") then return end
        if not roles[target.UserId] then return end
        if not alive[target.UserId] then return end
        votes[player.UserId] = target.UserId
    end)

    -- Detektif kill (client -> server)
    Remotes.event("DetektifKill").OnServerEvent:Connect(function(player, target)
        tryDetektifKill(player, target)
    end)

    -- Wire ProximityPrompt.Triggered for each mission station.
    if mapInfo and mapInfo.missionStations then
        for _, st in ipairs(mapInfo.missionStations) do
            st.prompt.Triggered:Connect(function(plr: Player)
                onMissionTriggered(plr, st.id)
            end)
        end
    end

    -- Capture (client -> server)
    Remotes.event("TryCapture").OnServerEvent:Connect(function(player)
        tryCapture(player)
    end)

    -- Disguise: client -> server "open picker"
    -- Server validates and replies with DisguisePickerOpen carrying the candidate list.
    Remotes.event("TryDisguise").OnServerEvent:Connect(function(player)
        if state ~= Config.STATES.ROUND then return end
        if roles[player.UserId] ~= Config.ROLE_PENIRU then return end
        if not alive[player.UserId] then return end
        local cdEnd = DisguiseSystem.getCooldownEnd(player)
        if cdEnd > os.clock() then
            notifyOne(player, ("Disguise cooldown %.1fs"):format(cdEnd - os.clock()), "warn", 2)
            return
        end
        -- Build candidate list (everyone alive except peniru themselves)
        local candidates = {}
        for _, p in ipairs(getAlivePlayers()) do
            if p.UserId ~= player.UserId then
                table.insert(candidates, p)
            end
        end
        if #candidates == 0 then
            notifyOne(player, "Tidak ada target untuk ditiru.", "warn", 2)
            return
        end
        Remotes.event("DisguisePickerOpen"):FireClient(player, candidates)
    end)

    -- Client picked a target -> actually run disguise
    Remotes.event("DisguisePick").OnServerEvent:Connect(function(player, target)
        if state ~= Config.STATES.ROUND then return end
        if roles[player.UserId] ~= Config.ROLE_PENIRU then return end
        if not alive[player.UserId] then return end
        if typeof(target) ~= "Instance" or not target:IsA("Player") then return end
        if target.UserId == player.UserId then return end
        if not alive[target.UserId] then
            notifyOne(player, "Target sudah tidak ada di kota.", "warn", 2)
            return
        end
        local ok, _ = DisguiseSystem.tryDisguise(player, target)
        if ok then
            notifyOne(player, "Penyamaran aktif!", "success", 2)
        else
            notifyOne(player, "Tidak bisa menyamar saat ini.", "warn", 2)
        end
        pushAbilityCooldowns(player)
    end)

    -- Flash + Hacker (client -> server)
    Remotes.event("TryFlash").OnServerEvent:Connect(function(player)
        tryFlash(player)
    end)
    Remotes.event("TryHacker").OnServerEvent:Connect(function(player)
        tryHacker(player)
    end)

    -- Vote chat (client -> server -> all clients).
    -- Only alive in-round players may speak; everyone receives.
    Remotes.event("VoteChatSend").OnServerEvent:Connect(function(player, text)
        if state ~= Config.STATES.VOTING then return end
        if not roles[player.UserId] then return end
        if not alive[player.UserId] then
            notifyOne(player, "Kamu tidak bisa chat (di lobby/penjara).", "warn", 2)
            return
        end
        if typeof(text) ~= "string" then return end
        local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
        if #trimmed == 0 then return end
        if #trimmed > Config.VOTE_CHAT_MAX_LEN then
            trimmed = trimmed:sub(1, Config.VOTE_CHAT_MAX_LEN)
        end
        -- IMPORTANT: do NOT send role over the network — that would leak the
        -- Peniru/Joker identity to client mods. Voice color is uniform.
        Remotes.event("VoteChatBroadcast"):FireAllClients(player.DisplayName, trimmed)
    end)

    Players.PlayerRemoving:Connect(function(player)
        roles[player.UserId] = nil
        subroles[player.UserId] = nil
        alive[player.UserId] = nil
        captured[player.UserId] = nil
        shields[player.UserId] = nil
        captureCooldown[player.UserId] = nil
        flashCooldown[player.UserId] = nil
        hackerCooldown[player.UserId] = nil
        flashActiveUntil[player.UserId] = nil
        hackerActiveUntil[player.UserId] = nil
        votes[player.UserId] = nil
    end)

    task.spawn(gameLoop)

    -- Void-fall monitor: during ROUND, any alive player whose root part falls
    -- below Config.VOID_Y is treated as captured (sent to prison).
    task.spawn(function()
        while true do
            task.wait(0.5)
            if state ~= Config.STATES.ROUND then continue end
            for _, p in ipairs(Players:GetPlayers()) do
                if alive[p.UserId] then
                    local char = p.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root and root.Position.Y < Config.VOID_Y then
                        if roles[p.UserId] == Config.ROLE_PENIRU then
                            -- Peniru falling into the void = instant Warga win.
                            -- Just teleport them out of the void; gameLoop will end the round.
                            peniruVoidFell = true
                            teleportToPrison(p)
                            notifyAll(("%s (Peniru) jatuh ke void! Warga menang!"):format(p.DisplayName), "success", 5)
                        else
                            imprison(p, nil, "void")
                        end
                    end
                end
            end
        end
    end)
end

function GameManager.getState(): string
    return state
end

return GameManager
