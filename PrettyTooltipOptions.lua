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
    -- Font names for all text and for names; unset follows the game's
    -- tooltip fonts (Expressway Bold for names with EllesmereUI).
    bodyFont = nil,
    titleFont = nil,
    -- "NONE", "OUTLINE", or "THICKOUTLINE", for elements without their own.
    outline = "NONE",
    -- The header band's opacity at its top and bottom edges, 0 to 1; unset
    -- follows the backdrop.
    headerTopAlpha = nil,
    headerBottomAlpha = nil,
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
ns.setOption = setOption

-- Every text element the editor can restyle, in panel order. kind is the
-- panel it belongs to: "item" (the default), "spell", or "both". size is the
-- default; title elements default to the name font. color is only where the
-- color picker starts while the color is automatic.
ns.ELEMENTS = {
    { key = "title", label = "Item name", size = 19, title = true, color = { 1, 1, 1 },
        note = "Quality color unless set." },
    { key = "subtitle", label = "Type and slot", size = 13, color = { .9, .9, .9 },
        note = "Half the quality color, red for a type you cannot use." },
    { key = "header", label = "Binding and level", size = 12, color = { .78, .72, .63 },
        note = "The required level is red while you are below it." },
    { key = "dps", label = "Damage per second", size = 18, color = { .95, .91, .84 } },
    { key = "damage", label = "Damage and speed", size = 12, color = { .71, .72, .73 } },
    { key = "armor", label = "Armor", size = 16, color = { .95, .91, .84 } },
    { key = "stats", label = "Stats", size = 13, color = { .90, .85, .74 },
        note = "Colored by category unless set." },
    { key = "equipEffects", label = "Equip effects", size = 13, color = { .48, .88, .48 } },
    { key = "enchants", label = "Enchants", size = 13, color = { .30, .90, .30 } },
    { key = "effects", label = "Use and other effects", size = 13, color = { .48, .88, .48 } },
    { key = "flavor", label = "Flavor text", size = 12, color = { .86, .74, .45 } },
    { key = "setName", label = "Set name and count", size = 15, title = true,
        color = { 1, .76, .18 } },
    { key = "setItems", label = "Set pieces", size = 12, color = { .94, .89, .77 },
        note = "Owned pieces bright, missing ones grey, unless set." },
    { key = "setBonuses", label = "Set bonuses", size = 12, color = { .48, .88, .48 },
        note = "Active bonuses green, inactive ones grey, unless set." },
    { key = "extras", label = "Other addons' rows", size = 11, color = { .60, .60, .63 },
        kind = "both" },
    { key = "changes", label = "Stat changes if replaced", size = 12, color = { .90, .85, .74 },
        note = "On the Equipped panel; gains green, losses red, unless set." },
    { key = "footer", label = "Footer", size = 11, color = { .82, .78, .71 },
        note = "Durability, crafter, requirements, and sell price." },
    { key = "badge", label = "Item level badge", size = 10, color = { .9, .9, .9 } },
    { key = "spellTitle", label = "Spell name", size = 17, title = true,
        color = { .96, .92, .84 }, kind = "spell" },
    { key = "spellBadges", label = "School and rank badges", size = 10, color = { .9, .9, .9 },
        kind = "spell", note = "Colored by school unless set." },
    { key = "spellValues", label = "Cost, cast, cooldown, range", size = 13,
        color = { .96, .92, .84 }, kind = "spell",
        note = "The cost takes its resource color unless set." },
    { key = "spellCaptions", label = "Strip captions", size = 9, color = { .60, .57, .52 },
        kind = "spell" },
    { key = "spellDetails", label = "Requirements and details", size = 11,
        color = { .82, .78, .71 }, kind = "spell",
        note = "Unmet requirements red, time remaining orange, unless set." },
    { key = "spellText", label = "Description", size = 12, color = { .92, .87, .76 },
        kind = "spell", note = "Numbers in the school color unless set." },
}
local ELEMENT_BY_KEY = {}
for _, element in ipairs(ns.ELEMENTS) do ELEMENT_BY_KEY[element.key] = element end
ns.ELEMENT_BY_KEY = ELEMENT_BY_KEY

-- Fonts are saved by name and looked up at use, so a font from another addon
-- follows that addon. LibSharedMedia lists the game's faces too, under its
-- own names; these are for when no addon has loaded it.
local GAME_FONTS = {
    { "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
    { "Arial Narrow", "Fonts\\ARIALN.TTF" },
    { "Morpheus", "Fonts\\MORPHEUS.TTF" },
    { "Skurri", "Fonts\\SKURRI.TTF" },
}

local function sharedMedia()
    return LibStub and LibStub:GetLibrary("LibSharedMedia-3.0", true)
end

function ns.fontNames()
    local names = {}
    local media = sharedMedia()
    if media then
        for _, name in ipairs(media:List("font")) do names[#names + 1] = name end
    else
        for _, font in ipairs(GAME_FONTS) do names[#names + 1] = font[1] end
    end
    return names
end

-- Nil for no name, or a font that is no longer installed.
function ns.fontPath(name)
    if type(name) ~= "string" then return end
    local media = sharedMedia()
    if media and media:IsValid("font", name) then return media:Fetch("font", name, true) end
    for _, font in ipairs(GAME_FONTS) do
        if font[1] == name then return font[2] end
    end
end

local function savedStyles(create)
    if type(PrettyTooltipDB) ~= "table" then
        if not create then return end
        PrettyTooltipDB = {}
    end
    if type(PrettyTooltipDB.styles) ~= "table" then
        if not create then return end
        PrettyTooltipDB.styles = {}
    end
    return PrettyTooltipDB.styles
end

-- One saved field of an element (font, size, color, outline); nil follows
-- the default.
function ns.elementSetting(key, field)
    local styles = savedStyles(false)
    local saved = styles and styles[key]
    -- An explicit nil: callers pass the result straight to tonumber.
    if type(saved) ~= "table" then return nil end
    return saved[field]
end

function ns.setElementSetting(key, field, value)
    local styles = savedStyles(true)
    local saved = type(styles[key]) == "table" and styles[key] or {}
    saved[field] = value
    styles[key] = next(saved) and saved or nil
end

function ns.resetElement(key)
    local styles = savedStyles(false)
    if styles then styles[key] = nil end
end

function ns.resetStyles()
    if type(PrettyTooltipDB) ~= "table" then return end
    PrettyTooltipDB.styles = nil
    PrettyTooltipDB.bodyFont, PrettyTooltipDB.titleFont, PrettyTooltipDB.outline = nil, nil, nil
    PrettyTooltipDB.headerTopAlpha, PrettyTooltipDB.headerBottomAlpha = nil, nil
end

-- How an element draws: size, font path (nil for its default font), font
-- flags, and a custom color that replaces every color it would have had.
function ns.style(key)
    local element = ELEMENT_BY_KEY[key]
    local outline = ns.elementSetting(key, "outline") or ns.option("outline")
    local color = ns.elementSetting(key, "color")
    if type(color) ~= "table" then color = nil end
    return {
        key = key,
        title = element.title,
        size = tonumber(ns.elementSetting(key, "size")) or element.size,
        font = ns.fontPath(ns.elementSetting(key, "font")),
        flags = (outline == "OUTLINE" or outline == "THICKOUTLINE") and outline or "",
        color = color and { color[1], color[2], color[3] },
    }
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

-- The style editor is its own window; PrettyTooltipEditor.lua defines
-- ns.openEditor, unless the panel is off for this client.
local editorButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
editorButton:SetSize(180, 24)
editorButton:SetPoint("TOPLEFT", 16, -64)
editorButton:SetText("Open the style editor")
local editorNote = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
editorNote:SetPoint("LEFT", editorButton, "RIGHT", 10, 0)
editorNote:SetWidth(380)
editorNote:SetJustifyH("LEFT")
editorNote:SetText("The look of the tooltip: fonts, sizes, and colors for every part, "
    .. "the icon side, the badge, markers, and tints, with a live sample. Also /ptip.")
editorButton:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    if ns.openEditor then ns.openEditor() end
end)

local y = -102

local function section(text)
    local header = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", 16, y)
    header:SetText(text)
    y = y - 24
end

local function checkbox(label, description, isChecked, onClick)
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
    end
    controls[#controls + 1] = button
end

local function toggle(key, label, description)
    checkbox(label, description,
        function() return ns.option(key) end,
        function(checked) setOption(key, checked) end)
end

local function isInstalled(addon)
    if not (C_AddOns and C_AddOns.GetAddOnInfo) then return false end
    local ok, name, _, _, _, reason = pcall(C_AddOns.GetAddOnInfo, addon)
    return ok and name ~= nil and reason ~= "MISSING"
end
ns.isInstalled = isInstalled

-- One of several values, drawn as checkboxes that behave as radio buttons.
local function choice(key, value, label, description)
    checkbox(label, description,
        function() return ns.option(key) == value end,
        function() setOption(key, value) end)
end

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

function ns.openSettings()
    if category and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(page)
    end
end

-- "/ptip" opens the style editor, "/ptip options" the settings page.
SLASH_PRETTYTOOLTIP1 = "/prettytooltip"
SLASH_PRETTYTOOLTIP2 = "/ptip"
SlashCmdList.PRETTYTOOLTIP = function(message)
    local wanted = (message or ""):match("^%s*(.-)%s*$"):lower()
    if wanted ~= "options" and ns.openEditor then
        ns.openEditor()
    else
        ns.openSettings()
    end
end
