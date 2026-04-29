--!nonstrict
-- Procedurally builds the world: lobby plaza, simple city map, and prison area.
-- Uses only primitive Parts so it works without any imported assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MapBuilder = {}

local function makePart(props: { [string]: any }): BasePart
    local p = Instance.new("Part")
    p.Anchored = true
    p.Material = Enum.Material.SmoothPlastic
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.CastShadow = true
    for k, v in pairs(props) do
        (p :: any)[k] = v
    end
    return p
end

local function group(parent: Instance, name: string): Folder
    local f = Instance.new("Folder")
    f.Name = name
    f.Parent = parent
    return f
end

local function spawnLocation(name: string, cf: CFrame, parent: Instance, neutral: boolean): SpawnLocation
    local s = Instance.new("SpawnLocation")
    s.Name = name
    s.Size = Vector3.new(8, 1, 8)
    s.CFrame = cf
    s.Anchored = true
    s.Material = Enum.Material.Neon
    s.Color = Color3.fromRGB(80, 90, 120)
    s.Transparency = 0.4
    s.Neutral = neutral
    s.AllowTeamChangeOnTouch = false
    s.Duration = 0
    s.Parent = parent
    return s
end

local function buildLobby(workspace: Workspace)
    local f = group(workspace, "Lobby")

    -- Floor
    local floor = makePart({
        Name = "LobbyFloor",
        Size = Vector3.new(140, 2, 140),
        Position = Config.LOBBY_CENTER - Vector3.new(0, 4, 0),
        Color = Color3.fromRGB(34, 36, 46),
        Material = Enum.Material.Slate,
    })
    floor.Parent = f

    -- Decorative ring of pillars
    for i = 1, 16 do
        local angle = math.rad((i - 1) * (360 / 16))
        local r = 50
        local pos = Config.LOBBY_CENTER + Vector3.new(math.cos(angle) * r, 7, math.sin(angle) * r)
        local pillar = makePart({
            Name = "LobbyPillar",
            Size = Vector3.new(3, 18, 3),
            Position = pos,
            Color = Color3.fromRGB(60, 64, 80),
            Material = Enum.Material.Concrete,
        })
        pillar.Parent = f

        local glow = makePart({
            Name = "PillarGlow",
            Size = Vector3.new(3.2, 0.6, 3.2),
            Position = pos + Vector3.new(0, 9.2, 0),
            Color = Config.THEME.ACCENT,
            Material = Enum.Material.Neon,
            Transparency = 0.1,
        })
        glow.Parent = f
    end

    -- Center podium with sign
    local podium = makePart({
        Name = "Podium",
        Size = Vector3.new(20, 3, 20),
        Position = Config.LOBBY_CENTER - Vector3.new(0, 1.5, 0),
        Color = Color3.fromRGB(50, 54, 70),
        Material = Enum.Material.Metal,
    })
    podium.Parent = f

    -- Welcome sign (front)
    local signPart = makePart({
        Name = "WelcomeSign",
        Size = Vector3.new(22, 7, 0.5),
        CFrame = CFrame.new(Config.LOBBY_CENTER + Vector3.new(0, 7, 0)),
        Color = Color3.fromRGB(20, 22, 30),
        Material = Enum.Material.SmoothPlastic,
    })
    signPart.Parent = f

    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Front
    sg.AlwaysOnTop = false
    sg.CanvasSize = Vector2.new(1100, 350)
    sg.Parent = signPart

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.fromScale(1, 0.55)
    title.Position = UDim2.fromScale(0, 0.05)
    title.Text = "SIAPA SI PENIRU"
    title.Font = Enum.Font.GothamBlack
    title.TextColor3 = Config.THEME.ACCENT
    title.TextScaled = true
    title.Parent = sg

    local sub = Instance.new("TextLabel")
    sub.BackgroundTransparency = 1
    sub.Size = UDim2.fromScale(1, 0.35)
    sub.Position = UDim2.fromScale(0, 0.6)
    sub.Text = "Social Deduction • Min 3 Player • Buka Shop 🛍 & Rules 📖 di kanan-atas"
    sub.Font = Enum.Font.Gotham
    sub.TextColor3 = Config.THEME.TEXT_DIM
    sub.TextScaled = true
    sub.Parent = sg

    -- Rules board (back of welcome sign)
    local rulesPart = makePart({
        Name = "RulesBoard",
        Size = Vector3.new(22, 12, 0.5),
        CFrame = CFrame.new(Config.LOBBY_CENTER + Vector3.new(0, 9, 0)) * CFrame.Angles(0, math.pi, 0),
        Color = Color3.fromRGB(20, 22, 30),
        Material = Enum.Material.SmoothPlastic,
    })
    rulesPart.Parent = f

    local rg = Instance.new("SurfaceGui")
    rg.Face = Enum.NormalId.Back
    rg.AlwaysOnTop = false
    rg.CanvasSize = Vector2.new(1100, 600)
    rg.Parent = rulesPart

    local rTitle = Instance.new("TextLabel")
    rTitle.BackgroundTransparency = 1
    rTitle.Size = UDim2.new(1, 0, 0, 70)
    rTitle.Position = UDim2.fromOffset(0, 12)
    rTitle.Text = "📖  CARA BERMAIN"
    rTitle.Font = Enum.Font.GothamBlack
    rTitle.TextColor3 = Config.THEME.ACCENT
    rTitle.TextSize = 56
    rTitle.Parent = rg

    local rBody = Instance.new("TextLabel")
    rBody.BackgroundTransparency = 1
    rBody.Size = UDim2.new(1, -80, 1, -100)
    rBody.Position = UDim2.fromOffset(40, 90)
    rBody.Text = table.concat({
        "• 1 PENIRU + sisanya WARGA tiap ronde (30-60 detik).",
        "• PENIRU [E] menangkap warga, [Q] menyamar (15s), [F] flash, [H] hacker.",
        "• ANGEL (warga acak) punya 1 SHIELD untuk menahan capture sekali.",
        "• PENIRU menang jika sisa 1 warga; WARGA menang jika vote benar di akhir.",
        "• Coin & XP untuk shop dan level. Buka 🛍 di UI.",
    }, "\n")
    rBody.TextWrapped = true
    rBody.Font = Enum.Font.GothamSemibold
    rBody.TextColor3 = Config.THEME.TEXT
    rBody.TextSize = 32
    rBody.TextXAlignment = Enum.TextXAlignment.Left
    rBody.TextYAlignment = Enum.TextYAlignment.Top
    rBody.Parent = rg

    -- Decorative shop pillars next to podium
    for _, off in ipairs({ -16, 16 }) do
        local pad = makePart({
            Name = "DeskPad",
            Size = Vector3.new(8, 1, 8),
            Position = Config.LOBBY_CENTER + Vector3.new(off, -3, -16),
            Color = Color3.fromRGB(60, 64, 80),
            Material = Enum.Material.SmoothPlastic,
        })
        pad.Parent = f
        local glow = makePart({
            Name = "DeskGlow",
            Size = Vector3.new(8, 0.4, 8),
            Position = Config.LOBBY_CENTER + Vector3.new(off, -2.4, -16),
            Color = off < 0 and Config.THEME.GOLD or Config.THEME.ACCENT_2,
            Material = Enum.Material.Neon,
            Transparency = 0.2,
        })
        glow.Parent = f
    end

    -- Lobby spawn (neutral). Slight offset so player faces the welcome sign.
    spawnLocation("LobbySpawn",
        CFrame.new(Config.LOBBY_CENTER + Vector3.new(0, Config.SPAWN_HEIGHT, 24),
                   Config.LOBBY_CENTER + Vector3.new(0, Config.SPAWN_HEIGHT, 0)),
        f, true)

    return f
end

local function buildBuilding(parent: Instance, pos: Vector3, size: Vector3, color: Color3, name: string)
    local g = group(parent, name)

    local body = makePart({
        Name = "Body",
        Size = size,
        Position = pos + Vector3.new(0, size.Y / 2, 0),
        Color = color,
        Material = Enum.Material.Brick,
    })
    body.Parent = g

    -- Roof accent
    local roof = makePart({
        Name = "Roof",
        Size = Vector3.new(size.X + 2, 1, size.Z + 2),
        Position = pos + Vector3.new(0, size.Y + 0.5, 0),
        Color = Color3.fromRGB(30, 32, 42),
        Material = Enum.Material.Metal,
    })
    roof.Parent = g

    -- Door
    local door = makePart({
        Name = "Door",
        Size = Vector3.new(4, 6, 0.4),
        CFrame = CFrame.new(pos + Vector3.new(0, 3, size.Z / 2 + 0.1)),
        Color = Color3.fromRGB(70, 50, 40),
        Material = Enum.Material.Wood,
    })
    door.Parent = g

    -- Windows (random)
    local rows = math.floor(size.Y / 6)
    local cols = math.floor(size.X / 6)
    for r = 1, rows do
        for c = 1, cols do
            if math.random() < 0.55 then
                local w = makePart({
                    Name = "Window",
                    Size = Vector3.new(2.5, 2.5, 0.3),
                    CFrame = CFrame.new(
                        pos.X - size.X / 2 + 3 + (c - 1) * 6,
                        2 + (r - 0.5) * 6,
                        pos.Z + size.Z / 2 + 0.05
                    ),
                    Color = Color3.fromRGB(140, 200, 230),
                    Material = Enum.Material.Glass,
                    Transparency = 0.4,
                })
                w.Parent = g
            end
        end
    end
    return g
end

local function buildCity(workspace: Workspace, spawnsOut: { CFrame })
    local f = group(workspace, "City")

    -- Ground
    local ground = makePart({
        Name = "CityGround",
        Size = Vector3.new(Config.CITY_RADIUS * 2, 2, Config.CITY_RADIUS * 2),
        Position = Config.CITY_CENTER - Vector3.new(0, 4, 0),
        Color = Color3.fromRGB(50, 55, 65),
        Material = Enum.Material.Concrete,
    })
    ground.Parent = f

    -- Cross roads
    local roadColor = Color3.fromRGB(28, 30, 38)
    local roadH = makePart({
        Name = "RoadHorizontal",
        Size = Vector3.new(Config.CITY_RADIUS * 2, 0.2, 12),
        Position = Config.CITY_CENTER - Vector3.new(0, 2.9, 0),
        Color = roadColor,
        Material = Enum.Material.Asphalt,
    })
    roadH.Parent = f

    local roadV = makePart({
        Name = "RoadVertical",
        Size = Vector3.new(12, 0.2, Config.CITY_RADIUS * 2),
        Position = Config.CITY_CENTER - Vector3.new(0, 2.9, 0),
        Color = roadColor,
        Material = Enum.Material.Asphalt,
    })
    roadV.Parent = f

    -- Generate buildings in a 4x4 grid skipping the cross
    local palette = {
        Color3.fromRGB(120, 80, 70),
        Color3.fromRGB(90, 95, 110),
        Color3.fromRGB(160, 140, 110),
        Color3.fromRGB(80, 110, 100),
        Color3.fromRGB(110, 90, 130),
    }

    local cell = 80
    local startX = Config.CITY_CENTER.X - cell * 1.5
    local startZ = Config.CITY_CENTER.Z - cell * 1.5
    local i = 0
    for gx = 0, 3 do
        for gz = 0, 3 do
            local cx = startX + gx * cell
            local cz = startZ + gz * cell
            -- skip cells overlapping center cross (roads)
            local dx = math.abs(cx - Config.CITY_CENTER.X)
            local dz = math.abs(cz - Config.CITY_CENTER.Z)
            if dx < 20 or dz < 20 then
                continue
            end
            i += 1
            local sizeX = 30 + math.random(0, 8)
            local sizeZ = 30 + math.random(0, 8)
            local sizeY = 18 + math.random(0, 22)
            local color = palette[((i - 1) % #palette) + 1]
            buildBuilding(
                f,
                Vector3.new(cx, -3, cz),
                Vector3.new(sizeX, sizeY, sizeZ),
                color,
                string.format("Building_%d", i)
            )
        end
    end

    -- Streetlights
    for x = -Config.CITY_RADIUS + 30, Config.CITY_RADIUS - 30, 60 do
        for z = -Config.CITY_RADIUS + 30, Config.CITY_RADIUS - 30, 60 do
            if math.random() < 0.5 then
                continue
            end
            local pos = Config.CITY_CENTER + Vector3.new(x, 6, z)
            local pole = makePart({
                Name = "Lamp",
                Size = Vector3.new(0.6, 12, 0.6),
                Position = pos,
                Color = Color3.fromRGB(20, 22, 30),
                Material = Enum.Material.Metal,
            })
            pole.Parent = f
            local bulb = makePart({
                Name = "Bulb",
                Size = Vector3.new(1.6, 1.6, 1.6),
                Position = pos + Vector3.new(0, 6.5, 0),
                Color = Color3.fromRGB(255, 220, 160),
                Material = Enum.Material.Neon,
                Transparency = 0.05,
            })
            bulb.Parent = f
            local pl = Instance.new("PointLight")
            pl.Brightness = 1.4
            pl.Range = 18
            pl.Color = Color3.fromRGB(255, 220, 160)
            pl.Parent = bulb
        end
    end

    -- Spawn points along the cross-roads ONLY (guaranteed open ground, no buildings).
    -- 4 distances along each of 4 road arms = 16 spawns.
    local distances = { 25, 65, 105, 145 }
    local arms = {
        { dir = Vector3.new( 1, 0,  0), face = Vector3.new(-1, 0,  0) }, -- east arm, face center
        { dir = Vector3.new(-1, 0,  0), face = Vector3.new( 1, 0,  0) }, -- west arm
        { dir = Vector3.new( 0, 0,  1), face = Vector3.new( 0, 0, -1) }, -- north arm
        { dir = Vector3.new( 0, 0, -1), face = Vector3.new( 0, 0,  1) }, -- south arm
    }
    for _, arm in ipairs(arms) do
        for _, d in ipairs(distances) do
            local pos = Config.CITY_CENTER + arm.dir * d + Vector3.new(0, Config.SPAWN_HEIGHT, 0)
            -- Stagger slightly across the road width so players don't pile on one point
            local jitter = (arm.dir.X ~= 0) and Vector3.new(0, 0, math.random(-3, 3))
                                              or Vector3.new(math.random(-3, 3), 0, 0)
            pos = pos + jitter
            table.insert(spawnsOut, CFrame.new(pos, pos + arm.face))
        end
    end

    return f
end

local function buildPrison(workspace: Workspace, prisonSpawnsOut: { CFrame })
    local f = group(workspace, "Prison")

    local floor = makePart({
        Name = "PrisonFloor",
        Size = Vector3.new(80, 2, 80),
        Position = Config.PRISON_CENTER - Vector3.new(0, 4, 0),
        Color = Color3.fromRGB(36, 30, 30),
        Material = Enum.Material.Slate,
    })
    floor.Parent = f

    -- Walls (4 sides) with bars
    local barColor = Color3.fromRGB(140, 140, 150)

    local function buildWall(cf: CFrame, length: number)
        local base = makePart({
            Name = "WallBase",
            Size = Vector3.new(length, 1, 1),
            CFrame = cf,
            Color = Color3.fromRGB(90, 85, 80),
            Material = Enum.Material.Concrete,
        })
        base.Parent = f
        local top = makePart({
            Name = "WallTop",
            Size = Vector3.new(length, 1, 1),
            CFrame = cf * CFrame.new(0, 14, 0),
            Color = Color3.fromRGB(90, 85, 80),
            Material = Enum.Material.Concrete,
        })
        top.Parent = f
        local barCount = math.floor(length / 2)
        for i = 0, barCount - 1 do
            local x = -length / 2 + 1 + i * 2
            local bar = makePart({
                Name = "Bar",
                Size = Vector3.new(0.4, 13, 0.4),
                CFrame = cf * CFrame.new(x, 7, 0),
                Color = barColor,
                Material = Enum.Material.Metal,
            })
            bar.Parent = f
        end
    end

    local c = Config.PRISON_CENTER
    buildWall(CFrame.new(c + Vector3.new(0, 0, -30)), 60)
    buildWall(CFrame.new(c + Vector3.new(0, 0, 30)), 60)
    buildWall(CFrame.new(c + Vector3.new(-30, 0, 0)) * CFrame.Angles(0, math.rad(90), 0), 60)
    buildWall(CFrame.new(c + Vector3.new(30, 0, 0)) * CFrame.Angles(0, math.rad(90), 0), 60)

    -- Eerie red light overhead
    local glow = makePart({
        Name = "PrisonGlow",
        Size = Vector3.new(40, 0.4, 40),
        Position = c + Vector3.new(0, 16, 0),
        Color = Config.THEME.DANGER,
        Material = Enum.Material.Neon,
        Transparency = 0.3,
    })
    glow.Parent = f

    -- "JAIL" sign
    local sign = makePart({
        Name = "PrisonSign",
        Size = Vector3.new(20, 5, 0.4),
        CFrame = CFrame.new(c + Vector3.new(0, 18, -30)),
        Color = Color3.fromRGB(20, 18, 20),
        Material = Enum.Material.SmoothPlastic,
    })
    sign.Parent = f

    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Front
    sg.CanvasSize = Vector2.new(800, 200)
    sg.Parent = sign
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.Text = "PENJARA"
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextColor3 = Config.THEME.DANGER
    lbl.TextScaled = true
    lbl.Parent = sg

    -- Prison spawn cells
    for i = 1, 8 do
        local angle = math.rad((i - 1) * (360 / 8))
        local r = 16
        local pos = c + Vector3.new(math.cos(angle) * r, Config.SPAWN_HEIGHT, math.sin(angle) * r)
        table.insert(prisonSpawnsOut, CFrame.new(pos, c + Vector3.new(0, Config.SPAWN_HEIGHT, 0)))
    end

    return f
end

function MapBuilder.build()
    local workspace = game:GetService("Workspace")

    -- Clear any existing managed folders
    for _, name in ipairs({ "Lobby", "City", "Prison" }) do
        local existing = workspace:FindFirstChild(name)
        if existing then existing:Destroy() end
    end

    local citySpawns = {}
    local prisonSpawns = {}
    buildLobby(workspace)
    buildCity(workspace, citySpawns)
    buildPrison(workspace, prisonSpawns)

    return {
        citySpawns = citySpawns,
        prisonSpawns = prisonSpawns,
        lobbyCFrame = CFrame.new(Config.LOBBY_CENTER + Vector3.new(0, Config.SPAWN_HEIGHT, 0)),
    }
end

return MapBuilder
