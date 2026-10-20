-- The global size multiplies whole panels, while saved part sizes, native
-- tooltip scale, and positions remain independent.
return function(test)
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Object.lua", "Integration/Native.lua",
        "Integration/Cursor.lua", "UI/Options.lua" },
        { enums = { TooltipDataType = { Item = 0, Object = 4 } } })
    test.check("the default global scale is 100%", ns.tooltipScale(), 1)
    ns.setElementSetting("objectTitle", "size", 23)
    ns.setOption("tooltipScale", .75)
    UIParent:SetScale(.8)
    local anchor = CreateFrame("Frame", nil, UIParent)
    local model = ns.ui.objectModel({ name = "Mailbox", details = {}, quests = {}, extras = {} })
    local panel = ns.ui.renderPreview(anchor, model, 4)
    test.check("the entire preview scales relative to the UI",
        { panel:GetScale(), string.format("%.2f", panel:GetEffectiveScale()) }, { .75, "0.60" })
    test.check("part settings and resolved font sizes stay intact",
        { ns.elementSetting("objectTitle", "size"), ns.style("objectTitle").size }, { 23, 23 })
    ns.setOption("tooltipScale", 1.25)
    local reused = ns.ui.renderPreview(anchor, model, 4)
    test.check("an existing panel picks up the global setting", { reused == panel, panel:GetScale() }, { true, 1.25 })
    local other = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), model, 4)
    test.check("new panels use the same setting", other:GetScale(), 1.25)
    local mainPanel = ns.ui.getPanel(world.main)
    local comparison = ns.ui.getPanel(ShoppingTooltip1)
    for _, entry in ipairs({ { mainPanel, world.main }, { comparison, ShoppingTooltip1 } }) do
        ns.ui.renderView(entry[1], entry[2], { tooltipType = "item", color = { 1, 1, 1 }, header = {}, sections = {} })
    end
    ShoppingTooltip1:SetPoint("RIGHT", world.main, "LEFT", 0, 0)
    ns.Native.anchorToPanels(ShoppingTooltip1)
    test.check("main and comparison tooltips share the scale and meet at their panels",
        { mainPanel:GetScale(), comparison:GetScale(), select(2, ShoppingTooltip1:GetPoint(1)) == mainPanel },
        { 1.25, 1.25, true })

    -- A tooltip's padding is in its own units, not the scaled panel's units.
    local tooltip = world.main
    tooltip:SetScale(1.25)
    tooltip:SetSize(100, 50)
    tooltip:Show()
    tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
    local padding = { 0, 0, 0, 0 }
    tooltip.GetPadding = function() return unpack(padding) end
    tooltip.SetPadding = function(self, right, bottom, left, top)
        padding = { right, bottom, left, top }
        self:SetSize(100 + right, 50 + bottom)
    end
    panel = ns.ui.getPanel(tooltip)
    panel:SetSize(400, 200)
    panel:SetScale(.75)
    ns.Native.refitNative(tooltip, panel)
    test.check("native bounds fit the panel's physical size", { tooltip:GetWidth(), tooltip:GetHeight() }, { 240, 120 })
    panel:SetScale(1.25)
    ns.Native.refitNative(tooltip, panel)
    test.check("changing only scale invalidates the sizing cache",
        { tooltip:GetWidth(), tooltip:GetHeight() }, { 400, 200 })
    test.check("the native tooltip's own scale is preserved", tooltip:GetScale(), 1.25)
    panel.nativeSize, panel.fittedWidth = nil, nil
    tooltip.GetPadding = function() end
    tooltip:SetSize(100, 50)
    ns.Native.refitNative(tooltip, panel)
    test.check("the fallback sizing path also converts scale", { tooltip:GetWidth(), tooltip:GetHeight() }, { 400, 200 })

    -- Cursor offsets stay in native units, with the panel's scaled height.
    local follows = ns.ui.getPanel(tooltip)
    follows:Show()
    follows:SetSize(400, 200)
    follows:SetScale(.75)
    GameTooltip_SetDefaultAnchor = function(frame)
        frame:SetOwner(UIParent, "ANCHOR_NONE")
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
    end
    GetCursorPosition = function() return 400, 300 end
    ns.Cursor.register()
    ns.setOption("cursorObjects", true)
    GameTooltip_SetDefaultAnchor(tooltip)
    world.postCalls[4][1](tooltip, {})
    local _, _, _, x, y = tooltip:GetPoint(1)
    test.check("cursor placement accounts for the scaled height", { x, y }, { 16, 136 })

    -- The options slider edits one shared setting and participates in Defaults.
    local page
    Settings = { RegisterCanvasLayoutCategory = function(frame) page = frame return {} end,
        RegisterAddOnCategory = function() end }
    ns.Options.register()
    local slider
    for _, child in ipairs({ page:GetChildren() }) do
        if child:GetObjectType() == "Slider" then slider = child end
    end
    test.check("the main options expose the saved percentage", slider:GetValue(), 125)
    slider:GetScript("OnValueChanged")(slider, 70)
    test.check("one slider changes all tooltip sizes", ns.tooltipScale(), .7)
    slider:GetScript("OnValueChanged")(slider, 100)
    test.check("100% clears the override", ns.savedOption("tooltipScale"), nil)
    slider:GetScript("OnValueChanged")(slider, 80)
    page.OnDefault()
    test.check("Defaults restores both scale and slider", { ns.tooltipScale(), slider:GetValue() }, { 1, 100 })
    for _, value in ipairs({ "invalid", world.secret }) do
        ns.setOption("tooltipScale", value)
        test.check("an invalid saved scale falls back to 100%", ns.tooltipScale(), 1)
    end
    ns.setOption("tooltipScale", 0 / 0)
    test.check("a non-finite saved scale falls back to 100%", ns.tooltipScale(), 1)
    ns.setOption("tooltipScale", -1)
    test.check("saved scale cannot shrink below the slider minimum", ns.tooltipScale(), .5)
    ns.setOption("tooltipScale", 10)
    test.check("saved scale cannot exceed the slider maximum", ns.tooltipScale(), 1.5)
end
