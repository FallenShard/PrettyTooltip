-- Spell power coefficients and the base and spell power split, against values
-- checked in game (30 spell damage) and on foreverchanges.pro.
return function(test)
    local calls = { GetSpellBonusDamage = {}, GetSpellBonusHealing = { [""] = { n = 1, 300 } } }
    for school = 1, 7 do calls.GetSpellBonusDamage[tostring(school)] = { n = 1, 30 } end
    local ns = test.load({ "Core/Util.lua", "Data/Coefficients.lua" }, { calls = calls })

    local function rows(name, cast, text, spellID)
        local found = ns.spellPowerRows({ name = name, cast = { cast, "Cast" }, description = { text },
            spellID = spellID }, "FFFFFF")
        if not found then return "none" end
        local out = {}
        for _, row in ipairs(found) do out[#out + 1] = row.left .. " | " .. row.right:gsub("|cffFFFFFF", ""):gsub("|r", "") end
        return table.concat(out, "\n")
    end

    -- In game: rank 3, 2.2 sec shown as 1.7 with Improved Frostbolt, 62 to 68 at 30 spell damage, base 45 to 51.
    test.check("Frostbolt rank 3, talented", rows("Frostbolt", "1.7 sec",
        "Launches a bolt of frost at the enemy, causing 62 to 68 Frost damage and slowing movement speed by 40% for 6 sec.",
        837), "59.7% Coefficient | 45 to 51 + 17")
    -- In game: 66 to 83 at 30 spell damage; the burn does not scale.
    test.check("Fireball rank 3", rows("Fireball", "2.5 sec",
        "Hurls a fiery ball that causes 66 to 83 Fire damage and an additional 6 Fire damage over 6 sec.", 145),
        "71.4% Coefficient | 45 to 62 + 21\n0.0% Coefficient over time | 6 + 0")
    -- In game: rank 1, 39 to 48 at 30 spell damage; no penalty below level 20.
    test.check("Fire Blast rank 1", rows("Fire Blast", "Instant", "Blasts the enemy for 39 to 48 Fire damage.", 2136),
        "42.9% Coefficient | 27 to 36 + 12")
    -- foreverchanges.pro: 20% a tick, six ticks; no cap over 100%.
    test.check("Shadow Word: Pain", rows("Shadow Word: Pain", "Instant",
        "A word of darkness that causes 30 Shadow damage over 18 sec."), "120.0% Coefficient over time | 0 + 36")
    -- foreverchanges.pro: 28.6% at once, 7.1% a tick for seven ticks.
    test.check("Regrowth", rows("Regrowth", "2 sec", "Heals a friendly target for 89 to 103 and another 91 over 21 sec."),
        "28.6% Coefficient | 4 to 18 + 85\n50.0% Coefficient over time | 0 + 150")
    test.check("Holy Light rank 5", rows("Holy Light", "2.5 sec", "Heals a friendly target for 425 to 479.", 1042),
        "71.4% Coefficient | 211 to 265 + 214")
    test.check("an unknown spell is an estimate", rows("Mystery Bolt", "2.5 sec",
        "Hits the target for 221 to 261 Shadow damage."), "~71.4% Coefficient | 200 to 240 + 21")
    test.check("an unknown channeled spell shows nothing", rows("Arcane Missiles", "Channeled",
        "Launches Arcane Missiles at the enemy, causing 230 Arcane damage each second for 5 sec."), "none")
    test.check("a physical ability shows nothing", rows("Shield Bash", "Instant",
        "Bashes the target with your shield for 8 damage."), "none")
end
