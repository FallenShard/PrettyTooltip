-- Class spell ranks read through Data/SpellParts.lua: every printed number that
-- scales gets its own row, by the player's talents, with the description's
-- English wording from Forever 1.60.1.70888 and amounts filled in.
return function(test)
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Locale/Locale.lua", "Locale/English.lua",
        "Game/Game.lua", "Data/Schools.lua", "Data/SpellParts.lua", "Game/SpellAmounts.lua", "Data/Coefficients.lua" })
    local known, rank = {}, 0
    local game = {
        spellDamage = function() return 100 end,
        spellHealing = function() return 200 end,
        knowsSpell = function(id) return known[id] == true end,
        hasAura = function() return false end,
        talentRank = function() return rank end,
    }

    local function rows(spellID, text)
        local found = ns.spellPowerRows({ name = "?", cast = { "Instant", "Cast" }, description = { text },
            spellID = spellID }, "FFFFFF", game)
        local out = {}
        for _, row in ipairs(found or {}) do out[#out + 1] = row.left .. " | " .. ns.util.plainText(row.right) end
        return out
    end

    test.check("every number, in order, as the generator counts them",
        ns.SpellAmounts.numbersIn("Heals 1,234 to 1,300 over 1.5 sec, 40% of it, rank 4."), { 1234, 1300, 1.5, 40, 4 })

    test.check("damage or healing: a row each", rows(20473,
        "Blasts the target with Holy energy, causing 277 to 299 Holy damage to an enemy, or 365 to 395 healing to an ally."),
        { "Spell Power Coefficient | 42.9% · 235 to 257 + 42", "Healing Power Coefficient | 42.9% · 280 to 310 + 85" })

    local command = "Gives the Paladin a chance to deal additional Holy damage equal to 70%% of normal weapon damage.  "
        .. "Only one Seal can be active on the Paladin at any one time.  Lasts 30 sec.\n\nUnleashing this Seal's energy "
        .. "will judge an enemy, instantly causing %s Holy damage, %s if the target is stunned or incapacitated."
    test.check("a proc's bonus alone, then the judgement and its stunned variant", rows(20920,
        command:format("140 to 151", "281 to 302")),
        { "Proc | 29.0% · +29", "Judgement | 21.4% · 119 to 130 + 21", "Judgement, stunned target | 42.9% · 239 to 260 + 42" })
    test.check("other numbers than the data expects: the first amount, by the rank's first share", rows(20920,
        command:format("145", "291")), { "Spell Power Coefficient | 21.4% · 124 + 21" })

    local function rates(spellID, text)
        local _, found = ns.spellPowerRows({ name = "?", cast = { "Instant", "Cast" }, cost = { "140", "Mana" },
            description = { text }, spellID = spellID }, "FFFFFF", game)
        return found and #found or 0
    end
    test.check("a seal's amounts are not its cast's: no rates", rates(20920, command:format("140 to 151", "281 to 302")), 0)
    test.check("nor where the text falls back", rates(20920, command:format("145", "291")), 0)
    test.check("a spell that lands as cast keeps its rates", rates(20473,
        "Blasts the target with Holy energy, causing 277 to 299 Holy damage to an enemy, or 365 to 395 healing to an ally."), 2)

    test.check("an amount that gains nothing beside one that does", rows(20924,
        "Consecrates the land beneath the Paladin, doing 384 Holy damage over 8 sec to enemies who enter the area. "
        .. "The first 4 enemies who enter the area will take an additional 120 damage over 8 sec."),
        { "Spell Power Coefficient | 0.0% · 384 + 0", "Extra to the first targets | 33.6% · 87 + 33" })

    local righteousness = "Fills the Paladin with holy spirit for 30 sec, granting each melee attack an additional "
        .. "24 to 82 Holy damage.  Slower weapons cause more Holy damage per swing.  Only one Seal can be active on the "
        .. "Paladin at any one time.\n\nUnleashing this Seal's energy will cause 98 to 109 Holy damage to an enemy."
    test.check("a talent's rank: none", rows(20293, righteousness), { "Per swing, fast weapon | 7.9% · 17 + 7",
        "Per swing, slow weapon | 12.8% · 70 + 12", "Judgement | 42.9% · 56 to 67 + 42" })
    rank = 2
    test.check("a talent's rank: the second", rows(20293, righteousness), { "Per swing, fast weapon | 8.4% · 16 + 8",
        "Per swing, slow weapon | 13.6% · 69 + 13", "Judgement | 42.9% · 56 to 67 + 42" })
    rank = 0

    local frostbolt = "Launches a bolt of frost at the enemy, causing 62 to 68 Frost damage and slowing movement speed "
        .. "by 40% for 6 sec."
    test.check("a talent known by its rank's spell: none", rows(837, frostbolt),
        { "Spell Power Coefficient | 59.7% · 3 to 9 + 59" })
    known[11151] = true
    test.check("a talent known by its rank's spell: the first", rows(837, frostbolt),
        { "Spell Power Coefficient | 60.9% · 2 to 8 + 60" })
    known[11151] = nil

    test.check("an effect no number prints: its bonus alone", rows(1277462,
        "Place a Holy ward on an ally for 30 sec. The next time this ally takes damage dropping their Health below 30%, "
        .. "they will gain a shield absorbing 120 damage and begin healing for 0 Health over 15 sec. A target may be "
        .. "affected by only one Contingency Plan."), { "Healing Power Coefficient over time | 20.0% · +40 each" })

    test.check("a rank whose scaling is not shown yet has no rows", rows(53,
        "Backstab the target, causing 150% weapon damage plus 15 to the target. Must be behind the target."), {})
end
