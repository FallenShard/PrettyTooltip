-- A shield's block, as the game prints it ("11 Block"), follows its armor on
-- the same line, "547 Armor · 11 Block", colored as the armor is. Not a row
-- at the bottom.
return function(test)
    local FILES = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua",
        "Panel/Render.lua", "Tooltips/Item.lua" }

    local function shield(locale, lines)
        local capture = { client = locale and { locale = locale },
            enums = { TooltipDataType = { Item = 0 }, TooltipDataLineType = { None = 0, ItemName = 1 } },
            data = { type = 0, id = 2000, quality = 2, lines = {} }, lines = {} }
        for index, line in ipairs(lines) do
            local left, right = line, nil
            if type(line) == "table" then left, right = line[1], line[2] end
            capture.data.lines[index] = { type = index == 1 and 1 or 0, lineIndex = index, leftText = left,
                rightText = right }
            capture.lines[index] = { left = { text = left }, right = right and { text = right } }
        end
        local files = FILES
        if locale then
            files = { unpack(FILES) }
            table.insert(files, 6, "Locale/" .. locale .. ".lua")
        end
        local ns, world = test.load(files, capture)
        return ns.TooltipTypes[0].read(world.main, capture.data, ns.Game), ns
    end
    -- Rows at the bottom that hold the block; the slot line lands there too in these tests.
    local function blockExtras(model, word)
        local count = 0
        for _, row in ipairs(model.extras) do
            if row.left:find(word, 1, true) then count = count + 1 end
        end
        return count
    end
    -- The lines holding a word, as drawn from the top: text and size.
    local function drawn(ns, model, words)
        local panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), model, 0)
        local out = {}
        for _, font in ipairs(panel.pool) do
            local text = font:IsShown() and font:GetText() or ""
            for _, word in ipairs(words) do
                if ns.util.uncolored(text):find(word, 1, true) then
                    out[#out + 1] = { text, (select(2, font:GetFont())) }
                end
            end
        end
        return out
    end

    local model, ns = shield(nil, { "Mirror of Rath'mael", "Binds when picked up", { "Off Hand", "Shield" },
        "547 Armor", "11 Block", "+5 Strength", "+1.0% Block Chance", "Requires Level 19" })
    test.check("enUS: the block is read beside the armor", { model.block, model.blockValue }, { "11 Block", "11" })
    test.check("enUS: not a stat, nor a row at the bottom", { #model.primary, blockExtras(model, "11 Block") }, { 1, 0 })
    test.check("enUS: one line, the armor and then the block, in the armor's colors", drawn(ns, model, { "11 Block" }),
        { { "|cffF2E8D5547|r |cffA89F8EArmor|r  \194\183  |cffF2E8D511|r |cffA89F8EBlock|r", 16 } })

    -- French puts the word first, with a no-break space before its colon.
    local french, frNs = shield("frFR", { "Bouclier", { "Main gauche", "Bouclier" }, "Armure : 547",
        "Bloquer\194\160: 11" })
    local frLines = drawn(frNs, french, { "Bloquer" })
    test.check("frFR: the game's wording, its words dim before its number", frLines[1] and frLines[1][1],
        "|cffF2E8D5547|r |cffA89F8EArmure|r  \194\183  |cffA89F8EBloquer\194\160:|r |cffF2E8D511|r")
    local alone = shield(nil, { "Odd Shield", "11 Block" })
    test.check("without armor, the block takes the armor's line",
        { #alone.armor, alone.armor[1] and alone.armor[1].left, alone.block }, { 1, "11 Block", nil })
    local russian = shield("ruRU", { "Щит", { "Левая рука", "Щит" }, "Броня: 547", "Вероятность блока: 11" })
    test.check("ruRU: read beside the armor", { russian.blockValue, blockExtras(russian, "блока") }, { "11", 0 })
end
