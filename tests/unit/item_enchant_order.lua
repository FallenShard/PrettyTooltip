-- An item's own effects come first, then what is added to it: its enchant and
-- a temporary one. On another player's weapon the game names the temporary
-- enchant without its time left ("Windfury 4"), which still goes with the
-- enchants. Seeping Willow as an inspected weapon, from /ptip dump.
return function(test)
    local LINE = { None = 0, ItemName = 1, ItemBinding = 2, EquipSlot = 3, ItemSpellTriggerOnProc = 4,
        ItemEnchantmentPermanent = 5, UsageRequirement = 6 }
    local WHITE, GREEN, BLUE = { r = 1, g = 1, b = 1, a = 1 }, { r = 0, g = 1, b = 0, a = 1 }, { r = 0, g = .44, b = .87, a = 1 }
    local PROC = "Chance on hit: Deals 51 Nature damage every 2 sec to all enemies within an 8 yard radius of the caster for 10 sec."
    local LINES = {
        { LINE.ItemName, "Seeping Willow", BLUE },
        { LINE.ItemBinding, "Binds when picked up", WHITE },
        { LINE.EquipSlot, "Two-Hand", WHITE, "Mace" },
        { LINE.None, "155 - 233 Damage", WHITE, "Speed 3.60" },
        { LINE.None, "(53.9 damage per second)", WHITE },
        { LINE.ItemSpellTriggerOnProc, PROC, GREEN },
        { LINE.ItemEnchantmentPermanent, "Enchanted: Insight", GREEN },
        { LINE.None, "Windfury 4", GREEN },
        { LINE.UsageRequirement, "Requires Level 58", WHITE },
    }
    local capture = { client = { locale = "enUS" },
        enums = { TooltipDataType = { Item = 0 }, TooltipDataLineType = LINE },
        calls = { UnitLevel = { player = { n = 1, 60 } } },
        data = { type = 0, id = 12969, quality = 3, lines = {} }, lines = {} }
    for index, line in ipairs(LINES) do
        capture.data.lines[index] = { type = line[1], lineIndex = index, leftText = line[2], leftColor = line[3],
            rightText = line[4], rightColor = line[4] and WHITE }
        capture.lines[index] = { left = { text = line[2] }, right = line[4] and { text = line[4] } }
    end
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua",
        "Integration/Native.lua", "Integration/Placement.lua" }, capture)
    local model = ns.TooltipTypes[0].read(world.main, capture.data, ns.Game)
    local function lefts(rows)
        local out = {}
        for index, row in ipairs(rows or {}) do out[index] = ns.util.trim(ns.util.plainText(row.left)) end
        return out
    end
    test.check("the enchant and the timeless temporary one are both enchants",
        { lefts(model.enchants), lefts(model.imbues), lefts(model.extras) }, { { "Insight" }, { "Windfury 4" }, {} })

    local panel = ns.ui.getPanel(world.main)
    ns.TooltipTypes[0].render(panel, world.main, model)
    local function top(text)
        for _, font in ipairs(panel.pool) do
            if font._shown and type(font._text) == "string" and font._text:find(text, 1, true) then
                local _, _, _, _, y = font:GetPoint()
                return -y
            end
        end
    end
    local proc, insight, windfury = top("enemies within"), top("Insight"), top("Windfury 4")
    test.check("the item's own effect first, then its enchant, then the temporary one",
        { proc < insight, insight < windfury }, { true, true })
end
