-- Both editor treatments are available without other addons. The editor's
-- Layout and keys page switches them live, and the options page's Defaults
-- restores the Blizzard appearance.
return function(test)
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua", "UI/Samples.lua",
        "UI/Options.lua", "UI/EditorSkin.lua", "UI/Editor.lua" }, { enums = { TooltipDataType = { Item = 0 } } })
    local installed = false
    C_AddOns.GetAddOnInfo = function(addon)
        if installed and addon == "EllesmereUI" then return addon end
    end
    test.check("Blizzard is the default without EllesmereUI", ns.editorStyle(), "native")
    installed = true
    test.check("installing EllesmereUI keeps the Blizzard default", ns.editorStyle(), "native")
    installed = false

    local skin = ns.EditorSkin.create()
    local window = CreateFrame("Frame", nil, UIParent)
    local flatBackground = window:CreateTexture()
    flatBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
    skin:surface(window, flatBackground, {}, true)
    local layout = CreateFrame("Frame", nil, window)
    skin:settingsLayout(layout, 14, 56, 14, 44, 204, 728)
    local layoutArt, layoutRules, layoutShade = {}, {}, {}
    for _, region in ipairs({ layout:GetRegions() }) do
        local texture = region:GetTexture()
        local regions = layoutRules
        if texture == "atlas:!UI-Frame-InnerLeftTile" then regions = layoutArt
        elseif texture == "color" or tostring(texture):find("ShadowOverlay", 1, true) then regions = layoutShade end
        regions[#regions + 1] = region
    end
    local layoutBorder = layout:GetChildren()
    local function allShown(regions, shown)
        for _, region in ipairs(regions) do if region:IsShown() ~= shown then return false end end
        return true
    end
    local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    local parts = skin.templateParts(button)
    local flatButton = button:CreateTexture()
    button.label = button:CreateFontString()
    skin:button(button, flatButton, {}, parts)
    local tab = CreateFrame("Button", nil, window, "MinimalTabTemplate")
    tab.label = tab.Text
    tab.label:SetText("Quests")
    skin:tab(tab, tab:CreateTexture(), {})
    tab:SetSelected(true)
    local slider = CreateFrame("Slider", nil, window, "MinimalSliderTemplate")
    parts = skin.templateParts(slider)
    local track = slider:CreateTexture()
    skin:slider(slider, track, parts)
    slider:SetValue(17)
    local edits = 0
    button:SetScript("OnClick", function() edits = edits + 1 end)
    -- The editor's own frames follow too; this window stands in for them.
    local editorRefresh = ns.refreshEditorStyle
    ns.refreshEditorStyle = function() editorRefresh() skin:refresh() end

    local page
    Settings = {
        RegisterCanvasLayoutCategory = function(canvas) page = canvas return {} end,
        RegisterAddOnCategory = function() end,
    }
    ns.Options.register()
    ns.openEditor()
    local navigationHeaders = {}
    for _, object in ipairs(world.objects) do
        if object:GetTexture() == "atlas:Options_CategoryHeader_1" or object:GetTexture() == "atlas:Options_CategoryHeader_2" then
            -- Atlas padding must not change navigation row or highlight size.
            object:SetHeight(160)
            navigationHeaders[#navigationHeaders + 1] = object:GetParent()
        end
    end
    PrettyTooltipEditor:GetScript("OnShow")(PrettyTooltipEditor)
    test.check("header artwork padding keeps compact navigation rows",
        { navigationHeaders[1]:GetHeight(), navigationHeaders[2]:GetHeight() }, { 30, 30 })
    local _, _, _, _, tooltipHeaderY = navigationHeaders[2]:GetPoint()
    test.check("header artwork padding does not push tooltip pages downward", tooltipHeaderY, -54)
    -- The last "Blizzard" radio is the appearance's; the layout has one too.
    local nativeChoice, flatChoice
    for _, child in ipairs(world.objects) do
        if child:GetObjectType() == "CheckButton" then
            for _, label in ipairs({ child:GetRegions() }) do
                if label:GetText() == "Blizzard" then nativeChoice = child end
                if label:GetText() == "Flat" then flatChoice = child end
            end
        end
    end
    test.check("the editor selects Blizzard initially", nativeChoice:GetChecked(), true)
    test.check("Flat is available without EllesmereUI", flatChoice:IsEnabled(), true)
    ns.refreshEditorStyle()
    test.check("native button artwork is visible", button.Left:IsShown(), true)
    test.check("flat artwork starts hidden", flatBackground:IsShown(), false)
    local editorBase = PrettyTooltipEditor.editorSurface.nativeBackground
    test.check("native editor uses the Options window's background template",
        { editorBase:IsShown(), editorBase._template }, { true, "FlatPanelBackgroundTemplate" })
    local stockBackground = CreateFrame("Frame", nil, UIParent, "FlatPanelBackgroundTemplate")
    test.check("native background keeps the game's tint and opacity",
        { editorBase.TopSection:GetVertexColor() }, { stockBackground.TopSection:GetVertexColor() })
    test.check("native layout has two independent dividers", #layoutArt, 2)
    local _, _, _, sidebarX = layoutArt[1]:GetPoint()
    local _, _, _, previewX = layoutArt[2]:GetPoint()
    test.check("dividers stay between their columns", { sidebarX, previewX, layoutArt[1]:GetWidth(), layoutArt[2]:GetWidth() },
        { 204, 728, 3, 3 })
    test.check("native layout keeps only the shared border", { layoutBorder:IsShown(), layoutBorder.Center:IsShown() }, { true, false })
    test.check("native layout shows its artwork", allShown(layoutArt, true), true)
    test.check("native layout hides the flat rules", allShown(layoutRules, false), true)
    test.check("native columns have the inner tint and shadow", { #layoutShade, allShown(layoutShade, true) }, { 27, true })
    local function matchingSurfaces(native)
        local expected = native and editorBase or PrettyTooltipEditor.editorSurface.flatBackground
        local function appearance(region)
            if native then
                return { region._template, region:GetAlpha(), region.TopSection:GetVertexColor() }
            end
            return { region:GetTexture(), region:GetVertexColor() }
        end
        for _, object in ipairs(world.objects) do
            local surface = object.editorSurface
            if surface then
                local region = native and surface.nativeBackground or surface.flatBackground
                local got, want = appearance(region), appearance(expected)
                for index, value in ipairs(want) do
                    if got[index] ~= value then return false end
                end
                if not region:IsShown() then return false end
            end
        end
        return true
    end
    test.check("all native surfaces have the same visible background and brightness", matchingSurfaces(true), true)

    flatChoice:GetScript("OnClick")(flatChoice)
    test.check("choosing Flat saves the appearance", ns.option("editorStyle"), "flat")
    test.check("options radios update immediately", { nativeChoice:GetChecked(), flatChoice:GetChecked() }, { false, true })
    test.check("the live frame switches to flat", flatBackground:IsShown(), true)
    test.check("Flat uses its own opaque base", { editorBase:IsShown(),
        select(4, PrettyTooltipEditor.editorSurface.flatBackground:GetVertexColor()) }, { false, 1 })
    test.check("all Flat surfaces have the same visible background and brightness", matchingSurfaces(false), true)
    test.check("Flat hides the native frame artwork", allShown(layoutArt, false), true)
    test.check("Flat hides the shared native border", layoutBorder:IsShown(), false)
    test.check("Flat hides the inner tint and shadow", allShown(layoutShade, false), true)
    test.check("Flat keeps two simple column dividers", { #layoutRules, allShown(layoutRules, true) }, { 2, true })
    test.check("native button artwork is hidden in Flat", button.Left:IsShown(), false)
    test.check("Flat hides the native tab artwork", tab.Left:IsShown(), false)
    test.check("the selected tab label stays visible in Flat", tab.label:IsVisible(), true)
    test.check("the flat button artwork is visible", flatButton:IsShown(), true)
    test.check("native slider art is hidden in Flat", slider.Left:IsShown(), false)
    test.check("the slider thumb stays visible", slider:GetThumbTexture():IsShown(), true)
    test.check("button labels stay visible", button.label:IsVisible(), true)
    button:GetScript("OnClick")(button)
    test.check("editing still works after switching", edits, 1)
    test.check("a control's current value survives switching", slider:GetValue(), 17)
    ns.resetStyles()
    test.check("reset fonts and colors keeps editor appearance", ns.editorStyle(), "flat")

    installed = true
    ns.refreshEditorStyle()
    test.check("installing EllesmereUI keeps the Flat choice", ns.editorStyle(), "flat")
    installed = false
    ns.refreshEditorStyle()
    test.check("removing EllesmereUI keeps the Flat choice", ns.editorStyle(), "flat")
    test.check("Flat stays available without EllesmereUI", flatChoice:IsEnabled(), true)
    test.check("Flat stays selected in the options", flatChoice:GetChecked(), true)
    nativeChoice:GetScript("OnClick")(nativeChoice)
    test.check("choosing Blizzard restores native controls", button.Left:IsShown(), true)
    test.check("choosing Blizzard restores tab artwork", tab.Left:IsShown(), true)
    test.check("the selected tab survives switching", tab.selected, true)
    test.check("choosing Blizzard hides flat controls", flatButton:IsShown(), false)
    flatChoice:GetScript("OnClick")(flatChoice)
    test.check("Flat can be chosen without EllesmereUI", ns.option("editorStyle"), "flat")

    installed = true
    flatChoice:GetScript("OnClick")(flatChoice)
    page.OnDefault()
    test.check("Defaults restores Blizzard even with EllesmereUI", ns.editorStyle(), "native")
    test.check("Defaults immediately updates the editor", flatBackground:IsShown(), false)
    test.check("Defaults refreshes the selected radio", nativeChoice:GetChecked(), true)
    test.check("Defaults leaves the current control value intact", slider:GetValue(), 17)
    ns.setOption("editorStyle", "unknown")
    test.check("an invalid saved appearance uses Blizzard", ns.editorStyle(), "native")
end
