-- Spell lines the client leaves untyped are read by their wording, which is
-- the game's own strings in the client's language: the strip's cost, cast,
-- cooldown, and range, and the requirement and detail lines under it.
return function(test)
    local SPELL, NAME = 1, 13
    local GOLD = { r = 1, g = .82, b = 0 }

    -- The spell's model from its lines: each a left text, or { left, right },
    -- the first the spell's name and rank.
    local function read(lines)
        local capture = { enums = { TooltipDataType = { Item = 0, Spell = SPELL },
            TooltipDataLineType = { None = 0, SpellName = NAME } },
            data = { type = SPELL, id = 72, lines = {} }, lines = {} }
        for index, line in ipairs(lines) do
            local left, right = line, nil
            if type(line) == "table" then left, right = line[1], line[2] end
            capture.data.lines[index] = { type = index == 1 and NAME or 0, lineIndex = index,
                leftText = left, rightText = right, leftColor = index == #lines and GOLD or nil }
            capture.lines[index] = { left = { text = left }, right = right and { text = right } }
        end
        local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
            "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
            "Game/TooltipData.lua", "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Spell.lua" }, capture)
        return ns.TooltipTypes[SPELL].read(world.main, capture.data, ns.Game)
    end

    local function lefts(rows)
        local out = {}
        for index, row in ipairs(rows) do out[index] = row.left end
        return out
    end

    -- What the wording decided, line by line.
    local function summary(model)
        return {
            strip = { model.cost, model.cast, model.cooldown, model.range },
            power = model.power, passive = model.passive,
            requirements = lefts(model.requirements), details = lefts(model.details),
            description = model.description, extras = lefts(model.extras),
        }
    end

    test.check("enUS: rage, an instant, melee range, and the lines under the strip", summary(read({
        { "Shield Bash", "Rank 2" },
        { "10 Rage", "Melee Range" },
        { "Instant", "12 sec cooldown" },
        "Requires Shields",
        "Cooldown remaining: 8 sec",
        "Reagents: Holy Candle",
        "Bashes the target with your shield.",
    })), {
        strip = { { "10", "Rage" }, { "Instant", "Cast" }, { "12 sec", "Cooldown" }, { "Melee", "Range" } },
        power = "Rage",
        requirements = { "Requires Shields" },
        details = { "Cooldown remaining: 8 sec", "Reagents: Holy Candle" },
        description = { "Bashes the target with your shield." },
        extras = {},
    })

    test.check("enUS: mana, a cast in seconds, a cooldown in minutes, and a range", summary(read({
        { "Flash Heal", "Rank 3" },
        { "1,125 Mana", "30 yd range" },
        { "1.5 sec cast", "1 min cooldown" },
        "Heals a friendly target.",
    })).strip, { { "1,125", "Mana" }, { "1.5 sec", "Cast" }, { "1 min", "Cooldown" }, { "30 yd", "Range" } })

    test.check("enUS: a share of base mana, a channel, and a cooldown in hours", summary(read({
        "Drain Life",
        "15% of base mana",
        { "Channeled", "1 hour cooldown" },
        "Drains life from the target.",
    })), {
        strip = { { "15%", "Base Mana" }, { "Channeled", "Cast" }, { "1 hour", "Cooldown" } },
        power = "Mana",
        requirements = {}, details = {},
        description = { "Drains life from the target." },
        extras = {},
    })

    test.check("enUS: energy, the next melee swing, and a passive", summary(read({
        "Test Strike",
        { "40 Energy", "2 day cooldown" },
        "Next melee",
        "Passive",
        "A strong attack.",
    })), {
        strip = { { "40", "Energy" }, { "Next melee", "Cast" }, { "2 days", "Cooldown" } },
        power = "Energy", passive = "Passive",
        requirements = {}, details = {},
        description = { "A strong attack." },
        extras = {},
    })

    -- A cost the game does not word is not one: it stays another line.
    test.check("enUS: words that read like a cost", summary(read({
        "Mystery",
        "Restores 50 Mana",
        "Does something.",
    })).extras, { "Restores 50 Mana" })
end
