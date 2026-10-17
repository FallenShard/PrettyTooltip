-- Settings-page presentation and registration. The shared API lives in Core/Settings.lua.
local _, ns = ...
local setOption = ns.setOption

local page, category
ns.Options = {}

-- Called by the entry file after saved settings arrive.
function ns.Options.register()
    if page then return end
    page = CreateFrame("Frame")
    page.name = "PrettyTooltip"
    -- Created hidden, or the settings window never fires OnShow on first open.
    page:Hide()
    local controls = {}

    local function refreshControls()
        for _, control in ipairs(controls) do control.refresh() end
    end

    local pageTitle = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    pageTitle:SetPoint("TOPLEFT", 16, -16)
    pageTitle:SetText("PrettyTooltip")
    local subtitle = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", pageTitle, "BOTTOMLEFT", 0, -6)
    subtitle:SetText("A full reskin of tooltips. Changes apply the next time a tooltip opens.")

    local editorButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    editorButton:SetSize(180, 24)
    editorButton:SetPoint("TOPLEFT", 16, -64)
    editorButton:SetText("Open the style editor")

    -- Explanations show on hover, which keeps the page short.
    local function explain(widget, title, text)
        widget:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(title, 1, 1, 1)
            GameTooltip:AddLine(text, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    explain(editorButton, "Style editor", "The look of every kind of tooltip, with a live sample: fonts, "
        .. "sizes, and colors for every part, text size, tints, and opacities, and each kind's own details, "
        .. "as disenchant results, the spell power breakdown, and the health bar. Also /ptip.")
    editorButton:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        if ns.openEditor then ns.openEditor() end
    end)

    -- Two columns: the types of tooltip on the left, the other settings on the right.
    local COLUMNS_TOP = -100
    local leftColumn = { x = 16, y = COLUMNS_TOP }
    local rightColumn = { x = 440, y = COLUMNS_TOP }

    local function section(column, text)
        local header = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        header:SetPoint("TOPLEFT", column.x, column.y)
        header:SetText(text)
        column.y = column.y - 24
    end

    section(leftColumn, "Restyled Tooltips")
    for index, heading in ipairs({ "Restyle", "Follow cursor" }) do
        local label = page:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", leftColumn.x + 244 + (index - 1) * 90, leftColumn.y)
        label:SetText(heading)
    end
    leftColumn.y = leftColumn.y - 16

    local function typeBox(x, key, title, text)
        local button = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        button:SetSize(24, 24)
        button:SetPoint("TOPLEFT", x, leftColumn.y + 4)
        if key then
            button:SetScript("OnClick", function(self) setOption(key, self:GetChecked() and true or false) end)
            button.refresh = function() button:SetChecked(ns.option(key)) end
            controls[#controls + 1] = button
        else
            button:Disable()
            -- A disabled button takes no hover unless told to; its tooltip still shows.
            if button.SetMotionScriptsWhileDisabled then button:SetMotionScriptsWhileDisabled(true) end
        end
        explain(button, title, text)
    end

    for _, tooltipType in ipairs(ns.TOOLTIP_TYPES) do
        local label = page:CreateFontString(nil, "ARTWORK",
            tooltipType.restyle and "GameFontHighlight" or "GameFontDisable")
        label:SetPoint("TOPLEFT", leftColumn.x + 8, leftColumn.y - 1)
        label:SetText(tooltipType.label)
        typeBox(leftColumn.x + 254, tooltipType.restyle, "Restyle " .. tooltipType.label:lower(), tooltipType.restyle
            and "Draws the PrettyTooltip panel. Off, this kind keeps the game's own tooltip."
            or "Not restyled yet; this kind keeps the game's own tooltip.")
        typeBox(leftColumn.x + 354, tooltipType.cursor, "Follow cursor", "Shows this kind's tooltip at the cursor "
            .. "when the game would put it in its default corner; bags and other panels keep theirs. Off, "
            .. "its position is left to the game and other addons.")
        leftColumn.y = leftColumn.y - 22
    end

    local MODIFIERS = {
        { "CTRL", "CTRL", "Hold CTRL to see the game's own tooltip instead of the panel." },
        { "ALT", "ALT", "Hold ALT to see the game's own tooltip instead of the panel." },
        { "NONE", "Never", "Never show the game's own tooltip in place of the panel." },
    }
    section(rightColumn, "Default Tooltip Modifier")
    for _, modifier in ipairs(MODIFIERS) do
        local value, label, note = modifier[1], modifier[2], modifier[3]
        local button = CreateFrame("CheckButton", nil, page, "UIRadioButtonTemplate")
        button:SetPoint("TOPLEFT", rightColumn.x + 8, rightColumn.y)
        local text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", button, "RIGHT", 6, 0)
        text:SetText(label)
        button:SetHitRectInsets(0, -(text:GetStringWidth() + 8), 0, 0)
        button:SetScript("OnClick", function()
            setOption("originalKey", value)
            refreshControls()
        end)
        button.refresh = function() button:SetChecked(ns.option("originalKey") == value) end
        controls[#controls + 1] = button
        explain(button, label, note)
        rightColumn.y = rightColumn.y - 22
    end
    rightColumn.y = rightColumn.y - 12

    page:SetScript("OnShow", refreshControls)
    -- Hooks the settings window calls on canvas pages: when it shows them, and
    -- from its Defaults button.
    page.OnRefresh = refreshControls
    page.OnDefault = function()
        ns.resetOptions()
        refreshControls()
    end

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        category = Settings.RegisterCanvasLayoutCategory(page, page.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(page)
    end
    refreshControls()
end

function ns.openSettings()
    if category and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(page)
    end
end
