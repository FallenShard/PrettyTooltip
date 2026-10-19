-- Formatting and shortening need only explicit inputs, not settings or game hooks.
return function(test)
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Locale/Locale.lua", "Locale/English.lua",
        "Data/Stats.lua" })
    test.check("rules install no pre-calls", next(world.preCalls), nil)
    test.check("rules install no post-calls", next(world.postCalls), nil)
    test.check("rules do not create saved settings", PrettyTooltipDB, nil)
    test.check("rules do not depend on settings module", ns.option, nil)

    -- A contradictory DB and absent game APIs expose any hidden dependencies.
    PrettyTooltipDB = { statColors = false, statMarkers = false }
    TooltipDataProcessor, GetLocale = nil, nil
    local stats = ns.Stats
    local plain = "+6 Intellect"
    local highlighted = "|cffE9DDC4+6|r |cffEEE7DAIntellect|r"
    local marker = "|TInterface\\AddOns\\PrettyTooltip\\art\\stat-marker:9:9:0:-2|t  "
    local display, markerFree = stats.styleStat(plain, true, true)
    test.check("explicit settings control stat formatting", display, marker .. highlighted)
    test.check("colored wording without marker", markerFree, highlighted)
    test.check("neutral stat formatting retains original shades", stats.styleStat(plain, false, false),
        "|cffF2E8D5+6|r |cffA89F8EIntellect|r")
    test.check("unknown stat remains untouched", stats.styleStat("+6 Unknown", true, true), "+6 Unknown")
    test.check("school stat colors retain their exact values", stats.styleDamage("64 - 120 Shadow Damage", true),
        "|cffC174FF64 - 120|r |cffC9A2EEShadow Damage|r")
    test.check("explicit colors off preserves damage", stats.styleDamage("64 - 120 Shadow Damage", false),
        "64 - 120 Shadow Damage")
    test.check("proc formatting works without game or settings", stats.styleEffect("Deals 40 Fire damage.", true),
        "Deals |cffFF996040|r Fire damage.")
    -- Item effects name a school by its spells, as well as by its damage.
    test.check("an effect on a school's spells takes its tint", stats.styleEffect(
        "Increasing damage done by Fire spells and effects by up to 4.", true),
        "Increasing damage done by Fire spells and effects by up to |cffFF99604|r.")
    test.check("a school's spell damage takes its tint", stats.styleEffect("+12 Shadow spell damage.", true),
        "+|cffD49DFF12|r Shadow spell damage.")
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
    -- Bonuses against one kind of creature read as stats, in their stat's color.
    test.check("spell damage against a creature type", stats.rewrite(
        "Equip: Increases damage done to Elementals by magical spells and effects by up to 9."),
        { "+9 Spell Damage Power vs Elementals" })
    test.check("attack power against a creature type", stats.rewrite("Equip: +20 Attack Power when fighting Undead."),
        { "+20 Attack Power vs Undead" })
    -- Each creature type, for both stats and every wording.
    for _, creature in ipairs({ "Humanoids", "Elementals", "Beasts" }) do
        test.check("spell damage vs " .. creature, stats.rewrite("Equip: Increases damage done to " .. creature
            .. " by magical spells and effects by up to 12."), { "+12 Spell Damage Power vs " .. creature })
        for _, wording in ipairs({ "Equip: +30 Attack Power when fighting %s.", "Equip: Increases attack power by 30 when fighting %s.",
            "Equip: Increases attack power by 30 against %s." }) do
            test.check("attack power vs " .. creature .. ": " .. wording, stats.rewrite(wording:format(creature)),
                { "+30 Attack Power vs " .. creature })
        end
    end
    test.check("a creature bonus takes its stat's color", stats.styleStat("+20 Attack Power vs Undead", true, false),
        "|cffFAA365+20|r |cffF7C5A5Attack Power vs Undead|r")
    test.check("unclaimed text is left to reader", stats.rewrite("Durability 100 / 100"), nil)
    test.check("formatting does not mutate saved settings", PrettyTooltipDB, { statColors = false, statMarkers = false })
end
