-- Formatting and shortening need only explicit inputs, not settings or game hooks.
return function(test)
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Data/Stats.lua" },
        { client = { locale = "deDE" } })
    test.check("rules install no pre-calls", next(world.preCalls), nil)
    test.check("rules install no post-calls", next(world.postCalls), nil)
    test.check("rules do not create saved settings", PrettyTooltipDB, nil)
    test.check("rules do not depend on settings module", ns.option, nil)

    -- A contradictory DB and absent game APIs expose any hidden dependencies.
    PrettyTooltipDB = { statColors = false, statMarkers = false }
    TooltipDataProcessor, GetLocale = nil, nil
    local stats = ns.Stats
    local plain = "+6 Intellect"
    local highlighted = "|cff0CD29D+6|r |cff79DCC2Intellect|r"
    local marker = "|TInterface\\AddOns\\PrettyTooltip\\art\\stat-marker:9:9:0:-2|t  "
    local display, lite = stats.styleStat(plain, true, true)
    test.check("explicit settings control stat formatting", display, marker .. highlighted)
    test.check("lite wording has no marker", lite, highlighted)
    test.check("neutral stat formatting retains original shades", stats.styleStat(plain, false, false),
        "|cffF2E8D5+6|r |cffA89F8EIntellect|r")
    test.check("unknown stat remains untouched", stats.styleStat("+6 Unknown", true, true), "+6 Unknown")
    test.check("school stat colors retain their exact values", stats.styleDamage("64 - 120 Shadow Damage", true),
        "|cffA44EE264 - 120|r |cffC595E8Shadow Damage|r")
    test.check("explicit colors off preserves damage", stats.styleDamage("64 - 120 Shadow Damage", false),
        "64 - 120 Shadow Damage")
    test.check("proc formatting works without game or settings", stats.styleEffect("Deals 40 Fire damage.", true),
        "Deals |cffFF996040|r Fire damage.")
    -- Item effects name a school by its spells, as well as by its damage.
    test.check("an effect on a school's spells takes its tint", stats.styleEffect(
        "Increasing damage done by Fire spells and effects by up to 4.", true),
        "Increasing damage done by Fire spells and effects by up to |cffFF99604|r.")
    test.check("a school's spell damage takes its tint", stats.styleEffect("+12 Shadow spell damage.", true),
        "+|cffBF84EB12|r Shadow spell damage.")
    test.check("healing by spells names no school", stats.styleEffect(
        "Increases healing done by spells and effects by up to 20.", true),
        "Increases healing done by spells and effects by up to |cffFFF6E420|r.")
    test.check("the first school named wins", stats.styleEffect(
        "Deals 10 Frost damage and empowers your Fire spells.", true),
        "Deals |cff82D8FA10|r Frost damage and empowers your Fire spells.")
    test.check("combined bonuses split without hooks", stats.rewrite(
        "Equip: Increases healing done by up to 20 and damage done by up to 10 for all magical spells and effects."),
        { "+20 Healing Power", "+10 Spell Damage Power" })
    test.check("shortening retains whitespace tolerance", stats.rewrite("  Equip: +20 Attack Power.  "),
        { "+20 Attack Power" })
    test.check("unclaimed text is left to reader", stats.rewrite("Durability 100 / 100"), nil)
    test.check("formatting does not mutate saved settings", PrettyTooltipDB, { statColors = false, statMarkers = false })
end
