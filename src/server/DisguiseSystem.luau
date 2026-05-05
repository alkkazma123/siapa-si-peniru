--!nonstrict
-- Disguise system: when the Peniru disguises as a target, we spawn a fresh R15
-- dummy model built from the target's HumanoidDescription, hide the Peniru's
-- own character, and update the dummy's CFrame each frame to follow the Peniru.
-- This makes the disguise look real (full avatar, not just name swap).

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DisguiseSystem = {}

local OverheadManager
local DataManager
local Remotes

type Original = {
    transparencies: { [BasePart]: number },
    decals: { [Decal]: number },
    nameDisplay: number?,
    healthDisplay: number?,
}

local cooldowns: { [number]: number } = {}
local activeToken: { [number]: number } = {}

local activeDummies: { [number]: Model } = {}
local activeConns: { [number]: RBXScriptConnection } = {}
local activeAnimConns: { [number]: RBXScriptConnection } = {}
local originals: { [number]: Original } = {}

-- Default R15 animation asset ids
local ANIM_IDLE = "rbxassetid://507766388"
local ANIM_WALK = "rbxassetid://913402848"
local ANIM_RUN  = "rbxassetid://913376220"
local ANIM_JUMP = "rbxassetid://507765000"
local ANIM_FALL = "rbxassetid://507767968"

local function getHumanoid(player: Player): Humanoid?
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function hideCharacter(peniru: Player): Original?
    local char = peniru.Character
    if not char then return nil end
    local saved: Original = {
        transparencies = {},
        decals = {},
    }
    for _, inst in ipairs(char:GetDescendants()) do
        if inst:IsA("BasePart") then
            saved.transparencies[inst] = inst.Transparency
            inst.Transparency = 1
            inst.LocalTransparencyModifier = 1
        elseif inst:IsA("Decal") or inst:IsA("Texture") then
            saved.decals[inst] = inst.Transparency
            inst.Transparency = 1
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        saved.nameDisplay = hum.NameDisplayDistance
        saved.healthDisplay = hum.HealthDisplayDistance
        hum.NameDisplayDistance = 0
        hum.HealthDisplayDistance = 0
    end
    -- Hide our own overhead
    if OverheadManager then
        OverheadManager.setVisible(peniru, false)
    end
    return saved
end

local function unhideCharacter(peniru: Player)
    local saved = originals[peniru.UserId]
    originals[peniru.UserId] = nil
    if not saved then return end
    for part, t in pairs(saved.transparencies) do
        if part and part.Parent then
            part.Transparency = t
            part.LocalTransparencyModifier = 0
        end
    end
    for decal, t in pairs(saved.decals) do
        if decal and decal.Parent then
            decal.Transparency = t
        end
    end
    local char = peniru.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.NameDisplayDistance = saved.nameDisplay or 100
            hum.HealthDisplayDistance = saved.healthDisplay or 100
        end
    end
    if OverheadManager then
        OverheadManager.setVisible(peniru, true)
    end
end

local function buildDummy(target: Player, displayName: string, level: number): Model?
    local hum = getHumanoid(target)
    if not hum then return nil end
    local desc: HumanoidDescription? = nil
    pcall(function()
        desc = hum:GetAppliedDescription():Clone()
    end)
    if not desc then return nil end

    local model
    local ok = pcall(function()
        model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15, Enum.AssetTypeVerification.Default)
    end)
    if not ok or not model then
        -- Fallback: try without verification
        pcall(function()
            model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
        end)
    end
    if not model then return nil end

    model.Name = "Disguise_" .. tostring(target.UserId)

    -- Configure all current parts to be non-collide / non-query / non-touch.
    local function makeNonCollide(inst)
        if inst:IsA("BasePart") then
            inst.CanCollide = false
            inst.CanQuery = false
            inst.CanTouch = false
            inst.Massless = true
        end
    end
    for _, inst in ipairs(model:GetDescendants()) do
        makeNonCollide(inst)
    end
    -- Also catch any descendants added later (e.g. accessories streaming in).
    model.DescendantAdded:Connect(makeNonCollide)

    local dHum = model:FindFirstChildOfClass("Humanoid")
    if dHum then
        dHum.DisplayName = displayName
        dHum.NameDisplayDistance = 0   -- our own overhead handles label
        dHum.HealthDisplayDistance = 0
        dHum.BreakJointsOnDeath = false
        dHum.RequiresNeck = false
    end

    local dHRP = model:FindFirstChild("HumanoidRootPart")
    if dHRP then
        dHRP.Anchored = true
    end

    -- Attach our custom overhead with target name + level
    if OverheadManager then
        OverheadManager.applyToCharacter(model, displayName, level)
    end

    return model
end

local function startAnimLoop(peniru: Player, dummy: Model)
    local dHum = dummy:FindFirstChildOfClass("Humanoid")
    if not dHum then return end
    local animator = dHum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = dHum
    end

    local function makeAnim(id: string)
        local a = Instance.new("Animation")
        a.AnimationId = id
        return a
    end

    local tracks = {}
    local ok = pcall(function()
        tracks.idle = animator:LoadAnimation(makeAnim(ANIM_IDLE))
        tracks.walk = animator:LoadAnimation(makeAnim(ANIM_WALK))
        tracks.run  = animator:LoadAnimation(makeAnim(ANIM_RUN))
        tracks.jump = animator:LoadAnimation(makeAnim(ANIM_JUMP))
        tracks.fall = animator:LoadAnimation(makeAnim(ANIM_FALL))
    end)
    if not ok then return end

    -- Loop everything
    for _, t in pairs(tracks) do
        t.Looped = true
    end

    tracks.idle:Play(0)

    local lastState: string = "idle"
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local char = peniru.Character
        local pHum = char and char:FindFirstChildOfClass("Humanoid")
        if not pHum then return end

        local hState = pHum:GetState()
        local newState: string
        if hState == Enum.HumanoidStateType.Jumping then
            newState = "jump"
        elseif hState == Enum.HumanoidStateType.Freefall then
            newState = "fall"
        elseif pHum.MoveDirection.Magnitude > 0.05 then
            newState = (pHum.WalkSpeed > 22) and "run" or "walk"
        else
            newState = "idle"
        end

        if newState ~= lastState then
            for _, t in pairs(tracks) do t:Stop(0.15) end
            local active = tracks[newState]
            if active then active:Play(0.15) end
            lastState = newState
        end

        -- Match track speed to player walk speed for natural feel
        if newState == "walk" or newState == "run" then
            local active = tracks[newState]
            if active then
                active:AdjustSpeed(math.clamp(pHum.WalkSpeed / 16, 0.6, 2.5))
            end
        end
    end)
    activeAnimConns[peniru.UserId] = conn
end

local function startFollowLoop(peniru: Player, dummy: Model)
    local dHRP = dummy:FindFirstChild("HumanoidRootPart")
    if not dHRP then return end
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local char = peniru.Character
        local pHRP = char and char:FindFirstChild("HumanoidRootPart")
        if not pHRP or not pHRP.Parent or not dHRP.Parent then return end
        dHRP.CFrame = pHRP.CFrame
    end)
    activeConns[peniru.UserId] = conn
end

function DisguiseSystem.tryDisguise(peniru: Player, target: Player)
    local now = os.clock()
    if (cooldowns[peniru.UserId] or 0) > now then
        return false, "Cooldown aktif"
    end
    if not target or target == peniru then
        return false, "Target tidak valid"
    end
    -- Already disguised? Revert first.
    if activeDummies[peniru.UserId] then
        DisguiseSystem.restore(peniru)
    end

    local profile = DataManager and DataManager.getProfile(target)
    local lvl = profile and profile.level or 1

    -- Build dummy
    local dummy = buildDummy(target, target.DisplayName, lvl)
    if not dummy then
        return false, "Gagal membuat penyamaran"
    end
    dummy.Parent = workspace

    -- Place dummy at peniru position to start
    local pchar = peniru.Character
    local pHRP = pchar and pchar:FindFirstChild("HumanoidRootPart")
    local dHRP = dummy:FindFirstChild("HumanoidRootPart")
    if pHRP and dHRP then
        dHRP.CFrame = pHRP.CFrame
    end

    -- Hide peniru's body
    originals[peniru.UserId] = hideCharacter(peniru)

    activeDummies[peniru.UserId] = dummy
    startFollowLoop(peniru, dummy)
    startAnimLoop(peniru, dummy)

    cooldowns[peniru.UserId] = now + Config.DISGUISE_COOLDOWN

    if Remotes then
        Remotes.event("DisguiseUpdated"):FireAllClients(peniru, target)
    end

    -- Auto-revert
    local token = (activeToken[peniru.UserId] or 0) + 1
    activeToken[peniru.UserId] = token
    task.delay(Config.DISGUISE_DURATION, function()
        if activeToken[peniru.UserId] ~= token then return end
        DisguiseSystem.restore(peniru)
        if Remotes then
            Remotes.event("Notify"):FireClient(peniru, "Penyamaran berakhir", "warn", 2)
        end
    end)

    return true, target
end

function DisguiseSystem.restore(player: Player)
    -- Disconnect follow
    local conn = activeConns[player.UserId]
    if conn then
        conn:Disconnect()
        activeConns[player.UserId] = nil
    end
    -- Disconnect anim
    local aconn = activeAnimConns[player.UserId]
    if aconn then
        aconn:Disconnect()
        activeAnimConns[player.UserId] = nil
    end
    -- Destroy dummy
    local dummy = activeDummies[player.UserId]
    if dummy then
        dummy:Destroy()
        activeDummies[player.UserId] = nil
    end
    -- Unhide peniru
    unhideCharacter(player)

    if Remotes then
        Remotes.event("DisguiseUpdated"):FireAllClients(player, nil)
    end
end

function DisguiseSystem.restoreAll()
    for userId, _ in pairs(activeDummies) do
        local p = Players:GetPlayerByUserId(userId)
        if p then DisguiseSystem.restore(p) end
    end
    for _, conn in pairs(activeConns) do
        if conn then conn:Disconnect() end
    end
    for _, conn in pairs(activeAnimConns) do
        if conn then conn:Disconnect() end
    end
    for _, dummy in pairs(activeDummies) do
        if dummy then dummy:Destroy() end
    end
    activeConns = {}
    activeAnimConns = {}
    activeDummies = {}
    originals = {}
    cooldowns = {}
    activeToken = {}
end

function DisguiseSystem.init(deps)
    OverheadManager = deps.OverheadManager
    DataManager     = deps.DataManager
    Remotes         = deps.Remotes

    local function bindCharacterCleanup(player: Player)
        player.CharacterRemoving:Connect(function()
            if activeDummies[player.UserId] then
                DisguiseSystem.restore(player)
            end
        end)
    end

    Players.PlayerAdded:Connect(bindCharacterCleanup)
    for _, p in ipairs(Players:GetPlayers()) do
        bindCharacterCleanup(p)
    end

    -- If a disguised player leaves, force-clear their disguise.
    Players.PlayerRemoving:Connect(function(player)
        if activeDummies[player.UserId] then
            DisguiseSystem.restore(player)
        end
        cooldowns[player.UserId] = nil
        activeToken[player.UserId] = nil
    end)
end

function DisguiseSystem.getCooldownEnd(player: Player): number
    return cooldowns[player.UserId] or 0
end

return DisguiseSystem
