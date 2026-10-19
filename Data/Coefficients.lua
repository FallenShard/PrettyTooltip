-- Spell power coefficients: the share of the caster's spell power a spell's
-- damage or healing gains. No game API has them. Each class spell rank's
-- comes from Data/SpellRanks.lua, the Forever client's data; any other spell's
-- is estimated from Classic's rules (cast time / 3.5, duration / 15), which
-- Forever follows without Classic's cap on spells over time or its penalty
-- for spells learned before level 20. Forever's tooltips already count spell
-- power in, so the base is what is left without it.
local _, ns = ...

local util = ns.util
local L = ns.L

-- Between a row's coefficient and its split, dim, as between badges.
local SEPARATOR = " |cff" .. util.hex(ns.Palette.roles.caption) .. "\194\183|r "

-- As GetSpellBonusDamage numbers the schools.
local SCHOOLS = { Holy = 2, Fire = 3, Nature = 4, Frost = 5, Shadow = 6, Arcane = 7 }

local words = ns.Locale.descriptions
-- A wording can have regional or grammatical alternatives. Prefer the first
-- occurrence, then the longest match (a range before its single-number prefix).
local function findFormat(text, formats, init, lead)
    if type(formats) ~= "table" then return util.findFormat(text, formats, init, lead) end
    local best
    for _, format in ipairs(formats) do
        local found = util.pack(util.findFormat(text, format, init, lead))
        if found[1] and (not best or found[1] < best[1] or (found[1] == best[1] and found[2] > best[2])) then
            best = found
        end
    end
    if best then return unpack(best, 1, best.n) end
end

-- A number as a description prints it.
local function readNumber(text)
    return util.parseNumber(text, LARGE_NUMBER_SEPERATOR)
end

-- Whether the number from start to stop is an amount, not a part of a word
-- or a decimal, a percent, or a duration, distance, or count ("15 sec").
local function isAmount(text, start, stop)
    local before = text:sub(start - 1, start - 1)
    if before:match("%a") or before == "." or before == DECIMAL_SEPERATOR then return false end
    local after = text:sub(stop + 1):gsub("^%s+", "")
    if after:sub(1, 1) == "%" or after:match("^[%.,]%d") then return false end
    for _, unit in ipairs(words.units) do
        if after:sub(1, #unit) == unit
            and (not words.unitBoundaries or not after:sub(#unit + 1, #unit + 1):match("[%a\128-\255]")) then
            return false
        end
    end
    return true
end

-- Before the next number or the sentence's end.
local CLAUSE = "^[^%d%.]-"

-- How an amount spreads over time: "over 15 sec" is the whole duration's;
-- "each second for 5 sec", or "every 2 sec for 10 sec" (or "... Lasts 10
-- sec"), is one tick's of several. The duration, and the ticks where per tick.
local function overTime(after, before, periodicOnly)
    -- A periodic-only spell can place its area radius before the interval:
    -- Tranquility heals an amount "within 40 m every 2 sec for 10 sec".
    local clause = periodicOnly and "^.-" or words.clause or CLAUSE
    local seconds = select(3, findFormat(after, words.eachSecond, 1, clause))
    if seconds then return readNumber(seconds), readNumber(seconds) end
    local _, stop, every = findFormat(after, words.every, 1, clause)
    if every then
        -- After the rest of the word: "every 2 seconds".
        local rest = after:sub(stop + 1):gsub("^[%a\128-\255]*%.?%s*", "")
        seconds = select(3, findFormat(rest, words.everyFor, 1, "^%s*")) or select(3, findFormat(rest, words.lasts, 1, ""))
        if seconds and readNumber(every) and readNumber(every) > 0 then
            return readNumber(seconds), readNumber(seconds) / readNumber(every)
        end
    end
    local interval = select(3, findFormat(before, words.everyBefore, 1, ""))
    interval = interval and readNumber(interval)
    seconds = select(3, findFormat(after, words.over, 1, clause))
        or select(3, findFormat(before, words.overBefore, 1, ""))
        or (interval and select(3, findFormat(after, words.lasts, 1, "")))
    if seconds then
        local duration = readNumber(seconds)
        for _, phrase in ipairs(words.perSecondBefore or {}) do
            if before:find(phrase, 1, true) then interval = 1 break end
        end
        for _, phrase in ipairs(words.perSecondAfter or {}) do
            if after:find(phrase, 1, true) then interval = 1 break end
        end
        if duration and (not interval or interval > 0) then return duration, interval and duration / interval end
    end
end

-- The first amount dealt or healed at once, and the first spread over time:
-- each { low, high }, the second with its duration and, if per tick, ticks.
-- The text is in lower case.
local function readAmounts(text, rank)
    local direct, periodic
    local pos, previous = 1, 1
    while not (direct and periodic) do
        local start, stop = text:find("%d[%d%.,]*", pos)
        if not start then break end
        local lowText = text:sub(start, stop):gsub("[%.,]+$", "")
        stop = start + #lowText - 1
        local low, high = readNumber(lowText), nil
        local _, rangeStop, _, highText = findFormat(text, words.range, start, "^")
        if rangeStop then
            -- The sentence's period is not the number's.
            local trimmed = highText:gsub("[%.,]+$", "")
            high, stop = readNumber(trimmed), rangeStop - (#highText - #trimmed)
        end
        pos = stop + 1
        if isAmount(text, start, stop) then
            local amount = { low = low, high = high or low }
            -- A slow or shield duration must not turn a known direct spell
            -- into periodic damage. Its coefficient table identifies the kind.
            if rank and rank[2] and not rank[3] then return amount end
            local seconds, ticks = overTime(text:sub(stop + 1), text:sub(previous, start - 1), rank and not rank[2])
            if seconds then
                if not periodic then
                    amount.duration, amount.ticks = seconds, ticks
                    periodic = amount
                end
            elseif not direct and not (rank and not rank[2]) then
                direct = amount
            end
            previous = stop + 1
        end
    end
    return direct, periodic
end

-- The strip's cast, as Tooltips/Spell.lua words it: the game's "Instant" or
-- "Channeled", or a duration in seconds, "2.5 sec".
local function isInstant(cast)
    local value = cast and cast[1]
    return util.unformat(value, SPELL_CAST_TIME_INSTANT) or util.unformat(value, SPELL_CAST_TIME_INSTANT_NO_MANA)
end

local function isChanneled(cast)
    return util.unformat(cast and cast[1], SPELL_CAST_CHANNELED) ~= nil
end

local function castTime(cast)
    return util.parseNumber(util.unformat(cast and cast[1], SPELL_DURATION_SEC), LARGE_NUMBER_SEPERATOR)
end

-- For the rules: instant casts count as 1.5 sec; casts beyond 3.5 sec gain no
-- more. The tooltip shows the cast after talents and haste, so a spell the
-- rules estimate can be off by those.
local function castSeconds(cast)
    if isInstant(cast) then return 1.5 end
    local seconds = castTime(cast)
    return seconds and math.min(3.5, math.max(1.5, seconds))
end

local function playerPower(game, school, healing)
    if healing then return game.spellHealing() end
    return game.spellDamage(SCHOOLS[school])
end

local function range(low, high)
    if low == high then return tostring(low) end
    return util.fill(L["%s to %s"], low, high)
end

-- A number with places decimals, as the client prints one: "1,5" in German.
local function decimal(value, places)
    return (string.format("%." .. places .. "f", value):gsub("%.", function() return DECIMAL_SEPERATOR or "." end))
end

-- The time a cast takes from the player: the cast shown, after talents and
-- haste; at least the global cooldown; a channel's whole duration.
local function executeSeconds(cast, periodic)
    if isInstant(cast) then return 1.5 end
    if isChanneled(cast) then return periodic and periodic.duration end
    local seconds = castTime(cast)
    return seconds and math.max(1.5, seconds)
end

-- The average a cast deals or heals per second and per mana, a row each; nil
-- without either. Per second, what lands at once counts over the execute
-- time and what comes over time over its duration, as its ticks land.
local function rateRows(part, direct, periodic, healing)
    local directTotal = direct and (direct.low + direct.high) / 2 or 0
    local periodicTotal = periodic and (periodic.low + periodic.high) / 2 * (periodic.ticks or 1) or 0
    local perSecond
    local seconds = executeSeconds(part.cast, periodic)
    if direct and seconds then perSecond = directTotal / seconds end
    -- Without its execute time, a direct amount leaves the rate unknown.
    if periodic and periodic.duration > 0 and (perSecond or not direct) then
        perSecond = (perSecond or 0) + periodicTotal / periodic.duration
    end
    local rows = {}
    if perSecond then
        rows[#rows + 1] = { left = healing and L["Healing per Second"] or DAMAGE_PER_SECOND, right = decimal(perSecond, 1) }
    end
    local total = directTotal + periodicTotal
    -- A cost in mana, not a share of base mana or another power.
    local cost = part.cost and part.cost[2] == MANA and util.parseNumber(part.cost[1], LARGE_NUMBER_SEPERATOR)
    if cost and cost > 0 then
        rows[#rows + 1] = { left = healing and L["Healing per Mana"] or L["Damage per Mana"], right = decimal(total / cost, 2) }
    end
    if #rows > 0 then return rows end
end

-- Whether a description says the spell heals: "Heals", or "healing", not
-- "health".
local function heals(text)
    local lower = " " .. util.lower(text):gsub("[^%a\128-\255]", " ") .. " "
    for _, word in ipairs(words.heals) do
        local phrase = words.healBoundaries == false and word or " " .. word .. " "
        if lower:find(phrase, 1, true) then return true end
    end
    return false
end

-- Each rank's spell ID in rank order, by the spell's name on this client;
-- the names are asked for at the first use.
local byName
local function ranksNamed(name)
    if not byName then
        byName = {}
        for english, ranks in pairs(ns.spellRankByName or {}) do
            byName[ns.Game.localSpellName(ranks[1], english)] = ranks
        end
    end
    return name and byName[name]
end

-- Rows splitting a spell's amounts into base and spell power, or nil; and
-- the rows of its rates, or nil. part has the panel's name, cost,
-- cast, description, and spellID; part.spellPower, when set, stands in for
-- the player's, as on the editor's samples; else game answers it.
function ns.spellPowerRows(part, bonusCode, game)
    local text = util.uncolored(table.concat(part.description, " ")):gsub("\194\160", " "):gsub("\226\128\175", " ")
    local rank = ns.spellRanks and ns.spellRanks[part.spellID]
    local named = not rank and ranksNamed(part.name)
    if named then
        -- A spell named without an ID it has: the rank it names, else its top rank.
        local number = tonumber((part.rank or ""):match("(%d+)"))
        rank = ns.spellRanks[named[number] or named[#named]]
    end
    local school = ns.Palette.schoolIn(text, words.damageSchool or { words.school[1] }, SCHOOLS)
    -- Some translations name the school only in the spell's name (Chinese
    -- Arcane Missiles). A known scaling rank also has a school in our data.
    if rank and not rank.heals and not school then
        local known = ns.Palette.detectSchool(part.description, part.name, part.spellID)
        if SCHOOLS[known] then school = known end
    end
    -- The table holds every class spell that scales; another class spell, as
    -- Dampen Magic, gains nothing, however its text reads.
    if not rank and ns.spellSchool and ns.spellSchool(part.name, part.spellID) then return end
    -- Heals, healing, or healed; not health, as a totem's.
    local healing = (rank and rank.heals) or (not school and heals(text))
    if not (school or healing) then return end
    local direct, periodic = readAmounts(util.lower(text), rank)
    if not (direct or periodic) then return end

    local directShare, periodicShare
    if rank then
        directShare, periodicShare = rank[2], rank[3]
    else
        -- Channeled spells have no rule.
        if isChanneled(part.cast) then return end
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
    local function addRow(amount, share, label)
        if not (amount and share) then return end
        -- An amount per tick gains its share of the whole duration's bonus.
        local bonus = math.floor(power * share / (amount.ticks or 1) + 1e-6)
        -- The share in the school's color, as the bonus it brings, then the split.
        rows[#rows + 1] = {
            left = label,
            right = "|cff" .. bonusCode .. (estimate and "~" or "") .. decimal(share * 100, 1) .. "%" .. "|r"
                .. SEPARATOR .. range(math.max(0, amount.low - bonus), math.max(0, amount.high - bonus))
                .. " + |cff" .. bonusCode .. bonus .. "|r" .. (amount.ticks and " " .. L["each"] or ""),
        }
    end
    addRow(direct, directShare, healing and L["Healing Power Coefficient"] or L["Spell Power Coefficient"])
    addRow(periodic, periodicShare,
        healing and L["Healing Power Coefficient over time"] or L["Spell Power Coefficient over time"])
    if #rows > 0 then return rows, rateRows(part, direct, periodic, healing) end
end
