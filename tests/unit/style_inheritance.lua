-- Defaults stay compatible; fields inherit, override, and return to their
-- parent without copying values or losing false/zero saved settings.
return function(test)
    for client, toc in pairs(test.tocs) do
        local ns = test.load(toc, { enums = test.enums })
        local function check(name, got, expected) test.check(client .. ": " .. name, got, expected) end
        check("original title sizes remain distinct", { ns.style("title").size, ns.style("spellTitle").size }, { 19, 17 })
        check("original icon defaults remain distinct", { ns.option("iconItems"), ns.option("iconQuests") }, { true, false })
        check("original cursor defaults remain distinct", { ns.option("cursorObjects"), ns.option("cursorItems") }, { true, false })
        ns.setOption("titleSize", 20)
        ns.setOption("titleFont", "Morpheus")
        ns.setOption("titleColor", { .2, .3, .4 })
        ns.setOption("bodySize", 14)
        ns.setOption("bodyFont", "Arial Narrow")
        check("shared roles affect names and body text", { ns.style("title").size, ns.style("auraName").size, ns.style("stats").size }, { 20, 20, 14 })
        ns.setTooltipSetting("item", "titleSize", 24)
        ns.setTooltipSetting("item", "bodyFont", "Skurri")
        ns.setElementSetting("title", "outline", "OUTLINE")
        check("properties resolve independently", { ns.style("title").size, ns.style("title").font, ns.style("title").flags, ns.style("stats").font },
            { 24, "Fonts\\MORPHEUS.TTF", "OUTLINE", "Fonts\\SKURRI.TTF" })
        ns.setOption("titleSize", 22)
        check("shared changes leave overrides intact", { ns.style("title").size, ns.style("spellTitle").size }, { 24, 22 })
        ns.setElementSetting("title", "size", 26)
        ns.setTooltipSetting("item", "titleSize", 25)
        check("a part overrides its type", ns.style("title").size, 26)
        ns.resetElement("title")
        check("resetting a part returns to its type", ns.style("title").size, 25)
        ns.setTooltipSetting("item", "titleSize", nil)
        check("resetting a type field returns to shared style", ns.style("title").size, 22)
        ns.setTooltipSetting("item", "titleSize", "automatic")
        check("a type can explicitly retain original sizes", ns.style("title").size, 19)
        ns.setOption("titleCaps", true)
        ns.setTooltipSetting("item", "titleCaps", false)
        check("false overrides inherited true", { ns.style("title").caps, ns.style("spellTitle").caps }, { false, true })
        ns.setTooltipSetting("item", "titleColor", "automatic")
        check("Automatic restores semantic colors", { ns.style("title").color, ns.style("spellTitle").color }, { nil, { .2, .3, .4 } })
        ns.setElementSetting("title", "color", { .8, .7, .6 })
        local resolved = ns.style("title")
        resolved.color[1] = 0
        check("resolved colors do not mutate overrides", ns.elementSetting("title", "color")[1], .8)

        ns.setOption("backdropAlpha", .5)
        ns.setOption("backdropAlphaSpells", 0)
        check("legacy zero overrides shared opacity", ns.option("backdropAlpha", "spell"), 0)
        ns.setTooltipSetting("spell", "backdropAlpha", .8)
        check("new overrides replace their legacy key", { ns.option("backdropAlphaSpells"), ns.savedOption("backdropAlphaSpells") }, { .8, nil })
        ns.setOption("backdropAlphaSpells", 0)
        check("legacy setters replace new overrides", ns.option("backdropAlpha", "spell"), 0)
        ns.setTooltipSetting("spell", "backdropAlpha", nil)
        check("removing an override cannot resurrect its legacy value", ns.option("backdropAlphaSpells"), .5)
        ns.setOption("restyle", false)
        ns.setTooltipSetting("item", "restyle", true)
        check("shared restyle supports per-type exceptions", { ns.restyles("itemPanels"), ns.restyles("spellPanels") }, { true, false })
        ns.setOption("followCursor", false)
        ns.setTooltipSetting("object", "followCursor", true)
        check("shared cursor supports per-type exceptions", { ns.option("cursorObjects"), ns.option("cursorItems") }, { true, false })

        ns.resetOptions()
        ns.setOption("minWidth", 300)
        ns.setOption("padding", 20)
        ns.setTooltipSetting("item", "minWidth", 220)
        ns.setTooltipSetting("item", "padding", 10)
        ns.setTooltipSetting("item", "backdropStyle", "flat")
        ns.setTooltipSetting("item", "tooltipScale", .75)
        ns.setTooltipSetting("item", "backdropAlpha", 0)
        local anchor = CreateFrame("Frame", nil, UIParent)
        local panel = ns.ui.getPanel(anchor)
        local function draw(tooltipType, key)
            ns.ui.renderView(panel, anchor, { tooltipType = tooltipType, color = { 1, 1, 1 },
                header = { { text = "Name", style = ns.ui.styleOf(key), color = { 1, 1, 1 }, gap = 0 } }, sections = {} })
        end
        draw("item", "title")
        check("render uses a type's width padding scale and background", { panel:GetWidth(), ns.ui.pad(panel), panel:GetScale(), panel.backdropMode },
            { 220, 10, .75, "flat" })
        check("zero opacity survives rendering", panel.background._gradient[2][4], 0)
        draw("spell", "spellTitle")
        check("a reused panel returns to inherited geometry", { panel:GetWidth(), ns.ui.pad(panel), panel:GetScale() }, { 300, 20, 1 })

        PrettyTooltipDB = { outline = "OUTLINE", bodyOutline = "NONE",
            tooltips = { spell = { outline = "THICKOUTLINE", titleOutline = "NONE" } } }
        ns.migrateOptions()
        check("a shared outline moves where Title and Body have none",
            { PrettyTooltipDB.outline, PrettyTooltipDB.titleOutline, PrettyTooltipDB.bodyOutline }, { nil, "OUTLINE", "NONE" })
        check("a type's outline moves the same way, under its own",
            { ns.tooltipSetting("spell", "outline"), ns.tooltipSetting("spell", "titleOutline"), ns.tooltipSetting("spell", "bodyOutline") },
            { nil, "NONE", "THICKOUTLINE" })
        check("text keeps its outline after the move",
            { ns.style("title").flags, ns.style("stats").flags, ns.style("spellTitle").flags, ns.style("spellText").flags },
            { "OUTLINE", "", "", "THICKOUTLINE" })
    end
end
