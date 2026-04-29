--!nonstrict
-- Camera FX: dramatic zoom + cinematic orbit during voting & reveal phases.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CameraController = {}

local connection: RBXScriptConnection?

local function disconnect()
    if connection then
        connection:Disconnect()
        connection = nil
    end
end

local function restoreCustom()
    disconnect()
    camera.CameraType = Enum.CameraType.Custom
end

function CameraController.zoomVoting()
    camera.CameraType = Enum.CameraType.Scriptable

    local startTime = os.clock()
    disconnect()
    connection = RunService.RenderStepped:Connect(function()
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local t = (os.clock() - startTime)
        local angle = t * 0.4 -- slow orbit
        local r = 14
        local pos = hrp.Position + Vector3.new(math.cos(angle) * r, 6, math.sin(angle) * r)
        camera.CFrame = CFrame.new(pos, hrp.Position + Vector3.new(0, 2, 0))
        camera.FieldOfView = 55
    end)
end

function CameraController.zoomReveal(targetCharacter: Model?)
    camera.CameraType = Enum.CameraType.Scriptable
    local startTime = os.clock()
    disconnect()
    connection = RunService.RenderStepped:Connect(function()
        local target
        if targetCharacter then
            target = targetCharacter:FindFirstChild("HumanoidRootPart")
        end
        if not target then
            local char = player.Character
            target = char and char:FindFirstChild("HumanoidRootPart")
        end
        if not target then return end
        local t = (os.clock() - startTime)
        local angle = math.pi - t * 0.6
        local r = 8
        local pos = target.Position + Vector3.new(math.cos(angle) * r, 4, math.sin(angle) * r)
        camera.CFrame = CFrame.new(pos, target.Position + Vector3.new(0, 1.5, 0))
        camera.FieldOfView = 45
    end)
end

function CameraController.flashFOV()
    local original = camera.FieldOfView
    local tw = TweenService:Create(camera, TweenInfo.new(0.15, Enum.EasingStyle.Sine), { FieldOfView = 90 })
    tw:Play()
    tw.Completed:Connect(function()
        TweenService:Create(camera, TweenInfo.new(0.4, Enum.EasingStyle.Sine), { FieldOfView = original }):Play()
    end)
end

function CameraController.restore()
    restoreCustom()
    camera.FieldOfView = 70
end

return CameraController
