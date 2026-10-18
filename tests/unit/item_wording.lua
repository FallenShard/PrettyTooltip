-- Item lines the client leaves untyped are read by their wording, which is the
-- game's own strings in the client's language: a crafted weapon, a set piece,
-- a bag, and a recipe, each line taking the branch only its wording leads to.
return function(test)
    local LINE = { None = 0, ItemName = 1 }

    -- The item's model from its lines: each a left text, or { left, right },
    -- the first the item's name.
    local function read(locale, lines)
        local capture = { client = { locale = locale },
            enums = { TooltipDataType = { Item = 0 }, TooltipDataLineType = LINE },
            calls = { UnitLevel = { player = { n = 1, 30 } } },
            data = { type = 0, id = 2000, quality = 2, lines = {} }, lines = {} }
        for index, line in ipairs(lines) do
            local left, right = line, nil
            if type(line) == "table" then left, right = line[1], line[2] end
            local kind = (index == 1 or left:find("^\n")) and LINE.ItemName or LINE.None
            capture.data.lines[index] = { type = kind, lineIndex = index, leftText = left, rightText = right }
            capture.lines[index] = { left = { text = left }, right = right and { text = right } }
        end
        local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
            "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
            "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua", "Tooltips/Item.lua" }, capture)
        return ns.TooltipTypes[0].read(world.main, capture.data, ns.Game), ns
    end

    local function lefts(ns, rows)
        local out = {}
        for index, row in ipairs(rows or {}) do out[index] = ns.util.plainText(row.left) end
        return out
    end

    -- What the wording decided, line by line.
    local function summary(model, ns)
        return {
            header = lefts(ns, model.header),
            weapon = { model.weaponDamage, model.weaponSpeed, model.weaponDps, model.weaponBonus[1] },
            armor = model.armor[1] and model.armor[1].value,
            durability = model.footerLeft[1] and model.footerLeft[1].durability,
            footerLeft = lefts(ns, model.footerLeft),
            level = model.levelRequirement and { model.levelRequirement.text, model.levelRequirement.met },
            footerRight = lefts(ns, model.footerRight),
            onHit = { lefts(ns, model.equipEffects)[1], model.equipEffects[1] and model.equipEffects[1].onHit },
            equip = lefts(ns, model.equipEffects)[2],
            use = { lefts(ns, model.effects)[1], model.effects[1] and model.effects[1].use },
            enchants = lefts(ns, model.enchants),
            madeBy = model.madeBy,
            quest = { model.quest, model.startsQuest },
            flavor = lefts(ns, model.flavor),
            extras = lefts(ns, model.extras),
            set = { model.setName, model.setCount, lefts(ns, model.setItems), lefts(ns, model.setBonuses) },
        }
    end

    local model, ns = read("enUS", {
        "Gleaming Claymore",
        "Soulbound",
        "Unique",
        "This Item Begins a Quest",
        { "41 - 77 Damage", "Speed 3.20" },
        "+5 - 7 Fire Damage",
        "(18.4 damage per second)",
        "1,234 Armor",
        "Durability 34 / 100",
        "Classes: Warrior",
        "Requires Level 40",
        "Requires Thorium Brotherhood - Friendly",
        "Chance on hit: Sends a shadowy bolt at the enemy.",
        "Equip: Improves your chance to hit by 1%.",
        "Use: Restores 100 health.",
        "Enchanted: Crusader",
        "<Made by Thrall>",
        '"Forged in the depths."',
        "If you replace this item, the following stat changes will occur:",
        "+5 Stamina",
        "Defias Leather (2/5)",
        "Defias Leather Vest",
        "Defias Leather Gloves",
        "(3) Set: +10 Attack Power.",
    })
    test.check("enUS: a crafted set weapon", summary(model, ns), {
        header = { "Soulbound", "Unique" },
        weapon = { "41 - 77 Damage", "Speed 3.20", "18.4", "+5 - 7 Fire Damage" },
        armor = "1234",
        durability = { 34, 100 },
        footerLeft = { "Durability 34 / 100", "Made by Thrall", "Classes: Warrior" },
        level = { "Requires Level 40", false },
        footerRight = { "Requires Thorium Brotherhood - Friendly" },
        onHit = { "Sends a shadowy bolt at the enemy.", true },
        equip = "Improves your chance to hit by 1%.",
        use = { "Restores 100 health.", true },
        enchants = { "Crusader" },
        madeBy = "Thrall",
        quest = { true, "This Item Begins a Quest" },
        flavor = { '"Forged in the depths."' },
        extras = { "If you replace this item, the following stat changes will occur:", "+5 Stamina" },
        set = { "Defias Leather", "2/5", { "Defias Leather Vest", "Defias Leather Gloves" },
            { "(3) Set: +10 Attack Power." } },
    })

    model, ns = read("enUS", { "Heavy Brown Bag", "Quest Item", "16 Slot Bag", "Crafting Reagent" })
    test.check("enUS: a bag's slots and kind", { model.bag, model.quest, model.slot },
        { { count = 16, kind = "Bag" }, true, "Crafting Reagent \194\183 Bag \194\183 16 Slots" })

    model, ns = read("enUS", {
        "Plans: Copper Chain Belt",
        "Requires Blacksmithing (35)",
        "Use: Teaches you how to make a Copper Chain Belt.",
        "\nCopper Chain Belt",
        "Binds when equipped",
        "Requires Copper Bar (6), Linen Cloth (2)",
    })
    local reagents = {}
    for index, reagent in ipairs(model.reagents or {}) do reagents[index] = { reagent.name, reagent.count } end
    test.check("enUS: a recipe", {
        skill = model.skill and { model.skill.name, model.skill.level },
        teaches = model.teaches and model.teaches.left,
        created = model.created and { model.created.name, model.created.binding },
        reagents = reagents,
        slot = model.slot,
        level = model.levelRequirement and model.levelRequirement.text,
    }, {
        skill = { "Blacksmithing", 35 },
        teaches = "Use: Teaches you how to make a Copper Chain Belt.",
        created = { "Copper Chain Belt", "Binds when equipped" },
        reagents = { { "Copper Bar", 6 }, { "Linen Cloth", 2 } },
        slot = "Plans \194\183 Blacksmithing",
        level = "Requires Blacksmithing 35",
    })
end
