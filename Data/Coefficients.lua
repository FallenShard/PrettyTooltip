-- Spell power coefficients: the share of the caster's spell power a spell's
-- damage or healing gains. No game API has them. A class spell rank's come
-- from Data/SpellParts.lua, the Forever client's own tooltip formulas: which
-- of the numbers its description prints scale, and by how much. Any other
-- spell's is estimated from Classic's rules (cast time / 3.5, duration / 15),
-- which Forever follows without Classic's cap on spells over time or its
-- penalty for spells learned before level 20. Forever's tooltips already
-- count spell power in, so the base is what is left without it.
-- Forever only: retail's .toc leaves this file out.
local _, ns = ...
ns.provideData("coefficients")

local util = ns.util
local L = ns.L

-- Between a row's coefficient and its split, dim, as between badges.
local SEPARATOR = " |cff" .. util.hex(ns.Palette.roles.caption) .. "\194\183|r "

-- As GetSpellBonusDamage numbers the schools.
local SCHOOLS = { Holy = 2, Fire = 3, Nature = 4, Frost = 5, Shadow = 6, Arcane = 7 }

local amounts = ns.SpellAmounts
local words = ns.Locale.descriptions
local readAmounts, numbersIn, isInstant, isChanneled, castTime = amounts.readAmounts, amounts.numbersIn,
    amounts.isInstant, amounts.isChanneled, amounts.castTime
local decimal, heals, rateRows = amounts.decimal, amounts.heals, amounts.rateRows

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
    return SCHOOLS[school] and game.spellDamage(SCHOOLS[school])
end

local function range(low, high)
    if low == high then return tostring(low) end
    return util.fill(L["%s to %s"], low, high)
end

local function caption(healing, overTime)
    if healing then return overTime and L["Healing Power Coefficient over time"] or L["Healing Power Coefficient"] end
    return overTime and L["Spell Power Coefficient over time"] or L["Spell Power Coefficient"]
end

-- The share in the school's color, then the split of the amount into its base
-- and the bonus it brings; the bonus alone where no amount is printed for it.
local function row(label, share, bonusCode, estimate, bonus, low, high, each)
    local split = "+|cff" .. bonusCode .. bonus .. "|r"
    if low then split = range(math.max(0, low), math.max(0, high)) .. " + |cff" .. bonusCode .. bonus .. "|r" end
    return {
        left = label,
        right = "|cff" .. bonusCode .. (estimate and "~" or "") .. decimal(share * 100, 1) .. "%" .. "|r"
            .. SEPARATOR .. split .. (each and " " .. L["each"] or ""),
    }
end

-- Each rank's spell ID in rank order, by the spell's name on this client;
-- the names are asked for at the first use.
local byName
local function ranksNamed(name)
    if not byName then
        byName = {}
        for english, ranks in pairs(ns.spellPartsByName or {}) do
            byName[ns.Game.localSpellName(ranks[1], english)] = ranks
        end
    end
    return name and byName[name]
end

-- A part's value for this player: a number, or a tree of conditions on the
-- spells they know, their auras, and their talent ranks (Data/SpellParts.lua).
local function resolve(value, game)
    while type(value) == "table" do
        local kind, id, index = value[1], value[2], 0
        if kind == "r" then
            local node = ns.spellTalentNodes and ns.spellTalentNodes[id]
            index = node and game.talentRank and game.talentRank(node) or 0
        elseif kind == "s" then
            index = game.knowsSpell and game.knowsSpell(id) and 1 or 0
        elseif game.hasAura and game.hasAura(id) then
            index = 1
        end
        value = value[3 + index]
    end
    return value
end

local LABELS = {
    proc = L["Proc"],
    judgement = L["Judgement"],
    judgementStunned = L["Judgement, stunned target"],
    perSwingFast = L["Per swing, fast weapon"],
    perSwingSlow = L["Per swing, slow weapon"],
    firstTargets = L["Extra to the first targets"],
}

-- A seal's amounts land from its procs and its Judgement, not from casting it,
-- so its rates would divide them by the wrong cast and cost.
local NOT_CAST = { proc = true, judgement = true, judgementStunned = true, perSwingFast = true, perSwingSlow = true }

local function castLands(entry)
    for index = 3, #entry do
        if NOT_CAST[entry[index].label] then return false end
    end
    return true
end

-- What the parts of a rank read from text alone tell readAmounts and the
-- rates: whether it lands at once, over time, and whether it heals.
local function kindsOf(entry, game)
    local direct, periodic, damage, healing
    for index = 3, #entry do
        local data = entry[index]
        local share = resolve(data.sp, game) or resolve(data.heal, game)
        if not data.hidden and data[1] ~= "weapon" and share then
            if data.ticks or data.perTick then periodic = true else direct = true end
            if data.heal ~= nil then healing = true else damage = true end
        end
    end
    return { 0, direct, periodic, heals = healing and not damage }
end

-- Rows for a class spell rank's parts, or nil where its description does not
-- print as many numbers as the data expects in this language, as when a talent
-- rewords it.
local function partRows(entry, spellID, part, text, school, bonusCode, game)
    local own = ns.spellSlots and ns.spellSlots[spellID]
    if own == false then return end
    local numbers = numbersIn(text)
    if #numbers ~= (own and own[1] or entry[2]) then return end
    local rows, printed = {}, 0
    for index = 3, #entry do
        local data = entry[index]
        if not data.hidden then printed = printed + 1 end
        local healing = data.heal ~= nil
        local share = resolve(healing and data.heal or data.sp, game)
        local slot = not data.hidden and (own and own[1 + printed] or resolve(data.slot, game))
        local power = part.spellPower or playerPower(game, data.school or school, healing)
        -- Attack power and weapon damage alone are not shown yet.
        if share and power and (slot or data.hidden) then
            local bonus = math.floor(power * share + 1e-6)
            local label = LABELS[data.label] or caption(healing, data.ticks or data.perTick)
            if data.hidden or data.pct then
                rows[#rows + 1] = row(label, share, bonusCode, data.est, bonus, nil, nil, data.ticks ~= nil)
            elseif numbers[slot] then
                local low, high = numbers[slot], numbers[slot + (data.n or 1) - 1]
                if not data.add then low, high = low - bonus, high - bonus end
                rows[#rows + 1] = row(label, share, bonusCode, data.est, bonus, low, high, data.perTick)
            end
        end
    end
    return rows
end

-- Rows splitting a spell's amounts into base and spell power, or nil; and
-- the rows of its rates, or nil. part has the panel's name, cost,
-- cast, description, and spellID; part.spellPower, when set, stands in for
-- the player's, as on the editor's samples; else game answers it.
function ns.spellPowerRows(part, bonusCode, game)
    local text = util.uncolored(table.concat(part.description, " ")):gsub("\194\160", " "):gsub("\226\128\175", " ")
    local spellID = part.spellID
    local entry = ns.spellParts and ns.spellParts[spellID]
    local named = not entry and ranksNamed(part.name)
    if named then
        -- A spell named without an ID it has: the rank it names, else its top rank.
        local number = tonumber((part.rank or ""):match("(%d+)"))
        spellID = named[number] or named[#named]
        entry = ns.spellParts[spellID]
    end
    -- The table holds every class spell; another class spell, as Dampen
    -- Magic, gains nothing, however its text reads.
    if not entry and ns.spellSchool and ns.spellSchool(part.name, part.spellID) then return end
    local school = ns.Palette.schoolIn(text, words.damageSchool or { words.school[1] }, SCHOOLS)
    -- Some translations name the school only in the spell's name (Chinese
    -- Arcane Missiles). A class spell has a school in our data.
    if entry and not school then
        local known = ns.Palette.detectSchool(part.description, part.name, spellID)
        if SCHOOLS[known] then school = known end
    end

    local kinds = entry and kindsOf(entry, game)
    if kinds and not (kinds[2] or kinds[3]) then kinds = nil end
    -- Heals, healing, or healed; not health, as a totem's.
    local healing = (kinds and kinds.heals) or (not school and heals(text))
    local direct, periodic = readAmounts(util.lower(text), kinds)
    local rates
    if (direct or periodic) and (school or healing) and (not entry or castLands(entry)) then
        rates = rateRows(part, direct, periodic, healing, game)
    end
    local rows = entry and partRows(entry, spellID, part, text, school, bonusCode, game)
    if rows then
        if #rows > 0 then return rows, rates end
        return
    end
    if not (school or healing) or not (direct or periodic) then return end

    -- Without parts that fit the text, the first amount at once and the first
    -- over time, read from it: by the rank's parts where it has them, else by
    -- the rules.
    local directShare, periodicShare, estimate
    if entry then
        for index = 3, #entry do
            local data = entry[index]
            local share = not data.hidden and data[1] ~= "weapon" and resolve(data.heal or data.sp, game)
            if share and (data.ticks or data.perTick) then
                -- A rank's share per tick is the whole duration's here.
                if data.perTick and periodic and periodic.ticks then share = share * periodic.ticks end
                periodicShare = periodicShare or share
            elseif share then
                directShare = directShare or share
            end
            estimate = estimate or (share and data.est)
        end
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
        estimate = true
    end

    local power = part.spellPower or playerPower(game, school, healing) or 0
    rows = {}
    local function addRow(amount, share, label)
        if not (amount and share) then return end
        -- An amount per tick gains its share of the whole duration's bonus.
        share = share / (amount.ticks or 1)
        local bonus = math.floor(power * share + 1e-6)
        rows[#rows + 1] = row(label, share, bonusCode, estimate, bonus, amount.low - bonus, amount.high - bonus,
            amount.ticks ~= nil)
    end
    addRow(direct, directShare, caption(healing, false))
    addRow(periodic, periodicShare, caption(healing, true))
    if #rows > 0 then return rows, rates end
end
