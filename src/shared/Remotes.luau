--!nonstrict
-- Auto-creates RemoteEvents/Functions in ReplicatedStorage.Shared.Remotes
-- Both server and client require this to access typed remote getters.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Config = require(script.Parent.Config)

local Remotes = {}

local function ensureFolder(parent: Instance, name: string): Folder
    local f = parent:FindFirstChild(name)
    if not f then
        if RunService:IsServer() then
            f = Instance.new("Folder")
            f.Name = name
            f.Parent = parent
        else
            f = parent:WaitForChild(name, 30)
        end
    end
    return f :: Folder
end

local sharedFolder  = ensureFolder(ReplicatedStorage, "Shared")
local remotesFolder = ensureFolder(sharedFolder, "Remotes")
local eventsFolder  = ensureFolder(remotesFolder, "Events")
local funcsFolder   = ensureFolder(remotesFolder, "Functions")

local function ensureRemote(parent: Instance, className: string, name: string)
    local r = parent:FindFirstChild(name)
    if not r then
        if RunService:IsServer() then
            r = Instance.new(className)
            r.Name = name
            r.Parent = parent
        else
            r = parent:WaitForChild(name, 30)
        end
    end
    return r
end

if RunService:IsServer() then
    for _, name in ipairs(Config.REMOTES.Events) do
        ensureRemote(eventsFolder, "RemoteEvent", name)
    end
    for _, name in ipairs(Config.REMOTES.Functions) do
        ensureRemote(funcsFolder, "RemoteFunction", name)
    end
end

function Remotes.event(name: string): RemoteEvent
    local r = ensureRemote(eventsFolder, "RemoteEvent", name)
    return r :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
    local r = ensureRemote(funcsFolder, "RemoteFunction", name)
    return r :: RemoteFunction
end

return Remotes
