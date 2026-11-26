-- A set's bonuses stay with the set: the game drops an active bonus's count
-- ("Set: +8 All Resistances."), which is known again when the pieces worn
-- leave no doubt, and left out when they do. Lightforge Gauntlets as the game
-- shows them, from /ptip dump.
return function(test)
    local LINE = { None = 0, ItemName = 1, DisabledLine = 2 }
    local WHITE, GOLD, GREY = { r = 1, g = 1, b = 1, a = 1 }, { r = 1, g = .82, b = 0, a = 1 }, { r = .5, g = .5, b = .5, a = 1 }
    local SET, GREEN, BLUE = { r = 1, g = 1, b = .59, a = 1 }, { r = 0, g = 1, b = 0, a = 1 }, { r = 0, g = .44, b = .87, a = 1 }

    -- Each line { text, color, type }.
    local function read(lines)
        local capture = { client = { locale = "enUS" },
            enums = { TooltipDataType = { Item = 0 }, TooltipDataLineType = LINE },
            calls = { UnitLevel = { player = { n = 1, 60 } } },
            data = { type = 0, id = 16724, quality = 3, lines = {} }, lines = {} }
        for index, line in ipairs(lines) do
            capture.data.lines[index] = { type = line[3] or (index == 1 and LINE.ItemName or LINE.None), lineIndex = index,
                leftText = line[1], leftColor = line[2] }
            capture.lines[index] = { left = { text = line[1] } }
        end
        local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
            "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
            "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua", "Tooltips/Item.lua" }, capture)
        return ns.TooltipTypes[0].read(world.main, capture.data, ns.Game), ns
    end

    local function bonuses(ns, model)
        local out = {}
        for index, bonus in ipairs(model.setBonuses) do
            out[index] = { bonus.pieces or false, ns.util.plainText(bonus.text), bonus.active }
        end
        return out
    end

    local function gauntlets(worn, active, inactive)
        local lines = {
            { "Lightforge Gauntlets", BLUE }, { "Soulbound", WHITE }, { "386 Armor", WHITE }, { "+14 Strength", WHITE },
            { " ", GOLD }, { "Lightforge Armor (" .. worn .. "/8)", GOLD },
            { "  Lightforge Belt", SET }, { "  Lightforge Boots", GREY, LINE.DisabledLine },
            { "  Lightforge Bracers", GREY, LINE.DisabledLine }, { "  Lightforge Breastplate", GREY, LINE.DisabledLine },
            { "  Lightforge Gauntlets", SET }, { "  Lightforge Legplates", GREY, LINE.DisabledLine },
            { "  Lightforge Spaulders", GREY, LINE.DisabledLine }, { "  Lightforge Helm", GREY, LINE.DisabledLine },
            { " ", GOLD },
        }
        for _, text in ipairs(active) do lines[#lines + 1] = { "Set: " .. text, GREEN } end
        for _, bonus in ipairs(inactive) do
            lines[#lines + 1] = { "(" .. bonus[1] .. ") Set: " .. bonus[2], GREY, LINE.DisabledLine }
        end
        lines[#lines + 1] = { " ", GOLD }
        lines[#lines + 1] = { "Durability 45 / 45", WHITE }
        lines[#lines + 1] = { "Requires Level 54", WHITE }
        return lines
    end

    local INACTIVE = {
        { 3, "Increases damage and healing done by magical spells and effects by up to 18." },
        { 4, "When struck by a harmful spell, has a 7% chance of Silencing the caster for 3 sec. Can only occur once every 60 sec." },
        { 5, "Chance on melee autoattack and spellcast to increase your damage and healing done by magical spells and effects by up to 65 for 10 sec." },
        { 6, "Restores 8 mana per 5 sec." },
    }
    local model, ns = read(gauntlets(2, { "+8 All Resistances." }, INACTIVE))
    test.check("an active bonus stays with the set, its count known from the pieces worn", bonuses(ns, model), {
        { 2, "+8 All Resistances.", true },
        { 3, INACTIVE[1][2], false },
        { 4, INACTIVE[2][2], false },
        { 5, INACTIVE[3][2], false },
        { 6, INACTIVE[4][2], false },
    })
    test.check("nothing of the set spills into other addons' rows", #model.extras, 0)

    model, ns = read(gauntlets(4, { "+8 All Resistances.", "Increases damage and healing done by magical spells and effects by up to 18.",
        "When struck by a harmful spell, has a 7% chance of Silencing the caster for 3 sec. Can only occur once every 60 sec." },
        { INACTIVE[3], INACTIVE[4] }))
    test.check("every count from two to the pieces worn is active", bonuses(ns, model)[3], { 4, INACTIVE[2][2], true })

    model, ns = read(gauntlets(5, { "+8 All Resistances.", "Restores 8 mana per 5 sec." }, { { 6, "Something more." } }))
    test.check("an active bonus whose count is in doubt keeps none",
        { bonuses(ns, model)[1][1], bonuses(ns, model)[2][1], bonuses(ns, model)[3][1] }, { false, false, 6 })
end
