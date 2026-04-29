--!nonstrict
local Util = {}

function Util.shallowCopy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

function Util.tableLen(t): number
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function Util.shuffleInPlace(t)
    local n = #t
    for i = n, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

function Util.choose(list)
    if #list == 0 then return nil end
    return list[math.random(1, #list)]
end

function Util.formatTime(secs: number): string
    secs = math.max(0, math.floor(secs))
    local m = math.floor(secs / 60)
    local s = secs % 60
    return string.format("%02d:%02d", m, s)
end

function Util.lerpColor(a: Color3, b: Color3, t: number): Color3
    return a:Lerp(b, math.clamp(t, 0, 1))
end

function Util.distance2D(a: Vector3, b: Vector3): number
    local dx, dz = a.X - b.X, a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

return Util
