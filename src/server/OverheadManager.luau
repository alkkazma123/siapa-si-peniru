--!nonstrict
-- Manages overhead BillboardGui (level tag + display name).
-- Built server-side so it replicates and can be cloned by the disguise system.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local DataManager -- set lazily via init

local OverheadManager = {}

local function buildOverhead(displayName: string, level: number, role: string?): BillboardGui
    local bg = Instance.new("BillboardGui")
    bg.Name = "OverheadGui"
    bg.Size = UDim2.fromOffset(220, 70)
    bg.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
    bg.AlwaysOnTop = true
    bg.MaxDistance = 200
    bg.LightInfluence = 0

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundTransparency = 1
    frame.Parent = bg

    -- Level chip
    local chip = Instance.new("Frame")
    chip.Name = "LevelChip"
    chip.Size = UDim2.new(0, 60, 0, 28)
    chip.Position = UDim2.new(0, 0, 0, 0)
    chip.AnchorPoint = Vector2.new(0, 0)
    chip.BackgroundColor3 = Config.THEME.ACCENT
    chip.BorderSizePixel = 0
    chip.Parent = frame

    local chipCorner = Instance.new("UICorner")
    chipCorner.CornerRadius = UDim.new(0, 8)
    chipCorner.Parent = chip

    local chipLbl = Instance.new("TextLabel")
    chipLbl.Name = "Lvl"
    chipLbl.Size = UDim2.fromScale(1, 1)
    chipLbl.BackgroundTransparency = 1
    chipLbl.Text = "LV " .. tostring(level)
    chipLbl.Font = Enum.Font.GothamBold
    chipLbl.TextColor3 = Color3.fromRGB(15, 16, 22)
    chipLbl.TextScaled = true
    chipLbl.Parent = chip

    local chipPad = Instance.new("UIPadding")
    chipPad.PaddingLeft = UDim.new(0, 6)
    chipPad.PaddingRight = UDim.new(0, 6)
    chipPad.Parent = chip

    -- Name label
    local nameBg = Instance.new("Frame")
    nameBg.Name = "NameBg"
    nameBg.Size = UDim2.new(1, -68, 0, 28)
    nameBg.Position = UDim2.new(0, 68, 0, 0)
    nameBg.BackgroundColor3 = Config.THEME.SURFACE
    nameBg.BackgroundTransparency = 0.15
    nameBg.BorderSizePixel = 0
    nameBg.Parent = frame
    local nbCorner = Instance.new("UICorner")
    nbCorner.CornerRadius = UDim.new(0, 8)
    nbCorner.Parent = nameBg

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "DisplayName"
    nameLbl.Size = UDim2.fromScale(1, 1)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = displayName
    nameLbl.Font = Enum.Font.GothamSemibold
    nameLbl.TextColor3 = Config.THEME.TEXT
    nameLbl.TextScaled = true
    nameLbl.Parent = nameBg

    local namePad = Instance.new("UIPadding")
    namePad.PaddingLeft = UDim.new(0, 8)
    namePad.PaddingRight = UDim.new(0, 8)
    namePad.Parent = nameBg

    -- Role badge (hidden by default; only shown to teammates if needed by server logic)
    local roleBg = Instance.new("Frame")
    roleBg.Name = "RoleBg"
    roleBg.Size = UDim2.new(1, 0, 0, 22)
    roleBg.Position = UDim2.new(0, 0, 0, 36)
    roleBg.BackgroundColor3 = Config.THEME.BG_ALT
    roleBg.BorderSizePixel = 0
    roleBg.Visible = role ~= nil and role ~= ""
    roleBg.Parent = frame
    local rbCorner = Instance.new("UICorner")
    rbCorner.CornerRadius = UDim.new(0, 8)
    rbCorner.Parent = roleBg

    local roleLbl = Instance.new("TextLabel")
    roleLbl.Name = "RoleText"
    roleLbl.Size = UDim2.fromScale(1, 1)
    roleLbl.BackgroundTransparency = 1
    roleLbl.Text = role or ""
    roleLbl.Font = Enum.Font.GothamMedium
    roleLbl.TextColor3 = Config.THEME.TEXT_DIM
    roleLbl.TextScaled = true
    roleLbl.Parent = roleBg

    return bg
end

local function attachOverhead(player: Player)
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    -- Remove old
    local prev = head:FindFirstChild("OverheadGui")
    if prev then prev:Destroy() end

    local profile = DataManager and DataManager.getProfile(player)
    local level = profile and profile.level or 1
    local bg = buildOverhead(player.DisplayName, level, nil)
    bg.Parent = head
end

function OverheadManager.refresh(player: Player)
    attachOverhead(player)
end

-- Replace overhead with arbitrary text/level (used by DisguiseSystem)
function OverheadManager.applyDisguise(player: Player, displayName: string, level: number)
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    local prev = head:FindFirstChild("OverheadGui")
    if prev then prev:Destroy() end
    local bg = buildOverhead(displayName, level, nil)
    bg.Parent = head
end

function OverheadManager.init(dataManagerModule)
    DataManager = dataManagerModule
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(char)
            char:WaitForChild("Head", 10)
            task.wait(0.2)
            attachOverhead(player)
        end)
        if player.Character then
            attachOverhead(player)
        end
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            attachOverhead(player)
        end
    end
end

return OverheadManager
