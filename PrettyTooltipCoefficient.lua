-- Spell power coefficients: the share of the caster's spell power a spell's
-- damage or healing gains. No game API has them. WoW Forever's follow
-- Classic's rules (cast time / 3.5, duration / 15) without Classic's cap on
-- spells over time or its penalty for spells learned before level 20, as the
-- spell data on foreverchanges.pro shows; the spells below are confirmed or
-- corrected there, and any other spell's is an estimate. Forever's tooltips
-- already count spell power in, so the base is what is left without it.
local _, ns = ...

local isSecret = issecretvalue or function() return false end

-- As GetSpellBonusDamage numbers the schools.
local SCHOOLS = { Holy = 2, Fire = 3, Nature = 4, Frost = 5, Shadow = 6, Arcane = 7 }

-- By name, so every rank matches. direct or periodic: a fixed coefficient,
-- periodic for the whole duration; directScale or periodicScale: a factor on
-- the rules' value; healing: scales with healing power though its text never
-- says heal. An empty entry: the rules are right. Channeled spells have no
-- rule and need an entry.
local KNOWN = {
    -- Mage
    Fireball = { periodic = 0 },
    Frostbolt = { directScale = .95 },
    ["Fire Blast"] = {},
    Scorch = {},
    ["Arcane Explosion"] = { directScale = 1 / 3 },
    ["Frost Nova"] = { direct = .029 },
    Flamestrike = { direct = .157, periodic = 0 },
    -- Warlock
    ["Shadow Bolt"] = {},
    Immolate = { direct = .2, periodicScale = .65 },
    Corruption = {},
    ["Bane of Agony"] = {},
    ["Bane of Doom"] = { direct = 4 },
    ["Searing Pain"] = {},
    ["Soul Fire"] = {},
    Shadowburn = {},
    Conflagrate = {},
    ["Death Coil"] = { direct = .214 },
    ["Drain Soul"] = { periodic = .5 },
    -- Priest
    Smite = {},
    ["Mind Blast"] = {},
    ["Shadow Word: Pain"] = {},
    ["Mind Flay"] = { periodic = .5 },
    Starshards = { periodic = 1 },
    ["Lesser Heal"] = {},
    Heal = {},
    ["Greater Heal"] = {},
    ["Flash Heal"] = {},
    Renew = {},
    ["Desperate Prayer"] = {},
    ["Power Word: Shield"] = { direct = .1, healing = true },
    -- Druid
    Wrath = {},
    Starfire = {},
    Moonfire = { direct = .15, periodicScale = .65 },
    ["Entangling Roots"] = { periodicScale = .3 },
    ["Healing Touch"] = {},
    Rejuvenation = {},
    Regrowth = { direct = .286, periodic = .5 },
    -- Shaman
    ["Lightning Bolt"] = {},
    ["Chain Lightning"] = {},
    ["Earth Shock"] = { directScale = .9 },
    ["Frost Shock"] = { directScale = .9 },
    ["Flame Shock"] = { direct = .214, periodicScale = .5 },
    ["Healing Wave"] = {},
    ["Lesser Healing Wave"] = {},
    ["Chain Heal"] = {},
    -- Paladin
    ["Holy Light"] = {},
    ["Flash of Light"] = {},
    ["Holy Shock"] = {},
    Exorcism = {},
    ["Hammer of Wrath"] = {},
}

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

-- The first amount dealt or healed at once, and the first spread "over N sec":
-- each { low, high }, the second with its duration.
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
            local seconds = text:sub(stop + 1):match("^[^%d%.]-over (%d+) sec")
            if seconds then
                if not periodic then
                    amount.duration = tonumber(seconds)
                    periodic = amount
                end
            elseif not direct then
                direct = amount
            end
        end
    end
    return direct, periodic
end

-- Instant casts count as 1.5 sec; casts beyond 3.5 sec gain no more. The
-- tooltip gives the spell's own cast time, which talents that shorten the
-- cast leave alone, as does the coefficient.
local function castSeconds(cast)
    local value = cast and cast[1]
    if value == "Instant" then return 1.5 end
    local seconds = type(value) == "string" and tonumber(value:match("^([%d%.]+) sec"))
    return seconds and math.min(3.5, math.max(1.5, seconds))
end

local function playerPower(school, healing)
    local ok, power
    if healing then
        if not GetSpellBonusHealing then return end
        ok, power = pcall(GetSpellBonusHealing)
    else
        if not GetSpellBonusDamage then return end
        ok, power = pcall(GetSpellBonusDamage, SCHOOLS[school])
    end
    if ok and not isSecret(power) and type(power) == "number" then return power end
end

local function range(low, high)
    if low == high then return tostring(low) end
    return low .. " to " .. high
end

-- Rows splitting a spell's amounts into base and spell power, or nil. part
-- has the panel's name, cast, and description; part.spellPower, when set,
-- stands in for the player's, as on the editor's samples.
function ns.spellPowerRows(part, bonusCode)
    local text = table.concat(part.description, " "):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local school
    for word in text:gmatch("(%a+) damage") do
        if SCHOOLS[word] then school = word break end
    end
    local known = KNOWN[part.name]
    local healing = not school and ((known and known.healing) or text:find("[Hh]eal") ~= nil)
    if not (school or healing) then return end
    local direct, periodic = readAmounts(text)
    if not (direct or periodic) then return end

    local cast = castSeconds(part.cast)
    if part.cast and part.cast[1] == "Channeled" and not known then return end
    -- Classic's split, for a spell whose entry settles neither part.
    local hybrid = direct and periodic
        and not (known and (known.direct or known.periodic or known.directScale or known.periodicScale))
    local directShare, periodicShare
    if hybrid then
        if cast then
            local castPart, timePart = cast / 3.5, periodic.duration / 15
            directShare = castPart * castPart / (castPart + timePart)
            periodicShare = timePart * timePart / (castPart + timePart)
        end
    else
        directShare = direct and cast and cast / 3.5
        periodicShare = periodic and periodic.duration / 15
    end
    if known then
        directShare = known.direct or (directShare and directShare * (known.directScale or 1))
        periodicShare = known.periodic or (periodicShare and periodicShare * (known.periodicScale or 1))
    end

    local power = part.spellPower or playerPower(school, healing) or 0
    local rows = {}
    local function addRow(amount, share, suffix)
        if not (amount and share) then return end
        local bonus = math.floor(power * share + 1e-6)
        rows[#rows + 1] = {
            left = (known and "" or "~") .. string.format("%.1f%% Coefficient", share * 100) .. suffix,
            right = range(math.max(0, amount.low - bonus), math.max(0, amount.high - bonus))
                .. " + |cff" .. bonusCode .. bonus .. "|r",
        }
    end
    addRow(direct, directShare, "")
    addRow(periodic, periodicShare, " over time")
    if #rows > 0 then return rows end
end
