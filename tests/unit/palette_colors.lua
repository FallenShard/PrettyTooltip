-- School overrides reach every consumer after loading; resetting restores
-- the exact original item tones as well as the panel defaults.
return function(test)
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua" })
    test.check("school defaults work before settings load", ns.Palette.school("Fire"), { 1, .43, .11 })
    test.check("an unknown school has no color", ns.Palette.school("Physical"), nil)

    ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Data/Schools.lua", "Data/Stats.lua", "Panel/Layout.lua", "Panel/Render.lua",
        "Tooltips/Spell.lua", "Tooltips/Macro.lua" },
        { enums = { TooltipDataType = { Item = 0, Spell = 1, Macro = 8 } } })
    local palette = ns.Palette
    local function stat(text) return select(2, ns.Stats.styleStat(text, true, false)) end
    for school, expected in pairs({
        Arcane = { "EB60D6", "F0ADE6" }, Fire = { "FF6D1B", "EE9F72" },
        Frost = { "4CC6F7", "9EDCF5" }, Holy = { "FBBA38", "F6D28A" },
        Nature = { "7FCD48", "A6D783" }, Shadow = { "C174FF", "C9A2EE" },
    }) do
        test.check(school .. " keeps its original item tones", { palette.schoolStatColors(school) }, expected)
    end
    test.check("reading defaults does not create saved settings", PrettyTooltipDB, nil)

    -- Saved variables can arrive after the tooltip modules have loaded.
    PrettyTooltipDB = { schoolColorFire = { 1, 0, 0 } }
    test.check("a saved school color is read at use time", palette.school("Fire"), { 1, 0, 0 })
    test.check("the item name shade follows the override", { palette.schoolStatColors("Fire") },
        { "FF0000", "FF7373" })
    test.check("school spell power follows the override", stat("+20 Fire Spell Damage Power"),
        "|cffFF0000+20|r |cffFF7373Fire Spell Damage Power|r")
    test.check("school resistance follows the override", stat("+5 Fire Resistance"),
        "|cffFF0000+5|r |cffFF7373Fire Resistance|r")
    test.check("weapon damage follows the override", ns.Stats.styleDamage("64 - 120 Fire Damage", true),
        "|cffFF000064 - 120|r |cffFF7373Fire Damage|r")
    test.check("uncolored weapon damage stays plain", ns.Stats.styleDamage("64 - 120 Fire Damage", false),
        "64 - 120 Fire Damage")
    test.check("item effect highlighting follows the override", ns.Stats.styleEffect("Deals 40 Fire damage.", true),
        "Deals |cffFF4D4D40|r Fire damage.")

    -- Capture the views built by the real renderers, before the frame drawing.
    local view
    ns.ui.renderView = function(_, _, value) view = value end
    local spell = ns.ui.spellModel({ name = "Fireball", description = { "Deals 40 Fire damage." } })
    ns.TooltipTypes[1].render({}, nil, spell)
    test.check("the spell tint uses the live school color", view.tint, { 1, 0, 0 })
    test.check("the spell school badge uses the live color", view.header[2].badges[1][2], { 1, 0, 0 })
    ns.TooltipTypes[8].render({}, nil, ns.ui.macroModel({ name = "Fire", body = { "/cast Fireball" } }))
    test.check("macro accents use the live school color", view.tint, { 1, 0, 0 })
    ns.setOption("schoolColorFire", { 0, 1, 0 })
    ns.TooltipTypes[1].render({}, nil, spell)
    test.check("an already-loaded renderer sees a changed color", view.tint, { 0, 1, 0 })
    test.check("school defaults were not mutated", palette.schools.Fire, { 1, .43, .11 })

    ns.setOption("schoolColorHolyfire", { 0, 0, 1 })
    ns.setOption("schoolColorFrostfire", { 1, 1, 0 })
    test.check("Holyfire has an independent color", palette.school("Holyfire"), { 0, 0, 1 })
    test.check("Frostfire has an independent color", palette.school("Frostfire"), { 1, 1, 0 })
    test.check("dual-school gradients still follow their component schools", palette.gradient("Holyfire"),
        { palette.school("Holy"), { 0, 1, 0 } })
    for _, invalid in ipairs({ {}, { 1 }, { 1, "green", 0 }, { 2, 0, 0 }, { 0, -1, 0 } }) do
        ns.setOption("schoolColorFire", invalid)
        test.check("malformed school colors use the default", palette.school("Fire"), palette.schools.Fire)
    end
    ns.setOption("schoolColorFire", nil)
    test.check("reset restores the exact item shades", stat("+20 Fire Spell Damage Power"),
        "|cffFF6D1B+20|r |cffEE9F72Fire Spell Damage Power|r")

    ns.setOption("statColorMagic", { 1, 0, 0 })
    ns.setOption("schoolColorFire", { 1, 0, 0 })
    ns.setOption("statColors", false)
    ns.setOption("sellPrice", false)
    ns.resetStyles()
    test.check("reset fonts and colors clears stat and school overrides", {
        stat = ns.savedOption("statColorMagic"), school = ns.savedOption("schoolColorFire"),
        dual = ns.savedOption("schoolColorHolyfire"),
    }, {})
    test.check("reset fonts and colors preserves behavior switches", PrettyTooltipDB,
        { statColors = false, sellPrice = false })
end
