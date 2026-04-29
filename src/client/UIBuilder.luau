--!nonstrict
--!nolint LocalUnused
-- Builds all UI for "Siapa Si Peniru" programmatically (no manual GUIs).
-- Dark theme, minimalist, mobile + PC support.
-- Many GuiObjects are intentionally created without further reference (auto-parented).

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Util   = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"))

local THEME = Config.THEME
local player = Players.LocalPlayer

local UIBuilder = {}

----------------------------------------------------------------
-- helpers
----------------------------------------------------------------

local function corner(parent: Instance, radius: number)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness
    s.Transparency = transparency or 0
    s.Parent = parent
    return s
end

local function pad(parent: Instance, p: number)
    local up = Instance.new("UIPadding")
    up.PaddingLeft = UDim.new(0, p)
    up.PaddingRight = UDim.new(0, p)
    up.PaddingTop = UDim.new(0, p)
    up.PaddingBottom = UDim.new(0, p)
    up.Parent = parent
    return up
end

local function makeText(parent: Instance, props: { [string]: any })
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.Gotham
    t.TextColor3 = THEME.TEXT
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextYAlignment = Enum.TextYAlignment.Center
    t.TextSize = 14
    t.Parent = parent
    for k, v in pairs(props) do (t :: any)[k] = v end
    return t
end

local function makeFrame(parent: Instance, props: { [string]: any })
    local f = Instance.new("Frame")
    f.BackgroundColor3 = THEME.SURFACE
    f.BorderSizePixel = 0
    f.Parent = parent
    for k, v in pairs(props) do (f :: any)[k] = v end
    return f
end

local function makeButton(parent: Instance, props: { [string]: any })
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = THEME.SURFACE
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Font = Enum.Font.GothamSemibold
    b.TextColor3 = THEME.TEXT
    b.TextSize = 14
    b.Text = ""
    b.Parent = parent
    for k, v in pairs(props) do (b :: any)[k] = v end
    return b
end

local function pulse(instance: GuiObject, scale: number?)
    scale = scale or 1.06
    local original = instance.Size
    local tw = TweenService:Create(instance, TweenInfo.new(0.12, Enum.EasingStyle.Sine), {
        Size = UDim2.new(original.X.Scale * scale, original.X.Offset * scale,
                         original.Y.Scale * scale, original.Y.Offset * scale)
    })
    tw:Play()
    tw.Completed:Connect(function()
        TweenService:Create(instance, TweenInfo.new(0.18, Enum.EasingStyle.Sine), { Size = original }):Play()
    end)
end

----------------------------------------------------------------
-- root
----------------------------------------------------------------

local screenGui: ScreenGui
local notifyStack : Frame
local timerLabel  : TextLabel
local stateLabel  : TextLabel
local roleBadge   : Frame
local roleBadgeText : TextLabel
local coinLabel   : TextLabel
local levelLabel  : TextLabel
local xpBarFill   : Frame
local mobileButtons : Frame
local captureBtn  : TextButton
local disguiseBtn : TextButton
local voteBtn     : TextButton
local voteOverlay : Frame
local voteList    : Frame
local voteTitle   : TextLabel
local voteResultPanel : Frame
local revealPanel : Frame
local roleRevealPanel : Frame
local leaderboardBtn : TextButton
local leaderboardPanel : Frame
local lobbyInfoPanel : Frame

local captureCooldownEnd, disguiseCooldownEnd = 0, 0

----------------------------------------------------------------
-- build
----------------------------------------------------------------

function UIBuilder.build()
    if screenGui and screenGui.Parent then screenGui:Destroy() end

    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PeniruUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = player:WaitForChild("PlayerGui")

    -- Top bar (timer + state + role badge)
    local topBar = makeFrame(screenGui, {
        Name = "TopBar",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 16),
        Size = UDim2.new(0, 480, 0, 56),
        BackgroundColor3 = THEME.BG,
        BackgroundTransparency = 0.05,
    })
    corner(topBar, 14)
    stroke(topBar, THEME.BORDER, 1, 0.4)

    stateLabel = makeText(topBar, {
        Name = "State",
        Position = UDim2.new(0, 16, 0, 6),
        Size = UDim2.new(1, -32, 0, 18),
        Text = "MEMUAT...",
        Font = Enum.Font.GothamMedium,
        TextColor3 = THEME.TEXT_DIM,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    timerLabel = makeText(topBar, {
        Name = "Timer",
        Position = UDim2.new(0, 16, 0, 22),
        Size = UDim2.new(1, -32, 0, 28),
        Text = "Menunggu pemain...",
        Font = Enum.Font.GothamBold,
        TextColor3 = THEME.TEXT,
        TextSize = 22,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    -- Role badge (right side)
    roleBadge = makeFrame(topBar, {
        Name = "RoleBadge",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.new(0, 110, 0, 36),
        BackgroundColor3 = THEME.BG_ALT,
        Visible = false,
    })
    corner(roleBadge, 10)
    stroke(roleBadge, THEME.BORDER, 1, 0.5)
    roleBadgeText = makeText(roleBadge, {
        Size = UDim2.fromScale(1, 1),
        Text = "WARGA",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = THEME.WARGA,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    -- Stats panel (bottom-left): Level + XP bar + Coins
    local stats = makeFrame(screenGui, {
        Name = "Stats",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 16, 1, -16),
        Size = UDim2.new(0, 230, 0, 70),
        BackgroundColor3 = THEME.BG,
        BackgroundTransparency = 0.1,
    })
    corner(stats, 12)
    stroke(stats, THEME.BORDER, 1, 0.5)
    pad(stats, 10)

    levelLabel = makeText(stats, {
        Name = "Level",
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 18),
        Text = "Level 1",
        Font = Enum.Font.GothamBold,
        TextColor3 = THEME.ACCENT,
        TextSize = 16,
    })

    coinLabel = makeText(stats, {
        Name = "Coins",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 100, 0, 18),
        Text = "🟡 0",
        Font = Enum.Font.GothamSemibold,
        TextColor3 = THEME.WARN,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local xpBg = makeFrame(stats, {
        Name = "XPBg",
        Position = UDim2.new(0, 0, 0, 26),
        Size = UDim2.new(1, 0, 0, 8),
        BackgroundColor3 = THEME.BG_ALT,
    })
    corner(xpBg, 4)

    xpBarFill = makeFrame(xpBg, {
        Name = "Fill",
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = THEME.ACCENT_2,
    })
    corner(xpBarFill, 4)

    local xpText = makeText(stats, {
        Name = "XPText",
        Position = UDim2.new(0, 0, 0, 38),
        Size = UDim2.new(1, 0, 0, 12),
        Text = "0 / 100 XP",
        Font = Enum.Font.Gotham,
        TextColor3 = THEME.TEXT_DIM,
        TextSize = 11,
    })
    xpText.Name = "XPText"

    -- Mobile / accessible action buttons (bottom-right)
    mobileButtons = makeFrame(screenGui, {
        Name = "Actions",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.new(0, 280, 0, 84),
        BackgroundTransparency = 1,
    })
    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Horizontal
    list.HorizontalAlignment = Enum.HorizontalAlignment.Right
    list.VerticalAlignment = Enum.VerticalAlignment.Bottom
    list.Padding = UDim.new(0, 8)
    list.Parent = mobileButtons

    captureBtn = makeButton(mobileButtons, {
        Name = "CaptureBtn",
        Size = UDim2.new(0, 84, 0, 84),
        BackgroundColor3 = THEME.DANGER,
        Text = "TANGKAP\n[E]",
        TextColor3 = THEME.TEXT,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        AutoButtonColor = true,
        Visible = false,
    })
    corner(captureBtn, 16)
    stroke(captureBtn, THEME.BORDER, 1, 0.4)

    disguiseBtn = makeButton(mobileButtons, {
        Name = "DisguiseBtn",
        Size = UDim2.new(0, 84, 0, 84),
        BackgroundColor3 = THEME.ACCENT,
        Text = "MENYAMAR\n[Q]",
        TextColor3 = THEME.TEXT,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        AutoButtonColor = true,
        Visible = false,
    })
    corner(disguiseBtn, 16)
    stroke(disguiseBtn, THEME.BORDER, 1, 0.4)

    voteBtn = makeButton(mobileButtons, {
        Name = "VoteBtn",
        Size = UDim2.new(0, 84, 0, 84),
        BackgroundColor3 = THEME.ACCENT_2,
        Text = "VOTE\n[V]",
        TextColor3 = Color3.fromRGB(20, 22, 28),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        AutoButtonColor = true,
        Visible = false,
    })
    corner(voteBtn, 16)
    stroke(voteBtn, THEME.BORDER, 1, 0.4)

    -- Notification stack (top-center, below top bar)
    notifyStack = makeFrame(screenGui, {
        Name = "Notifications",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 84),
        Size = UDim2.new(0, 480, 0, 200),
        BackgroundTransparency = 1,
    })
    local nlist = Instance.new("UIListLayout")
    nlist.FillDirection = Enum.FillDirection.Vertical
    nlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
    nlist.SortOrder = Enum.SortOrder.LayoutOrder
    nlist.Padding = UDim.new(0, 6)
    nlist.Parent = notifyStack

    -- Voting overlay (full-screen)
    voteOverlay = makeFrame(screenGui, {
        Name = "VoteOverlay",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(8, 9, 14),
        BackgroundTransparency = 0.25,
        Visible = false,
        ZIndex = 50,
    })

    voteTitle = makeText(voteOverlay, {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 80),
        Size = UDim2.new(0, 700, 0, 60),
        Text = "SIAPA SI PENIRU?",
        Font = Enum.Font.GothamBlack,
        TextColor3 = THEME.ACCENT,
        TextSize = 36,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 51,
    })

    local voteSub = makeText(voteOverlay, {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 132),
        Size = UDim2.new(0, 700, 0, 24),
        Text = "Pilih satu pemain. Kamu hanya bisa memilih sekali.",
        Font = Enum.Font.Gotham,
        TextColor3 = THEME.TEXT_DIM,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 51,
    })

    voteList = makeFrame(voteOverlay, {
        Name = "List",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 20),
        Size = UDim2.new(0, 720, 0, 360),
        BackgroundTransparency = 1,
        ZIndex = 51,
    })
    local vgrid = Instance.new("UIGridLayout")
    vgrid.CellSize = UDim2.new(0, 220, 0, 80)
    vgrid.CellPadding = UDim2.new(0, 12, 0, 12)
    vgrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
    vgrid.VerticalAlignment = Enum.VerticalAlignment.Center
    vgrid.SortOrder = Enum.SortOrder.LayoutOrder
    vgrid.Parent = voteList

    -- Vote result tally
    voteResultPanel = makeFrame(screenGui, {
        Name = "VoteResultPanel",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 480, 0, 360),
        BackgroundColor3 = THEME.BG,
        BackgroundTransparency = 0.05,
        Visible = false,
        ZIndex = 60,
    })
    corner(voteResultPanel, 16)
    stroke(voteResultPanel, THEME.BORDER, 1, 0.3)

    -- Reveal panel (win/lose announcement)
    revealPanel = makeFrame(screenGui, {
        Name = "RevealPanel",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 70,
    })

    -- Role reveal panel
    roleRevealPanel = makeFrame(screenGui, {
        Name = "RoleRevealPanel",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.4,
        Visible = false,
        ZIndex = 80,
    })

    -- Leaderboard toggle button (top-left)
    leaderboardBtn = makeButton(screenGui, {
        Name = "LBBtn",
        Position = UDim2.new(0, 16, 0, 16),
        Size = UDim2.new(0, 56, 0, 56),
        BackgroundColor3 = THEME.SURFACE,
        Text = "🏆",
        TextSize = 24,
        AutoButtonColor = true,
    })
    corner(leaderboardBtn, 14)
    stroke(leaderboardBtn, THEME.BORDER, 1, 0.4)

    -- Leaderboard panel
    leaderboardPanel = makeFrame(screenGui, {
        Name = "LBPanel",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 16, 0.5, 0),
        Size = UDim2.new(0, 320, 0, 480),
        BackgroundColor3 = THEME.BG,
        BackgroundTransparency = 0.05,
        Visible = false,
        ZIndex = 30,
    })
    corner(leaderboardPanel, 14)
    stroke(leaderboardPanel, THEME.BORDER, 1, 0.4)

    local lbTitle = makeText(leaderboardPanel, {
        Position = UDim2.new(0, 16, 0, 12),
        Size = UDim2.new(1, -32, 0, 24),
        Text = "GLOBAL LEADERBOARD",
        Font = Enum.Font.GothamBlack,
        TextColor3 = THEME.ACCENT,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local lbSub = makeText(leaderboardPanel, {
        Position = UDim2.new(0, 16, 0, 36),
        Size = UDim2.new(1, -32, 0, 16),
        Text = "Top pemain berdasar Level + XP",
        Font = Enum.Font.Gotham,
        TextColor3 = THEME.TEXT_DIM,
        TextSize = 11,
    })

    local lbList = Instance.new("ScrollingFrame")
    lbList.Name = "List"
    lbList.Position = UDim2.new(0, 12, 0, 60)
    lbList.Size = UDim2.new(1, -24, 1, -72)
    lbList.BackgroundTransparency = 1
    lbList.BorderSizePixel = 0
    lbList.CanvasSize = UDim2.fromOffset(0, 0)
    lbList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    lbList.ScrollBarThickness = 4
    lbList.ScrollBarImageColor3 = THEME.BORDER
    lbList.Parent = leaderboardPanel
    local lbLayout = Instance.new("UIListLayout")
    lbLayout.SortOrder = Enum.SortOrder.LayoutOrder
    lbLayout.Padding = UDim.new(0, 6)
    lbLayout.Parent = lbList

    -- Lobby info panel (bottom-center)
    lobbyInfoPanel = makeFrame(screenGui, {
        Name = "LobbyInfo",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -110),
        Size = UDim2.new(0, 520, 0, 80),
        BackgroundColor3 = THEME.BG,
        BackgroundTransparency = 0.1,
        Visible = false,
    })
    corner(lobbyInfoPanel, 12)
    stroke(lobbyInfoPanel, THEME.BORDER, 1, 0.4)
    pad(lobbyInfoPanel, 12)

    local lobbyInfoText = makeText(lobbyInfoPanel, {
        Name = "Body",
        Size = UDim2.fromScale(1, 1),
        Text = "Tunggu di lobby. Game mulai otomatis saat ada minimal 3 pemain.\nKontrol: [E] tangkap • [Q] menyamar • [V] vote • PC + Mobile didukung.",
        Font = Enum.Font.Gotham,
        TextColor3 = THEME.TEXT_DIM,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextWrapped = true,
    })

    return {
        screenGui = screenGui,
        captureBtn = captureBtn,
        disguiseBtn = disguiseBtn,
        voteBtn = voteBtn,
        leaderboardBtn = leaderboardBtn,
        leaderboardPanel = leaderboardPanel,
        leaderboardList = lbList,
    }
end

----------------------------------------------------------------
-- public update API
----------------------------------------------------------------

function UIBuilder.setState(label: string)
    if stateLabel then stateLabel.Text = string.upper(label) end
end

function UIBuilder.setTimer(label: string, seconds: number?)
    if not timerLabel then return end
    if seconds and seconds > 0 then
        timerLabel.Text = string.format("%s • %s", label, Util.formatTime(seconds))
    else
        timerLabel.Text = label
    end
end

function UIBuilder.setRole(role: string?)
    if not roleBadge then return end
    if not role then
        roleBadge.Visible = false
        return
    end
    roleBadge.Visible = true
    roleBadgeText.Text = string.upper(role)
    if role == Config.ROLE_PENIRU then
        roleBadgeText.TextColor3 = THEME.PENIRU
    else
        roleBadgeText.TextColor3 = THEME.WARGA
    end
end

function UIBuilder.setStats(profile: { coins: number, xp: number, level: number, xpPerLevel: number? })
    if not levelLabel then return end
    levelLabel.Text = "Level " .. tostring(profile.level)
    coinLabel.Text  = "🟡 " .. tostring(profile.coins)
    local per = profile.xpPerLevel or Config.XP_PER_LEVEL
    local pct = math.clamp(profile.xp / per, 0, 1)
    TweenService:Create(xpBarFill, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {
        Size = UDim2.new(pct, 0, 1, 0)
    }):Play()
    local xpText = xpBarFill.Parent.Parent:FindFirstChild("XPText")
    if xpText then xpText.Text = string.format("%d / %d XP", profile.xp, per) end
end

function UIBuilder.setActionButtons(role: string?, isVoting: boolean)
    if not captureBtn then return end
    captureBtn.Visible  = role == Config.ROLE_PENIRU and not isVoting
    disguiseBtn.Visible = role == Config.ROLE_PENIRU and not isVoting
    voteBtn.Visible     = isVoting and role ~= nil
end

function UIBuilder.setAbilityCooldowns(captureEnd: number, disguiseEnd: number)
    captureCooldownEnd = captureEnd or 0
    disguiseCooldownEnd = disguiseEnd or 0
end

function UIBuilder.tickCooldowns()
    if not captureBtn then return end
    local now = os.clock()
    local cLeft = math.max(0, captureCooldownEnd - now)
    local dLeft = math.max(0, disguiseCooldownEnd - now)
    if cLeft > 0 then
        captureBtn.Text = string.format("TANGKAP\n%.1fs", cLeft)
        captureBtn.BackgroundTransparency = 0.4
    else
        captureBtn.Text = "TANGKAP\n[E]"
        captureBtn.BackgroundTransparency = 0
    end
    if dLeft > 0 then
        disguiseBtn.Text = string.format("MENYAMAR\n%.1fs", dLeft)
        disguiseBtn.BackgroundTransparency = 0.4
    else
        disguiseBtn.Text = "MENYAMAR\n[Q]"
        disguiseBtn.BackgroundTransparency = 0
    end
end

----------------------------------------------------------------
-- notifications
----------------------------------------------------------------

local function colorByKind(kind: string): Color3
    if kind == "danger" then return THEME.DANGER
    elseif kind == "warn" then return THEME.WARN
    elseif kind == "success" then return THEME.SUCCESS
    end
    return THEME.ACCENT
end

function UIBuilder.notify(text: string, kind: string?, duration: number?)
    if not notifyStack then return end
    duration = duration or 3
    local container = makeFrame(notifyStack, {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = THEME.BG,
        BackgroundTransparency = 0.05,
    })
    corner(container, 10)
    stroke(container, colorByKind(kind or "info"), 1.5, 0.2)
    local lbl = makeText(container, {
        Size = UDim2.fromScale(1, 1),
        Text = text,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextColor3 = THEME.TEXT,
        Font = Enum.Font.GothamSemibold,
        TextSize = 14,
    })
    pad(container, 10)
    container.Position = UDim2.new(0, 0, 0, -10)
    TweenService:Create(container, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {
        Position = UDim2.new(0, 0, 0, 0),
    }):Play()
    task.delay(duration, function()
        local fade = TweenService:Create(container, TweenInfo.new(0.4), {
            BackgroundTransparency = 1,
        })
        fade:Play()
        TweenService:Create(lbl, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
        fade.Completed:Wait()
        container:Destroy()
    end)
end

----------------------------------------------------------------
-- voting UI
----------------------------------------------------------------

local voteCallback: (Player) -> ()
local voteCast = false

function UIBuilder.openVote(candidates: { Player }, onVote: (Player) -> ())
    voteCallback = onVote
    voteCast = false
    voteOverlay.Visible = true
    voteOverlay.BackgroundTransparency = 1
    TweenService:Create(voteOverlay, TweenInfo.new(0.4), { BackgroundTransparency = 0.25 }):Play()

    voteList:ClearAllChildren()
    local vgrid = Instance.new("UIGridLayout")
    vgrid.CellSize = UDim2.new(0, 220, 0, 80)
    vgrid.CellPadding = UDim2.new(0, 12, 0, 12)
    vgrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
    vgrid.VerticalAlignment = Enum.VerticalAlignment.Center
    vgrid.SortOrder = Enum.SortOrder.LayoutOrder
    vgrid.Parent = voteList

    for _, p in ipairs(candidates) do
        local btn = makeButton(voteList, {
            BackgroundColor3 = THEME.SURFACE,
            Text = p.DisplayName .. "\n@" .. p.Name,
            Font = Enum.Font.GothamSemibold,
            TextSize = 16,
            ZIndex = 52,
        })
        corner(btn, 14)
        stroke(btn, THEME.BORDER, 1.5, 0.3)
        btn.MouseButton1Click:Connect(function()
            if voteCast then return end
            voteCast = true
            for _, child in ipairs(voteList:GetChildren()) do
                if child:IsA("TextButton") and child ~= btn then
                    child.AutoButtonColor = false
                    child.BackgroundTransparency = 0.5
                    child.TextTransparency = 0.5
                end
            end
            btn.BackgroundColor3 = THEME.SUCCESS
            btn.TextColor3 = Color3.fromRGB(20, 22, 28)
            pulse(btn, 1.08)
            if voteCallback then voteCallback(p) end
        end)
    end
end

function UIBuilder.closeVote()
    if voteOverlay then
        TweenService:Create(voteOverlay, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
        task.delay(0.3, function() voteOverlay.Visible = false end)
    end
end

function UIBuilder.showVoteResult(tallyOut: { { name: string, count: number, userId: number } }, accusedName: string?, isPeniru: boolean)
    voteResultPanel:ClearAllChildren()
    voteResultPanel.Visible = true
    voteResultPanel.BackgroundTransparency = 1
    pad(voteResultPanel, 18)

    local title = makeText(voteResultPanel, {
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 32),
        Text = "HASIL VOTING",
        Font = Enum.Font.GothamBlack,
        TextColor3 = THEME.ACCENT,
        TextSize = 22,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 61,
    })

    local sub = makeText(voteResultPanel, {
        Position = UDim2.new(0, 0, 0, 36),
        Size = UDim2.new(1, 0, 0, 22),
        Text = accusedName and ("Tertuduh: " .. accusedName) or "Tidak ada tertuduh",
        Font = Enum.Font.GothamSemibold,
        TextColor3 = isPeniru and THEME.SUCCESS or THEME.DANGER,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 61,
    })

    local listFrame = makeFrame(voteResultPanel, {
        Position = UDim2.new(0, 0, 0, 70),
        Size = UDim2.new(1, 0, 1, -70),
        BackgroundTransparency = 1,
        ZIndex = 61,
    })
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.Parent = listFrame

    for i, entry in ipairs(tallyOut) do
        local row = makeFrame(listFrame, {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundColor3 = THEME.SURFACE,
            ZIndex = 62,
        })
        corner(row, 8)
        local nLbl = makeText(row, {
            Position = UDim2.new(0, 12, 0, 0),
            Size = UDim2.new(0.6, 0, 1, 0),
            Text = string.format("%d. %s", i, entry.name),
            Font = Enum.Font.GothamSemibold,
            TextSize = 14,
            ZIndex = 63,
        })
        local cLbl = makeText(row, {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -12, 0, 0),
            Size = UDim2.new(0.4, 0, 1, 0),
            Text = string.format("%d suara", entry.count),
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = THEME.ACCENT_2,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            ZIndex = 63,
        })
    end

    TweenService:Create(voteResultPanel, TweenInfo.new(0.35, Enum.EasingStyle.Back), {
        BackgroundTransparency = 0.05,
    }):Play()

    task.delay(5, function()
        TweenService:Create(voteResultPanel, TweenInfo.new(0.3), {
            BackgroundTransparency = 1,
        }):Play()
        task.wait(0.3)
        voteResultPanel.Visible = false
    end)
end

----------------------------------------------------------------
-- role + win reveal animations
----------------------------------------------------------------

function UIBuilder.showRoleReveal(role: string, info: any)
    roleRevealPanel:ClearAllChildren()
    roleRevealPanel.Visible = true
    roleRevealPanel.BackgroundTransparency = 1
    TweenService:Create(roleRevealPanel, TweenInfo.new(0.3), { BackgroundTransparency = 0.5 }):Play()

    local card = makeFrame(roleRevealPanel, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 80),
        Size = UDim2.new(0, 460, 0, 240),
        BackgroundColor3 = THEME.BG,
        BackgroundTransparency = 1,
        ZIndex = 81,
    })
    corner(card, 18)
    local color = role == Config.ROLE_PENIRU and THEME.PENIRU or THEME.WARGA
    stroke(card, color, 2, 0)

    local roleLbl = makeText(card, {
        Position = UDim2.new(0, 0, 0, 30),
        Size = UDim2.new(1, 0, 0, 36),
        Text = "PERAN KAMU",
        Font = Enum.Font.GothamMedium,
        TextColor3 = THEME.TEXT_DIM,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 82,
    })
    local big = makeText(card, {
        Position = UDim2.new(0, 0, 0, 70),
        Size = UDim2.new(1, 0, 0, 70),
        Text = string.upper(role),
        Font = Enum.Font.GothamBlack,
        TextColor3 = color,
        TextSize = 56,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 82,
    })
    local desc = makeText(card, {
        Position = UDim2.new(0, 16, 0, 150),
        Size = UDim2.new(1, -32, 0, 70),
        Text = role == Config.ROLE_PENIRU
            and "Tangkap pemain dengan [E]. Menyamar dengan [Q]. Sisakan 1 survivor untuk menang."
            or "Cari Si Peniru. Vote dia di akhir ronde untuk menang.",
        Font = Enum.Font.Gotham,
        TextColor3 = THEME.TEXT,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextWrapped = true,
        ZIndex = 82,
    })

    -- Animate card in
    TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundTransparency = 0,
    }):Play()

    task.delay(3.5, function()
        TweenService:Create(card, TweenInfo.new(0.3), {
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, 0, 0.5, -40),
        }):Play()
        TweenService:Create(roleRevealPanel, TweenInfo.new(0.3), {
            BackgroundTransparency = 1,
        }):Play()
        task.wait(0.3)
        roleRevealPanel.Visible = false
    end)
end

function UIBuilder.showWinAnnouncement(winningTeam: string, peniruName: string?)
    revealPanel:ClearAllChildren()
    revealPanel.Visible = true
    revealPanel.BackgroundTransparency = 1
    TweenService:Create(revealPanel, TweenInfo.new(0.3), { BackgroundTransparency = 0.5 }):Play()

    local color = winningTeam == "Warga" and THEME.WARGA or THEME.PENIRU
    local title = makeText(revealPanel, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, -40),
        Size = UDim2.new(1, 0, 0, 80),
        Text = string.format("TIM %s MENANG", string.upper(winningTeam)),
        Font = Enum.Font.GothamBlack,
        TextColor3 = color,
        TextSize = 56,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 71,
    })
    local subText = winningTeam == "Warga"
        and (peniruName and ("Si Peniru: " .. peniruName) or "Si Peniru terungkap.")
        or (peniruName and ("Si Peniru: " .. peniruName) or "Peniru berhasil bersembunyi.")
    local sub = makeText(revealPanel, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 30),
        Size = UDim2.new(1, 0, 0, 32),
        Text = subText,
        Font = Enum.Font.GothamSemibold,
        TextColor3 = THEME.TEXT,
        TextSize = 22,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 71,
    })

    title.TextTransparency = 1
    sub.TextTransparency = 1
    TweenService:Create(title, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
    TweenService:Create(sub,   TweenInfo.new(0.5), { TextTransparency = 0 }):Play()

    task.delay(Config.REVEAL_DURATION - 0.5, function()
        TweenService:Create(revealPanel, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(title, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
        TweenService:Create(sub,   TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
        task.wait(0.4)
        revealPanel.Visible = false
    end)
end

----------------------------------------------------------------
-- leaderboard
----------------------------------------------------------------

function UIBuilder.toggleLeaderboard(): boolean
    leaderboardPanel.Visible = not leaderboardPanel.Visible
    return leaderboardPanel.Visible
end

function UIBuilder.populateLeaderboard(entries: { { name: string, level: number, xp: number, userId: number } })
    local list = leaderboardPanel:FindFirstChild("List")
    if not list then return end
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    if #entries == 0 then
        local empty = makeText(list, {
            Size = UDim2.new(1, 0, 0, 30),
            Text = "Belum ada data leaderboard.",
            Font = Enum.Font.Gotham,
            TextColor3 = THEME.TEXT_DIM,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        empty.BackgroundTransparency = 1
        return
    end
    for i, e in ipairs(entries) do
        local row = makeFrame(list, {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = THEME.SURFACE,
        })
        corner(row, 8)
        local idx = makeText(row, {
            Position = UDim2.new(0, 8, 0, 0),
            Size = UDim2.new(0, 28, 1, 0),
            Text = "#" .. tostring(i),
            Font = Enum.Font.GothamBold,
            TextColor3 = THEME.ACCENT,
            TextSize = 13,
        })
        local nm = makeText(row, {
            Position = UDim2.new(0, 40, 0, 0),
            Size = UDim2.new(1, -120, 1, 0),
            Text = e.name,
            Font = Enum.Font.GothamSemibold,
            TextSize = 13,
        })
        local lvl = makeText(row, {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -8, 0, 0),
            Size = UDim2.new(0, 80, 1, 0),
            Text = string.format("LV %d", e.level),
            Font = Enum.Font.GothamBold,
            TextColor3 = THEME.ACCENT_2,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Right,
        })
    end
end

function UIBuilder.setLobbyVisible(b: boolean)
    if lobbyInfoPanel then lobbyInfoPanel.Visible = b end
end

return UIBuilder
