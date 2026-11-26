-- Shared settings and styles. Values are read at use time because saved
-- variables arrive after the files run; this file creates no UI or hooks.
local _, ns = ...
local colors = ns.Palette.roles
local TYPE_KEYS, LEGACY_KEYS = {}, {}

local DEFAULTS = {
    iconRight = false,
    -- "pretty" draws panels for the types turned on below; "blizzard" keeps
    -- the game's own tooltips everywhere.
    layout = "pretty",
    fadeTooltips = false,
    hideDelay = 1,
    fadeDuration = 1,
    itemPanels = true,
    -- The game's own item tooltip shortens Equip effects, in its colors but for magic.
    liteWording = true,
    objectPanels = true,
    unitPanels = true,
    auraPanels = true,
    -- A weapon imbue's buff button shows the imbue's panel, not its weapon's tooltip.
    imbuePanels = true,
    questPanels = true,
    macroPanels = true,
    petPanels = true,
    minimapPanels = true,
    taxiPanels = true,
    mailPanels = true,
    iconMail = true,
    iconItems = true,
    iconSpells = true,
    iconObjects = true,
    iconUnits = true,
    iconAuras = true,
    iconQuests = false,
    iconMacros = true,
    cursorObjects = true,
    cursorDisableInCombat = true,
    statColors = true,
    -- Cloth, leather, mail, and plate in their own colors in the item's subtitle.
    armorColors = false,
    qualityTint = true,
    statMarkers = true,
    -- A weapon's damage on the large line, its DPS and speed under it.
    swapDamage = false,
    itemLevelBadge = true,
    unitLevelBadge = true,
    -- A guild's realm beside its name, when it is another realm's.
    unitRealm = true,
    separators = true,
    spellPanels = true,
    disenchant = true,
    -- What herb and ore nodes and skinnable creatures give, on their panels.
    gatheringLoot = true,
    sellPrice = true,
    spellPower = true,
    -- Damage or healing per second and per mana, under the spell power breakdown.
    spellRates = true,
    -- The game's health bar at the bottom of unit panels.
    unitHealthBar = true,
    -- The item's, spell's, or NPC's ID under the other addons' rows.
    showIDs = true,
    -- "SHIFT" shows disenchant results, the spell power rows, gathering
    -- contents, and IDs only while it is held; "ALWAYS" shows them always.
    detailsKey = "SHIFT",
    -- Only takes effect while DialogueUI is installed.
    dialogueBackdrop = true,
    -- DialogueUI's brown paper for quests and quest items, when installed.
    questParchment = false,
    -- nil chooses: DialogueUI's art when installed, flat with EllesmereUI, else
    -- the game's own tooltip border. "native", "flat", or "dialogue" to pick one.
    backdropStyle = nil,
    -- The editor's frame treatment, independent of the tooltips it previews.
    editorStyle = "native",
    -- "ALT", "CTRL", or "NONE". Shift is the game's comparison key.
    originalKey = "ALT",
    bodyFont = nil,
    titleFont = nil,
    -- "NONE", "OUTLINE", or "THICKOUTLINE", for elements without their own.
    titleOutline = "NONE",
    bodyOutline = "NONE",
    -- The panels' inner padding, and the width a panel is at least.
    -- Every part's text size is multiplied by this.
    fontScale = 1,
    tooltipScale = 1,
    padding = 19,
    minWidth = 260,
    -- Multiply the space between rows, and around rules, dividers, and captions.
    rowSpacing = 1,
    sectionSpacing = 1,
    headerTopAlpha = nil,
    headerBottomAlpha = nil,
    backdropAlpha = .9,
    glowAlpha = 1,
    restyle = true,
}

-- Existing per-type keys remain readable. New overrides are kept together;
-- nothing is copied from the shared defaults into a type's settings.
function ns.tooltipSetting(tooltipType, key)
    local db = PrettyTooltipDB
    if type(db) ~= "table" then return nil end
    local types = db.tooltips
    local own = type(types) == "table" and types[tooltipType]
    if type(own) == "table" and own[key] ~= nil then return own[key] end
    local legacy = TYPE_KEYS[tooltipType] and TYPE_KEYS[tooltipType][key]
    if legacy then return db[legacy] end
    return nil
end

function ns.option(key, tooltipType)
    local legacy = LEGACY_KEYS[key]
    if legacy then return ns.option(legacy.key, legacy.tooltipType) end
    if tooltipType then
        local own = ns.tooltipSetting(tooltipType, key)
        if own ~= nil then return own end
    end
    local db = PrettyTooltipDB
    if type(db) == "table" and db[key] ~= nil then return db[key] end
    if tooltipType and DEFAULTS[key] == nil then
        local oldKey = TYPE_KEYS[tooltipType] and TYPE_KEYS[tooltipType][key]
        if oldKey and DEFAULTS[oldKey] ~= nil then return DEFAULTS[oldKey] end
        if key == "followCursor" then return false end
    end
    return DEFAULTS[key]
end

-- Saved and unlike the default. The options page once saved every box clicked,
-- so a saved value can be the default.
function ns.optionChanged(key)
    local legacy = LEGACY_KEYS[key]
    if legacy then return ns.tooltipSetting(legacy.tooltipType, legacy.key) ~= nil end
    local db = PrettyTooltipDB
    if type(db) ~= "table" or db[key] == nil then return false end
    -- A switch with no default listed is off.
    if db[key] == false and DEFAULTS[key] == nil then return false end
    return db[key] ~= DEFAULTS[key]
end

function ns.fadeTiming()
    local function seconds(key)
        local value = ns.util.number(ns.option(key))
        if not value or value ~= value then return 1 end
        return math.max(0, math.min(5, value))
    end
    return seconds("hideDelay"), seconds("fadeDuration")
end

function ns.spacing(key, tooltipType)
    local scale = ns.util.number(ns.option(key, tooltipType))
    if not scale or scale ~= scale then return 1 end
    return math.max(.5, math.min(1.5, scale))
end

function ns.tooltipScale(tooltipType)
    local scale = ns.util.number(ns.option("tooltipScale", tooltipType))
    if not scale or scale ~= scale then return 1 end
    return math.max(.5, math.min(1.5, scale))
end

-- Whether a type whose panel the setting `option` turns on draws it. Nothing
-- does while /ptip perf ab or /ptip bench measures the game's tooltips alone.
function ns.restyles(option)
    return not ns.suspended and ns.option("layout") ~= "blizzard" and ns.option(option) and true or false
end

function ns.editorStyle()
    if ns.option("editorStyle") == "flat" then
        return "flat"
    end
    return "native"
end

-- Counts setting changes, so a panel drawn before one is drawn again.
ns.settingsVersion = 0
local function changed() ns.settingsVersion = ns.settingsVersion + 1 end

-- What is saved for a setting: nil while it is at its default.
function ns.savedOption(key)
    local db = PrettyTooltipDB
    if type(db) == "table" then return db[key] end
    return nil
end

local function setOption(key, value)
    if type(PrettyTooltipDB) ~= "table" then PrettyTooltipDB = {} end
    local legacy = LEGACY_KEYS[key]
    local types = PrettyTooltipDB.tooltips
    local own = legacy and type(types) == "table" and types[legacy.tooltipType]
    if type(own) == "table" then own[legacy.key] = nil end
    PrettyTooltipDB[key] = value
    changed()
end
ns.setOption = setOption

function ns.setTooltipSetting(tooltipType, key, value)
    if type(PrettyTooltipDB) ~= "table" then PrettyTooltipDB = {} end
    local types = type(PrettyTooltipDB.tooltips) == "table" and PrettyTooltipDB.tooltips or {}
    local own = type(types[tooltipType]) == "table" and types[tooltipType] or {}
    own[key] = value
    types[tooltipType] = next(own) and own or nil
    PrettyTooltipDB.tooltips = next(types) and types or nil
    local legacy = TYPE_KEYS[tooltipType] and TYPE_KEYS[tooltipType][key]
    if legacy then PrettyTooltipDB[legacy] = nil end
    changed()
end

function ns.migrateOptions()
    local db = PrettyTooltipDB
    if type(db) ~= "table" then return end
    -- 1.3's item lite mode was the game's item tooltip; it is now items not restyled.
    if db.itemLite == true then db.itemPanels = false end
    db.itemLite = nil
    -- 1.4.1's custom timings were the only fade a player chose; its default mirrored the game's.
    if db.customFade == true then db.fadeTooltips = true end
    db.customFade = nil
    -- An outline once shared by titles and body text stands where neither has its own.
    local function splitOutline(own)
        if own.outline == nil then return end
        if own.titleOutline == nil then own.titleOutline = own.outline end
        if own.bodyOutline == nil then own.bodyOutline = own.outline end
        own.outline = nil
    end
    splitOutline(db)
    for _, own in pairs(type(db.tooltips) == "table" and db.tooltips or {}) do
        if type(own) == "table" then splitOutline(own) end
    end
end

function ns.resetOptions()
    PrettyTooltipDB = {}
    changed()
end

-- tooltipType: "item" (default), "spell", "object", "unit", "aura", "quest", "macro", or "shared" by all. color is where the picker starts
-- while the color is automatic. needs: the data set the part is drawn from (ns.hasData), when only some clients
-- load it; the editor offers the part where it is loaded. Retail's own parts are in Retail/Core/Settings.lua.
ns.ELEMENTS = {
    { key = "mailTitle", label = "Mail Title", size = 16, title = true, color = colors.title, tooltipType = "mail" },
    { key = "mailPrices", label = "Attachments and Prices", size = 12, color = colors.detail, tooltipType = "mail" },
    { key = "title", label = "Item Name", size = 19, title = true, color = { 1, 1, 1 },
        note = "Quality color unless set." },
    { key = "subtitle", label = "Type and Slot", size = 13, color = { .9, .9, .9 },
        note = "Half the quality color, red for a type you cannot use." },
    { key = "header", label = "Binding and Level", size = 12, color = { .78, .72, .63 },
        note = "The required level is red while you are below it." },
    { key = "dps", label = "Damage per Second", size = 18, color = { .90, .93, .95 } },
    { key = "damage", label = "Damage and Speed", size = 12, color = { .62, .65, .70 } },
    { key = "armor", label = "Armor", size = 16, color = { .90, .93, .95 } },
    { key = "stats", label = "Stats", size = 13, color = { .90, .85, .74 },
        note = "Colored by category unless set." },
    { key = "equipEffects", label = "Equip Effects", size = 13, color = { .48, .88, .48 },
        note = "On-hit numbers use the spell tooltip's school colors unless set." },
    { key = "enchants", label = "Enchants", size = 13, color = { .30, .90, .30 } },
    { key = "effects", label = "Use and Other Effects", size = 13, color = { .48, .88, .48 } },
    { key = "flavor", label = "Flavor Text", size = 12, color = colors.flavor },
    { key = "setName", label = "Set Name and Count", size = 15, title = true,
        color = { 1, .76, .18 } },
    { key = "setItems", label = "Set Pieces", size = 12, color = { .94, .89, .77 },
        note = "Owned pieces bright, missing ones grey, unless set." },
    { key = "setBonuses", label = "Set Bonuses", size = 12, color = { .48, .88, .48 },
        note = "Active bonuses green, inactive ones grey, unless set." },
    { key = "extras", label = "Other Addons' Rows", size = 11, color = colors.extras,
        tooltipType = "shared" },
    { key = "footer", label = "Footer", size = 11, color = colors.detail,
        note = "Durability, crafter, requirements, and sell price." },
    { key = "badge", label = "Item Level Badge", size = 10, color = { .9, .9, .9 } },
    { key = "createdName", label = "Crafted Item's Name", size = 14, title = true, color = { 1, 1, 1 },
        note = "On recipes; quality color unless set." },
    { key = "reagents", label = "Reagents", size = 12, color = { .90, .85, .74 },
        note = "On recipes; the count you carry red while short, unless set." },
    { key = "caption", label = "Section Captions", size = 9, color = colors.caption, caps = true,
        note = "Creates and Reagents on recipes." },
    { key = "disenchant", label = "Disenchant Results", size = 11, color = colors.detail, needs = "disenchant",
        note = "The Enchanting needed red while yours is too low, grey without Enchanting, unless set." },
    { key = "spellTitle", label = "Spell Name", size = 17, title = true,
        color = colors.title, tooltipType = "spell" },
    { key = "spellBadges", label = "School and Rank Badges", size = 12, color = { .9, .9, .9 },
        tooltipType = "spell", note = "Colored by school unless set." },
    { key = "spellValues", label = "Cost, Cast, Cooldown, Range", size = 13,
        color = { .96, .92, .84 }, tooltipType = "spell",
        note = "The cost takes its resource color unless set." },
    { key = "spellCaptions", label = "Strip Captions", size = 9, color = colors.caption,
        tooltipType = "spell" },
    { key = "spellDetails", label = "Requirements and Details", size = 11,
        color = colors.detail, tooltipType = "spell",
        note = "Unmet requirements red, time remaining orange, unless set." },
    { key = "spellText", label = "Description", size = 12, color = colors.description,
        tooltipType = "spell", note = "Numbers in the school color unless set." },
    { key = "objectTitle", label = "Object Name", size = 17, title = true,
        color = colors.title, tooltipType = "object" },
    { key = "objectKind", label = "Kind of Object", size = 12, color = { .9, .9, .9 },
        tooltipType = "object", note = "Tinted by the skill it needs, unless set." },
    { key = "objectDetails", label = "Skill and Requirements", size = 12,
        color = colors.detail, tooltipType = "object",
        note = "The skill in its skill-up color, unmet requirements red, unless set." },
    { key = "objectQuests", label = "Quest Lines", size = 12, color = colors.objective,
        tooltipType = "object", note = "Quest names yellow, finished objectives green, unless set." },
    { key = "objectLoot", label = "Contents", size = 11, color = colors.detail, tooltipType = "object", needs = "nodeLoot",
        note = "A herb or ore node's yield over its taps, then what else it may hold and the chance each tap. "
            .. "Turned off by Gathering contents in the options." },
    { key = "objectPrices", label = "Prices", size = 11, color = { .88, .78, .60 },
        tooltipType = "object", note = "The yielded item's sell price, and its auction price with Auctionator." },
    { key = "unitName", label = "Name", size = 17, title = true, color = { 1, 1, 1 },
        tooltipType = "unit", note = "Class color for players, reaction color for NPCs, unless set." },
    { key = "unitGuild", label = "Guild or Role", size = 12, color = { .9, .9, .9 }, tooltipType = "unit" },
    { key = "unitRealm", label = "Guild Realm", size = 11, color = colors.detail, tooltipType = "unit",
        note = "Beside the guild, for a guild from another realm. Turned off by Guild realm in the options." },
    { key = "unitInfo", label = "Level, Race, and Class", size = 12, color = colors.detail,
        tooltipType = "unit", note = "The level in its difficulty color, unless set." },
    { key = "unitBadges", label = "Badges", size = 12, color = { .9, .9, .9 }, tooltipType = "unit",
        note = "Elite, rare, faction, PvP, AFK, dead, and Skinnable in its skill-up color." },
    { key = "unitSkinning", label = "Skinning", size = 11, color = colors.detail, tooltipType = "unit", needs = "skinningLoot",
        note = "On a dead creature that can be skinned: the Skinning it needs, in its skill-up color, and what "
            .. "it may give. Turned off by Gathering contents in the options." },
    { key = "unitDetails", label = "Target and Owner", size = 11, color = colors.detail,
        tooltipType = "unit" },
    { key = "unitQuests", label = "Quest Lines", size = 12, color = colors.objective,
        tooltipType = "unit", note = "Quest names yellow, finished objectives green, unless set." },
    { key = "auraName", label = "Name", size = 15, title = true, color = colors.title,
        tooltipType = "aura" },
    { key = "auraBadges", label = "Badges", size = 12, color = { .9, .9, .9 }, tooltipType = "aura",
        note = "Buff or debuff, dispel type in the game's colors, and stacks." },
    { key = "auraText", label = "Description", size = 12, color = colors.description,
        tooltipType = "aura", note = "Numbers in the aura's color unless set." },
    { key = "auraTime", label = "Time and Caster", size = 11, color = { .88, .78, .60 },
        tooltipType = "aura" },
    { key = "questTitle", label = "Quest Name", size = 16, title = true, color = colors.title,
        tooltipType = "quest" },
    { key = "questInfo", label = "Dungeon", size = 12, color = colors.detail, tooltipType = "quest" },
    { key = "questBadges", label = "Badges", size = 12, color = { .9, .9, .9 }, tooltipType = "quest",
        note = "The level in its difficulty color, tags, and where the quest stands." },
    { key = "questText", label = "Description", size = 12, color = colors.flavor, tooltipType = "quest" },
    { key = "questCaption", label = "Section Caption", size = 9, color = colors.caption,
        tooltipType = "quest", caps = true },
    { key = "questObjectives", label = "Objectives", size = 12, color = colors.objective,
        tooltipType = "quest", note = "Finished objectives green unless set." },
    { key = "macroName", label = "Name", size = 15, title = true, color = colors.title,
        tooltipType = "macro" },
    { key = "macroBadges", label = "Badges", size = 12, color = { .9, .9, .9 }, tooltipType = "macro" },
    { key = "macroText", label = "Macro Lines", size = 12, color = colors.detail, tooltipType = "macro",
        note = "Commands yellow, conditions grey, unless set." },
}
-- types are Enum.TooltipDataType names; ones missing on this client are skipped.
-- editor names a kind's page in the style editor; the rest are under Other tooltips.
ns.TOOLTIP_TYPES = {
    { label = "Items", editor = "item", restyle = "itemPanels", cursor = "cursorItems", types = { "Item" } },
    { label = "Spells", editor = "spell", restyle = "spellPanels", cursor = "cursorSpells", types = { "Spell" } },
    { label = "Players and NPCs", editor = "unit", restyle = "unitPanels", cursor = "cursorUnits",
        types = { "Unit", "Corpse" } },
    { label = "Buffs and Debuffs", editor = "aura", restyle = "auraPanels", cursor = "cursorAuras",
        types = { "UnitAura" } },
    { label = "Weapon Imbues", restyle = "imbuePanels", types = {} },
    { label = "Herbs, Ore, Chests, and Other Objects", editor = "object", restyle = "objectPanels",
        cursor = "cursorObjects", types = { "Object" } },
    { label = "Flight Paths", restyle = "taxiPanels", types = {} },
    { label = "Mail", editor = "mail", restyle = "mailPanels", types = {} },
    { label = "Quests", editor = "quest", restyle = "questPanels", cursor = "cursorQuests", types = { "Quest", "QuestPartyProgress" } },
    { label = "Macros", editor = "macro", restyle = "macroPanels", cursor = "cursorMacros", types = { "Macro" } },
    { label = "Currencies", cursor = "cursorCurrencies", types = { "Currency" } },
    { label = "Dungeon and Raid Lockouts", cursor = "cursorLockouts", types = { "InstanceLock" } },
    { label = "Pet Abilities", restyle = "petPanels", cursor = "cursorPetActions", types = { "PetAction" } },
    { label = "Minimap", restyle = "minimapPanels", cursor = "cursorMinimap", types = { "MinimapMouseover" } },
    { label = "Mounts, Toys, and Pets", cursor = "cursorCollections",
        types = { "Mount", "Toy", "CompanionPet", "BattlePet" } },
    { label = "Achievements", cursor = "cursorAchievements", types = { "Achievement" } },
    { label = "Totems", cursor = "cursorTotems", types = { "Totem" } },
    { label = "Flyout Buttons", cursor = "cursorFlyouts", types = { "Flyout" } },
}

-- A client's own defaults and parts (retail's Retail/Core/Settings.lua), each
-- part after the one it names, so the style editor lists it where it is drawn.
-- A part naming none stops the load: left out, its style would be missing
-- when its tooltip is drawn.
for _, extra in ipairs(ns.contributions("settings")) do
    for key, value in pairs(extra.defaults or {}) do DEFAULTS[key] = value end
    for _, element in ipairs(extra.elements or {}) do
        ns.util.insertAfter(ns.ELEMENTS, element.after, element, "style part")
    end
end

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
-- Use the client's Cyrillic and CJK faces where the Latin files lack glyphs.
-- LibSharedMedia filters its fonts by language; these are the choices without it.
if GetLocale() == "ruRU" then
    GAME_FONTS = {
        { "Friz Quadrata", "Fonts\\FRIZQT___CYR.TTF" },
        { "Arial Narrow", "Fonts\\ARIALN.TTF" },
        { "Morpheus", "Fonts\\MORPHEUS_CYR.TTF" },
        { "Skurri", "Fonts\\SKURRI_CYR.TTF" },
    }
elseif GetLocale() == "koKR" then
    GAME_FONTS = {
        { "기본 글꼴", "Fonts\\2002.TTF" },
        { "굵은 글꼴", "Fonts\\2002B.TTF" },
        { "퀘스트 글꼴", "Fonts\\K_Pagetext.TTF" },
    }
elseif GetLocale() == "zhCN" then
    GAME_FONTS = {
        { "默认", "Fonts\\ARKai_T.ttf" },
        { "聊天", "Fonts\\ARHei.ttf" },
        { "伤害数字", "Fonts\\ARKai_C.ttf" },
    }
elseif GetLocale() == "zhTW" then
    GAME_FONTS = {
        { "預設", "Fonts\\bLEI00D.ttf" },
        { "提示訊息", "Fonts\\bHEI00M.ttf" },
        { "聊天", "Fonts\\bHEI01B.ttf" },
        { "傷害數字", "Fonts\\bKAI00M.ttf" },
    }
end

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
-- The backdrop's opacity with none set, for every type and style.
ns.BACKDROP_ALPHA = .9
ns.TYPE_SUFFIX = { item = "Items", spell = "Spells", object = "Objects", unit = "Units", aura = "Auras", quest = "Quests",
    macro = "Macros", mail = "Mail" }

local function legacyKey(tooltipType, key, oldKey)
    TYPE_KEYS[tooltipType] = TYPE_KEYS[tooltipType] or {}
    TYPE_KEYS[tooltipType][key] = oldKey
    LEGACY_KEYS[oldKey] = { tooltipType = tooltipType, key = key }
end
for tooltipType, suffix in pairs(ns.TYPE_SUFFIX) do
    for _, key in ipairs({ "icon", "headerTopAlpha", "headerBottomAlpha", "backdropAlpha", "glowAlpha" }) do
        legacyKey(tooltipType, key, key .. suffix)
    end
end
for _, kind in ipairs(ns.TOOLTIP_TYPES) do
    local tooltipType = kind.editor or kind.restyle or kind.cursor
    if kind.restyle then legacyKey(tooltipType, "restyle", kind.restyle) end
    if kind.cursor then legacyKey(tooltipType, "followCursor", kind.cursor) end
end

-- The header band's opacity at an edge ("Top" or "Bottom") for a tooltip type; one
-- without its own follows the setting shared by all, and nil means the default.
function ns.headerAlpha(tooltipType, edge)
    return ns.option("header" .. edge .. "Alpha", tooltipType)
end

ns.TOOLTIP_STYLE_KEYS = { "tooltipScale", "fontScale", "bodyFont", "titleFont", "titleSize", "bodySize",
    "titleOutline", "bodyOutline", "titleColor", "bodyColor", "titleCaps", "bodyCaps", "padding", "minWidth",
    "rowSpacing", "sectionSpacing", "backdropStyle", "backdropAlpha", "glowAlpha", "headerTopAlpha", "headerBottomAlpha",
    "icon", "iconRight", "qualityTint", "separators" }

function ns.resetTooltipStyles(tooltipType)
    for _, key in ipairs(ns.TOOLTIP_STYLE_KEYS) do ns.setTooltipSetting(tooltipType, key, nil) end
end

function ns.resetStyles()
    if type(PrettyTooltipDB) ~= "table" then return end
    PrettyTooltipDB.styles = nil
    for _, key in ipairs(ns.TOOLTIP_STYLE_KEYS) do
        -- These layout and visibility preferences have always survived a text-style reset.
        if key:match("^title") or key:match("^body") or key:find("Alpha", 1, true) then
            PrettyTooltipDB[key] = nil
        end
    end
    for key in pairs(PrettyTooltipDB) do
        if type(key) == "string" and (key:match("^statColor%u") or key:match("^schoolColor%u")
            or key:match("^classColor%u") or key:match("^armorColor%u")) then
            PrettyTooltipDB[key] = nil
        end
    end
    for _, suffix in pairs(ns.TYPE_SUFFIX) do
        PrettyTooltipDB["headerTopAlpha" .. suffix] = nil
        PrettyTooltipDB["headerBottomAlpha" .. suffix] = nil
        PrettyTooltipDB["backdropAlpha" .. suffix] = nil
        PrettyTooltipDB["glowAlpha" .. suffix] = nil
    end
    for _, own in pairs(type(PrettyTooltipDB.tooltips) == "table" and PrettyTooltipDB.tooltips or {}) do
        if type(own) == "table" then
            for _, key in ipairs(ns.TOOLTIP_STYLE_KEYS) do
                if key:match("^title") or key:match("^body") or key:find("Alpha", 1, true) then own[key] = nil end
            end
        end
    end
    changed()
end

-- A field resolves independently: part, type's title/body style, shared role,
-- then the part's original default. "automatic" explicitly restores semantic colors.
function ns.elementValue(key, field, tooltipType, inherited)
    local element = ELEMENT_BY_KEY[key]
    tooltipType = tooltipType or (element.tooltipType or "item")
    local own
    if not inherited then own = ns.elementSetting(key, field) end
    if own ~= nil then return own end
    local role = element.title and "title" or "body"
    local property = role .. field:sub(1, 1):upper() .. field:sub(2)
    if field == "font" then property = role == "title" and "titleFont" or "bodyFont" end
    local value = ns.tooltipSetting(tooltipType, property)
    if value == nil then value = ns.option(property) end
    if value ~= nil and value ~= "automatic" then return value end
    if value == "automatic" and (field == "font" or field == "color") then return value end
    if field == "size" then return element.size end
    if field == "caps" then return element.caps or element.title == true end
    return nil
end

function ns.style(key, tooltipType)
    local element = ELEMENT_BY_KEY[key]
    tooltipType = tooltipType or (element.tooltipType or "item")
    local outline = ns.elementValue(key, "outline", tooltipType)
    local color = ns.elementValue(key, "color", tooltipType)
    if type(color) ~= "table" then color = nil end
    return {
        key = key,
        title = element.title,
        size = (tonumber(ns.elementValue(key, "size", tooltipType)) or element.size) * ns.option("fontScale", tooltipType),
        font = ns.fontPath(ns.elementValue(key, "font", tooltipType)),
        flags = (outline == "OUTLINE" or outline == "THICKOUTLINE") and outline or "",
        color = color and { color[1], color[2], color[3] },
        caps = ns.elementValue(key, "caps", tooltipType),
    }
end

-- The keys a modifier setting can name: how to tell one is held, and the keys
-- MODIFIER_STATE_CHANGED reports for it. A value not here, as "NONE" or
-- "ALWAYS", names no key.
local MODIFIERS = {
    SHIFT = { down = function() return IsShiftKeyDown() end, keys = { LSHIFT = true, RSHIFT = true } },
    CTRL = { down = function() return IsControlKeyDown() end, keys = { LCTRL = true, RCTRL = true } },
    ALT = { down = function() return IsAltKeyDown() end, keys = { LALT = true, RALT = true } },
}

local function keyDown(name)
    local modifier = MODIFIERS[name]
    return modifier ~= nil and modifier.down() and true or false
end

local function isKey(name, key)
    local modifier = MODIFIERS[name]
    return modifier ~= nil and modifier.keys[key] == true
end

function ns.originalKeyDown() return keyDown(ns.option("originalKey")) end
function ns.isOriginalKey(key) return isKey(ns.option("originalKey"), key) end

-- Whether the details show now: their key is held, or they always show.
function ns.detailsKeyDown()
    local name = ns.option("detailsKey")
    return not MODIFIERS[name] or keyDown(name)
end
function ns.isDetailsKey(key) return isKey(ns.option("detailsKey"), key) end

-- Whether a panel shows a detail its option turns on. The editor's previews,
-- and the details on the game's own tooltip, which follow the key themselves,
-- have every detail that is on.
function ns.showsDetail(key, panel)
    if not ns.option(key) then return false end
    if panel and (panel.isPreview or panel.allDetails) then return true end
    return ns.detailsKeyDown()
end
