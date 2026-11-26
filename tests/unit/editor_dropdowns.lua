-- Blizzard combo boxes use native menus and steppers. Nil inheritance and
-- false choices remain distinct, and font menus preview faces without SetFont.
return function(test)
    for client, toc in pairs(test.tocs) do
        local ns, world = test.load(toc, { enums = test.enums })
        ns.openEditor()
        PrettyTooltipEditor:GetScript("OnShow")(PrettyTooltipEditor)
        local pages = ns.editorPages
        local function check(name, got, expected) test.check(client .. ": " .. name, got, expected) end
        local function caption(holder, name)
            for _, label in ipairs({ holder:GetRegions() }) do
                if label.GetText and label:GetText() == name then return true end
            end
            return false
        end
        local function field(name)
            for _, object in ipairs(world.objects) do
                if object.nativeControl and object:IsVisible() and caption(object:GetParent(), name) then return object end
            end
            error("missing field: " .. name)
        end
        local function click(button) button:GetScript("OnClick")(button) end
        local shared = field("Restyle")
        local widget = shared.nativeControl
        check("uses the actual settings combo template", widget._template, "SettingsDropdownWithButtonsTemplate")
        check("the native value is selected", widget.Dropdown.Text:GetText(), "On")
        check("the first choice disables its previous button", { widget.DecrementButton:IsEnabled(), widget.IncrementButton:IsEnabled() }, { false, true })
        click(widget.IncrementButton)
        check("next chooses false", { ns.option("restyle"), widget.Dropdown.Text:GetText() }, { false, "Off" })
        check("the last choice disables its next button", { widget.DecrementButton:IsEnabled(), widget.IncrementButton:IsEnabled() }, { true, false })

        pages.open("item")
        local own = field("Restyle")
        widget = own.nativeControl
        check("a type initially follows its shared value", { own.current(), ns.option("itemPanels") }, { nil, false })
        click(widget.IncrementButton)
        check("next can override inherited false with true", { own.current(), ns.option("restyle") }, { true, false })
        click(widget.IncrementButton)
        check("false is an explicit choice after true", own.current(), false)
        click(widget.DecrementButton)
        click(widget.DecrementButton)
        check("previous returns to nil inheritance", { own.current(), ns.option("itemPanels") }, { nil, false })
        widget.Dropdown:OpenMenu()
        pages.open("spell")
        check("changing pages closes native menus", widget.Dropdown:IsMenuOpen(), false)

        ns.setOption("editorStyle", "flat")
        ns.refreshEditorStyle()
        pages.open("item")
        check("Flat hides the native widget and keeps the chosen value", { widget:IsShown(), own:IsMouseEnabled(), own.label:GetText() },
            { false, true, "All Tooltips: Off" })
        ns.setOption("editorStyle", nil)
        ns.refreshEditorStyle()
        check("switching back restores native controls", { widget:IsShown(), own:IsMouseEnabled(), widget.Dropdown.Text:GetText() },
            { true, false, "All Tooltips: Off" })

        pages.open("tooltips")
        for _, object in ipairs(world.objects) do
            if object:GetObjectType() == "Button" and not object.label and object:IsVisible()
                and object:GetScript("OnClick") and caption(object:GetParent(), "Text") then click(object) break end
        end
        local font = field("Font")
        local dropdown = font.nativeControl.Dropdown
        dropdown:OpenMenu()
        local menu = dropdown:GetMenuDescription()
        check("long menus have a bounded scroll area", menu.scrollHeight, 240)
        local arial
        for _, entry in ipairs(menu.entries) do if entry.text == "Arial Narrow" then arial = entry break end end
        -- Menu rows are Compositor regions, which raise an error on SetFont.
        local poolEntry = { fontString = CreateFrame("Frame"):CreateFontString() }
        poolEntry.fontString.SetFont = function() error("Use of function 'SetFont' is disallowed.") end
        arial.initialize(poolEntry)
        check("font choices preview their face without SetFont", select(1, poolEntry.fontString:GetFont()), "Fonts\\ARIALN.TTF")
        check("the Compositor resets pooled rows itself", arial.reset, nil)
        arial.respond()
        check("native menu selection updates the shared style", { ns.option("titleFont"), dropdown.Text:GetText() }, { "Arial Narrow", "Arial Narrow" })

        local sharedCaps = field("Capitalization")
        local choices = sharedCaps.items()
        check("shared capitalization offers two clear choices", { #choices, choices[1].text, choices[2].text },
            { 2, "Default", "All Caps" })
        local sharedWidget = sharedCaps.nativeControl
        check("names start in capitals, and the title list says so",
            { sharedWidget.Dropdown.Text:GetText(), ns.savedOption("titleCaps"), ns.style("title").caps }, { "All Caps", nil, true })
        click(sharedWidget.DecrementButton)
        check("shared Default writes names as they are",
            { ns.savedOption("titleCaps"), ns.style("title").caps, ns.style("spellTitle").caps }, { false, false, false })
        click(sharedWidget.IncrementButton)
        check("choosing what names show by default saves nothing", { ns.savedOption("titleCaps"), ns.style("title").caps }, { nil, true })
        local bodyCaps
        for _, object in ipairs(world.objects) do
            if object.nativeControl and object ~= sharedCaps and object:IsVisible() and caption(object:GetParent(), "Capitalization") then
                bodyCaps = object
            end
        end
        check("body text starts as written", { bodyCaps.nativeControl.Dropdown.Text:GetText(), ns.style("stats").caps }, { "Default", false })
        click(bodyCaps.nativeControl.IncrementButton)
        check("shared All Caps reaches body text", { ns.savedOption("bodyCaps"), ns.style("stats").caps }, { true, true })
        pages.open("item")
        for _, object in ipairs(world.objects) do
            if object:GetObjectType() == "Button" and not object.label and object:IsVisible()
                and object:GetScript("OnClick") and caption(object:GetParent(), "Text") then click(object) break end
        end
        local ownCaps = field("Capitalization")
        widget = ownCaps.nativeControl
        check("inherited capitalization names the shared choice", widget.Dropdown.Text:GetText(), "All Tooltips: All Caps")
        click(widget.IncrementButton)
        check("a type can choose Default over capital names",
            { ns.tooltipSetting("item", "titleCaps"), ns.style("title").caps, ns.style("spellTitle").caps }, { false, false, true })
        click(widget.IncrementButton)
        check("a type can choose All Caps explicitly", ns.tooltipSetting("item", "titleCaps"), true)
        click(widget.DecrementButton)
        click(widget.DecrementButton)
        check("a type can return to shared capitalization", { ownCaps.current(), ns.style("title").caps }, { nil, true })
        ns.setOption("titleCaps", false)
        ns.refreshEditorStyle()
        check("inherited Default has a clear label", widget.Dropdown.Text:GetText(), "All Tooltips: Default")
        local ownBody
        for _, object in ipairs(world.objects) do
            if object.nativeControl and object ~= ownCaps and object:IsVisible() and caption(object:GetParent(), "Capitalization") then
                ownBody = object
            end
        end
        click(ownBody.nativeControl.IncrementButton)
        check("a type's body Default undoes shared All Caps but keeps caption capitals",
            { ns.tooltipSetting("item", "bodyCaps"), ns.style("stats").caps, ns.style("caption").caps, ns.style("spellText").caps },
            { "automatic", false, true, true })
        ns.setTooltipSetting("item", "titleCaps", false)
        ns.refreshEditorStyle()
        check("old false overrides remain intact and have a selected choice",
            { ns.savedOption("titleCaps"), ns.tooltipSetting("item", "titleCaps"), widget.Dropdown.Text:GetText() }, { false, false, "Default" })
        pages.open("tooltips")
        check("old shared false remains intact under Default", { ns.savedOption("titleCaps"), sharedWidget.Dropdown.Text:GetText() },
            { false, "Default" })
    end
end
