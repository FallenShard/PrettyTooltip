-- Spell power coefficients: the share of the caster's spell power a spell's
-- damage or healing gains. No game API has them. Each class spell rank's
-- comes from Data/SpellRanks.lua, the Forever client's data; any other spell's
-- is estimated from Classic's rules (cast time / 3.5, duration / 15), which
-- Forever follows without Classic's cap on spells over time or its penalty
-- for spells learned before level 20. Forever's tooltips already count spell
-- power in, so the base is what is left without it.
local _, ns = ...

local util = ns.util

-- As GetSpellBonusDamage numbers the schools.
local SCHOOLS = { Holy = 2, Fire = 3, Nature = 4, Frost = 5, Shadow = 6, Arcane = 7 }

-- Numbers that are durations, distances, chances, or counts, not amounts.
local NOT_AMOUNT = {
    "^%%", "^%.%d", "^ ?sec", "^ ?min", "^ ?hour", "^ ?yd", "^ yards?", "^ ?ft",
    "^ times?", "^ targets?", "^ charges?", "^ stacks?",
}

local function isAmount(text, start, stop)
    if text:sub(start - 1, start - 1):match("[%a%.]") then return false end
    local after = text:sub(stop + 1)
    for _, pattern in ipairs(NOT_AMOUNT) do
        if after:match(pattern) then return false end
    end
    return true
end

-- How an amount spreads over time: "over 15 sec" is the whole duration's;
-- "each second for 5 sec", or "every 2 sec for 10 sec" (or "... Lasts 10
-- sec"), is one tick's of several. The duration, and the ticks where per tick.
local function overTime(after)
    local seconds = after:match("^[^%d%.]-over (%d+) sec")
    if seconds then return tonumber(seconds) end
    seconds = after:match("^[^%d%.]-each second for (%d+) sec")
    if seconds then return tonumber(seconds), tonumber(seconds) end
    local every, rest = after:match("^[^%d%.]-every (%d+) sec%a*(.*)$")
    if every then
        seconds = rest:match("^ for (%d+) sec") or rest:match("[Ll]asts (%d+) sec")
        if seconds then return tonumber(seconds), tonumber(seconds) / tonumber(every) end
    end
end

-- The first amount dealt or healed at once, and the first spread over time:
-- each { low, high }, the second with its duration and, if per tick, ticks.
local function readAmounts(text)
    local direct, periodic
    local pos = 1
    while not (direct and periodic) do
        local start, stop = text:find("%d+", pos)
        if not start then break end
        local low, high = tonumber(text:sub(start, stop)), nil
        local _, rangeStop, highText = text:find("^ to (%d+)", stop + 1)
        if rangeStop then high, stop = tonumber(highText), rangeStop end
        pos = stop + 1
        if isAmount(text, start, stop) then
            local amount = { low = low, high = high or low }
            local seconds, ticks = overTime(text:sub(stop + 1))
            if seconds then
                if not periodic then
                    amount.duration, amount.ticks = seconds, ticks
                    periodic = amount
                end
            elseif not direct then
                direct = amount
            end
        end
    end
    return direct, periodic
end

-- For the rules: instant casts count as 1.5 sec; casts beyond 3.5 sec gain no
-- more. The tooltip shows the cast after talents and haste, so a spell the
-- rules estimate can be off by those.
local function castSeconds(cast)
    local value = cast and cast[1]
    if value == "Instant" then return 1.5 end
    local seconds = type(value) == "string" and tonumber(value:match("^([%d%.]+) sec"))
    return seconds and math.min(3.5, math.max(1.5, seconds))
end

local function playerPower(game, school, healing)
    if healing then return game.spellHealing() end
    return game.spellDamage(SCHOOLS[school])
end

local function range(low, high)
    if low == high then return tostring(low) end
    return low .. " to " .. high
end

-- Rows splitting a spell's amounts into base and spell power, or nil. part
-- has the panel's name, cast, description, and spellID; part.spellPower,
-- when set, stands in for the player's, as on the editor's samples; else
-- game answers it.
function ns.spellPowerRows(part, bonusCode, game)
    local text = util.uncolored(table.concat(part.description, " "))
    local school
    for word in text:gmatch("(%a+) damage") do
        if SCHOOLS[word] then school = word break end
    end
    local rank = ns.spellRanks and ns.spellRanks[part.spellID]
    local named = not rank and ns.spellRankByName and ns.spellRankByName[part.name]
    if named then
        -- A spell named without an ID it has: the rank it names, else its top rank.
        local number = tonumber((part.rank or ""):match("(%d+)"))
        rank = ns.spellRanks[named[number] or named[#named]]
    end
    -- The table holds every class spell that scales; another class spell, as
    -- Dampen Magic, gains nothing, however its text reads.
    if not rank and ns.spellSchools and ns.spellSchools[part.name] then return end
    -- Heals, healing, or healed; not health, as a totem's.
    local healing = not school and ((rank and rank.heals) or text:find("[Hh]eal[^t]") ~= nil)
    if not (school or healing) then return end
    local direct, periodic = readAmounts(text)
    if not (direct or periodic) then return end

    local directShare, periodicShare
    if rank then
        directShare, periodicShare = rank[2], rank[3]
    else
        -- Channeled spells have no rule.
        if part.cast and part.cast[1] == "Channeled" then return end
        local cast = castSeconds(part.cast)
        if direct and periodic then
            -- Classic's split between what lands at once and over time.
            if cast then
                local castPart, timePart = cast / 3.5, periodic.duration / 15
                directShare = castPart * castPart / (castPart + timePart)
                periodicShare = timePart * timePart / (castPart + timePart)
            end
        else
            directShare = direct and cast and cast / 3.5
            periodicShare = periodic and periodic.duration / 15
        end
    end
    local estimate = not rank or rank.estimate

    local power = part.spellPower or playerPower(game, school, healing) or 0
    local rows = {}
    local function addRow(amount, share, suffix)
        if not (amount and share) then return end
        -- An amount per tick gains its share of the whole duration's bonus.
        local bonus = math.floor(power * share / (amount.ticks or 1) + 1e-6)
        rows[#rows + 1] = {
            left = (estimate and "~" or "") .. string.format("%.1f%% Coefficient", share * 100) .. suffix,
            right = range(math.max(0, amount.low - bonus), math.max(0, amount.high - bonus))
                .. " + |cff" .. bonusCode .. bonus .. "|r" .. (amount.ticks and " each" or ""),
        }
    end
    addRow(direct, directShare, "")
    addRow(periodic, periodicShare, " over time")
    if #rows > 0 then return rows end
end
