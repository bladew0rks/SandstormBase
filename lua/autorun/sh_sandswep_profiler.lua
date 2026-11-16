AddCSLuaFile()

SandSwep = SandSwep or {}

local SysTime, gcCount = SysTime, collectgarbage

local session
local depth, childTime, childKb = 0, {}, {}

local function Stat(name)
    local stat = session.stats[name]
    if not stat then
        stat = {
            name = name,
            calls = 0,
            total = 0,
            self = 0,
            worst = 0,
            kb = 0,
            bytes = 0,
        }
        session.stats[name] = stat
    end

    return stat
end

local function Finish(stat, outer, startTime, startKb, ...)
    local took = SysTime() - startTime
    local kb = math.max(gcCount("count") - startKb, 0)
    local inner = outer + 1

    stat.calls = stat.calls + 1
    stat.total = stat.total + took
    stat.self = stat.self + math.max(took - childTime[inner], 0)
    stat.kb = stat.kb + math.max(kb - childKb[inner], 0)
    if took > stat.worst then stat.worst = took end

    depth = outer
    if outer > 0 then
        childTime[outer] = childTime[outer] + took
        childKb[outer] = childKb[outer] + kb
    end

    return ...
end

local function Timed(name, fn)
    local stat = Stat(name)

    return function(...)
        local outer = depth
        depth = outer + 1
        childTime[outer + 1], childKb[outer + 1] = 0, 0

        local startTime, startKb = SysTime(), gcCount("count")
        return Finish(stat, outer, startTime, startKb, fn(...))
    end
end

local function WrapHooks(restore)
    for event, hooks in pairs(hook.GetTable()) do
        local ids = {}
        for id, fn in pairs(hooks) do
            if isfunction(fn) then ids[#ids + 1] = id end
        end

        for _, id in ipairs(ids) do
            local fn = hooks[id]
            hook.Add(event, id, Timed("hook " .. event .. " / " .. tostring(id), fn))
            restore[#restore + 1] = function() hook.Add(event, id, fn) end
        end
    end
end

local function ClassChain(wep)
    local list, class, seen = {}, wep:GetClass(), {}
    while class and not seen[class] do
        seen[class] = true
        local stored = weapons.GetStored(class)
        if not stored then break end
        list[#list + 1] = stored
        class = stored.Base
    end

    return list
end

local function WrapWeapon(wep, restore)
    if not IsValid(wep) or not wep.IsSandSwep then return end

    local wepTable = wep:GetTable()
    local keys = {}
    for k in pairs(wepTable) do keys[k] = true end
    for _, stored in ipairs(ClassChain(wep)) do
        for k in pairs(stored) do keys[k] = true end
    end

    local originals = {}
    for k in pairs(keys) do
        local fn = isstring(k) and wep[k]
        if isfunction(fn) then
            originals[k] = { rawget(wepTable, k) }
            wepTable[k] = Timed("weapon:" .. k, fn)
        end
    end

    restore[#restore + 1] = function()
        if not IsValid(wep) then return end

        local current = wep:GetTable()
        for k, orig in pairs(originals) do current[k] = orig[1] end
    end
end

local SKIP = { Profile = true, ProfileRunning = true }

local function WrapTable(tbl, prefix, restore, level)
    local keys = {}
    for k, v in pairs(tbl) do
        if isstring(k) and not SKIP[k] then keys[#keys + 1] = k end
    end

    for _, k in ipairs(keys) do
        local v = tbl[k]
        if isfunction(v) then
            tbl[k] = Timed(prefix .. k, v)
            restore[#restore + 1] = function() tbl[k] = v end
        elseif istable(v) and level < 2 and getmetatable(v) == nil and table.Count(v) <= 64 then
            WrapTable(v, prefix .. k .. ".", restore, level + 1)
        end
    end
end

local function WrapNet(restore)
    for msg, fn in pairs(net.Receivers) do
        local name = "net " .. msg
        net.Receivers[msg] = function(len, sender)
            local stat = Stat(name)
            stat.bytes = stat.bytes + math.ceil(len / 8)

            local startTime = SysTime()
            fn(len, sender)
            local took = SysTime() - startTime

            stat.calls = stat.calls + 1
            stat.total = stat.total + took
            stat.self = stat.self + took
            if took > stat.worst then stat.worst = took end
        end

        restore[#restore + 1] = function() net.Receivers[msg] = fn end
    end
end

local function Report(realm, duration, stats, frames)
    local list = {}
    for _, stat in pairs(stats) do
        if stat.calls > 0 then list[#list + 1] = stat end
    end

    local out = {}
    local function line(fmt, ...) out[#out + 1] = string.format(fmt, ...) end

    line("[sandswep] %s profile, %d seconds", realm, duration)
    if #frames > 0 then
        local sum, worst, slow = 0, 0, 0
        for _, frameTime in ipairs(frames) do
            sum = sum + frameTime
            worst = math.max(worst, frameTime)
        end

        local avg = sum / #frames
        for _, frameTime in ipairs(frames) do
            if frameTime > avg * 2 then slow = slow + 1 end
        end

        line("frames: %d, average %.2f ms (%.0f fps), worst %.2f ms, %d over twice the average", #frames, avg * 1000, 1 / avg, worst * 1000, slow)
    end

    local perFrame = #frames > 0 and #frames or nil
    local function Section(title, sortKey, limit)
        table.sort(list, function(a, b) return a[sortKey] > b[sortKey] end)

        line("")
        line(title)
        line("  %8s %9s %9s %9s %9s %9s %8s  %s", "calls", "self ms", "total ms", "worst ms", perFrame and "self/frm" or "us/call", "self KB", "bytes", "name")
        for i = 1, math.min(#list, limit) do
            local stat = list[i]
            local rate = perFrame and stat.self * 1000 / perFrame or stat.self * 1e6 / stat.calls
            line("  %8d %9.2f %9.2f %9.3f %9.4f %9.1f %8s  %s", stat.calls, stat.self * 1000, stat.total * 1000, stat.worst * 1000,
                rate, stat.kb, stat.bytes > 0 and stat.bytes or "", stat.name)
        end
    end

    Section("by self time:", "self", 50)
    Section("by total time (includes nested calls):", "total", 20)
    Section("by allocation:", "kb", 20)
    Section("by worst single call:", "worst", 15)

    local text = table.concat(out, "\n")
    print(text)

    file.CreateDir("sandswep")
    local path = "sandswep/profile_" .. realm .. ".txt"
    file.Write(path, text .. "\n")
    print("[sandswep] profile written to data/" .. path)
end

function SandSwep.Profile(duration, realm, ply)
    if session then
        print("[sandswep] a profile is already running")
        return
    end

    session = { stats = {} }
    depth = 0
    local restore, frames = {}, {}

    WrapHooks(restore)

    local owner = CLIENT and LocalPlayer() or ply
    local wrapped = {}
    local function WrapActive()
        if not IsValid(owner) then return end

        local wep = owner:GetActiveWeapon()
        if IsValid(wep) and wep.IsSandSwep and not wrapped[wep] then
            wrapped[wep] = true
            WrapWeapon(wep, restore)
        end
    end

    WrapActive()
    hook.Add("Think", "SandSwep_ProfileWeapon", WrapActive)
    restore[#restore + 1] = function() hook.Remove("Think", "SandSwep_ProfileWeapon") end

    WrapTable(SandSwep, "SandSwep.", restore, 1)
    WrapNet(restore)

    if CLIENT then
        hook.Add("Think", "SandSwep_ProfileFrames", function() frames[#frames + 1] = RealFrameTime() end)
        restore[#restore + 1] = function() hook.Remove("Think", "SandSwep_ProfileFrames") end
    end

    print(string.format("[sandswep] profiling the %s for %d seconds...", realm, duration))
    timer.Simple(duration, function()
        for i = #restore, 1, -1 do restore[i]() end

        local stats = session.stats
        session = nil
        depth = 0
        Report(realm, duration, stats, frames)
    end)
end

local function Seconds(args)
    return math.Clamp(tonumber(args[1]) or 10, 1, 60)
end

if CLIENT then
    concommand.Add("sandswep_profile", function(_, _, args)
        local seconds = Seconds(args)
        SandSwep.Profile(seconds, "client")
        RunConsoleCommand("sandswep_profile_sv", tostring(seconds))
    end, nil, "Time hooks, the active sandswep weapon, SandSwep functions and net messages on client and server")
else
    concommand.Add("sandswep_profile_sv", function(ply, _, args)
        local allowed = not IsValid(ply) or game.SinglePlayer() or ply:IsListenServerHost() or ply:IsSuperAdmin()
        if not allowed then return end

        SandSwep.Profile(Seconds(args), "server", ply)
    end, nil, "Time hooks, the caller's active sandswep weapon, SandSwep functions and net messages on the server")
end
