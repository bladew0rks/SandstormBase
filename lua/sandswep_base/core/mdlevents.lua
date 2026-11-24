SandSwep = SandSwep or {}

local EVENT_SOUND = 5004
local EVENT_MARK = 6000

local sbyte, sfind, ssub = string.byte, string.find, string.sub
local bor, band, lshift, rshift, arshift = bit.bor, bit.band, bit.lshift, bit.rshift, bit.arshift
local ldexp, huge = math.ldexp, math.huge

local function i32(data, offset)
    local b0, b1, b2, b3 = sbyte(data, offset + 1, offset + 4)
    if not b3 then return 0 end
    return bor(b0, lshift(b1, 8), lshift(b2, 16), lshift(b3, 24))
end

local function i16(data, offset)
    local b0, b1 = sbyte(data, offset + 1, offset + 2)
    if not b1 then return 0 end
    return arshift(lshift(bor(b0, lshift(b1, 8)), 16), 16)
end

local function f32(data, offset)
    local bits = i32(data, offset)
    local e = band(rshift(bits, 23), 0xFF)
    local m = band(bits, 0x7FFFFF)
    local v
    if e == 0 then
        if m == 0 then return 0 end
        v = ldexp(m, -149)
    elseif e == 255 then
        v = huge
    else
        v = ldexp(m + 0x800000, e - 150)
    end
    return bits < 0 and -v or v
end

local function cstr(data, offset)
    local stop = sfind(data, "\0", offset + 1, true)
    return ssub(data, offset + 1, (stop or #data + 1) - 1)
end

local cache = {}

local Parse

local function MergeIncludes(data, seqs, depth)
    if depth > 4 then return end

    local numInc, incIndex = i32(data, 336), i32(data, 340)
    if numInc <= 0 or numInc > 32 or incIndex <= 0 or incIndex >= #data then return end

    for k = 0, numInc - 1 do
        local incBase = incIndex + k * 8
        local name = cstr(data, incBase + i32(data, incBase + 4))
        if name ~= "" then
            for label, info in pairs(Parse(name, depth + 1)) do
                if seqs[label] == nil then seqs[label] = info end
            end
        end
    end
end

function Parse(model, depth)
    local data = file.Read(model, "GAME")
    if not data or #data < 200 or string.sub(data, 1, 4) ~= "IDST" then return {} end

    local numAnim, animIndex = i32(data, 180), i32(data, 184)
    local numSeq, seqIndex = i32(data, 188), i32(data, 192)
    local seqs = {}

    for i = 0, numSeq - 1 do
        local seqBase = seqIndex + i * 212
        local label = cstr(data, seqBase + i32(data, seqBase + 4))
        local numEvents, eventIndex = i32(data, seqBase + 24), i32(data, seqBase + 28)
        local animIdx = i16(data, seqBase + i32(data, seqBase + 60))

        local len, count = 0, 0
        if animIdx >= 0 and animIdx < numAnim then
            local animBase = animIndex + animIdx * 100
            local fps, frames = f32(data, animBase + 8), i32(data, animBase + 16)
            if fps > 0 and frames > 1 then len, count = (frames - 1) / fps, frames end
        end

        local info = { len = len, frames = count }
        for k = 0, numEvents - 1 do
            local eventBase = seqBase + eventIndex + k * 80
            local cycle, event = f32(data, eventBase), i32(data, eventBase + 4)
            local opt = cstr(data, eventBase + 12)

            if event == EVENT_SOUND and opt ~= "" then
                info.sounds = info.sounds or {}
                info.sounds[#info.sounds + 1] = { cycle = cycle, s = opt }
            elseif event == EVENT_MARK and opt ~= "" then
                info.marks = info.marks or {}
                info.marks[string.lower(opt)] = cycle
            end
        end

        if info.sounds then table.sort(info.sounds, function(x, y) return x.cycle < y.cycle end) end
        seqs[string.lower(label)] = info
    end

    MergeIncludes(data, seqs, depth or 0)
    return seqs
end

local EMPTY_SEQS = {}

function SandSwep.GetModelSequences(model)
    if not isstring(model) or model == "" then return EMPTY_SEQS end

    local seqs = cache[model]
    if not seqs then
        seqs = Parse(model)
        cache[model] = seqs
    end

    return seqs
end

function SandSwep.GetSequenceData(model, seq)
    if not isstring(seq) then return end
    local seqs = SandSwep.GetModelSequences(model)
    return seqs[seq] or seqs[string.lower(seq)]
end
