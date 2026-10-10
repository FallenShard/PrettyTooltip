-- Saved settings and the options page. Loads first so the other files can
-- read settings; values are looked up at use time because saved variables
-- arrive after the files run.
local addonName, ns = ...

local DEFAULTS = {
    iconRight = false,
    itemPanels = true,
    -- The game's item tooltip with shortened, colored stats, instead of the panel.
    itemLite = false,
    objectPanels = true,
    unitPanels = true,
    auraPanels = true,
    questPanels = true,
    iconItems = true,
    iconSpells = true,
    iconObjects = true,
    iconUnits = true,
    iconAuras = true,
    iconQuests = false,
    cursorObjects = true,
    statColors = true,
    qualityTint = true,
    statMarkers = true,
    itemLevelBadge = true,
    separators = true,
    spellPanels = true,
    disenchant = true,
    sellPrice = true,
    spellPower = true,
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

-- Counts setting changes, so a panel drawn before one is drawn again.
ns.settingsVersion = 0
local function changed() ns.settingsVersion = ns.settingsVersion + 1 end

local function setOption(key, value)
    if type(PrettyTooltipDB) ~= "table" then PrettyTooltipDB = {} end
    PrettyTooltipDB[key] = value
    changed()
end
ns.setOption = setOption

-- tooltipType: "item" (default), "spell", "object", "unit", "aura", "quest", or "shared" by all. color is where the picker starts
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
        tooltipType = "shared" },
    { key = "footer", label = "Footer", size = 11, color = { .82, .78, .71 },
        note = "Durability, crafter, requirements, and sell price." },
    { key = "badge", label = "Item level badge", size = 10, color = { .9, .9, .9 } },
    { key = "createdName", label = "Crafted item's name", size = 14, title = true, color = { 1, 1, 1 },
        note = "On recipes; quality color unless set." },
    { key = "reagents", label = "Reagents", size = 12, color = { .90, .85, .74 },
        note = "On recipes; the count you carry red while short, unless set." },
    { key = "caption", label = "Section captions", size = 9, color = { .60, .57, .52 }, caps = true,
        note = "Creates and Reagents on recipes." },
    { key = "disenchant", label = "Disenchant results", size = 11, color = { .82, .78, .71 },
        note = "The Enchanting needed red while yours is too low, grey without Enchanting, unless set." },
    { key = "spellTitle", label = "Spell name", size = 17, title = true,
        color = { .96, .92, .84 }, tooltipType = "spell" },
    { key = "spellBadges", label = "School and rank badges", size = 10, color = { .9, .9, .9 },
        tooltipType = "spell", note = "Colored by school unless set." },
    { key = "spellValues", label = "Cost, cast, cooldown, range", size = 13,
        color = { .96, .92, .84 }, tooltipType = "spell",
        note = "The cost takes its resource color unless set." },
    { key = "spellCaptions", label = "Strip captions", size = 9, color = { .60, .57, .52 },
        tooltipType = "spell" },
    { key = "spellDetails", label = "Requirements and details", size = 11,
        color = { .82, .78, .71 }, tooltipType = "spell",
        note = "Unmet requirements red, time remaining orange, unless set." },
    { key = "spellText", label = "Description", size = 12, color = { .92, .87, .76 },
        tooltipType = "spell", note = "Numbers in the school color unless set." },
    { key = "objectTitle", label = "Object name", size = 17, title = true,
        color = { .96, .92, .84 }, tooltipType = "object" },
    { key = "objectKind", label = "Kind of object", size = 12, color = { .9, .9, .9 },
        tooltipType = "object", note = "Tinted by the skill it needs, unless set." },
    { key = "objectDetails", label = "Skill and requirements", size = 12,
        color = { .82, .78, .71 }, tooltipType = "object",
        note = "The skill in its skill-up color, unmet requirements red, unless set." },
    { key = "objectQuests", label = "Quest lines", size = 12, color = { .90, .85, .74 },
        tooltipType = "object", note = "Quest names gold, finished objectives green, unless set." },
    { key = "objectPrices", label = "Prices", size = 11, color = { .88, .78, .60 },
        tooltipType = "object", note = "The yielded item's sell price, and its auction price with Auctionator." },
    { key = "unitName", label = "Name", size = 17, title = true, color = { 1, 1, 1 },
        tooltipType = "unit", note = "Class color for players, reaction color for NPCs, unless set." },
    { key = "unitGuild", label = "Guild or role", size = 12, color = { .9, .9, .9 }, tooltipType = "unit" },
    { key = "unitInfo", label = "Level, race, and class", size = 12, color = { .82, .78, .71 },
        tooltipType = "unit", note = "The level in its difficulty color, unless set." },
    { key = "unitBadges", label = "Badges", size = 10, color = { .9, .9, .9 }, tooltipType = "unit",
        note = "Elite, rare, faction, PvP, AFK, and dead." },
    { key = "unitHealth", label = "Health", size = 11, color = { .82, .78, .71 }, tooltipType = "unit" },
    { key = "unitDetails", label = "Target and owner", size = 11, color = { .82, .78, .71 },
        tooltipType = "unit" },
    { key = "unitQuests", label = "Quest lines", size = 12, color = { .90, .85, .74 },
        tooltipType = "unit", note = "Quest names gold, finished objectives green, unless set." },
    { key = "auraName", label = "Name", size = 15, title = true, color = { .96, .92, .84 },
        tooltipType = "aura" },
    { key = "auraBadges", label = "Badges", size = 10, color = { .9, .9, .9 }, tooltipType = "aura",
        note = "Buff or debuff, dispel type in the game's colors, and stacks." },
    { key = "auraText", label = "Description", size = 12, color = { .92, .87, .76 },
        tooltipType = "aura", note = "Numbers in the aura's color unless set." },
    { key = "auraTime", label = "Time and caster", size = 11, color = { .88, .78, .60 },
        tooltipType = "aura" },
    { key = "questTitle", label = "Quest name", size = 16, title = true, color = { .96, .92, .84 },
        tooltipType = "quest" },
    { key = "questInfo", label = "Dungeon", size = 12, color = { .82, .78, .71 }, tooltipType = "quest" },
    { key = "questBadges", label = "Badges", size = 10, color = { .9, .9, .9 }, tooltipType = "quest",
        note = "The level in its difficulty color, tags, and where the quest stands." },
    { key = "questText", label = "Description", size = 12, color = { .86, .74, .45 }, tooltipType = "quest" },
    { key = "questCaption", label = "Section caption", size = 9, color = { .60, .57, .52 },
        tooltipType = "quest", caps = true },
    { key = "questObjectives", label = "Objectives", size = 12, color = { .90, .85, .74 },
        tooltipType = "quest", note = "Finished objectives green unless set." },
}
-- types are Enum.TooltipDataType names; ones missing on this client are skipped.
ns.TOOLTIP_TYPES = {
    { label = "Items", restyle = "itemPanels", cursor = "cursorItems", types = { "Item" } },
    { label = "Spells", restyle = "spellPanels", cursor = "cursorSpells", types = { "Spell" } },
    { label = "Players and NPCs", restyle = "unitPanels", cursor = "cursorUnits",
        types = { "Unit", "Corpse" } },
    { label = "Buffs and debuffs", restyle = "auraPanels", cursor = "cursorAuras",
        types = { "UnitAura" } },
    { label = "Herbs, ore, chests, and other objects", restyle = "objectPanels",
        cursor = "cursorObjects", types = { "Object" } },
    { label = "Quests", restyle = "questPanels", cursor = "cursorQuests", types = { "Quest", "QuestPartyProgress" } },
    { label = "Currencies", cursor = "cursorCurrencies", types = { "Currency" } },
    { label = "Dungeon and raid lockouts", cursor = "cursorLockouts", types = { "InstanceLock" } },
    { label = "Pet abilities", cursor = "cursorPetActions", types = { "PetAction" } },
    { label = "Minimap", cursor = "cursorMinimap", types = { "MinimapMouseover" } },
    { label = "Mounts, toys, and pets", cursor = "cursorCollections",
        types = { "Mount", "Toy", "CompanionPet", "BattlePet" } },
    { label = "Achievements", cursor = "cursorAchievements", types = { "Achievement" } },
    { label = "Totems", cursor = "cursorTotems", types = { "Totem" } },
    { label = "Flyout buttons", cursor = "cursorFlyouts", types = { "Flyout" } },
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
    changed()
end

function ns.resetElement(key)
    local styles = savedStyles(false)
    if styles then styles[key] = nil end
    changed()
end

-- Settings kept per type of tooltip are named with these, as iconItems.
ns.TYPE_SUFFIX = { item = "Items", spell = "Spells", object = "Objects", unit = "Units", aura = "Auras", quest = "Quests" }

-- The header band's opacity at an edge ("Top" or "Bottom") for a tooltip type; one
-- without its own follows the setting shared by all, and nil means the default.
function ns.headerAlpha(tooltipType, edge)
    local suffix = ns.TYPE_SUFFIX[tooltipType]
    local own = suffix and ns.option("header" .. edge .. "Alpha" .. suffix)
    if own ~= nil then return own end
    return ns.option("header" .. edge .. "Alpha")
end

function ns.resetStyles()
    if type(PrettyTooltipDB) ~= "table" then return end
    PrettyTooltipDB.styles = nil
    PrettyTooltipDB.bodyFont, PrettyTooltipDB.titleFont, PrettyTooltipDB.outline = nil, nil, nil
    PrettyTooltipDB.headerTopAlpha, PrettyTooltipDB.headerBottomAlpha = nil, nil
    for _, suffix in pairs(ns.TYPE_SUFFIX) do
        PrettyTooltipDB["headerTopAlpha" .. suffix] = nil
        PrettyTooltipDB["headerBottomAlpha" .. suffix] = nil
        PrettyTooltipDB["backdropAlpha" .. suffix] = nil
        PrettyTooltipDB["glowAlpha" .. suffix] = nil
        PrettyTooltipDB["footerAlpha" .. suffix] = nil
    end
    changed()
end

function ns.style(key)
    local element = ELEMENT_BY_KEY[key]
    local outline = ns.elementSetting(key, "outline") or ns.option("outline")
    local color = ns.elementSetting(key, "color")
    if type(color) ~= "table" then color = nil end
    -- Names are in capitals unless turned off; other parts only when turned on.
    local caps = ns.elementSetting(key, "caps")
    if caps == nil then caps = element.caps or element.title == true end
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

explain(editorButton, "Style editor", "The look of the tooltip: fonts, sizes, and colors for every part, "
    .. "the icon side, the badge, markers, and tints, with a live sample. Also /ptip.")
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

local function isInstalled(addon)
    if not (C_AddOns and C_AddOns.GetAddOnInfo) then return false end
    local ok, name, _, _, _, reason = pcall(C_AddOns.GetAddOnInfo, addon)
    return ok and name ~= nil and reason ~= "MISSING"
end
ns.isInstalled = isInstalled

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

local function detailBox(key, label, note)
    local box = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    box:SetSize(24, 24)
    box:SetPoint("TOPLEFT", rightColumn.x + 4, rightColumn.y + 4)
    local text = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", box, "RIGHT", 4, 0)
    text:SetText(label)
    box:SetHitRectInsets(0, -(text:GetStringWidth() + 8), 0, 0)
    box:SetScript("OnClick", function(self) setOption(key, self:GetChecked() and true or false) end)
    box.refresh = function() box:SetChecked(ns.option(key)) end
    controls[#controls + 1] = box
    explain(box, label, note)
    rightColumn.y = rightColumn.y - 24
end

section(rightColumn, "Item Details")
detailBox("itemLite", "Lite item tooltips", "Keep the game's own item tooltip, with its Equip effects "
    .. "shortened, as +1% Critical Strike Chance, and its stats colored. Hold the modifier for the full wording. "
    .. "The panel's item settings, such as disenchant results, do not apply.")
detailBox("disenchant", "Disenchant results", "Green, blue, and purple armor and weapons list what "
    .. "they disenchant into, with each result's chance and the Enchanting it needs; with "
    .. "Auctionator, the expected value.")
detailBox("sellPrice", "Sell price", "The vendor price in the footer; for a stack, the price of "
    .. "one and of the whole stack.")
rightColumn.y = rightColumn.y - 12

section(rightColumn, "Spell Details")
detailBox("spellPower", "Spell power breakdown", "Under the description, each amount's spell power "
    .. "coefficient and its split into base and spell power. No game API has coefficients: they follow "
    .. "Classic's rules, checked against Forever's spell data, and ones marked ~ are estimates.")

page:SetScript("OnShow", refreshControls)
-- Hooks the settings window calls on canvas pages: when it shows them, and
-- from its Defaults button.
page.OnRefresh = refreshControls
page.OnDefault = function()
    PrettyTooltipDB = {}
    changed()
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
-- Prints the shown tooltip's raw data, to see what a type of tooltip carries.
local function dumpTooltip()
    -- A clicked chat link opens in its own tooltip.
    local tooltip = GameTooltip:IsShown() and GameTooltip or ItemRefTooltip
    if not (tooltip and tooltip:IsShown()) then
        print("PrettyTooltip: hover something first; there is no tooltip to dump.")
        return
    end
    local data = tooltip.GetTooltipData and tooltip:GetTooltipData()
    if type(data) ~= "table" then
        -- Filled by an addon with lines alone, as Questie's quest links.
        print("PrettyTooltip dump: no tooltip data; the lines shown:")
        for index = 1, tooltip:NumLines() do
            local left = _G[tooltip:GetName() .. "TextLeft" .. index]
            local right = _G[tooltip:GetName() .. "TextRight" .. index]
            local text = (left and left:GetText() or "") .. (right and right:GetText() and "  ||  " .. right:GetText() or "")
            print(index .. ". " .. text:gsub("|", "||"))
        end
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
    if wanted == "perf" then
        if ns.perfCapture then ns.perfCapture(5) end
        return
    end
    if wanted == "anchors" then
        if ns.dumpAnchors then pcall(ns.dumpAnchors) end
        return
    end
    -- /ptip capture <name>, list, or clear: tooltips saved as test fixtures.
    local command, argument = wanted:match("^(%S+)%s*(.-)$")
    if command == "capture" and ns.capture then
        if argument == "list" then
            ns.listCaptures()
        elseif argument == "clear" then
            ns.clearCaptures()
        else
            ns.capture(argument)
        end
        return
    end
    if wanted == "dump" then
        -- Secret values cannot be printed in some situations.
        local ok, problem = pcall(dumpTooltip)
        if not ok then print("PrettyTooltip: this tooltip cannot be read right now (" .. tostring(problem) .. ").") end
        return
    end
    if wanted ~= "options" and ns.openEditor then
        ns.openEditor()
    else
        ns.openSettings()
    end
end
