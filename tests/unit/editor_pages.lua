-- Exercise page controls: shared edits, independent overrides, inherited-value
-- links, collapse state, and resets of each scope.
return function(test)
    for client, toc in pairs(test.tocs) do
        local ns, world = test.load(toc, { enums = test.enums })
        local pages = ns.editorPages
        ns.openEditor()
        PrettyTooltipEditor:GetScript("OnShow")(PrettyTooltipEditor)
        local function check(name, got, expected) test.check(client .. ": " .. name, got, expected) end
        local function caption(holder, name)
            for _, label in ipairs({ holder:GetRegions() }) do
                if label.GetText and label:GetText() == name then return true end
            end
            return false
        end
        local function section(name)
            for _, object in ipairs(world.objects) do
                if object:GetObjectType() == "Button" and object:GetScript("OnClick") and not object.label
                    and object:GetParent():IsVisible() and caption(object:GetParent(), name) then return object end
            end
            error("missing section: " .. name)
        end
        local function field(name)
            for _, object in ipairs(world.objects) do
                if object.pick and object:IsVisible() and caption(object:GetParent(), name) then return object end
            end
            error("missing field: " .. name)
        end
        local function click(button) button:GetScript("OnClick")(button) end
        local function pick(control, value) control.pick(value) ns.refreshEditorStyle() end

        check("opens on shared defaults", pages.current(), "tooltips")
        local sectionNames = {}
        for _, object in ipairs(world.objects) do
            if object:GetObjectType() == "Button" and object:GetScript("OnClick") and not object.label
                and object:GetParent():IsVisible() and object:GetParent().sectionCard then
                for _, name in ipairs({ "Appearance", "Layout", "Text", "Behavior" }) do
                    if caption(object:GetParent(), name) then sectionNames[#sectionNames + 1] = name end
                end
            end
        end
        check("shared styling has four sections", sectionNames, { "Appearance", "Layout", "Text", "Behavior" })
        local schoolColors
        for _, object in ipairs(world.objects) do
            if object:GetObjectType() == "FontString" and object:GetText() == "School Colors" and object:IsVisible() then schoolColors = object end
        end
        check("school colors starts inside expanded Appearance", schoolColors ~= nil, true)
        click(section("Layout"))
        local sharedScale
        for _, object in ipairs(world.objects) do
            if object:GetObjectType() == "Slider" and caption(object:GetParent():GetParent(), "Global Scale") then sharedScale = object break end
        end
        check("shared scale is visible", sharedScale:IsVisible(), true)
        pages.open("general")
        check("addon preferences leave tooltip controls out", sharedScale:IsVisible(), false)
        ns.setOption("detailsKey", "ALWAYS")
        ns.setOption("padding", 24)
        check("each root tracks its own settings", { pages.changed("general"), pages.changed("tooltips") }, { true, true })
        pages.reset("general")
        check("reset addon preferences preserves shared style", { ns.option("detailsKey"), ns.option("padding") }, { "SHIFT", 24 })

        pages.open("tooltips")
        click(section("Text"))
        pick(field("Font"), "Arial Narrow")
        pick(field("Size"), 20)
        check("shared title settings affect multiple types", { ns.style("title").size, ns.style("spellTitle").size }, { 20, 20 })
        pages.open("item")
        click(section("Text"))
        local itemFont = field("Font")
        check("the font starts inherited", itemFont.current(), nil)
        check("inherited font names its current value", itemFont.label:GetText():find("Arial Narrow", 1, true) ~= nil, true)
        pick(field("Size"), 24)
        check("the text group counts its override", caption(section("Text"):GetParent(), "1 override"), true)
        check("a type changes one property", { ns.style("title").size, ns.style("spellTitle").size, ns.style("title").font },
            { 24, 20, "Fonts\\ARIALN.TTF" })

        local link
        for _, child in ipairs({ itemFont:GetParent():GetChildren() }) do
            if child.label then link = child end
        end
        check("inherited rows have no link under them", link, nil)
        pages.open("tooltips")
        pick(field("Font"), "Morpheus")
        check("a shared font update crosses a size override", { ns.style("title").size, ns.style("title").font }, { 24, "Fonts\\MORPHEUS.TTF" })
        pages.open("item")
        local size = field("Size")
        local reset
        for _, child in ipairs({ size:GetParent():GetChildren() }) do
            if child:GetObjectType() == "Button" and not child.label then reset = child end
        end
        click(reset)
        check("a field reset restores inheritance", { ns.tooltipSetting("item", "titleSize"), ns.style("title").size }, { nil, 20 })
        local titleCard = section("Text"):GetParent().sectionCard
        local expandedHeight = titleCard:GetHeight()
        click(section("Text"))
        check("collapsing hides its controls", itemFont:IsVisible(), false)
        check("the background shrinks with its collapsed group", titleCard:GetHeight() < expandedHeight, true)
        pages.open("general")
        check("a type's card is hidden on another page", titleCard:IsShown(), false)
        pages.open("spell")
        pages.open("item")
        check("a type remembers collapsed groups", itemFont:IsVisible(), false)

        ns.setTooltipSetting("item", "padding", 30)
        ns.setTooltipSetting("item", "titleCaps", false)
        ns.setElementSetting("title", "size", 26)
        ns.setOption("questParchment", true)
        pages.reset("item")
        check("type reset removes styling and part overrides", { ns.option("padding", "item"), ns.style("title").size, pages.changed("item") },
            { 24, 20, false })
        check("type reset preserves shared content preferences", ns.option("questParchment"), true)
        ns.setTooltipSetting("item", "padding", 30)
        pages.reset("tooltips")
        check("shared reset preserves type overrides", { ns.option("padding"), ns.option("padding", "item") }, { 19, 30 })

        for _, kind in ipairs(ns.TOOLTIP_TYPES) do
            if kind.editor and kind.restyle then
                ns.setOption(kind.restyle, false)
                check(kind.editor .. " restyle marks its page", pages.changed(kind.editor), true)
                pages.reset(kind.editor)
                check(kind.editor .. " reset restores restyle", ns.option(kind.restyle), true)
            end
        end
        pages.open("other")
        check("other tooltip kinds have their own page", pages.current(), "other")
        ns.setElementSetting("extras", "size", 14)
        check("shared text parts mark All tooltips", pages.changed("tooltips"), true)
        pages.reset("tooltips")
        check("shared reset includes shared text parts", ns.elementSetting("extras", "size"), nil)

        pages.open("item")
        local function inlineSwitch(label, key, colorKey)
            local boxes = {}
            for _, object in ipairs(world.objects) do
                if object:GetObjectType() == "CheckButton" and object.caption and object.caption:GetText() == label then
                    boxes[#boxes + 1] = object
                end
            end
            check(label .. " has one switch", #boxes, 1)
            local box = boxes[1]
            local inline = box:GetParent()
            check(label .. " switch shares its color row", caption(inline:GetParent(), label), true)
            local swatches
            for _, object in ipairs(world.objects) do
                if object:GetParent() == inline and object ~= box then swatches = object end
            end
            ns.setOption(key, false)
            ns.refreshEditorStyle()
            check(label .. " colors dim while the switch is off", { box:GetChecked(), swatches:GetAlpha() }, { false, .4 })
            box:SetChecked(true)
            click(box)
            check(label .. " inline switch turns colors on", { ns.option(key), swatches:GetAlpha() }, { true, 1 })
            ns.setOption(colorKey, { .1, .2, .3 })
            pages.reset("item")
            check(label .. " page reset clears the switch and colors", { ns.savedOption(key), ns.savedOption(colorKey) }, { nil, nil })
        end
        inlineSwitch("Armor Colors", "armorColors", "armorColorCloth")
        inlineSwitch("Stat Colors", "statColors", "statColor" .. ns.Stats.CATEGORIES[1].key)

        pages.open("tooltips")
        local combatBox
        for _, object in ipairs(world.objects) do
            if object:GetObjectType() == "CheckButton" and object.caption
                and object.caption:GetText() == "Follow Cursor in Combat" then combatBox = object end
        end
        ns.refreshEditorStyle()
        check("the combat switch starts unchecked, as tooltips stop following in combat",
            { combatBox:GetChecked(), ns.option("cursorDisableInCombat") }, { false, true })
        combatBox:SetChecked(true)
        click(combatBox)
        check("checking it keeps following the cursor in combat", ns.option("cursorDisableInCombat"), false)
    end
end
