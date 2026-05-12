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
local flashBtn    : TextButton
local hackerBtn   : TextButton
local voteBtn     : TextButton
local voteOverlay : Frame
local voteList    : Frame
local voteTitle   : TextLabel
local voteResultPanel : Frame
local voteChatPanel    : Frame
local voteChatLines    : ScrollingFrame
local voteChatInput    : TextBox
local voteChatHooked   = false
local voteCandidatesOrdered: { Player } = {}
local revealPanel : Frame
local roleRevealPanel : Frame
local leaderboardBtn : TextButton
local leaderboardPanel : Frame
local lobbyInfoPanel : Frame

local captureCooldownEnd, disguiseCooldownEnd = 0, 0
local flashCooldownEnd, hackerCooldownEnd = 0, 0
local flashActiveUntil, hackerActiveUntil = 0, 0
local shieldCharges = 0
local shopBtn       : TextButton
local rulesBtn      : TextButton
local shopFrame     : Frame
local rulesFrame    : Frame
local loadingFrame  : Frame
local disguiseFrame : Frame
local disguiseList  : ScrollingFrame
-- Detektif kill UI
local detektifBtn      : TextButton
local detektifPanel    : Frame
local detektifList     : ScrollingFrame
local detektifSelected : Player?  = nil
local detektifConfirmBtn : TextButton
local detektifClosed   = false
-- Mission UI
local missionBar       : Frame
local missionBarFill   : Frame
local missionBarText   : TextLabel
local missionListPanel : Frame
local missionListItems : Frame
local missionData: { id: string, name: string, done: boolean }? = nil
-- Skip vote
local voteSkipBtn      : TextButton
-- Daily login modal
local dailyFrame       : Frame

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

    -- Auto-scale: keep UI roughly the same density across PC/mobile by scaling
    -- to the smaller axis of the viewport relative to the 1280x720 baseline.
    local uiScale = Instance.new("UIScale")
    uiScale.Name = "AutoScale"
    uiScale.Scale = 1
    uiScale.Parent = screenGui

    local Workspace = game:GetService("Workspace")
    local function recalcScale()
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local v = cam.ViewportSize
        if v.X < 1 or v.Y < 1 then return end
        local s = math.min(v.X / 1280, v.Y / 720)
        -- Clamp so it never goes too small on phones or absurdly big on 4K.
        s = math.clamp(s, 0.65, 1.4)
        uiScale.Scale = s
    end
    recalcScale()
    task.spawn(function()
        while screenGui.Parent do
            local cam = Workspace.CurrentCamera
            if cam then
                cam:GetPropertyChangedSignal("ViewportSize"):Wait()
                recalcScale()
            else
                task.wait(0.5)
            end
        end
    end)

    -- Top bar (timer + state + role badge)
    -- y offset 52 = Roblox topbar (~36) + 16 padding so it doesn't collide.
    local topBar = makeFrame(screenGui, {
        Name = "TopBar",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 52),
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

    -- Action buttons — vertical stack on RIGHT side, mid-vertical, sized to NOT
    -- overlap Roblox's mobile jump button (bottom-right) or movement thumbstick.
    -- Each button is 70x70 with 8px padding; container is anchored at right-middle.
    mobileButtons = makeFrame(screenGui, {
        Name = "Actions",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(0, 76, 0, 5 * 70 + 4 * 8),  -- up to 5 buttons stacked
        BackgroundTransparency = 1,
    })
    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Vertical
    list.HorizontalAlignment = Enum.HorizontalAlignment.Right
    list.VerticalAlignment = Enum.VerticalAlignment.Center
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 8)
    list.Parent = mobileButtons

    local function makeActionBtn(name, color, text, textColor, layoutOrder)
        local b = makeButton(mobileButtons, {
            Name = name,
            Size = UDim2.new(0, 70, 0, 70),
            BackgroundColor3 = color,
            Text = text,
            TextColor3 = textColor or THEME.TEXT,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            AutoButtonColor = true,
            Visible = false,
            LayoutOrder = layoutOrder,
        })
        corner(b, 14)
        stroke(b, THEME.BORDER, 1, 0.4)
        return b
    end

    captureBtn  = makeActionBtn("CaptureBtn",  THEME.DANGER,   "TANGKAP\n[E]",   THEME.TEXT, 1)
    disguiseBtn = makeActionBtn("DisguiseBtn", THEME.ACCENT,   "SAMAR\n[Q]",     THEME.TEXT, 2)
    flashBtn    = makeActionBtn("FlashBtn",    THEME.WARN,     "FLASH\n[F]",     Color3.fromRGB(20, 22, 28), 3)
    hackerBtn   = makeActionBtn("HackerBtn",   THEME.ACCENT_2, "HACKER\n[H]",    Color3.fromRGB(20, 22, 28), 4)
    voteBtn     = makeActionBtn("VoteBtn",     THEME.ACCENT_2, "VOTE\n[V]",      Color3.fromRGB(20, 22, 28), 5)

    -- Notification stack (top-center, below top bar; topbar y=52 + height 56 + gap 12)
    notifyStack = makeFrame(screenGui, {
        Name = "Notifications",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 120),
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
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 24, 0.5, 20),
        Size = UDim2.new(1, -360, 0, 360),
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

    -- Vote chat panel (right side, Among-Us style)
    voteChatPanel = makeFrame(voteOverlay, {
        Name = "VoteChat",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.new(0, 320, 0, 460),
        BackgroundColor3 = Color3.fromRGB(15, 18, 24),
        BackgroundTransparency = 0.1,
        ZIndex = 52,
    })
    corner(voteChatPanel, 12)
    stroke(voteChatPanel, THEME.ACCENT, 1.5, 0.3)
    pad(voteChatPanel, 10)

    makeText(voteChatPanel, {
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 24),
        Text = "💬 Chat Voting",
        Font = Enum.Font.GothamBold,
        TextColor3 = THEME.ACCENT,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 53,
    })

    voteChatLines = Instance.new("ScrollingFrame")
    voteChatLines.Name = "Lines"
    voteChatLines.Position = UDim2.new(0, 0, 0, 30)
    voteChatLines.Size = UDim2.new(1, 0, 1, -76)
    voteChatLines.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
    voteChatLines.BackgroundTransparency = 0.3
    voteChatLines.BorderSizePixel = 0
    voteChatLines.ScrollBarThickness = 4
    voteChatLines.CanvasSize = UDim2.new(0, 0, 0, 0)
    voteChatLines.AutomaticCanvasSize = Enum.AutomaticSize.Y
    voteChatLines.ZIndex = 53
    voteChatLines.Parent = voteChatPanel
    corner(voteChatLines, 8)
    pad(voteChatLines, 6)

    local linesLayout = Instance.new("UIListLayout")
    linesLayout.SortOrder = Enum.SortOrder.LayoutOrder
    linesLayout.Padding = UDim.new(0, 4)
    linesLayout.Parent = voteChatLines

    voteChatInput = Instance.new("TextBox")
    voteChatInput.Name = "Input"
    voteChatInput.AnchorPoint = Vector2.new(0, 1)
    voteChatInput.Position = UDim2.new(0, 0, 1, 0)
    voteChatInput.Size = UDim2.new(1, 0, 0, 36)
    voteChatInput.BackgroundColor3 = Color3.fromRGB(28, 31, 41)
    voteChatInput.BorderSizePixel = 0
    voteChatInput.PlaceholderText = "Ketik pesan… (Enter untuk kirim)"
    voteChatInput.PlaceholderColor3 = THEME.TEXT_DIM
    voteChatInput.Text = ""
    voteChatInput.TextColor3 = THEME.TEXT
    voteChatInput.Font = Enum.Font.Gotham
    voteChatInput.TextSize = 14
    voteChatInput.TextXAlignment = Enum.TextXAlignment.Left
    voteChatInput.ClearTextOnFocus = false
    voteChatInput.ZIndex = 53
    voteChatInput.Parent = voteChatPanel
    corner(voteChatInput, 8)
    local inputPad = Instance.new("UIPadding")
    inputPad.PaddingLeft = UDim.new(0, 10)
    inputPad.PaddingRight = UDim.new(0, 10)
    inputPad.Parent = voteChatInput

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

    -- Top-left utility buttons (Leaderboard, Shop, Rules)
    -- y offset 52 = Roblox topbar (~36) + 16 padding.
    local leftCol = makeFrame(screenGui, {
        Name = "LeftCol",
        Position = UDim2.new(0, 16, 0, 52),
        Size = UDim2.new(0, 56, 0, 56 * 3 + 16),
        BackgroundTransparency = 1,
    })
    local leftLayout = Instance.new("UIListLayout")
    leftLayout.FillDirection = Enum.FillDirection.Vertical
    leftLayout.Padding = UDim.new(0, 8)
    leftLayout.Parent = leftCol

    leaderboardBtn = makeButton(leftCol, {
        Name = "LBBtn",
        Size = UDim2.new(0, 56, 0, 56),
        BackgroundColor3 = THEME.SURFACE,
        Text = "🏆",
        TextSize = 24,
        AutoButtonColor = true,
        LayoutOrder = 1,
    })
    corner(leaderboardBtn, 14)
    stroke(leaderboardBtn, THEME.BORDER, 1, 0.4)

    shopBtn = makeButton(leftCol, {
        Name = "ShopBtn",
        Size = UDim2.new(0, 56, 0, 56),
        BackgroundColor3 = THEME.SURFACE,
        Text = "🛍",
        TextSize = 24,
        AutoButtonColor = true,
        LayoutOrder = 2,
    })
    corner(shopBtn, 14)
    stroke(shopBtn, THEME.BORDER, 1, 0.4)

    rulesBtn = makeButton(leftCol, {
        Name = "RulesBtn",
        Size = UDim2.new(0, 56, 0, 56),
        BackgroundColor3 = THEME.SURFACE,
        Text = "📖",
        TextSize = 24,
        AutoButtonColor = true,
        LayoutOrder = 3,
    })
    corner(rulesBtn, 14)
    stroke(rulesBtn, THEME.BORDER, 1, 0.4)

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
        Text = "Lobby — game mulai otomatis saat ≥3 pemain.\n[E] Tangkap  [Q] Samar  [F] Flash  [H] Hacker  [V] Vote",
        Font = Enum.Font.Gotham,
        TextColor3 = THEME.TEXT_DIM,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextWrapped = true,
    })

    -- Shop modal (full-screen overlay)
    shopFrame = makeFrame(screenGui, {
        Name = "Shop",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(8, 9, 14),
        BackgroundTransparency = 0.2,
        Visible = false,
        ZIndex = 60,
    })
    do
        local card = makeFrame(shopFrame, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(0, 720, 0, 520),
            BackgroundColor3 = THEME.BG_ALT,
            ZIndex = 61,
        })
        corner(card, 18)
        stroke(card, THEME.BORDER, 1.5, 0.2)

        makeText(card, {
            Position = UDim2.new(0, 24, 0, 18),
            Size = UDim2.new(1, -160, 0, 32),
            Text = "🛍  SHOP SKILL",
            Font = Enum.Font.GothamBlack,
            TextColor3 = THEME.ACCENT,
            TextSize = 22,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 62,
        })

        local coinTag = makeText(card, {
            Name = "CoinTag",
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -64, 0, 22),
            Size = UDim2.new(0, 100, 0, 26),
            Text = "🟡 0",
            Font = Enum.Font.GothamBold,
            TextColor3 = THEME.GOLD,
            TextSize = 18,
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 62,
        })

        local closeBtn = makeButton(card, {
            Name = "CloseBtn",
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -16, 0, 16),
            Size = UDim2.new(0, 36, 0, 36),
            BackgroundColor3 = THEME.SURFACE,
            Text = "×",
            TextSize = 22,
            Font = Enum.Font.GothamBold,
            AutoButtonColor = true,
            ZIndex = 62,
        })
        corner(closeBtn, 12)
        closeBtn.MouseButton1Click:Connect(function()
            shopFrame.Visible = false
        end)

        local list = Instance.new("ScrollingFrame")
        list.Name = "List"
        list.Position = UDim2.new(0, 24, 0, 70)
        list.Size = UDim2.new(1, -48, 1, -94)
        list.BackgroundTransparency = 1
        list.BorderSizePixel = 0
        list.CanvasSize = UDim2.fromOffset(0, 0)
        list.AutomaticCanvasSize = Enum.AutomaticSize.Y
        list.ScrollBarThickness = 4
        list.ScrollBarImageColor3 = THEME.BORDER
        list.ZIndex = 62
        list.Parent = card

        local grid = Instance.new("UIGridLayout")
        grid.CellSize = UDim2.new(0, 200, 0, 200)
        grid.CellPadding = UDim2.fromOffset(12, 12)
        grid.SortOrder = Enum.SortOrder.LayoutOrder
        grid.Parent = list

        shopFrame:SetAttribute("ListPath", list:GetFullName())
        shopFrame:SetAttribute("CoinPath", coinTag:GetFullName())
    end

    -- Rules popup
    rulesFrame = makeFrame(screenGui, {
        Name = "Rules",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(8, 9, 14),
        BackgroundTransparency = 0.25,
        Visible = false,
        ZIndex = 70,
    })
    do
        local card = makeFrame(rulesFrame, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(0, 580, 0, 480),
            BackgroundColor3 = THEME.BG_ALT,
            ZIndex = 71,
        })
        corner(card, 18)
        stroke(card, THEME.ACCENT, 1.5, 0.2)

        makeText(card, {
            Position = UDim2.new(0, 24, 0, 20),
            Size = UDim2.new(1, -48, 0, 32),
            Text = "📖  CARA BERMAIN",
            Font = Enum.Font.GothamBlack,
            TextColor3 = THEME.ACCENT,
            TextSize = 22,
            ZIndex = 72,
        })

        makeText(card, {
            Position = UDim2.new(0, 24, 0, 64),
            Size = UDim2.new(1, -48, 1, -130),
            Text = table.concat({
                "1) Setiap ronde 1 PENIRU dipilih acak. Sisanya WARGA.",
                "2) Salah satu warga jadi ANGEL — punya 1 SHIELD untuk menahan capture.",
                "",
                "PENIRU bisa:",
                "  • [E] TANGKAP warga terdekat (cooldown ~10s).",
                "  • [Q] SAMAR jadi warga (15s, lalu balik ke wujud asli).",
                "  • [F] FLASH (kecepatan +90%, durasi 5s, cooldown 30s).",
                "  • [H] HACKER (lihat lokasi warga 4s, cooldown 35s).",
                "",
                "WARGA bisa:",
                "  • Bertahan, observasi, lalu [V] VOTE pas voting phase.",
                "  • ANGEL otomatis menahan 1 capture pertama.",
                "",
                "Win:",
                "  • PENIRU menang jika sisa 1 warga (sisanya tertangkap).",
                "  • WARGA menang jika berhasil vote PENIRU di akhir ronde.",
                "",
                "Hadiah: Coin (untuk shop 🛍) + XP (level naik tiap 100 XP).",
            }, "\n"),
            Font = Enum.Font.GothamSemibold,
            TextColor3 = THEME.TEXT,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            ZIndex = 72,
        })

        local okBtn = makeButton(card, {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, -20),
            Size = UDim2.new(0, 200, 0, 44),
            BackgroundColor3 = THEME.ACCENT,
            Text = "MENGERTI",
            TextColor3 = THEME.TEXT,
            Font = Enum.Font.GothamBold,
            TextSize = 16,
            AutoButtonColor = true,
            ZIndex = 72,
        })
        corner(okBtn, 12)
        okBtn.MouseButton1Click:Connect(function()
            rulesFrame.Visible = false
        end)
    end

    -- Loading screen (initial)
    loadingFrame = makeFrame(screenGui, {
        Name = "Loading",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = THEME.BG,
        BackgroundTransparency = 0,
        Visible = true,
        ZIndex = 200,
    })
    do
        makeText(loadingFrame, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.45, 0),
            Size = UDim2.new(0, 600, 0, 60),
            Text = "SIAPA SI PENIRU",
            Font = Enum.Font.GothamBlack,
            TextColor3 = THEME.ACCENT,
            TextSize = 42,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 201,
        })
        makeText(loadingFrame, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 16),
            Size = UDim2.new(0, 600, 0, 26),
            Text = "Social Deduction • Memuat dunia, suara, dan UI...",
            Font = Enum.Font.Gotham,
            TextColor3 = THEME.TEXT_DIM,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 201,
        })
        local barBg = makeFrame(loadingFrame, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.6, 0),
            Size = UDim2.new(0, 360, 0, 8),
            BackgroundColor3 = THEME.SURFACE,
            ZIndex = 201,
        })
        corner(barBg, 4)
        local fill = makeFrame(barBg, {
            Name = "Fill",
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = THEME.ACCENT,
            ZIndex = 202,
        })
        corner(fill, 4)
        loadingFrame:SetAttribute("FillPath", fill:GetFullName())
    end

    -- Disguise picker modal (Peniru clicks Q -> opens; pick a target by name)
    disguiseFrame = makeFrame(screenGui, {
        Name = "DisguisePicker",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 460, 0, 420),
        BackgroundColor3 = THEME.BG,
        BackgroundTransparency = 0.05,
        Visible = false,
        ZIndex = 150,
    })
    corner(disguiseFrame, 16)
    stroke(disguiseFrame, THEME.PENIRU, 2, 0.2)
    pad(disguiseFrame, 16)

    makeText(disguiseFrame, {
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 32),
        Text = "🎭 Pilih siapa yang akan kamu tiru",
        Font = Enum.Font.GothamBlack,
        TextColor3 = THEME.PENIRU,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 151,
    })
    makeText(disguiseFrame, {
        Position = UDim2.new(0, 0, 0, 36),
        Size = UDim2.new(1, 0, 0, 18),
        Text = "Klik pemain dari daftar di bawah. ESC untuk batal.",
        Font = Enum.Font.Gotham,
        TextColor3 = THEME.TEXT_DIM,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 151,
    })

    disguiseList = Instance.new("ScrollingFrame")
    disguiseList.Name = "List"
    disguiseList.Position = UDim2.new(0, 0, 0, 64)
    disguiseList.Size = UDim2.new(1, 0, 1, -110)
    disguiseList.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
    disguiseList.BackgroundTransparency = 0.3
    disguiseList.BorderSizePixel = 0
    disguiseList.ScrollBarThickness = 6
    disguiseList.CanvasSize = UDim2.new(0, 0, 0, 0)
    disguiseList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    disguiseList.ZIndex = 151
    disguiseList.Parent = disguiseFrame
    corner(disguiseList, 10)
    pad(disguiseList, 8)
    local dlist = Instance.new("UIListLayout")
    dlist.SortOrder = Enum.SortOrder.LayoutOrder
    dlist.Padding = UDim.new(0, 6)
    dlist.Parent = disguiseList

    local cancelBtn = makeButton(disguiseFrame, {
        Name = "Cancel",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = THEME.SURFACE_ALT,
        Text = "BATAL",
        Font = Enum.Font.GothamBold,
        TextColor3 = THEME.TEXT,
        TextSize = 14,
        AutoButtonColor = true,
        ZIndex = 151,
    })
    corner(cancelBtn, 10)
    cancelBtn.MouseButton1Click:Connect(function()
        disguiseFrame.Visible = false
    end)

    ----------------------------------------------------------------
    -- Mission UI: progress bar (top-center, below topbar) + mission list (right)
    ----------------------------------------------------------------
    missionBar = makeFrame(screenGui, {
        Name = "MissionBar",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 116),
        Size = UDim2.new(0, 480, 0, 22),
        BackgroundColor3 = Color3.fromRGB(20, 22, 30),
        BackgroundTransparency = 0.15,
        Visible = false,
    })
    corner(missionBar, 8)
    stroke(missionBar, THEME.ACCENT, 1, 0.4)

    missionBarFill = makeFrame(missionBar, {
        Name = "Fill",
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = THEME.SUCCESS,
    })
    corner(missionBarFill, 8)

    missionBarText = makeText(missionBar, {
        Name = "Text",
        Size = UDim2.fromScale(1, 1),
        Text = "MISI 0%",
        Font = Enum.Font.GothamBold,
        TextColor3 = THEME.TEXT,
        TextSize = 13,
        ZIndex = 5,
    })

    -- Mission list panel (left side, below LeftCol buttons)
    missionListPanel = makeFrame(screenGui, {
        Name = "MissionList",
        Position = UDim2.new(0, 16, 0, 52 + 56 * 3 + 16 + 8),
        Size = UDim2.new(0, 220, 0, 180),
        BackgroundColor3 = THEME.BG,
        BackgroundTransparency = 0.1,
        Visible = false,
    })
    corner(missionListPanel, 12)
    stroke(missionListPanel, THEME.BORDER, 1, 0.4)
    pad(missionListPanel, 10)

    makeText(missionListPanel, {
        Name = "Title",
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 18),
        Text = "🗒 MISI KAMU",
        Font = Enum.Font.GothamBold,
        TextColor3 = THEME.ACCENT,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    missionListItems = Instance.new("Frame")
    missionListItems.Name = "Items"
    missionListItems.Position = UDim2.new(0, 0, 0, 24)
    missionListItems.Size = UDim2.new(1, 0, 1, -24)
    missionListItems.BackgroundTransparency = 1
    missionListItems.Parent = missionListPanel
    local mlist = Instance.new("UIListLayout")
    mlist.SortOrder = Enum.SortOrder.LayoutOrder
    mlist.Padding = UDim.new(0, 4)
    mlist.Parent = missionListItems

    ----------------------------------------------------------------
    -- Skip vote button (in vote overlay, bottom-center)
    ----------------------------------------------------------------
    voteSkipBtn = makeButton(voteOverlay, {
        Name = "SkipVote",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -32),
        Size = UDim2.new(0, 240, 0, 44),
        BackgroundColor3 = THEME.SURFACE,
        Text = "SKIP VOTE",
        Font = Enum.Font.GothamBold,
        TextColor3 = THEME.TEXT,
        TextSize = 16,
        AutoButtonColor = true,
        ZIndex = 53,
    })
    corner(voteSkipBtn, 10)
    stroke(voteSkipBtn, THEME.BORDER, 1.5, 0.3)

    ----------------------------------------------------------------
    -- Detektif kill button + panel
    ----------------------------------------------------------------
    detektifBtn = makeButton(mobileButtons, {
        Name = "DetektifBtn",
        Size = UDim2.new(0, 70, 0, 70),
        BackgroundColor3 = Color3.fromRGB(255, 230, 130),
        Text = "DETEKTIF\n[G]",
        TextColor3 = Color3.fromRGB(20, 22, 28),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        AutoButtonColor = true,
        Visible = false,
        LayoutOrder = 6,
    })
    corner(detektifBtn, 14)
    stroke(detektifBtn, THEME.BORDER, 1, 0.4)

    detektifPanel = makeFrame(screenGui, {
        Name = "DetektifPanel",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 460, 0, 480),
        BackgroundColor3 = THEME.BG,
        BackgroundTransparency = 0.05,
        Visible = false,
        ZIndex = 200,
    })
    corner(detektifPanel, 14)
    stroke(detektifPanel, Color3.fromRGB(255, 230, 130), 2, 0.2)
    pad(detektifPanel, 14)

    makeText(detektifPanel, {
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 28),
        Text = "🔍 DETEKTIF — TEMBAK PENIRU",
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(255, 230, 130),
        TextSize = 18,
        ZIndex = 201,
    })
    makeText(detektifPanel, {
        Position = UDim2.new(0, 0, 0, 30),
        Size = UDim2.new(1, 0, 0, 18),
        Text = "Salah orang = kamu masuk penjara. Sekali pakai per ronde.",
        Font = Enum.Font.Gotham,
        TextColor3 = THEME.TEXT_DIM,
        TextSize = 12,
        ZIndex = 201,
    })

    detektifList = Instance.new("ScrollingFrame")
    detektifList.Name = "List"
    detektifList.Position = UDim2.new(0, 0, 0, 56)
    detektifList.Size = UDim2.new(1, 0, 1, -110)
    detektifList.BackgroundColor3 = THEME.BG_ALT
    detektifList.BorderSizePixel = 0
    detektifList.ScrollBarThickness = 4
    detektifList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    detektifList.CanvasSize = UDim2.new(0, 0, 0, 0)
    detektifList.ZIndex = 201
    detektifList.Parent = detektifPanel
    corner(detektifList, 10)
    pad(detektifList, 8)
    local dkLayout = Instance.new("UIListLayout")
    dkLayout.SortOrder = Enum.SortOrder.LayoutOrder
    dkLayout.Padding = UDim.new(0, 6)
    dkLayout.Parent = detektifList

    detektifConfirmBtn = makeButton(detektifPanel, {
        Name = "Confirm",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(0.6, -4, 0, 44),
        BackgroundColor3 = THEME.DANGER,
        Text = "CONFIRM KILL",
        Font = Enum.Font.GothamBold,
        TextColor3 = THEME.TEXT,
        TextSize = 16,
        AutoButtonColor = true,
        ZIndex = 201,
    })
    corner(detektifConfirmBtn, 10)
    local detektifCancel = makeButton(detektifPanel, {
        Name = "Cancel",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, 0, 1, 0),
        Size = UDim2.new(0.4, -4, 0, 44),
        BackgroundColor3 = THEME.SURFACE_ALT,
        Text = "BATAL",
        Font = Enum.Font.GothamBold,
        TextColor3 = THEME.TEXT,
        TextSize = 14,
        AutoButtonColor = true,
        ZIndex = 201,
    })
    corner(detektifCancel, 10)
    detektifCancel.MouseButton1Click:Connect(function()
        detektifPanel.Visible = false
        detektifSelected = nil
    end)

    ----------------------------------------------------------------
    -- Daily login modal
    ----------------------------------------------------------------
    dailyFrame = makeFrame(screenGui, {
        Name = "DailyLogin",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 360, 0, 220),
        BackgroundColor3 = THEME.BG,
        BackgroundTransparency = 0.05,
        Visible = false,
        ZIndex = 220,
    })
    corner(dailyFrame, 14)
    stroke(dailyFrame, THEME.WARN, 2, 0.2)
    pad(dailyFrame, 16)

    return {
        screenGui = screenGui,
        captureBtn = captureBtn,
        disguiseBtn = disguiseBtn,
        flashBtn = flashBtn,
        hackerBtn = hackerBtn,
        voteBtn = voteBtn,
        detektifBtn = detektifBtn,
        leaderboardBtn = leaderboardBtn,
        leaderboardPanel = leaderboardPanel,
        leaderboardList = lbList,
        shopBtn = shopBtn,
        rulesBtn = rulesBtn,
        voteChatInput = voteChatInput,
        voteSkipBtn = voteSkipBtn,
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
    elseif role == Config.ROLE_JOKER then
        roleBadgeText.TextColor3 = THEME.JOKER
    elseif role == Config.ROLE_DETEKTIF then
        roleBadgeText.TextColor3 = THEME.DETEKTIF or Color3.fromRGB(255, 230, 130)
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
    local penIngame = role == Config.ROLE_PENIRU and not isVoting
    local detIngame = role == Config.ROLE_DETEKTIF and not isVoting
    captureBtn.Visible  = penIngame
    disguiseBtn.Visible = penIngame
    flashBtn.Visible    = penIngame
    hackerBtn.Visible   = penIngame
    voteBtn.Visible     = isVoting and role ~= nil
    if detektifBtn then detektifBtn.Visible = detIngame end
    -- Mission UI is for Warga + Detektif during round
    local missionEligible = (role == Config.ROLE_WARGA or role == Config.ROLE_DETEKTIF) and not isVoting
    if missionBar then missionBar.Visible = missionEligible end
    if missionListPanel then missionListPanel.Visible = missionEligible end
end

function UIBuilder.setAbilityCooldowns(data)
    if type(data) ~= "table" then return end
    captureCooldownEnd  = data.captureCooldownEnd or 0
    disguiseCooldownEnd = data.disguiseCooldownEnd or 0
    flashCooldownEnd    = data.flashCooldownEnd or 0
    hackerCooldownEnd   = data.hackerCooldownEnd or 0
    flashActiveUntil    = data.flashActiveUntil or 0
    hackerActiveUntil   = data.hackerActiveUntil or 0
    shieldCharges       = data.shieldCharges or 0
end

local function setBtnText(btn, label, key, cdLeft, activeLeft)
    if not btn then return end
    if activeLeft and activeLeft > 0 then
        btn.Text = string.format("%s\nAKTIF %.1fs", label, activeLeft)
        btn.BackgroundTransparency = 0
    elseif cdLeft and cdLeft > 0 then
        btn.Text = string.format("%s\n%.1fs", label, cdLeft)
        btn.BackgroundTransparency = 0.45
    else
        btn.Text = string.format("%s\n[%s]", label, key)
        btn.BackgroundTransparency = 0
    end
end

function UIBuilder.tickCooldowns()
    if not captureBtn then return end
    local now = os.clock()
    setBtnText(captureBtn,  "TANGKAP", "E", captureCooldownEnd - now,  nil)
    setBtnText(disguiseBtn, "SAMAR",   "Q", disguiseCooldownEnd - now, nil)
    setBtnText(flashBtn,    "FLASH",   "F", flashCooldownEnd - now,    flashActiveUntil - now)
    setBtnText(hackerBtn,   "HACKER",  "H", hackerCooldownEnd - now,   hackerActiveUntil - now)

    -- Update Angel shield indicator on roleBadge if applicable
    if roleBadge and roleBadge.Visible and shieldCharges > 0 then
        local shieldDot = roleBadge:FindFirstChild("ShieldDot")
        if not shieldDot then
            shieldDot = Instance.new("TextLabel")
            shieldDot.Name = "ShieldDot"
            shieldDot.BackgroundTransparency = 1
            shieldDot.Text = "🛡️"
            shieldDot.Font = Enum.Font.GothamBold
            shieldDot.TextSize = 18
            shieldDot.AnchorPoint = Vector2.new(1, 0.5)
            shieldDot.Position = UDim2.new(1, -8, 0.5, 0)
            shieldDot.Size = UDim2.new(0, 24, 0, 24)
            shieldDot.Parent = roleBadge
        end
        shieldDot.Visible = true
    elseif roleBadge then
        local shieldDot = roleBadge:FindFirstChild("ShieldDot")
        if shieldDot then shieldDot.Visible = false end
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

    voteCandidatesOrdered = {}
    for i, p in ipairs(candidates) do voteCandidatesOrdered[i] = p end
    UIBuilder.clearVoteChat()

    voteList:ClearAllChildren()
    local vgrid = Instance.new("UIGridLayout")
    vgrid.CellSize = UDim2.new(0, 240, 0, 96)
    vgrid.CellPadding = UDim2.new(0, 12, 0, 12)
    vgrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
    vgrid.VerticalAlignment = Enum.VerticalAlignment.Center
    vgrid.SortOrder = Enum.SortOrder.LayoutOrder
    vgrid.Parent = voteList

    for i, p in ipairs(candidates) do
        local tile = makeFrame(voteList, {
            BackgroundColor3 = THEME.SURFACE,
            ZIndex = 52,
            LayoutOrder = i,
        })
        corner(tile, 14)
        stroke(tile, THEME.BORDER, 1.5, 0.3)

        local btn = makeButton(tile, {
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 1, -28),
            BackgroundTransparency = 1,
            Text = ("[%d]   %s\n@%s"):format(i, p.DisplayName, p.Name),
            Font = Enum.Font.GothamSemibold,
            TextSize = 15,
            TextColor3 = THEME.TEXT,
            ZIndex = 53,
            AutoButtonColor = true,
        })
        local chatHint = makeButton(tile, {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 8, 1, -4),
            Size = UDim2.new(1, -16, 0, 22),
            BackgroundColor3 = THEME.BG_ALT,
            Text = ("💬  (vote %s)"):format(p.Name),
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextColor3 = THEME.TEXT_DIM,
            ZIndex = 53,
            AutoButtonColor = true,
        })
        corner(chatHint, 6)

        local function castVoteHere()
            if voteCast then return end
            voteCast = true
            for _, child in ipairs(voteList:GetChildren()) do
                if child:IsA("Frame") and child ~= tile then
                    child.BackgroundTransparency = 0.5
                    for _, sub in ipairs(child:GetDescendants()) do
                        if sub:IsA("TextButton") then
                            sub.AutoButtonColor = false
                        end
                        if sub:IsA("TextLabel") or sub:IsA("TextButton") then
                            sub.TextTransparency = 0.5
                        end
                    end
                end
            end
            tile.BackgroundColor3 = THEME.SUCCESS
            btn.TextColor3 = Color3.fromRGB(20, 22, 28)
            pulse(tile, 1.06)
            if voteCallback then voteCallback(p) end
        end
        btn.MouseButton1Click:Connect(castVoteHere)

        chatHint.MouseButton1Click:Connect(function()
            if voteChatInput then
                voteChatInput.Text = ("(vote %s)"):format(p.Name)
                voteChatInput:CaptureFocus()
            end
        end)
    end
end

-- Vote by ordered index (used by 1-9 keyboard shortcut). Returns true on success.
function UIBuilder.voteByIndex(idx: number): boolean
    if voteCast then return false end
    local p = voteCandidatesOrdered[idx]
    if not p then return false end
    if voteCallback then
        voteCast = true
        voteCallback(p)
        return true
    end
    return false
end

function UIBuilder.isVoteOpen(): boolean
    return voteOverlay and voteOverlay.Visible == true
end

function UIBuilder.getVoteCandidates(): { Player }
    local out = {}
    for i, p in ipairs(voteCandidatesOrdered) do out[i] = p end
    return out
end

function UIBuilder.closeVote()
    if voteOverlay then
        TweenService:Create(voteOverlay, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
        task.delay(0.3, function() voteOverlay.Visible = false end)
    end
end

function UIBuilder.showVoteResult(tallyOut: { { name: string, count: number, userId: number } }, accusedName: string?, isPeniru: boolean, outcome: string?)
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

    local subColor, subText
    if outcome == "joker" then
        subColor = THEME.JOKER
        subText = accusedName and (accusedName .. " adalah JOKER!") or "Joker terpilih!"
    elseif outcome == "peniru" or isPeniru then
        subColor = THEME.SUCCESS
        subText = accusedName and ("Tertuduh: " .. accusedName .. " (Peniru!)") or "Peniru ditemukan"
    elseif outcome == "wrong" then
        subColor = THEME.DANGER
        subText = accusedName and ("Salah! " .. accusedName .. " adalah Warga.") or "Salah tebak."
    else
        subColor = THEME.WARN
        subText = "Vote tidak konklusif — ronde lanjut"
    end
    local sub = makeText(voteResultPanel, {
        Position = UDim2.new(0, 0, 0, 36),
        Size = UDim2.new(1, 0, 0, 22),
        Text = subText,
        Font = Enum.Font.GothamSemibold,
        TextColor3 = subColor,
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
    local color
    if role == Config.ROLE_PENIRU then color = THEME.PENIRU
    elseif role == Config.ROLE_JOKER then color = THEME.JOKER
    else color = THEME.WARGA end
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
    local descText
    if role == Config.ROLE_PENIRU then
        descText = "Tangkap dgn [E]. Menyamar dgn [Q]. Tangkap semua warga untuk menang."
    elseif role == Config.ROLE_JOKER then
        descText = "Kamu Joker. Berbaur dgn warga. Kalau berhasil di-vote, kamu menang!"
    else
        descText = "Cari Si Peniru. Vote dia di akhir ronde untuk menang."
    end
    local desc = makeText(card, {
        Position = UDim2.new(0, 16, 0, 150),
        Size = UDim2.new(1, -32, 0, 70),
        Text = descText,
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

    local color
    if winningTeam == Config.ROLE_WARGA then color = THEME.WARGA
    elseif winningTeam == Config.ROLE_JOKER then color = THEME.JOKER
    else color = THEME.PENIRU end

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
    local subText
    if winningTeam == Config.ROLE_JOKER then
        subText = "Si Joker berhasil di-vote — chaos menang!"
    elseif winningTeam == Config.ROLE_WARGA then
        subText = peniruName and ("Si Peniru: " .. peniruName) or "Si Peniru terungkap."
    else
        subText = peniruName and ("Si Peniru: " .. peniruName) or "Peniru berhasil bersembunyi."
    end
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

----------------------------------------------------------------
-- Loading screen
----------------------------------------------------------------

function UIBuilder.setLoadingProgress(pct: number)
    if not loadingFrame then return end
    local fill = loadingFrame:FindFirstChild("Fill", true)
    if fill and fill:IsA("Frame") then
        TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {
            Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0),
        }):Play()
    end
end

function UIBuilder.dismissLoading()
    if not loadingFrame then return end
    UIBuilder.setLoadingProgress(1)
    task.delay(0.25, function()
        local tw = TweenService:Create(loadingFrame, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
            BackgroundTransparency = 1,
        })
        tw:Play()
        for _, child in ipairs(loadingFrame:GetDescendants()) do
            if child:IsA("TextLabel") then
                TweenService:Create(child, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
            elseif child:IsA("Frame") then
                TweenService:Create(child, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
            end
        end
        tw.Completed:Connect(function()
            loadingFrame.Visible = false
        end)
    end)
end

----------------------------------------------------------------
-- Rules popup
----------------------------------------------------------------

function UIBuilder.showRules()
    if rulesFrame then rulesFrame.Visible = true end
end

function UIBuilder.hideRules()
    if rulesFrame then rulesFrame.Visible = false end
end

----------------------------------------------------------------
-- Shop
----------------------------------------------------------------

----------------------------------------------------------------
-- Hacker waypoints
----------------------------------------------------------------

local hackerPanel: Frame? = nil

function UIBuilder.showHackerVision(playerList, duration)
    -- playerList: { Player } — apply Highlight ESP on each character
    if hackerPanel then hackerPanel:Destroy() end
    if not screenGui then return end

    -- Title banner
    hackerPanel = makeFrame(screenGui, {
        Name = "HackerVision",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 130),
        Size = UDim2.new(0, 360, 0, 36),
        BackgroundColor3 = Color3.fromRGB(15, 18, 24),
        BackgroundTransparency = 0.15,
        ZIndex = 40,
    })
    corner(hackerPanel, 10)
    stroke(hackerPanel, THEME.ACCENT_2, 1.5, 0.2)

    local title = makeText(hackerPanel, {
        Size = UDim2.fromScale(1, 1),
        Text = ("💻 HACKER VISION • %.1fs"):format(duration or 0),
        Font = Enum.Font.GothamBold,
        TextColor3 = THEME.ACCENT_2,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 41,
    })

    -- Apply Highlight ESP on each warga
    local highlights: { Highlight } = {}
    for _, p in ipairs(playerList or {}) do
        if typeof(p) == "Instance" and p:IsA("Player") then
            local char = p.Character
            if char then
                local hl = Instance.new("Highlight")
                hl.Name = "HackerESP"
                hl.FillColor = Color3.fromRGB(255, 60, 80)
                hl.OutlineColor = Color3.fromRGB(255, 200, 200)
                hl.FillTransparency = 0.55
                hl.OutlineTransparency = 0
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Adornee = char
                hl.Parent = char
                table.insert(highlights, hl)
            end
        end
    end

    -- Auto-update countdown + cleanup
    local startTime = os.clock()
    task.spawn(function()
        while hackerPanel and hackerPanel.Parent do
            local left = (duration or 0) - (os.clock() - startTime)
            if left <= 0 then
                if hackerPanel then hackerPanel:Destroy() end
                hackerPanel = nil
                for _, hl in ipairs(highlights) do
                    if hl and hl.Parent then hl:Destroy() end
                end
                break
            end
            if title and title.Parent then
                title.Text = ("💻 HACKER VISION • %.1fs"):format(left)
            end
            task.wait(0.1)
        end
        -- Final cleanup if loop exited unexpectedly
        for _, hl in ipairs(highlights) do
            if hl and hl.Parent then hl:Destroy() end
        end
    end)
end

----------------------------------------------------------------
-- Shop
----------------------------------------------------------------

function UIBuilder.openShop()
    if shopFrame then shopFrame.Visible = true end
end

function UIBuilder.closeShop()
    if shopFrame then shopFrame.Visible = false end
end

----------------------------------------------------------------
-- disguise picker
----------------------------------------------------------------

function UIBuilder.openDisguisePicker(candidates: { Player }, onPick: (Player) -> ())
    if not disguiseFrame or not disguiseList then return end
    -- Clear old buttons
    for _, c in ipairs(disguiseList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for i, p in ipairs(candidates) do
        local row = makeButton(disguiseList, {
            Name = "Pick_" .. tostring(p.UserId),
            Size = UDim2.new(1, -8, 0, 44),
            BackgroundColor3 = THEME.SURFACE_ALT,
            Text = ("  👤  %s   (@%s)"):format(p.DisplayName, p.Name),
            Font = Enum.Font.GothamSemibold,
            TextColor3 = THEME.TEXT,
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = true,
            LayoutOrder = i,
            ZIndex = 152,
        })
        corner(row, 8)
        stroke(row, THEME.BORDER, 1, 0.4)
        row.MouseButton1Click:Connect(function()
            disguiseFrame.Visible = false
            if onPick then onPick(p) end
        end)
    end
    disguiseFrame.Visible = true
end

function UIBuilder.closeDisguisePicker()
    if disguiseFrame then disguiseFrame.Visible = false end
end

----------------------------------------------------------------
-- vote chat (custom Among-Us style)
----------------------------------------------------------------

-- Vote chat name color: ALWAYS neutral. We deliberately do NOT vary by role
-- because that would leak who the Peniru / Joker is during voting.
local VOTE_CHAT_NAME_COLOR = THEME.ACCENT

function UIBuilder.appendVoteChat(senderName: string, text: string, role: string?)
    if not voteChatLines then return end
    local row = makeFrame(voteChatLines, {
        Name = "Msg",
        Size = UDim2.new(1, -8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = 54,
    })
    local nameLbl = makeText(row, {
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 16),
        Text = senderName,
        Font = Enum.Font.GothamBold,
        TextColor3 = VOTE_CHAT_NAME_COLOR,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 55,
    })
    nameLbl.Name = "Name"
    local body = makeText(row, {
        Position = UDim2.new(0, 0, 0, 16),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = text,
        Font = Enum.Font.Gotham,
        TextColor3 = THEME.TEXT,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        ZIndex = 55,
    })
    body.Name = "Body"
    -- ScrollingFrame auto-grows; nudge to bottom
    task.defer(function()
        if voteChatLines and voteChatLines.Parent then
            voteChatLines.CanvasPosition = Vector2.new(0, 999999)
        end
    end)
end

function UIBuilder.clearVoteChat()
    if not voteChatLines then return end
    for _, c in ipairs(voteChatLines:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
end

function UIBuilder.getVoteChatInput(): TextBox?
    return voteChatInput
end

function UIBuilder.setVoteChatText(s: string)
    if voteChatInput then voteChatInput.Text = s end
end

----------------------------------------------------------------
-- shop
----------------------------------------------------------------

function UIBuilder.populateShop(shopState, callbacks)
    if not shopFrame then return end
    shopState = shopState or { catalog = {}, owned = {}, equipped = {}, coins = 0 }
    callbacks = callbacks or {}

    local list = shopFrame:FindFirstChild("List", true)
    if not list then return end

    -- Clear old items
    for _, c in ipairs(list:GetChildren()) do
        if c:IsA("Frame") and c.Name:sub(1, 4) == "Item" then
            c:Destroy()
        end
    end

    -- Update coin tag
    local coinTag = shopFrame:FindFirstChild("CoinTag", true)
    if coinTag and coinTag:IsA("TextLabel") then
        coinTag.Text = "🟡 " .. tostring(shopState.coins or 0)
    end

    -- Sort catalog by role then price
    local catalog = {}
    for _, item in ipairs(shopState.catalog or {}) do
        table.insert(catalog, item)
    end
    table.sort(catalog, function(a, b)
        if a.role == b.role then return (a.price or 0) < (b.price or 0) end
        return tostring(a.role) < tostring(b.role)
    end)

    for i, item in ipairs(catalog) do
        local frame = makeFrame(list, {
            Name = "Item_" .. item.id,
            Size = UDim2.new(0, 200, 0, 200),
            BackgroundColor3 = THEME.SURFACE,
            LayoutOrder = i,
            ZIndex = 62,
        })
        corner(frame, 12)
        stroke(frame, THEME.BORDER, 1, 0.4)

        local swatch = makeFrame(frame, {
            Position = UDim2.new(0, 12, 0, 12),
            Size = UDim2.new(1, -24, 0, 80),
            BackgroundColor3 = item.color or Color3.fromRGB(180, 180, 180),
            ZIndex = 63,
        })
        corner(swatch, 10)

        makeText(frame, {
            Position = UDim2.new(0, 12, 0, 100),
            Size = UDim2.new(1, -24, 0, 20),
            Text = item.name or item.id,
            Font = Enum.Font.GothamBold,
            TextColor3 = THEME.TEXT,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 63,
        })

        local roleLabel = (item.role == Config.ROLE_PENIRU) and "Peniru" or "Warga"
        local kindLabel = item.kind == "ability" and "SKILL" or "SKIN"
        makeText(frame, {
            Position = UDim2.new(0, 12, 0, 122),
            Size = UDim2.new(1, -24, 0, 16),
            Text = ("%s • Untuk %s • 🟡 %d"):format(kindLabel, roleLabel, item.price or 0),
            Font = Enum.Font.Gotham,
            TextColor3 = THEME.TEXT_DIM,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 63,
        })

        if item.desc then
            makeText(frame, {
                Position = UDim2.new(0, 12, 0, 138),
                Size = UDim2.new(1, -24, 0, 16),
                Text = item.desc,
                Font = Enum.Font.Gotham,
                TextColor3 = THEME.TEXT_DIM,
                TextSize = 11,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 63,
            })
        end

        local owned = (shopState.owned or {})[item.id] == true
        local isAbility = item.kind == "ability"
        local equipped = (not isAbility) and ((shopState.equipped or {})[item.role] == item.id)

        local btnLabel, btnColor
        if isAbility then
            if owned then
                btnLabel, btnColor = "TERSEDIA ✓", THEME.SUCCESS
            else
                btnLabel, btnColor = ("BELI 🟡" .. tostring(item.price or 0)), THEME.GOLD
            end
        else
            if equipped then
                btnLabel, btnColor = "TERPAKAI", THEME.SUCCESS
            elseif owned then
                btnLabel, btnColor = "PAKAI", THEME.ACCENT
            else
                btnLabel, btnColor = ("BELI 🟡" .. tostring(item.price or 0)), THEME.GOLD
            end
        end

        local btn = makeButton(frame, {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 12, 1, -12),
            Size = UDim2.new(1, -24, 0, 36),
            BackgroundColor3 = btnColor,
            Text = btnLabel,
            Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(20, 22, 28),
            TextSize = 14,
            AutoButtonColor = true,
            ZIndex = 63,
        })
        corner(btn, 10)

        btn.MouseButton1Click:Connect(function()
            if isAbility then
                if owned then return end
                if callbacks.onPurchase then callbacks.onPurchase(item.id) end
            else
                if equipped then return end
                if owned then
                    if callbacks.onEquip then callbacks.onEquip(item.id) end
                else
                    if callbacks.onPurchase then callbacks.onPurchase(item.id) end
                end
            end
        end)
    end
end

----------------------------------------------------------------
-- Mission UI helpers
----------------------------------------------------------------

function UIBuilder.setMissionList(missions: { { id: string, name: string, pos: Vector3 } })
    if not missionListItems then return end
    missionListItems:ClearAllChildren()
    local mlist = Instance.new("UIListLayout")
    mlist.SortOrder = Enum.SortOrder.LayoutOrder
    mlist.Padding = UDim.new(0, 4)
    mlist.Parent = missionListItems

    missionData = {}
    for i, m in ipairs(missions or {}) do
        table.insert(missionData, { id = m.id, name = m.name, done = false })
        local row = Instance.new("TextLabel")
        row.Name = m.id
        row.LayoutOrder = i
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, 0, 0, 18)
        row.Text = ("• %s"):format(m.name)
        row.Font = Enum.Font.Gotham
        row.TextSize = 12
        row.TextColor3 = THEME.TEXT
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.Parent = missionListItems
    end
end

function UIBuilder.markMissionDone(stationId: string)
    if not missionListItems or not missionData then return end
    for _, m in ipairs(missionData) do
        if m.id == stationId then m.done = true end
    end
    local row = missionListItems:FindFirstChild(stationId)
    if row and row:IsA("TextLabel") then
        row.Text = ("✓ %s"):format(row.Text:gsub("^[•✓]%s*", ""))
        row.TextColor3 = THEME.SUCCESS
    end
end

function UIBuilder.setMissionProgress(pct: number, done: number, total: number)
    if not missionBar then return end
    local p = math.clamp((pct or 0) / 100, 0, 1)
    TweenService:Create(missionBarFill, TweenInfo.new(0.3), {
        Size = UDim2.new(p, 0, 1, 0),
    }):Play()
    missionBarText.Text = string.format("MISI %d%%   (%d / %d)", math.floor(pct or 0), done or 0, total or 0)
end

function UIBuilder.clearMissions()
    if missionListItems then missionListItems:ClearAllChildren() end
    missionData = nil
    if missionBar then missionBar.Visible = false end
    if missionListPanel then missionListPanel.Visible = false end
    if missionBarFill then missionBarFill.Size = UDim2.new(0, 0, 1, 0) end
end

----------------------------------------------------------------
-- Skip vote
----------------------------------------------------------------

local _skipVoteConn: RBXScriptConnection? = nil
function UIBuilder.bindSkipVote(onSkip: () -> ())
    if not voteSkipBtn then return end
    if _skipVoteConn then _skipVoteConn:Disconnect() end
    _skipVoteConn = voteSkipBtn.MouseButton1Click:Connect(function()
        if onSkip then onSkip() end
    end)
end

----------------------------------------------------------------
-- Detektif kill panel
----------------------------------------------------------------

local _detektifConn: RBXScriptConnection? = nil

function UIBuilder.openDetektif(candidates: { Player }, onConfirm: (Player) -> ())
    if not detektifPanel then return end
    detektifSelected = nil
    detektifPanel.Visible = true
    detektifList:ClearAllChildren()
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.Parent = detektifList

    local rows: { TextButton } = {}
    for i, p in ipairs(candidates) do
        local row = makeButton(detektifList, {
            Name = "Cand_" .. tostring(p.UserId),
            LayoutOrder = i,
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundColor3 = THEME.SURFACE,
            Text = ("   %s   (@%s)"):format(p.DisplayName, p.Name),
            Font = Enum.Font.GothamSemibold,
            TextColor3 = THEME.TEXT,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 202,
        })
        corner(row, 8)
        stroke(row, THEME.BORDER, 1, 0.5)
        table.insert(rows, row)

        row.MouseButton1Click:Connect(function()
            detektifSelected = p
            for _, r in ipairs(rows) do
                r.BackgroundColor3 = THEME.SURFACE
            end
            row.BackgroundColor3 = THEME.DANGER
        end)
    end

    -- Rewire confirm with a tracked connection so we don't stack handlers.
    if _detektifConn then _detektifConn:Disconnect() end
    _detektifConn = detektifConfirmBtn.MouseButton1Click:Connect(function()
        if not detektifSelected then return end
        if onConfirm then onConfirm(detektifSelected) end
        detektifPanel.Visible = false
        detektifSelected = nil
        if _detektifConn then
            _detektifConn:Disconnect()
            _detektifConn = nil
        end
    end)
end

function UIBuilder.toggleDetektif(): boolean
    if not detektifPanel then return false end
    detektifPanel.Visible = not detektifPanel.Visible
    return detektifPanel.Visible
end

function UIBuilder.closeDetektif()
    if detektifPanel then detektifPanel.Visible = false end
    detektifSelected = nil
end

----------------------------------------------------------------
-- Daily login modal
----------------------------------------------------------------

local function fmtTime(secs: number): string
    secs = math.max(0, math.floor(secs or 0))
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = secs % 60
    if h > 0 then return string.format("%dj %dm", h, m) end
    if m > 0 then return string.format("%dm %ds", m, s) end
    return string.format("%ds", s)
end

function UIBuilder.showDailyLogin(status: { claimed: boolean, secondsLeft: number, reward: number, coins: number }, onClaim: () -> ())
    if not dailyFrame then return end
    -- Clear and rebuild content
    for _, c in ipairs(dailyFrame:GetChildren()) do
        if c:IsA("TextLabel") or c:IsA("TextButton") then c:Destroy() end
    end

    makeText(dailyFrame, {
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 28),
        Text = "🎁 DAILY LOGIN",
        Font = Enum.Font.GothamBlack,
        TextColor3 = THEME.WARN,
        TextSize = 22,
        ZIndex = 221,
    })

    local body
    if status.claimed then
        body = string.format("Sudah diklaim hari ini.\nKembali dalam %s untuk hadiah berikutnya.", fmtTime(status.secondsLeft))
    else
        body = string.format("Klaim %d 🟡 hari ini!", status.reward or 0)
    end
    makeText(dailyFrame, {
        Position = UDim2.new(0, 0, 0, 36),
        Size = UDim2.new(1, 0, 0, 60),
        Text = body,
        Font = Enum.Font.Gotham,
        TextColor3 = THEME.TEXT,
        TextSize = 14,
        TextWrapped = true,
        ZIndex = 221,
    })

    local btn = makeButton(dailyFrame, {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, 0),
        Size = UDim2.new(0.6, 0, 0, 44),
        BackgroundColor3 = status.claimed and THEME.SURFACE_ALT or THEME.SUCCESS,
        Text = status.claimed and "TUTUP" or ("KLAIM " .. tostring(status.reward or 0) .. " 🟡"),
        Font = Enum.Font.GothamBold,
        TextColor3 = status.claimed and THEME.TEXT or Color3.fromRGB(20, 22, 28),
        TextSize = 16,
        AutoButtonColor = true,
        ZIndex = 221,
    })
    corner(btn, 10)

    btn.MouseButton1Click:Connect(function()
        if status.claimed then
            dailyFrame.Visible = false
        else
            if onClaim then onClaim() end
            -- Close — main.client will call showDailyLogin again with updated status if needed
            dailyFrame.Visible = false
        end
    end)

    dailyFrame.Visible = true
end

function UIBuilder.hideDailyLogin()
    if dailyFrame then dailyFrame.Visible = false end
end

return UIBuilder
