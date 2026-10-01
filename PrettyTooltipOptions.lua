-- Saved settings and the options page. Loads first so the other files can
-- read settings; values are looked up at use time because saved variables
-- arrive after the files run.
local addonName, ns = ...

local DEFAULTS = {
    iconRight = false,
    statColors = true,
    qualityTint = true,
    statMarkers = true,
    itemLevelBadge = true,
    spellPanels = true,
    -- Only takes effect while DialogueUI is installed.
    dialogueBackdrop = true,
    -- "ALT", "CTRL", or "NONE". Shift is the game's comparison key.
    originalKey = "ALT",
}

function ns.option(key)
    local db = PrettyTooltipDB
    if type(db) == "table" and db[key] ~= nil then return db[key] end
    return DEFAULTS[key]
end

local function setOption(key, value)
    if type(PrettyTooltipDB) ~= "table" then PrettyTooltipDB = {} end
    PrettyTooltipDB[key] = value
end

function ns.originalKeyDown()
    local key = ns.option("originalKey")
    if key == "ALT" then return IsAltKeyDown() end
    if key == "CTRL" then return IsControlKeyDown() end
    return false
end

-- Whether a MODIFIER_STATE_CHANGED key is the one that shows the original.
function ns.isOriginalKey(key)
    local option = ns.option("originalKey")
    if option == "ALT" then return key == "LALT" or key == "RALT" end
    if option == "CTRL" then return key == "LCTRL" or key == "RCTRL" end
    return false
end

local page = CreateFrame("Frame")
page.name = "PrettyTooltip"
-- Created hidden, or the settings window never fires OnShow on first open.
page:Hide()
local controls = {}

local function refreshControls()
    for _, control in ipairs(controls) do control.refresh() end
end

local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("PrettyTooltip")
local subtitle = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
subtitle:SetText("A full reskin of item and spell tooltips. Changes apply the next time a tooltip opens.")

local y = -66

local function section(text)
    local header = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", 16, y)
    header:SetText(text)
    y = y - 24
end

local function checkbox(label, description, isChecked, onClick, isAvailable)
    local button = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    button:SetSize(24, 24)
    button:SetPoint("TOPLEFT", 20, y)
    local text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", button, "RIGHT", 4, 1)
    text:SetText(label)
    y = y - 22
    if description then
        local note = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        note:SetPoint("TOPLEFT", 48, y)
        note:SetWidth(520)
        note:SetJustifyH("LEFT")
        note:SetText(description)
        y = y - (note:GetStringHeight() + 10)
    else
        y = y - 6
    end
    button:SetScript("OnClick", function(self)
        onClick(self:GetChecked() and true or false)
        refreshControls()
    end)
    button.refresh = function()
        button:SetChecked(isChecked())
        local available = not isAvailable or isAvailable()
        button:SetEnabled(available)
        text:SetFontObject(available and "GameFontHighlight" or "GameFontDisable")
    end
    controls[#controls + 1] = button
end

local function toggle(key, label, description, isAvailable)
    checkbox(label, description,
        function() return ns.option(key) end,
        function(checked) setOption(key, checked) end,
        isAvailable)
end

local function isInstalled(addon)
    if not (C_AddOns and C_AddOns.GetAddOnInfo) then return false end
    local ok, name, _, _, _, reason = pcall(C_AddOns.GetAddOnInfo, addon)
    return ok and name ~= nil and reason ~= "MISSING"
end

-- One of several values, drawn as checkboxes that behave as radio buttons.
local function choice(key, value, label, description)
    checkbox(label, description,
        function() return ns.option(key) == value end,
        function() setOption(key, value) end)
end

section("Layout")
toggle("iconRight", "Show the icon on the right",
    "Moves the item or spell icon, and the item level badge under it, to the right of the name.")
toggle("itemLevelBadge", "Show the item level badge",
    "The small iLvl box under an equipment icon.")
toggle("statMarkers", "Show stat markers",
    "The small diamond before each stat; enchants use a green one.")
toggle("dialogueBackdrop", "Use DialogueUI's backdrop",
    "Draws the panel on DialogueUI's dark textured background, read from that addon's "
        .. "folder. Needs DialogueUI installed; off, or without it, the panel is a plain "
        .. "dark gradient.",
    function() return isInstalled("DialogueUI") end)

section("Colors")
toggle("statColors", "Color stats by category",
    "Teal for attributes, orange for attack, blue for defense, purple for magic, "
        .. "green for healing, and the school colors. Off, every stat is parchment.")
toggle("qualityTint", "Tint the panel",
    "Washes the panel in the item's quality color, or the spell's school or resource. "
        .. "Off, every panel is neutral; the name keeps its quality color.")

section("Spells")
toggle("spellPanels", "Restyle spell tooltips",
    "Off, spells keep the game's tooltip; items are still restyled.")

section("Original tooltip")
choice("originalKey", "ALT", "Hold ALT to see the original")
choice("originalKey", "CTRL", "Hold CTRL to see the original")
choice("originalKey", "NONE", "Never show the original")

page:SetScript("OnShow", refreshControls)
-- Hooks the settings window calls on canvas pages: when it shows them, and
-- from its Defaults button.
page.OnRefresh = refreshControls
page.OnDefault = function()
    PrettyTooltipDB = {}
    refreshControls()
end

-- Saved settings arrive after this file runs.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    refreshControls()
end)

local category
if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    category = Settings.RegisterCanvasLayoutCategory(page, page.name)
    Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(page)
end

SLASH_PRETTYTOOLTIP1 = "/prettytooltip"
SLASH_PRETTYTOOLTIP2 = "/ptip"
SlashCmdList.PRETTYTOOLTIP = function()
    if category and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(page)
    end
end
