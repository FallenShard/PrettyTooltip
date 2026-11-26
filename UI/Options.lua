-- Settings-page presentation and registration. The shared API lives in Core/Settings.lua.
local _, ns = ...
local L = ns.L

local page, category
ns.Options = {}

-- Called by the entry file after saved settings arrive.
function ns.Options.register()
    if page then return end
    page = CreateFrame("Frame")
    page.name = "PrettyTooltip"
    -- Created hidden, or the settings window never fires OnShow on first open.
    page:Hide()
    local pageTitle = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    pageTitle:SetPoint("TOPLEFT", 16, -16)
    pageTitle:SetText("PrettyTooltip")
    local subtitle = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", pageTitle, "BOTTOMLEFT", 0, -6)
    subtitle:SetText(L["A full reskin of tooltips. Changes apply the next time a tooltip opens."])

    local editorButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    editorButton:SetSize(180, 24)
    editorButton:SetPoint("TOPLEFT", 16, -64)
    editorButton:SetText(L["Open the Style Editor"])

    -- Explanations show on hover, which keeps the page short.
    local function explain(widget, title, text)
        widget:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L[title], 1, 1, 1)
            GameTooltip:AddLine(L[text], nil, nil, nil, true)
            GameTooltip:Show()
        end)
        widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    explain(editorButton, "Style Editor", "Every setting, with a live sample: which kinds of tooltip are restyled "
        .. "and follow the cursor, the modifier keys, and the look of each kind, down to the font and color of "
        .. "every part. Also /ptip.")
    -- Opens over the settings window, which is left as it is: closing it from
    -- here would run its code under the addon's taint.
    editorButton:SetScript("OnClick", function()
        if ns.openEditor then ns.openEditor() end
    end)

    -- The canvas page's Defaults button still resets all addon settings.
    page.OnDefault = function()
        ns.resetOptions()
        if ns.refreshEditorStyle then ns.refreshEditorStyle() end
    end

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        category = Settings.RegisterCanvasLayoutCategory(page, page.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(page)
    end
end

-- The game's settings window does not open in combat; the player is told so
-- instead of nothing happening. True when it opened.
function ns.openSettings()
    if InCombatLockdown() then
        print(L["PrettyTooltip: the options cannot open during combat. Try again once it ends."])
        return false
    end
    if category and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(page)
    end
    return true
end
