-- Stats are read by the game's own wordings in the client's language, into a
-- stat and its amount, and printed again as the game prints a stat, in that
-- language's order and words.
return function(test)
    local function load(locale)
        local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Locale/Locale.lua", "Locale/English.lua",
            "Data/Stats.lua" }, { client = { locale = locale } })
        return ns.Stats
    end
    local function key(stat) return stat and { stat.key, stat.sign, stat.amount, stat.school } end

    local stats = load("enUS")
    test.check("enUS: a rating in the game's words", stats.rewrite("Equip: Increases your hit by 10."),
        { "+10 Hit Rating" })
    test.check("enUS: attack power against a creature type, in the game's words",
        stats.rewrite("Equip: +15 Attack Power against Mechanical units."), { "+15 Attack Power vs Mechanical" })
    test.check("enUS: a school's spell damage", stats.rewrite(
        "Equip: Increases damage done by Fire spells and effects by up to 20."), { "+20 Fire Spell Damage Power" })
    test.check("enUS: a chance in percent", stats.rewrite("Equip: Improves your chance to hit by 1%."),
        { "+1% Hit Chance" })
    test.check("enUS: a resistance line", key(stats.read("+5 Fire Resistance")), { "RESISTANCE", "+", "5", "Fire" })
    test.check("enUS: all resistances, as the game words them", key(stats.read("+5 to All Resistances")),
        { "ALL_RESISTANCES", "+", "5" })
    test.check("enUS: a group separator", key(stats.read("+1,200 Armor")), { "ARMOR", "+", "1200" })
    test.check("enUS: an unknown stat", stats.read("+6 Unknown"), nil)
    test.check("enUS: a primary stat colored", select(2, stats.styleStat("+10 Stamina", true, false)),
        "|cffE9DDC4+10|r |cffEEE7DAStamina|r")

    stats = load("deDE")
    test.check("deDE: a stat line", key(stats.read("+10 Ausdauer")), { "STAMINA", "+", "10" })
    test.check("deDE: a resistance joined to its school", key(stats.read("+5 Feuerwiderstand")),
        { "RESISTANCE", "+", "5", "Fire" })
    test.check("deDE: spell power", stats.rewrite(
        "Anlegen: Erh\195\182ht durch magische Zauber und Effekte verursachten Schaden und Heilung um bis zu 23."),
        { "+23 Zaubermacht" })
    test.check("deDE: healing and damage, in their order", stats.rewrite("Anlegen: Erh\195\182ht durch s\195\164mtliche"
        .. " Zauber und magische Effekte verursachte Heilung um bis zu 20 und den verursachten Schaden um bis zu 10."),
        { "+20 Healing Power", "+10 Spell Damage Power" })
    test.check("deDE: a decimal comma, not a group", key(stats.read("+1,5% Ausdauer")), { "STAMINA", "+", "1,5" })
    test.check("deDE: school damage colored", stats.styleDamage("64 - 120 Schattenschaden", true),
        "|cffC174FF64 - 120|r |cffC9A2EESchattenschaden|r")

    stats = load("frFR")
    test.check("frFR: spell power after the label with a no-break space", stats.rewrite(
        "\195\137quip\195\169\194\160: augmente les d\195\169g\195\162ts et les soins des sorts et effets magiques de"
        .. " 23 au maximum."), { "+23 Puissance des sorts" })
    test.check("frFR: school damage, the value last", stats.styleDamage("D\195\169g\195\162ts (Ombre) : 64 - 120", true),
        "|cffC9A2EED\195\169g\195\162ts (Ombre) :|r |cffC174FF64 - 120|r")

    stats = load("koKR")
    test.check("koKR: the name before the value", key(stats.read("\236\178\180\235\160\165 +10")),
        { "STAMINA", "+", "10" })
    test.check("koKR: printed in that order", stats.text({ key = "STAMINA", sign = "+", amount = "10" }),
        "\236\178\180\235\160\165 +10")
    test.check("koKR: colored in that order", select(2, stats.styleStat("\236\178\180\235\160\165 +10", true, false)),
        "|cffEEE7DA\236\178\180\235\160\165|r |cffE9DDC4+10|r")
end
