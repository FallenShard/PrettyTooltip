-- Saved settings and the options page. Loads first so the other files can
-- read settings; values are looked up at use time because saved variables
-- arrive after the files run.
local addonName, ns = ...

local DEFAULTS = {
    iconRight = false,
    itemPanels = true,
    objectPanels = true,
    cursorObjects = true,
    statColors = true,
    qualityTint = true,
    statMarkers = true,
    itemLevelBadge = true,
    separators = true,
    spellPanels = true,
    -- Only takes effect while DialogueUI is installed.
    dialogueBackdrop = true,
    -- "ALT", "CTRL", or "NONE". Shift is the game's comparison key.
    originalKey = "ALT",
    bodyFont = nil,
    titleFont = nil,
    -- "NONE", "OUTLINE", or "THICKOUTLINE", for elements without their own.
    outline = "NONE",
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

-- kind: "item" (default), "spell", "object", or "shared" by all. color is where the picker starts
-- while the color is automatic.
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
        kind = "shared" },
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
    { key = "objectTitle", label = "Object name", size = 17, title = true,
        color = { .96, .92, .84 }, kind = "object" },
    { key = "objectKind", label = "Kind of object", size = 12, color = { .9, .9, .9 },
        kind = "object", note = "Tinted by the skill it needs, unless set." },
    { key = "objectDetails", label = "Skill and requirements", size = 12,
        color = { .82, .78, .71 }, kind = "object",
        note = "The skill in its skill-up color, unmet requirements red, unless set." },
    { key = "objectQuests", label = "Quest lines", size = 12, color = { .90, .85, .74 },
        kind = "object", note = "Quest names gold, finished objectives green, unless set." },
    { key = "objectPrices", label = "Prices", size = 11, color = { .88, .78, .60 },
        kind = "object", note = "The yielded item's sell price, and its auction price with Auctionator." },
}
-- types are Enum.TooltipDataType names; ones missing on this client are skipped.
ns.TOOLTIP_KINDS = {
    { label = "Items", restyle = "itemPanels", cursor = "cursorItems", types = { "Item" } },
    { label = "Spells", restyle = "spellPanels", cursor = "cursorSpells", types = { "Spell" } },
    { label = "Players and NPCs", cursor = "cursorUnits", types = { "Unit", "Corpse" } },
    { label = "Buffs and debuffs", cursor = "cursorAuras", types = { "UnitAura" } },
    { label = "Herbs, ore, chests, and other objects", restyle = "objectPanels",
        cursor = "cursorObjects", types = { "Object" } },
    { label = "Quests", cursor = "cursorQuests", types = { "Quest", "QuestPartyProgress" } },
    { label = "Currencies", cursor = "cursorCurrencies", types = { "Currency" } },
    { label = "Dungeon and raid lockouts", cursor = "cursorLockouts", types = { "InstanceLock" } },
    { label = "Pet abilities", cursor = "cursorPetActions", types = { "PetAction" } },
    { label = "Minimap", cursor = "cursorMinimap", types = { "MinimapMouseover" } },
    { label = "Mounts, toys, and pets", cursor = "cursorCollections",
        types = { "Mount", "Toy", "CompanionPet", "BattlePet" } },
    { label = "Achievements", cursor = "cursorAchievements", types = { "Achievement" } },
}

local ELEMENT_BY_KEY = {}
for _, element in ipairs(ns.ELEMENTS) do ELEMENT_BY_KEY[element.key] = element end
ns.ELEMENT_BY_KEY = ELEMENT_BY_KEY

-- Saved by name; LibSharedMedia lists the game's faces too, under its own names.
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

function ns.style(key)
    local element = ELEMENT_BY_KEY[key]
    local outline = ns.elementSetting(key, "outline") or ns.option("outline")
    local color = ns.elementSetting(key, "color")
    if type(color) ~= "table" then color = nil end
    -- Names are in capitals unless turned off; other parts only when turned on.
    local caps = ns.elementSetting(key, "caps")
    if caps == nil then caps = element.title == true end
    return {
        key = key,
        title = element.title,
        size = tonumber(ns.elementSetting(key, "size")) or element.size,
        font = ns.fontPath(ns.elementSetting(key, "font")),
        flags = (outline == "OUTLINE" or outline == "THICKOUTLINE") and outline or "",
        color = color and { color[1], color[2], color[3] },
        caps = caps,
    }
end

function ns.originalKeyDown()
    local key = ns.option("originalKey")
    if key == "ALT" then return IsAltKeyDown() end
    if key == "CTRL" then return IsControlKeyDown() end
    return false
end

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

local function isInstalled(addon)
    if not (C_AddOns and C_AddOns.GetAddOnInfo) then return false end
    local ok, name, _, _, _, reason = pcall(C_AddOns.GetAddOnInfo, addon)
    return ok and name ~= nil and reason ~= "MISSING"
end
ns.isInstalled = isInstalled

section("Restyled Tooltips")
local kindsNote = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
kindsNote:SetPoint("TOPLEFT", 20, y)
kindsNote:SetWidth(560)
kindsNote:SetJustifyH("LEFT")
kindsNote:SetText("Restyle draws the PrettyTooltip panel; a kind that is off keeps the game's "
    .. "own tooltip, and greyed kinds are not restyled yet. Follow cursor moves the kind's "
    .. "mouse-over tooltip to the cursor; off, its position is left to the game and other addons.")
y = y - kindsNote:GetStringHeight() - 10
for index, heading in ipairs({ "Restyle", "Follow cursor" }) do
    local label = page:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 260 + (index - 1) * 90, y)
    label:SetText(heading)
end
y = y - 16

local function kindBox(x, key)
    local button = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    button:SetSize(24, 24)
    button:SetPoint("TOPLEFT", x, y + 4)
    if key then
        button:SetScript("OnClick", function(self) setOption(key, self:GetChecked() and true or false) end)
        button.refresh = function() button:SetChecked(ns.option(key)) end
        controls[#controls + 1] = button
    else
        button:Disable()
    end
end

for _, kind in ipairs(ns.TOOLTIP_KINDS) do
    local label = page:CreateFontString(nil, "ARTWORK",
        kind.restyle and "GameFontHighlight" or "GameFontDisable")
    label:SetPoint("TOPLEFT", 24, y - 1)
    label:SetText(kind.label)
    kindBox(270, kind.restyle)
    kindBox(370, kind.cursor)
    y = y - 22
end
y = y - 12

local MODIFIERS = { { "CTRL", "CTRL" }, { "ALT", "ALT" }, { "NONE", "Never show default tooltip" } }
section("Default Tooltip Modifier")
local modifierNote = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
modifierNote:SetPoint("TOPLEFT", 20, y)
modifierNote:SetWidth(560)
modifierNote:SetJustifyH("LEFT")
modifierNote:SetText("Hold this key to see the game's own tooltip instead of the panel.")
y = y - 20
for index, modifier in ipairs(MODIFIERS) do
    local value, label = modifier[1], modifier[2]
    local button = CreateFrame("CheckButton", nil, page, "UIRadioButtonTemplate")
    button:SetPoint("TOPLEFT", 24 + (index - 1) * 120, y)
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
end
y = y - 24

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

SLASH_PRETTYTOOLTIP1 = "/prettytooltip"
SLASH_PRETTYTOOLTIP2 = "/ptip"
-- Prints the shown tooltip's raw data, to see what a kind of tooltip carries.
local function dumpTooltip()
    local data = GameTooltip:IsShown() and GameTooltip.GetTooltipData and GameTooltip:GetTooltipData()
    if type(data) ~= "table" then
        print("PrettyTooltip: hover something first; there is no tooltip data to dump.")
        return
    end
    local function names(enum)
        local found = {}
        for name, value in pairs(enum or {}) do found[value] = name end
        return found
    end
    local types, lineTypes = names(Enum.TooltipDataType), names(Enum.TooltipDataLineType)
    local function show(value)
        if type(value) == "table" and value.GenerateHexColor then return "#" .. value:GenerateHexColor() end
        if type(value) == "table" then return "{...}" end
        return tostring(value)
    end
    local fields = {}
    for key, value in pairs(data) do
        if key ~= "lines" then fields[#fields + 1] = key .. "=" .. show(value) end
    end
    print("PrettyTooltip dump: " .. tostring(types[data.type] or data.type) .. "  " .. table.concat(fields, "  "))
    for index, line in ipairs(data.lines or {}) do
        local parts = {}
        for key, value in pairs(line) do
            if key ~= "type" then parts[#parts + 1] = key .. "=" .. show(value) end
        end
        table.sort(parts)
        print(index .. ". " .. tostring(lineTypes[line.type] or line.type) .. "  " .. table.concat(parts, "  "))
    end
end

SlashCmdList.PRETTYTOOLTIP = function(message)
    local wanted = (message or ""):match("^%s*(.-)%s*$"):lower()
    if wanted == "dump" then
        -- Secret values cannot be printed in some situations.
        if not pcall(dumpTooltip) then print("PrettyTooltip: this tooltip cannot be read right now.") end
        return
    end
    if wanted ~= "options" and ns.openEditor then
        ns.openEditor()
    else
        ns.openSettings()
    end
end
