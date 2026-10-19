-- Text handling that holds for every language the client comes in: sentences,
-- capitals, and how long a line reads.
return function(test)
    local ns = test.load({ "Core/Util.lua" })
    local util = ns.util

    test.check("sentences end before a capital", util.splitSentences("Deals 10 damage. Lasts 1.5 sec."),
        { "Deals 10 damage.", "Lasts 1.5 sec." })
    test.check("a decimal stays whole", util.splitSentences("Lasts 1.5 sec. Then fades."),
        { "Lasts 1.5 sec.", "Then fades." })
    test.check("a capital outside ASCII", util.splitSentences("Verursacht 10 Schaden. \195\156berzieht den Feind."),
        { "Verursacht 10 Schaden.", "\195\156berzieht den Feind." })
    test.check("a lower case word does not start one", util.splitSentences("Lasts 5 sec. and more."),
        { "Lasts 5 sec. and more." })
    -- 造成10点伤害。持续5秒。
    test.check("Chinese full stops, without a space",
        util.splitSentences("\233\128\160\230\136\14810\231\130\185\228\188\164\229\174\179\227\128\130"
            .. "\230\140\129\231\187\1735\231\167\146\227\128\130"),
        { "\233\128\160\230\136\14810\231\130\185\228\188\164\229\174\179\227\128\130",
            "\230\140\129\231\187\1735\231\167\146\227\128\130" })

    test.check("capitals for ASCII", util.upper("Fireball"), "FIREBALL")
    test.check("capitals for accented letters", util.upper("D\195\169g\195\162ts \195\160 l'\197\147il"),
        "D\195\137G\195\130TS \195\128 L'\197\146IL")
    test.check("German sharp s stays", util.upper("Gro\195\159"), "GRO\195\159")
    test.check("Korean has no capitals", util.upper("\236\178\180\235\160\165"), "\236\178\180\235\160\165")

    test.check("width of ASCII", util.width("Fireball"), 8)
    test.check("an accented letter is one", util.width("D\195\169g\195\162ts"), 6)
    test.check("a Korean character is two", util.width("\236\178\180\235\160\165"), 4)

    -- An enchant's name lists its stats; each takes its own row.
    ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Panel/Layout.lua" }, { enums = { TooltipDataType = { Item = 0 } } })
    local function plain(rows)
        local out = {}
        for index, row in ipairs(rows) do out[index] = ns.util.plainText(row) end
        return out
    end
    test.check("an enchant's stats", plain(ns.ui.enchantRows("Stamina +2 and Armor +16")), { "+2 Stamina", "+16 Armor" })
    test.check("a list of three", plain(ns.ui.enchantRows("Strength +1, Agility +1, and Stamina +1")),
        { "+1 Strength", "+1 Agility", "+1 Stamina" })
    test.check("a name without stats stays whole", plain(ns.ui.enchantRows("Crusader")), { "Crusader" })
end
