-- Reading text the game printed from its own strings, in each language the
-- client comes in, with the strings that language's client defines.
return function(test)
    local function read(locale)
        local ns, world = test.load({ "Core/Util.lua" }, { client = { locale = locale } })
        return ns.util, world
    end
    local function all(...) return { n = select("#", ...), ... } end

    local util, world = read("enUS")
    local unformat = util.unformat
    test.check("the strings load in the fixture's language", ITEM_MIN_LEVEL, "Requires Level %d")
    test.check("a number", all(unformat("Requires Level 40", ITEM_MIN_LEVEL)), { n = 1, "40" })
    test.check("two numbers", all(unformat("Durability 34 / 100", DURABILITY_TEMPLATE)), { n = 2, "34", "100" })
    test.check("other text is not read", unformat("Requires Level 40 Mining", ITEM_MIN_LEVEL), nil)
    test.check("a string with nothing to fill matches as true", unformat("Soulbound", ITEM_SOULBOUND), true)
    test.check("the space around the text does not count", unformat("  Soulbound ", ITEM_SOULBOUND), true)
    test.check("a sign and an amount", all(unformat("+10 Stamina", ITEM_MOD_STAMINA)), { n = 2, "+", "10" })
    test.check("a number with a group separator", all(unformat("1,234 Armor", ARMOR_TEMPLATE)), { n = 1, "1,234" })
    -- ITEM_CREATED_BY is green: the text reads with its color or without it.
    test.check("the string's color code", unformat("|cff00ff00<Made by Thrall>|r", ITEM_CREATED_BY), "Thrall")
    test.check("text without the color", unformat("<Made by Thrall>", ITEM_CREATED_BY), "Thrall")
    test.check("a number that ends a sentence", unformat(
        "Equip: Increases damage and healing done by magical spells and effects by up to 23.",
        TOOLTIP_ITEM_STAT_SPELL_POWER_INCREASE), "23")
    test.check("not a string", unformat(nil, ITEM_MIN_LEVEL), nil)
    test.check("the separators", { DECIMAL_SEPERATOR, LARGE_NUMBER_SEPERATOR }, { ".", "," })

    -- Every string the addon names must compile, in every language.
    local function compiles(locale, strings)
        local failed = {}
        for name, value in pairs(strings) do
            if not pcall(util.unformat, "x", value) then failed[#failed + 1] = name end
        end
        table.sort(failed)
        test.check(locale .. ": every string compiles", failed, {})
    end
    compiles("enUS", world.gameStrings)

    util, world = read("deDE")
    unformat = util.unformat
    compiles("deDE", world.gameStrings)
    test.check("deDE: arguments by position", all(unformat("Haltbarkeit 34 / 100", DURABILITY_TEMPLATE)),
        { n = 2, "34", "100" })
    test.check("deDE: a school joined to its word", all(unformat("12 - 20 Feuerschaden", DAMAGE_TEMPLATE_WITH_SCHOOL)),
        { n = 3, "12", "20", "Feuer" })
    test.check("deDE: a decimal comma", unformat("Wirken in 1,5 Sek.", SPELL_CAST_TIME_SEC), "1,5")
    test.check("deDE: the plural", unformat("2 Stunden Abklingzeit", SPELL_RECAST_TIME_HOURS), "2")
    test.check("deDE: the singular", unformat("1 Stunde Abklingzeit", SPELL_RECAST_TIME_HOURS), "1")
    test.check("deDE: letters outside ASCII", unformat("Benötigt Stufe 40", ITEM_MIN_LEVEL), "40")
    test.check("deDE: the separators", { DECIMAL_SEPERATOR, LARGE_NUMBER_SEPERATOR }, { ",", "." })

    util, world = read("frFR")
    unformat = util.unformat
    compiles("frFR", world.gameStrings)
    test.check("frFR: arguments in another order", all(unformat("Sac en cuir 16 emplacements", CONTAINER_SLOTS)),
        { n = 2, "16", "Sac en cuir" })
    test.check("frFR: the school first", all(unformat("Dégâts (Feu) : 12 - 20", DAMAGE_TEMPLATE_WITH_SCHOOL)),
        { n = 3, "12", "20", "Feu" })
    -- The string has a no-break space; text with either space reads.
    test.check("frFR: a no-break space", all(unformat("+10\194\160Endurance", ITEM_MOD_STAMINA)), { n = 2, "+", "10" })
    test.check("frFR: a plain space for it", all(unformat("+10 Endurance", ITEM_MOD_STAMINA)), { n = 2, "+", "10" })
    test.check("frFR: de before a consonant", unformat("Pas assez de Badges", NOT_ENOUGH_CURRENCY), "Badges")
    test.check("frFR: d' before a vowel", unformat("Pas assez d'Insignes", NOT_ENOUGH_CURRENCY), "Insignes")
    test.check("frFR: no group separator", LARGE_NUMBER_SEPERATOR, "")

    util, world = read("koKR")
    unformat = util.unformat
    compiles("koKR", world.gameStrings)
    test.check("koKR: the amount after the stat", all(unformat("체력 +10", ITEM_MOD_STAMINA)), { n = 2, "+", "10" })
    test.check("koKR: the third argument first", all(unformat("화염 저항력 +10", ITEM_RESIST_SINGLE)),
        { n = 3, "+", "10", "화염" })
    -- |1 picks the particle by the word before it.
    test.check("koKR: one particle", all(unformat("고블린으로부터 10미터 안에 있는 적 대상", SPELL_TARGET_MULTIPLE_TEMPLATE)),
        { n = 3, "적", "10", "고블린" })
    test.check("koKR: the other particle", all(unformat("나무로부터 10미터 안에 있는 적 대상", SPELL_TARGET_MULTIPLE_TEMPLATE)),
        { n = 3, "적", "10", "나무" })

    util, world = read("zhCN")
    unformat = util.unformat
    compiles("zhCN", world.gameStrings)
    test.check("zhCN: no spaces", all(unformat("需要锻造（225）", ITEM_MIN_SKILL)), { n = 2, "锻造", "225" })

    util, world = read("zhTW")
    unformat = util.unformat
    compiles("zhTW", world.gameStrings)
    test.check("zhTW: the number inside the words", unformat("施法時間1.5秒", SPELL_CAST_TIME_SEC), "1.5")

    -- Numbers as each client prints them, and as Lua prints them on any client.
    local parse = util.parseNumber
    test.check("a group separator", parse("1,234", ","), 1234)
    test.check("groups and a decimal", parse("1,234,567.5", ","), 1234567.5)
    test.check("enUS: a decimal", parse("1.5", ","), 1.5)
    test.check("deDE: groups and a decimal comma", parse("1.234,5", "."), 1234.5)
    test.check("deDE: a decimal comma", parse("1,5", "."), 1.5)
    test.check("deDE: a point Lua printed", parse("1.5", "."), 1.5)
    test.check("deDE: a group", parse("1.234", "."), 1234)
    test.check("frFR: no groups", parse("1234,5", ""), 1234.5)
    test.check("a sign", parse("-3", ","), -3)
    test.check("not a number", parse("12 sec", ","), nil)
end
