-- The shared settings API works without constructing a settings page or editor.
return function(test)
    local dependencies = { "Core/Util.lua", "Core/Palette.lua" }
    local _, baseline = test.load(dependencies)
    local objects = #baseline.objects
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua" })
    test.check("settings create no frames", #world.objects, objects)
    test.check("settings install no tooltip callbacks", next(world.postCalls), nil)
    test.check("settings do not load the options page", ns.Options, nil)
    test.check("settings do not register slash commands", SlashCmdList.PRETTYTOOLTIP, nil)
    test.check("loading settings leaves saved variables absent", PrettyTooltipDB, nil)
    test.check("missing DB uses option defaults", ns.option("itemPanels"), true)
    test.check("reading defaults leaves DB absent", PrettyTooltipDB, nil)

    PrettyTooltipDB = { itemPanels = false, headerTopAlpha = .4,
        headerTopAlphaSpells = 0, styles = { spellTitle = { size = 23, caps = false,
            font = "Arial Narrow", color = { .2, .3, .4 } } } }
    test.check("saved false overrides defaults", ns.option("itemPanels"), false)
    test.check("saved styles arrive after loading", ns.style("spellTitle").size, 23)
    test.check("saved false disables title caps", ns.style("spellTitle").caps, false)
    test.check("saved font resolves without UI", ns.style("spellTitle").font, "Fonts\\ARIALN.TTF")
    test.check("zero alpha overrides shared alpha", ns.headerAlpha("spell", "Top"), 0)
    test.check("other tooltip uses shared alpha", ns.headerAlpha("aura", "Top"), .4)
    local style = ns.style("spellTitle")
    style.color[1] = 1
    test.check("resolved colors do not mutate saved colors", ns.elementSetting("spellTitle", "color")[1], .2)

    ns.setOption("itemPanels", true)
    test.check("option changes invalidate panels", ns.settingsVersion, 1)
    ns.setElementSetting("spellTitle", "size", 21)
    test.check("style changes invalidate panels", ns.settingsVersion, 2)
    test.check("style change reaches readers immediately", ns.style("spellTitle").size, 21)
    ns.resetElement("spellTitle")
    test.check("reset element restores defaults", ns.style("spellTitle").size, 17)
    test.check("element reset invalidates panels", ns.settingsVersion, 3)
    ns.setOption("bodyFont", "Arial Narrow")
    ns.resetStyles()
    test.check("reset styles preserves behavior options", ns.option("itemPanels"), true)
    test.check("reset styles clears fonts", ns.option("bodyFont"), nil)
    test.check("reset styles clears per-tooltip alpha", ns.headerAlpha("spell", "Top"), nil)
    test.check("style reset invalidates panels", ns.settingsVersion, 5)
    ns.setOption("itemPanels", false)
    ns.resetOptions()
    test.check("options reset replaces DB", PrettyTooltipDB, {})
    test.check("options reset restores defaults", ns.option("itemPanels"), true)
    test.check("options reset invalidates panels", ns.settingsVersion, 7)

    PrettyTooltipDB = "invalid"
    test.check("malformed DB uses defaults", ns.option("itemPanels"), true)
    ns.setElementSetting("spellTitle", "size", 22)
    test.check("writing repairs malformed DB", ns.style("spellTitle").size, 22)

    -- The text size scales every part's own size, a custom one too.
    ns.resetOptions()
    local title, custom = ns.style("title").size, ns.ELEMENT_BY_KEY.stats.size
    ns.setElementSetting("stats", "size", 15)
    ns.setOption("fontScale", 1.2)
    test.check("the text size scales each part", { ns.style("title").size, ns.style("stats").size },
        { title * 1.2, 15 * 1.2 })
    test.check("a part's own size stays unscaled in the editor", ns.elementSetting("stats", "size"), 15)
    test.check("the default stats size is unchanged", ns.ELEMENT_BY_KEY.stats.size, custom)
end
