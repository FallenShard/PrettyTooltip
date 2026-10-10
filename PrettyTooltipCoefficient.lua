-- Spell power coefficients: the share of the caster's spell power a spell's
-- damage or healing gains. No game API has them. WoW Forever's follow
-- Classic's rules (cast time / 3.5, duration / 15) without Classic's cap on
-- spells over time or its penalty for spells learned before level 20, as the
-- spell data on foreverchanges.pro shows; the spells below are confirmed or
-- corrected there, and any other spell's is an estimate. Forever's tooltips
-- already count spell power in, so the base is what is left without it.
local _, ns = ...

local util = ns.util
local isSecret = util.isSecret

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

-- Each rank's own cast time by spell ID, from foreverchanges.pro's spellbook.
-- The tooltip shows the cast after talents and haste (Frostbolt rank 3's 2.2
-- sec as 1.7 with Improved Frostbolt), but the coefficient follows the
-- spell's own.
local BASE_CAST = {
    -- Arcane Blast (Mage)
    [400574] = 2.5, [1239696] = 2.5, [1239697] = 2.5, [1239699] = 2.5, [1239700] = 2.5,
    -- Fireball (Mage)
    [133] = 1.5, [143] = 2, [145] = 2.5, [3140] = 3, [8400] = 3.5, [8401] = 3.5, [8402] = 3.5, [10148] = 3.5, [10149] = 3.5, [10150] = 3.5, [10151] = 3.5, [25306] = 3.5,
    -- Flamestrike (Mage)
    [2120] = 3, [2121] = 3, [8422] = 3, [8423] = 3, [10215] = 3, [10216] = 3,
    -- Pyroblast (Mage)
    [11366] = 6, [12505] = 6, [12522] = 6, [12523] = 6, [12524] = 6, [12525] = 6, [12526] = 6, [18809] = 6,
    -- Scorch (Mage)
    [2948] = 1.5, [8444] = 1.5, [8445] = 1.5, [8446] = 1.5, [10205] = 1.5, [10206] = 1.5, [10207] = 1.5,
    -- Frostfire Bolt (Mage)
    [401502] = 3, [1237312] = 3, [1237313] = 3,
    -- Frostbolt (Mage)
    [116] = 1.5, [205] = 1.8, [837] = 2.2, [7322] = 2.6, [8406] = 3, [8407] = 3, [8408] = 3, [10179] = 3, [10180] = 3, [10181] = 3, [25304] = 3,
    -- Mana Burn (Priest)
    [8129] = 3, [8131] = 3, [10874] = 3, [10875] = 3, [10876] = 3,
    -- Lesser Heal (Priest)
    [2050] = 1.5, [2052] = 2, [2053] = 2.5,
    -- Smite (Priest)
    [585] = 1.5, [591] = 2, [598] = 2.5, [984] = 2.5, [1004] = 2.5, [6060] = 2.5, [10933] = 2.5, [10934] = 2.5,
    -- Heal (Priest)
    [2054] = 3, [2055] = 3, [6063] = 3, [6064] = 3,
    -- Flash Heal (Priest)
    [2061] = 1.5, [9472] = 1.5, [9473] = 1.5, [9474] = 1.5, [10915] = 1.5, [10916] = 1.5, [10917] = 1.5,
    -- Holy Fire (Priest)
    [14914] = 3.5, [15262] = 3.5, [15263] = 3.5, [15264] = 3.5, [15265] = 3.5, [15266] = 3.5, [15267] = 3.5, [15261] = 3.5,
    -- Binding Heal (Priest)
    [401937] = 1.5, [1240770] = 1.5, [1240771] = 1.5, [1240772] = 1.5, [1240773] = 1.5, [1240774] = 1.5,
    -- Prayer of Healing (Priest)
    [596] = 3, [996] = 3, [10960] = 3, [10961] = 3, [25316] = 3,
    -- Greater Heal (Priest)
    [2060] = 3, [10963] = 3, [10964] = 3, [10965] = 3, [25314] = 3,
    -- Mind Blast (Priest)
    [8092] = 1.5, [8102] = 1.5, [8103] = 1.5, [8104] = 1.5, [8105] = 1.5, [8106] = 1.5, [10945] = 1.5, [10946] = 1.5, [10947] = 1.5,
    -- Corruption (Warlock)
    [172] = 2, [6222] = 2, [6223] = 2, [7648] = 2, [11671] = 2, [11672] = 2, [25311] = 2,
    -- Inferno (Warlock)
    [1122] = 2,
    -- Immolate (Warlock)
    [348] = 2, [707] = 2, [1094] = 2, [2941] = 2, [11665] = 2, [11667] = 2, [11668] = 2, [25309] = 2,
    -- Shadow Bolt (Warlock)
    [686] = 1.7, [695] = 2.2, [705] = 2.8, [1088] = 3, [1106] = 3, [7641] = 3, [11659] = 3, [11660] = 3, [11661] = 3, [25307] = 3,
    -- Searing Pain (Warlock)
    [5676] = 1.5, [17919] = 1.5, [17920] = 1.5, [17921] = 1.5, [17922] = 1.5, [17923] = 1.5,
    -- Incinerate (Warlock)
    [412758] = 2.5, [1293812] = 2.5, [1293813] = 2.5,
    -- Soul Fire (Warlock)
    [6353] = 6, [17924] = 6,
    -- Wrath (Druid)
    [5176] = 1.5, [5177] = 1.7, [5178] = 2, [5179] = 2, [5180] = 2, [6780] = 2, [8905] = 2, [9912] = 2,
    -- Entangling Roots (Druid)
    [339] = 1.5, [1062] = 1.5, [5195] = 1.5, [5196] = 1.5, [9852] = 1.5, [9853] = 1.5,
    -- Starfire (Druid)
    [2912] = 3.5, [8949] = 3.5, [8950] = 3.5, [8951] = 3.5, [9875] = 3.5, [9876] = 3.5, [25298] = 3.5,
    -- Healing Touch (Druid)
    [5185] = 1.5, [5186] = 2, [5187] = 2.5, [5188] = 3, [5189] = 3.5, [6778] = 3.5, [8903] = 3.5, [9758] = 3.5, [9888] = 3.5, [9889] = 3.5, [25297] = 3.5,
    -- Regrowth (Druid)
    [8936] = 2, [8938] = 2, [8939] = 2, [8940] = 2, [8941] = 2, [9750] = 2, [9856] = 2, [9857] = 2, [9858] = 2,
    -- Lightning Bolt (Shaman)
    [403] = 1.5, [529] = 2, [548] = 2.5, [915] = 2.5, [943] = 2.5, [6041] = 2.5, [10391] = 2.5, [10392] = 2.5, [15207] = 2.5, [15208] = 2.5,
    -- Chain Lightning (Shaman)
    [421] = 2, [930] = 2, [2860] = 2, [10605] = 2,
    -- Lava Burst (Shaman)
    [408490] = 2.5, [1238299] = 2.5, [1238300] = 2.5,
    -- Healing Wave (Shaman)
    [331] = 1.5, [332] = 2, [547] = 2.5, [913] = 3, [939] = 3, [959] = 3, [8005] = 3, [10395] = 3, [10396] = 3, [25357] = 3,
    -- Lesser Healing Wave (Shaman)
    [8004] = 1.5, [8008] = 1.5, [8010] = 1.5, [10466] = 1.5, [10467] = 1.5, [10468] = 1.5,
    -- Chain Heal (Shaman)
    [1064] = 2.5, [10622] = 2.5, [10623] = 2.5,
    -- Holy Light (Paladin)
    [635] = 2.5, [639] = 2.5, [647] = 2.5, [1026] = 2.5, [1042] = 2.5, [3472] = 2.5, [10328] = 2.5, [10329] = 2.5, [25292] = 2.5,
    -- Flash of Light (Paladin)
    [19750] = 1.5, [19939] = 1.5, [19940] = 1.5, [19941] = 1.5, [19942] = 1.5, [19943] = 1.5,
    -- Light's Vigil (Paladin)
    [1310911] = 1.5, [1311590] = 1.5, [1311595] = 1.5,
    -- Hammer of Wrath (Paladin)
    [24275] = 1, [24274] = 1, [24239] = 1,
    -- Holy Wrath (Paladin)
    [2812] = 2, [10318] = 2,
}

-- Instant casts count as 1.5 sec; casts beyond 3.5 sec gain no more.
local function castSeconds(cast, spellID)
    local seconds = BASE_CAST[spellID]
    if not seconds then
        local value = cast and cast[1]
        if value == "Instant" then return 1.5 end
        seconds = type(value) == "string" and tonumber(value:match("^([%d%.]+) sec"))
    end
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
-- has the panel's name, cast, description, and spellID; part.spellPower,
-- when set, stands in for the player's, as on the editor's samples.
function ns.spellPowerRows(part, bonusCode)
    local text = util.uncolored(table.concat(part.description, " "))
    local school
    for word in text:gmatch("(%a+) damage") do
        if SCHOOLS[word] then school = word break end
    end
    local known = KNOWN[part.name]
    local healing = not school and ((known and known.healing) or text:find("[Hh]eal") ~= nil)
    if not (school or healing) then return end
    local direct, periodic = readAmounts(text)
    if not (direct or periodic) then return end

    local cast = castSeconds(part.cast, part.spellID)
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
