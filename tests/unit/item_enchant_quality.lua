
-- Profession crafting-quality atlas handling on permanent enchant rows
-- and untyped enchant-copy rows, including Chinese conjunction localization.
return function(test)
    local ITEM = 0
    local LINE = { None = 0, ItemName = 22, ItemEnchantmentPermanent = 15 }

    local function read(locale, text, lineType)
        local capture = {
            client = { locale = locale },
            enums = {
                TooltipDataType = { Item = ITEM },
                TooltipDataLineType = LINE,
            },
            data = {
                type = ITEM,
                id = 3000,
                quality = 4,
                lines = {
                    { type = LINE.ItemName, lineIndex = 1, leftText = "Test Weapon" },
                    { type = lineType or LINE.ItemEnchantmentPermanent,
                        lineIndex = 2, leftText = text },
                },
            },
            lines = {
                { left = { text = "Test Weapon" } },
                { left = { text = text } },
            },
        }

        local ns, world = test.load(test.retail({
            "Core/Util.lua",
            "Core/Palette.lua",
            "Core/Settings.lua",
            "Locale/Locale.lua",
            "Locale/English.lua",
            "Locale/zhCN.lua",
            "Locale/zhTW.lua",
            "Game/Game.lua",
            "Game/TooltipData.lua",
            "Data/Stats.lua",
            "Panel/Layout.lua",
            "Panel/Render.lua",
            "Tooltips/Item.lua",
        }), capture)

        PrettyTooltipDB = {}

        return ns.TooltipTypes[ITEM].read(world.main, capture.data, ns.Game), ns
    end

    local function rowText(ns, model)
        local result = {}
        for _, row in ipairs(model.enchants or {}) do
            result[#result + 1] = ns.util.trim(ns.util.plainText(row.left))
        end
        return table.concat(result, " | ")
    end

    local function rawRows(model)
        local result = {}
        for _, row in ipairs(model.enchants or {}) do
            result[#result + 1] = row.left
        end
        return table.concat(result, " ")
    end

    local full = "Professions-ChatIcon-Quality-Tier1:16:16:0:0"
    local short = "Professions-ChatIcon-Quality-Tier1:16:16"
    local expectedIcon = "|A:Professions-ChatIcon-Quality-Tier1:16:16:0:0|a"

    -- 1. Already formatted atlas.
    local model, ns = read("enUS",
        "Enchanted: Crusader |A:" .. full .. "|a")

    local formattedText = rowText(ns, model)
    test.check("formatted atlas: enchant text is preserved",
        formattedText, "Crusader")

    test.check("formatted atlas: vertical alignment is adjusted",
        rawRows(model):find(expectedIcon, 1, true) ~= nil,
        true)

    -- 2. Bare full payload.
    model, ns = read("enUS", "Enchanted: Crusader " .. full)

    local bareFullText = rowText(ns, model)
    test.check("bare full payload: enchant text is preserved",
        bareFullText, "Crusader")

    test.check("bare full payload: atlas is restored",
        rawRows(model):find(expectedIcon, 1, true) ~= nil, true)

    -- 3. Short payload.
    model, ns = read("enUS", "Enchanted: Crusader " .. short .. "!")

    local shortText = rowText(ns, model)
    test.check("short payload: enchant text is preserved",
        shortText, "Crusader")

    test.check("short payload: missing atlas fields are completed",
        rawRows(model):find("|A:" .. short .. ":0:0|a", 1, true) ~= nil,
        true)

    -- 4. Normalization is idempotent.
    local normalized = ns.normalizeProfessionQualityAtlas(expectedIcon)
    test.check("existing atlas is not converted twice", normalized, expectedIcon)

    -- 5. Ordinary enchantments remain unchanged.
    model, ns = read("enUS", "Enchanted: Crusader")

    test.check("ordinary enchantment remains unchanged",
        rowText(ns, model), "Crusader")

    test.check("ordinary enchantment has no quality atlas",
        rawRows(model):find("|A:Professions%-ChatIcon%-Quality%-", 1) == nil,
        true)

    -- 6. Untyped enchant-copy path.
    model, ns = read("enUS", "Enchanted: Crusader " .. full, LINE.None)

    local untypedText = rowText(ns, model)
    test.check("untyped enchant-copy row is recognized",
        untypedText, "Crusader")

    test.check("untyped enchant-copy row retains quality atlas",
        rawRows(model):find(expectedIcon, 1, true) ~= nil, true)

    -- 7. Simplified Chinese conjunction.
    model, ns = read("zhCN",
        "Enchanted: Strength +2 & Armor +16")

    local cnText = rowText(ns, model)
    test.check("zhCN: conjunction is localized",
        cnText:find("和", 1, true) ~= nil
            and cnText:find("&", 1, true) == nil,
        true)

    -- 8. Traditional Chinese conjunction.
    model, ns = read("zhTW",
        "Enchanted: Strength +2 & Armor +16")

    local twText = rowText(ns, model)
    test.check("zhTW: conjunction is localized",
        twText:find("和", 1, true) ~= nil
            and twText:find("&", 1, true) == nil,
        true)

    -- 9. English conjunction is preserved.
    model, ns = read("enUS",
        "Enchanted: Strength +2 & Armor +16")

    local enText = rowText(ns, model)
    test.check("enUS: original conjunction is preserved",
        enText:find("&", 1, true) ~= nil
            and enText:find("和", 1, true) == nil,
        true)
end
