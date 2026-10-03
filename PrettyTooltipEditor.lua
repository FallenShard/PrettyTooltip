-- The /ptip style editor: a live sample panel and the controls for its parts.
local _, ns = ...
local ui = ns.ui
if not (ui and ui.renderPreview) then
    return
end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local WIDTH, HEIGHT = 820, 812
local PREVIEW_TOP = 106
local PREVIEW_WIDTH = 460
-- Room around the panel for its rarity halo and the Equipped tag above it.
local PREVIEW_MARGIN = 26
local SCROLL_STEP = 40
local CONTROLS_X = PREVIEW_WIDTH + 34
local CONTROLS_WIDTH = WIDTH - CONTROLS_X - 18
local LABEL_WIDTH = 86
local FIELD_WIDTH = CONTROLS_WIDTH - LABEL_WIDTH
local SIZE_MIN, SIZE_MAX = 8, 30
local MENU_ROWS, MENU_ROW_HEIGHT = 12, 20
local BACKGROUND = { .055, .045, .05 }
local FIELD = { .10, .085, .085 }
local FIELD_HOVER = { .16, .13, .12 }
local LINE = { .32, .26, .19 }
local GOLD = { .93, .80, .52 }
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
local OUTLINES = {
    { value = "NONE", text = "None" },
    { value = "OUTLINE", text = "Outline" },
    { value = "THICKOUTLINE", text = "Thick outline" },
}

-- Sample items --------------------------------------------------------------

local function itemIcon(itemID)
    if C_Item and C_Item.GetItemIconByID then
        local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
        if ok and icon then return icon end
    end
    return QUESTION_MARK
end

local function spellIcon(spellID)
    local getter = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
    if getter then
        local ok, icon = pcall(getter, spellID)
        if ok and icon then return icon end
    end
    return QUESTION_MARK
end

local function stat(text)
    return { left = ns.styleStat and ns.styleStat(text) or text, right = "" }
end

local LISTS = {
    "header", "armor", "primary", "secondary", "equipEffects", "enchants", "effects", "flavor",
    "setItems", "setBonuses", "extras", "footerLeft", "footerRight",
}

local function sampleModel(fields)
    for _, list in ipairs(LISTS) do fields[list] = fields[list] or {} end
    return fields
end

local function spellModel(fields)
    for _, list in ipairs({ "details", "requirements", "description", "extras" }) do
        fields[list] = fields[list] or {}
    end
    fields.cells = {}
    for _, field in ipairs({ "cost", "cast", "cooldown", "range" }) do
        if fields[field] then fields.cells[#fields.cells + 1] = fields[field] end
    end
    return fields
end

-- Built on every draw, since the stat options change their text.
local ITEM_SAMPLES = {
    {
        label = "Weapon",
        build = function()
            return sampleModel({
                name = "Arcanite Reaper", quality = 4, icon = itemIcon(12784), level = 63,
                equippable = true,
                slot = "Axe \194\183 Two-Hand",
                header = { { left = "Binds when equipped", right = "Requires Level 58",
                    rightColor = { .95, .93, .88 } } },
                weaponDps = "53.8",
                weaponDamage = "153 - 256 Damage", weaponSpeed = "Speed 3.80",
                primary = { stat("+13 Stamina") },
                secondary = { stat("+62 Attack Power") },
                equipEffects = { { left = "Your attacks have a chance to cleave a nearby enemy.",
                    right = "" } },
                flavor = { { left = "\"Sample flavor text sits here, in gold.\"", right = "" } },
                footerLeft = {
                    { left = "Durability 61 / 120", right = "", durability = { 61, 120 } },
                    { left = "Made by Lorelei", right = "", color = ui.FLAVOR_GOLD },
                },
                footerRight = { { left = "Sell Price", right = ui.formatMoney(64218) } },
                disenchant = ns.disenchantFor and ns.disenchantFor(2, 4, 63, "INVTYPE_2HWEAPON"),
            })
        end,
    },
    {
        label = "Set piece",
        build = function()
            local pieces, setItems = {
                "Redemption Tunic", "Redemption Legguards", "Redemption Handguards",
                "Redemption Headpiece", "Redemption Spaulders",
            }, {}
            for index, piece in ipairs(pieces) do
                setItems[index] = { left = piece, right = "", active = index <= 3 }
            end
            local enchants = {}
            for _, row in ipairs(ui.enchantRows("+4 All Stats")) do
                enchants[#enchants + 1] = { left = row, right = "" }
            end
            return sampleModel({
                name = "Redemption Tunic", quality = 4, icon = itemIcon(22416), level = 88,
                equippable = true,
                slot = "Plate \194\183 Chest",
                header = { { left = "Binds when picked up", right = "Requires Level 60",
                    rightColor = { .95, .93, .88 } } },
                armor = { { left = "1027 Armor", right = "", value = "1027" } },
                primary = { stat("+31 Intellect"), stat("+25 Stamina") },
                secondary = { stat("+1% Critical Strike Chance"), stat("+59 Healing Power"),
                    stat("+10 Mana per 5 sec") },
                enchants = enchants,
                setName = "Redemption Armor", setCount = "3/9",
                setItems = setItems,
                setBonuses = {
                    { left = "(2) Set: Increases the amount healed by your Judgement of Light by 20.",
                        right = "", active = true },
                    { left = "(4) Set: Reduces cooldown on your Lay on Hands by 12 min.",
                        right = "", active = false },
                },
                extras = { { left = "Dropped by: Kel'Thuzad", right = "",
                    color = { .17, .51, .77 } } },
                footerLeft = { { left = "Durability 165 / 165", right = "",
                    durability = { 165, 165 } } },
                footerRight = {
                    { left = "Requires Argent Dawn - Revered", right = "", requirement = true,
                        met = false },
                    { left = "Sell Price", right = ui.formatMoney(123767) },
                },
            })
        end,
    },
    {
        label = "Equipped",
        build = function()
            return sampleModel({
                name = "Blackhand Doomsaw", quality = 3, icon = itemIcon(12583), level = 63,
                equippable = true, comparison = true,
                slot = "Polearm \194\183 Two-Hand",
                header = { { left = "Soulbound", right = "Requires Level 55",
                    rightColor = { .95, .93, .88 } } },
                weaponDps = "45.1",
                weaponDamage = "131 - 197 Damage", weaponSpeed = "Speed 3.60",
                primary = { stat("+15 Strength") },
                extras = {
                    { left = "If you replace this item, the following stat changes will occur:",
                        right = "", color = { .85, .70, 0 } },
                    { left = "-15 Strength", right = "", color = { .85, .13, .13 } },
                    { left = "+13 Stamina", right = "", color = { .09, .85, .09 } },
                    { left = "+62 Attack Power", right = "", color = { .09, .85, .09 } },
                },
                footerLeft = { { left = "Durability 100 / 100", right = "",
                    durability = { 100, 100 } } },
                footerRight = { { left = "Sell Price", right = ui.formatMoney(41250) } },
            })
        end,
    },
    {
        label = "Potion",
        build = function()
            return sampleModel({
                name = "Major Healing Potion", quality = 1, icon = itemIcon(13446), level = 55,
                slot = "Consumable \194\183 Potion",
                header = { { left = "", right = "Requires Level 45",
                    rightColor = { .95, .93, .88 } } },
                effects = { { left = "Use: Restores 1050 to 1750 health. (2 Min Cooldown)",
                    right = "" } },
                footerRight = { { left = "Sell Price (each)", right = ui.formatMoney(1000) } },
            })
        end,
    },
    {
        label = "Recipe",
        build = function()
            return sampleModel({
                name = "Plans: Veteran's Gloves", quality = 2, icon = "Interface\\Icons\\INV_Scroll_03",
                slot = "Plans \194\183 Blacksmithing",
                header = { { left = "Binds when picked up", right = "Requires Blacksmithing 80",
                    rightColor = { .95, .93, .88 } } },
                created = sampleModel({
                    name = "Veteran's Gloves", quality = 2, icon = "Interface\\Icons\\INV_Gauntlets_05",
                    slot = "Mail \194\183 Hands", levelRequirement = { text = "Requires Level 15", met = true },
                    armor = { { left = "115 Armor", right = "", value = "115" } },
                    primary = { stat("+5 Strength"), stat("+3 Agility"), stat("+5 Stamina") },
                }),
                reagents = {
                    { name = "Bronze Bar", count = 10, have = 4, icon = itemIcon(2841) },
                    { name = "Rough Grinding Stone", count = 4, have = 4, icon = itemIcon(3470) },
                    { name = "Small Lustrous Pearl", count = 3, have = 1, icon = itemIcon(5498) },
                },
                footerRight = { { left = "Sell Price", right = ui.formatMoney(400) } },
            })
        end,
    },
}

local SPELL_SAMPLES = {
    {
        label = "Fireball",
        build = function()
            return spellModel({
                name = "Fireball", rank = "Rank 1", icon = spellIcon(133),
                cost = { "30", "Mana" }, power = "Mana", cast = { "1.5 sec", "Cast" },
                range = { "35 yd", "Range" },
                description = { "Hurls a fiery ball that causes 16 to 25 Fire damage and an "
                    .. "additional 2 Fire damage over 4 sec." },
            })
        end,
    },
    {
        label = "Ability",
        build = function()
            return spellModel({
                name = "Shield Bash", rank = "Rank 1", icon = spellIcon(72),
                cost = { "10", "Rage" }, power = "Rage", cast = { "Instant", "Cast" },
                cooldown = { "12 sec", "Cooldown" }, range = { "Melee", "Range" },
                requirements = { { left = "Requires Shields", right = "",
                    color = { 1, .34, .28 } } },
                details = { { left = "Cooldown remaining: 8 sec", right = "",
                    color = { 1, .60, .25 } } },
                description = { "Bashes the target with your shield for 8 damage. It also "
                    .. "interrupts spellcasting and prevents any spell in that school from being "
                    .. "cast for 6 sec." },
            })
        end,
    },
    {
        label = "Heal",
        build = function()
            return spellModel({
                name = "Holy Light", rank = "Rank 1", icon = spellIcon(635),
                cost = { "35", "Mana" }, power = "Mana", cast = { "2.5 sec", "Cast" },
                range = { "40 yd", "Range" },
                description = { "Heals a friendly target for 42 to 51." },
                extras = { { left = "Spell ID: 635", right = "", color = { .60, .60, .63 } } },
            })
        end,
    },
}

local function objectModel(fields)
    for _, list in ipairs({ "details", "quests", "extras" }) do fields[list] = fields[list] or {} end
    return ui.objectModel and ui.objectModel(fields) or fields
end

local OBJECT_SAMPLES = {
    {
        label = "Herb",
        build = function()
            return objectModel({ name = "Bruiseweed", skill = "Herbalism", skillColor = { 1, .5, .25 } })
        end,
    },
    {
        label = "Ore",
        build = function()
            return objectModel({
                name = "Mithril Deposit", skill = "Mining", skillMet = false,
                details = { { left = "Requires Mining", right = "", requirement = true, met = false } },
                extras = { { left = "Gathered here 12 times", right = "", color = { .17, .51, .77 } } },
            })
        end,
    },
    {
        label = "Chest",
        build = function()
            return objectModel({
                name = "Battered Chest", skill = "Lockpicking",
                details = {
                    { left = "Locked", right = "" },
                    { left = "Requires Lockpicking (25)", right = "", requirement = true, met = true },
                },
            })
        end,
    },
    {
        label = "Quest",
        build = function()
            return objectModel({
                name = "Sealed Supply Crate",
                quests = {
                    { left = "Heavy Supplies", right = "", title = true },
                    { left = "- Supply Crate: 2/5", right = "" },
                    { left = "- Report to the quartermaster", right = "", completed = true },
                },
            })
        end,
    },
}

local function unitModel(fields)
    return ui.unitModel and ui.unitModel(fields) or fields
end

local UNIT_SAMPLES = {
    {
        label = "Player",
        build = function()
            return unitModel({
                name = "Somniferie", iconPath = "Interface\\Icons\\INV_Misc_Head_Human_02",
                isPlayer = true, level = 60, race = "Human", className = "Warrior",
                classFile = "WARRIOR", guild = "Dawnbreakers", faction = "Alliance", pvp = true,
                health = 4230, healthMax = 5100, target = "Ragnaros", targetColor = { 1, .27, .22 },
                extras = { { left = "Item Level 61", right = "", color = { .60, .60, .63 } } },
            })
        end,
    },
    {
        label = "Enemy",
        build = function()
            return unitModel({
                name = "Defias Pillager", iconPath = "Interface\\Icons\\INV_Misc_Head_Human_01",
                level = 15, creature = "Humanoid", classification = "elite", reaction = 2,
                health = 512, healthMax = 980, target = "Somniferie", targetIsYou = true,
                quests = {
                    { left = "The Defias Brotherhood", right = "", title = true },
                    { left = "- Defias Pillager slain: 4/10", right = "" },
                },
            })
        end,
    },
    {
        label = "Vendor",
        build = function()
            return unitModel({
                name = "Innkeeper Farley", iconPath = "Interface\\Icons\\INV_Misc_Head_Dwarf_01",
                tag = "<Innkeeper>", level = 30, creature = "Humanoid", reaction = 5,
                health = 1420, healthMax = 1420,
            })
        end,
    },
    {
        label = "Rare",
        build = function()
            return unitModel({
                name = "Mother Fang", iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Spider",
                level = 10, creature = "Beast", classification = "rare", reaction = 2,
                health = 330, healthMax = 330,
            })
        end,
    },
}

local KINDS = {
    item = { label = "Items", dataType = Enum.TooltipDataType.Item, samples = ITEM_SAMPLES,
        first = "title", noun = "item" },
    spell = { label = "Spells", dataType = Enum.TooltipDataType.Spell, samples = SPELL_SAMPLES,
        first = "spellTitle", noun = "spell" },
}
local KIND_ORDER = { "item", "spell" }
-- Objects have no ID to look up.
if Enum.TooltipDataType.Object and ui.objectModel then
    KINDS.object = { label = "Objects", dataType = Enum.TooltipDataType.Object,
        samples = OBJECT_SAMPLES, first = "objectTitle", noun = "object", noLookup = true }
    KIND_ORDER[#KIND_ORDER + 1] = "object"
end
if Enum.TooltipDataType.Unit and ui.unitModel then
    KINDS.unit = { label = "Units", dataType = Enum.TooltipDataType.Unit,
        samples = UNIT_SAMPLES, first = "unitName", noun = "unit", noLookup = true }
    KIND_ORDER[#KIND_ORDER + 1] = "unit"
end
local AURA_SAMPLES = {
    {
        label = "Buff",
        build = function()
            return ui.auraModel({
                name = "Power Word: Fortitude", icon = spellIcon(1245), dispel = "Magic",
                harmful = false, text = "Increases Stamina by 26.", remaining = "17 minutes remaining",
                duration = 1800, expires = GetTime() + 1020, caster = "Somniferie",
            })
        end,
    },
    {
        label = "Curse",
        build = function()
            return ui.auraModel({
                name = "Curse of Agony", icon = spellIcon(980), dispel = "Curse", harmful = true,
                text = "Causes 84 Shadow damage over 24 sec. This damage is dealt slowly at first, "
                    .. "and builds up as the Curse reaches its full duration.",
                remaining = "16 seconds remaining", duration = 24, expires = GetTime() + 16,
            })
        end,
    },
    {
        label = "Poison",
        build = function()
            return ui.auraModel({
                name = "Deadly Poison", icon = spellIcon(2818), dispel = "Poison", harmful = true,
                stacks = 3, text = "Inflicts 9 Nature damage every 3 sec.",
                remaining = "9 seconds remaining", duration = 12, expires = GetTime() + 9,
            })
        end,
    },
}
if Enum.TooltipDataType.UnitAura and ui.auraModel then
    KINDS.aura = { label = "Buffs", dataType = Enum.TooltipDataType.UnitAura,
        samples = AURA_SAMPLES, first = "auraName", noun = "aura", noLookup = true }
    KIND_ORDER[#KIND_ORDER + 1] = "aura"
end
local QUEST_SAMPLES = {
    {
        label = "Active",
        build = function()
            return ui.questModel({
                name = "The Fury Runs Deep", level = 27, tags = { "Dungeon" }, zone = "The Stockade",
                active = true,
                description = { "Motley Garmason wants Kam Deepfury's head brought to him at Dun Modr." },
                objectives = { { left = "Head of Deepfury", right = "0/1", completed = false } },
            })
        end,
    },
    {
        label = "Ready",
        build = function()
            return ui.questModel({
                name = "Wolves Across the Border", level = 6, active = true, ready = true,
                description = { "Eliminate the wolves to the east of Northshire and bring their paws to Eagan Peltskinner." },
                objectives = { { left = "Tough Wolf Meat", right = "8/8", completed = true } },
                extras = { { left = "Ended by", right = "Eagan Peltskinner" } },
            })
        end,
    },
    {
        label = "New",
        build = function()
            return ui.questModel({
                name = "Arugal Must Die", level = 27, tags = { "Dungeon" }, zone = "Shadowfang Keep",
                description = { "Dalar Dawnweaver wants Arugal dead and his head brought to him." },
                objectives = { { left = "Head of Arugal" } },
                extras = { { left = "Started by", right = "Dalar Dawnweaver" },
                    { left = "Found in", right = "Silverpine Forest" } },
            })
        end,
    },
}
if Enum.TooltipDataType.Quest and ui.questModel then
    KINDS.quest = { label = "Quests", dataType = Enum.TooltipDataType.Quest,
        samples = QUEST_SAMPLES, first = "questTitle", noun = "quest", noLookup = true }
    KIND_ORDER[#KIND_ORDER + 1] = "quest"
end
local MAX_SAMPLES = 0
for _, kind in pairs(KINDS) do MAX_SAMPLES = math.max(MAX_SAMPLES, #kind.samples) end

-- Building blocks -----------------------------------------------------------

local function fill(parent, layer, color, alpha)
    local tex = parent:CreateTexture(nil, layer)
    tex:SetTexture(WHITE)
    tex:SetVertexColor(color[1], color[2], color[3], alpha or 1)
    return tex
end

local function background(frame, color, alpha)
    local tex = fill(frame, "BACKGROUND", color, alpha)
    tex:SetAllPoints()
    return tex
end

local function outline(frame, color, alpha)
    local edges = {}
    for index, points in ipairs({
        { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" },
    }) do
        local edge = fill(frame, "BORDER", color, alpha)
        edge:SetPoint(points[1])
        edge:SetPoint(points[2])
        if index <= 2 then edge:SetHeight(1) else edge:SetWidth(1) end
        edges[index] = edge
    end
    return edges
end

local function text(parent, template, value)
    local font = parent:CreateFontString(nil, "ARTWORK", template)
    font:SetJustifyH("LEFT")
    if value then font:SetText(value) end
    return font
end

-- A string given a font file keeps it through SetFontObject.
local function plainFont(font)
    local path, size, flags = GameFontHighlightSmall:GetFont()
    ui.setFont(font, path, size, flags)
end

local function flatButton(parent, label, width, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 22)
    button.bg = background(button, FIELD)
    outline(button, LINE)
    button.label = text(button, "GameFontHighlightSmall", label)
    button.label:SetPoint("CENTER")
    local function paint(self, hover)
        local color = self.selected and { .36, .27, .13 } or (hover and FIELD_HOVER or FIELD)
        self.bg:SetVertexColor(color[1], color[2], color[3], 1)
    end
    button:SetScript("OnEnter", function(self) paint(self, true) end)
    button:SetScript("OnLeave", function(self) paint(self, false) end)
    button:SetScript("OnClick", onClick)
    function button:SetSelected(selected)
        self.selected = selected
        paint(self, false)
    end
    return button
end

-- The window -----------------------------------------------------------------

local editor = CreateFrame("Frame", "PrettyTooltipEditor", UIParent)
editor:SetSize(WIDTH, HEIGHT)
editor:SetPoint("CENTER")
-- Below the color picker, which the editor opens.
editor:SetFrameStrata("HIGH")
editor:SetToplevel(true)
editor:SetClampedToScreen(true)
editor:EnableMouse(true)
editor:SetMovable(true)
editor:RegisterForDrag("LeftButton")
editor:SetScript("OnDragStart", editor.StartMoving)
editor:SetScript("OnDragStop", editor.StopMovingOrSizing)
editor:Hide()
tinsert(UISpecialFrames, "PrettyTooltipEditor")
background(editor, BACKGROUND)
outline(editor, LINE)

local heading = text(editor, "GameFontNormalLarge", "PrettyTooltip style editor")
heading:SetPoint("TOPLEFT", 16, -14)
local subheading = text(editor, "GameFontDisableSmall",
    "Click any part of the sample to restyle it. Tooltips use the new look the next time they open.")
subheading:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
local close = CreateFrame("Button", nil, editor, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)

local state = { kind = "item", sample = 1, selected = "title", saved = {} }
local controls = {}
local refresh, refreshLookup

local function samples()
    return KINDS[state.kind].samples
end

local function switchKind(kind)
    if kind == state.kind then return end
    state.saved[state.kind] = { sample = state.sample, selected = state.selected, lookup = state.lookup }
    local saved = state.saved[kind] or {}
    state.kind = kind
    state.sample = saved.sample or 1
    state.selected = saved.selected or KINDS[kind].first
    state.lookup = saved.lookup
    refresh()
end

-- The sample ----------------------------------------------------------------

local host = CreateFrame("Frame", nil, editor)
host:SetPoint("TOPLEFT", 16, -PREVIEW_TOP)
host:SetSize(PREVIEW_WIDTH, HEIGHT - PREVIEW_TOP - 16)
host:SetClipsChildren(true)
background(host, { .02, .016, .02 })
outline(host, LINE, .8)
-- Stands in for the game's tooltip; the panel pins itself to it.
local anchor = CreateFrame("Frame", nil, host)
anchor:SetSize(1, 1)
anchor:SetPoint("TOPLEFT", PREVIEW_MARGIN, -PREVIEW_MARGIN)
local kindTabs = {}
for index, kind in ipairs(KIND_ORDER) do
    local tab = flatButton(editor, KINDS[kind].label, 64, function() switchKind(kind) end)
    tab:SetPoint("BOTTOMLEFT", host, "TOPLEFT", (index - 1) * 68, 34)
    kindTabs[kind] = tab
end
local sampleTabs = {}
for index = 1, MAX_SAMPLES do
    local tab = flatButton(editor, "", 56, function()
        state.sample, state.lookup = index, nil
        refresh()
    end)
    tab:SetPoint("BOTTOMLEFT", host, "TOPLEFT", (index - 1) * 60, 6)
    sampleTabs[index] = tab
end

local overlay = CreateFrame("Frame", nil, host)
overlay:SetAllPoints()
overlay:EnableMouse(true)
local failure = text(overlay, "GameFontRedSmall")
failure:SetPoint("TOPLEFT", 12, -12)
failure:SetWidth(PREVIEW_WIDTH - 24)
local hint = text(overlay, "GameFontDisableSmall")
hint:SetPoint("BOTTOMLEFT", 10, 8)

local scrollBar = CreateFrame("Slider", nil, host)
scrollBar:SetOrientation("VERTICAL")
scrollBar:SetPoint("TOPRIGHT", -3, -3)
scrollBar:SetPoint("BOTTOMRIGHT", -3, 3)
scrollBar:SetWidth(8)
scrollBar:SetValueStep(1)
local scrollTrack = fill(scrollBar, "BACKGROUND", LINE, .6)
scrollTrack:SetAllPoints()
scrollBar:SetThumbTexture(WHITE)
local scrollThumbTexture = scrollBar:GetThumbTexture()
scrollThumbTexture:SetWidth(8)
scrollThumbTexture:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], .7)
scrollBar:Hide()
local scrolledFor

local function scrollTo(offset)
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPLEFT", PREVIEW_MARGIN, -PREVIEW_MARGIN + offset)
end
scrollBar:SetScript("OnValueChanged", function(_, offset) scrollTo(math.floor(offset + .5)) end)
overlay:EnableMouseWheel(true)
overlay:SetScript("OnMouseWheel", function(_, delta)
    if scrollBar:IsShown() then scrollBar:SetValue(scrollBar:GetValue() - delta * SCROLL_STEP) end
end)
local highlights = {}
local hovered

local function preview()
    return anchor.prettyTooltipPreview
end

local function hasPart(key)
    local panel = preview()
    for _, hit in ipairs(panel and panel.hits or {}) do
        if hit.key == key then return true end
    end
    return false
end

local function partAtCursor()
    local panel = preview()
    if not (panel and panel:IsShown() and panel.hits) then return end
    local x, y = GetCursorPosition()
    local scale = overlay:GetEffectiveScale()
    x, y = x / scale, y / scale
    for _, hit in ipairs(panel.hits) do
        local region = hit.region
        local left, right = region:GetLeft(), region:GetRight()
        local top, bottom = region:GetTop(), region:GetBottom()
        if left and region:IsShown() and x >= left - 2 and x <= right + 2
            and y <= top + 1 and y >= bottom - 1 then
            return hit.key
        end
    end
end

local function paintHighlights()
    for _, tex in ipairs(highlights) do tex:Hide() end
    local panel = preview()
    if not (panel and panel.hits) then return end
    local used = 0
    for _, hit in ipairs(panel.hits) do
        local selected = hit.key == state.selected
        if selected or hit.key == hovered then
            used = used + 1
            local tex = highlights[used]
            if not tex then
                tex = overlay:CreateTexture(nil, "OVERLAY")
                tex:SetTexture(WHITE)
                highlights[used] = tex
            end
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", hit.region, "TOPLEFT", -3, 2)
            tex:SetPoint("BOTTOMRIGHT", hit.region, "BOTTOMRIGHT", 3, -2)
            if selected then
                tex:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], .16)
            else
                tex:SetVertexColor(1, 1, 1, .07)
            end
            tex:Show()
        end
    end
end

local function showHint()
    local element = hovered and ns.ELEMENT_BY_KEY[hovered]
    hint:SetText(element and (element.label .. ": click to edit")
        or "Click any part of the sample to edit it.")
end

overlay:SetScript("OnUpdate", function(self)
    local key = self:IsMouseOver() and partAtCursor() or nil
    if key == hovered then return end
    hovered = key
    paintHighlights()
    showHint()
end)

-- Uncached items are requested; GET_ITEM_INFO_RECEIVED redraws.
local function lookupProblem(kind, id)
    if kind.dataType ~= Enum.TooltipDataType.Item or not C_Item then return end
    if C_Item.DoesItemExistByID and C_Item.DoesItemExistByID(id) == false then
        return "There is no item with ID " .. id .. "."
    end
    if C_Item.GetItemInfo and not C_Item.GetItemInfo(id) then
        if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
        return "Loading item " .. id .. "..."
    end
end

local function drawSample()
    local kind = KINDS[state.kind]
    local problem = state.lookup and lookupProblem(kind, state.lookup)
    local ok, panel = true, nil
    if not problem then
        ok, panel = pcall(function()
            if state.lookup then return ui.previewByID(anchor, kind.dataType, state.lookup) end
            return ui.renderPreview(anchor, kind.samples[state.sample].build(), kind.dataType)
        end)
        if not ok then
            problem = "The sample failed to draw: " .. tostring(panel)
        elseif not panel then
            problem = "Nothing to show for " .. kind.noun .. " ID " .. state.lookup .. "."
        end
    end
    failure:SetText(problem or "")
    local shown = preview()
    if shown then
        shown:SetShown(problem == nil)
        overlay:SetFrameLevel(shown:GetFrameLevel() + 20)
        scrollBar:SetFrameLevel(overlay:GetFrameLevel() + 5)
    end
    local showing = state.kind .. ":" .. state.sample .. ":" .. tostring(state.lookup)
    local offset = showing == scrolledFor and scrollBar:GetValue() or 0
    scrolledFor = showing
    local content = (shown and shown:IsShown()) and shown:GetHeight() + 2 * PREVIEW_MARGIN or 0
    local range = math.max(0, math.ceil(content - host:GetHeight()))
    scrollBar:SetMinMaxValues(0, range)
    scrollBar:SetShown(range > 0)
    if range > 0 then
        scrollThumbTexture:SetHeight(math.max(24, scrollBar:GetHeight() * host:GetHeight() / content))
    end
    offset = math.min(offset, range)
    scrollBar:SetValue(offset)
    scrollTo(offset)
end

local function selectPart(key)
    state.selected = key
    if not hasPart(key) and not state.lookup then
        for index = 1, #samples() do
            if index ~= state.sample then
                state.sample = index
                drawSample()
                if hasPart(key) then break end
            end
        end
    end
    refresh()
end

overlay:SetScript("OnMouseDown", function()
    if hovered then selectPart(hovered) end
end)

-- Dropdowns ------------------------------------------------------------------

local catcher = CreateFrame("Button", nil, editor)
catcher:SetAllPoints(UIParent)
catcher:SetFrameStrata("FULLSCREEN_DIALOG")
catcher:EnableMouse(true)
catcher:RegisterForClicks("AnyUp")
catcher:Hide()
local menu = CreateFrame("Frame", nil, catcher)
menu:SetFrameStrata("FULLSCREEN_DIALOG")
menu:EnableMouse(true)
menu:EnableMouseWheel(true)
background(menu, { .07, .06, .06 })
outline(menu, LINE)
local scrollThumb = fill(menu, "ARTWORK", GOLD, .5)
scrollThumb:SetWidth(2)
menu.rows = {}

local function closeMenu()
    catcher:Hide()
    menu.owner = nil
end
catcher:SetScript("OnClick", closeMenu)

local function fillMenu()
    local items, offset = menu.items, menu.offset
    local current = menu.owner.current()
    for index = 1, MENU_ROWS do
        local row = menu.rows[index]
        local item = items[index + offset]
        if item then
            row.item = item
            if item.font then
                ui.setFont(row.label, item.font, 13)
            else
                plainFont(row.label)
            end
            row.label:SetText(item.text)
            if item.value == current then
                row.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            else
                row.label:SetTextColor(.90, .87, .80)
            end
            row:Show()
        else
            row:Hide()
        end
    end
    local shown = math.min(#items, MENU_ROWS)
    if #items > MENU_ROWS then
        local track = shown * MENU_ROW_HEIGHT - 4
        local length = math.max(12, track * MENU_ROWS / #items)
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -2,
            -2 - (track - length) * offset / (#items - MENU_ROWS))
        scrollThumb:SetHeight(length)
        scrollThumb:Show()
    else
        scrollThumb:Hide()
    end
    menu:SetHeight(shown * MENU_ROW_HEIGHT + 4)
end

for index = 1, MENU_ROWS do
    local row = CreateFrame("Button", nil, menu)
    row:SetHeight(MENU_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 2, -2 - (index - 1) * MENU_ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", -6, -2 - (index - 1) * MENU_ROW_HEIGHT)
    local glow = fill(row, "HIGHLIGHT", GOLD, .12)
    glow:SetAllPoints()
    row.label = text(row, "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", 8, 0)
    row.label:SetPoint("RIGHT", -4, 0)
    row.label:SetWordWrap(false)
    row:SetScript("OnClick", function(self)
        local owner = menu.owner
        closeMenu()
        owner.pick(self.item.value)
        refresh()
    end)
    menu.rows[index] = row
end

menu:SetScript("OnMouseWheel", function(_, delta)
    local last = math.max(0, #menu.items - MENU_ROWS)
    menu.offset = math.max(0, math.min(last, menu.offset - delta))
    fillMenu()
end)

local function openMenu(owner)
    local items = owner.items()
    menu.owner, menu.items, menu.offset = owner, items, 0
    for index, item in ipairs(items) do
        if item.value == owner.current() then
            menu.offset = math.max(0, math.min(index - 1, #items - MENU_ROWS))
            break
        end
    end
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    menu:SetWidth(owner:GetWidth())
    catcher:Show()
    menu:SetFrameLevel(catcher:GetFrameLevel() + 10)
    fillMenu()
end

-- items() lists { value, text, font }; current() is the chosen value, nil for
-- the default; pick(value) saves a choice.
local function dropdown(width, items, current, pick)
    local button = CreateFrame("Button", nil, editor)
    button:SetSize(width, 22)
    button.bg = background(button, FIELD)
    outline(button, LINE)
    button.label = text(button, "GameFontHighlightSmall")
    button.label:SetPoint("LEFT", 8, 0)
    button.label:SetPoint("RIGHT", -20, 0)
    button.label:SetWordWrap(false)
    local arrow = text(button, "GameFontNormalSmall", "v")
    arrow:SetPoint("RIGHT", -8, 0)
    button.items, button.current, button.pick = items, current, pick
    button:SetScript("OnEnter", function(self)
        self.bg:SetVertexColor(FIELD_HOVER[1], FIELD_HOVER[2], FIELD_HOVER[3], 1)
    end)
    button:SetScript("OnLeave", function(self)
        self.bg:SetVertexColor(FIELD[1], FIELD[2], FIELD[3], 1)
    end)
    button:SetScript("OnClick", function(self)
        if menu.owner == self then closeMenu() else openMenu(self) end
    end)
    button.refresh = function()
        local value, shown = current(), nil
        for _, item in ipairs(items()) do
            if item.value == value then shown = item break end
        end
        if shown and shown.font then
            ui.setFont(button.label, shown.font, 13)
        else
            plainFont(button.label)
        end
        button.label:SetText(shown and shown.text or (tostring(value) .. " (not installed)"))
    end
    controls[#controls + 1] = button
    return button
end

local function fontItems(defaultText)
    local items = { { text = defaultText } }
    for _, name in ipairs(ns.fontNames()) do
        items[#items + 1] = { value = name, text = name, font = ns.fontPath(name) }
    end
    return items
end

-- Other controls -------------------------------------------------------------

local function slider(width, current, set, low, high, suffix)
    local holder = CreateFrame("Frame", nil, editor)
    holder:SetSize(width, 22)
    local bar = CreateFrame("Slider", nil, holder)
    bar:SetOrientation("HORIZONTAL")
    bar:SetPoint("LEFT", 0, 0)
    bar:SetSize(width - 46, 16)
    bar:SetMinMaxValues(low or SIZE_MIN, high or SIZE_MAX)
    bar:SetValueStep(1)
    if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
    local track = fill(bar, "BACKGROUND", LINE)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)
    bar:SetThumbTexture(WHITE)
    local thumb = bar:GetThumbTexture()
    thumb:SetSize(8, 16)
    thumb:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
    local value = text(holder, "GameFontHighlight")
    value:SetPoint("RIGHT", 0, 0)
    value:SetJustifyH("RIGHT")
    bar:SetScript("OnValueChanged", function(self, number)
        if self.updating then return end
        number = math.floor(number + .5)
        if number ~= current() then
            set(number)
            refresh()
        end
    end)
    bar:EnableMouseWheel(true)
    bar:SetScript("OnMouseWheel", function(self, delta) self:SetValue(self:GetValue() + delta) end)
    holder.refresh = function()
        bar.updating = true
        bar:SetValue(current())
        bar.updating = false
        value:SetText(current() .. (suffix or ""))
    end
    controls[#controls + 1] = holder
    return holder
end

-- Both color picker interfaces; cancelling restores the saved color.
local function pickColor(start, apply, restore)
    local function changed()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        apply({ r, g, b })
        refresh()
    end
    local function cancelled()
        restore()
        refresh()
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = start[1], g = start[2], b = start[3], hasOpacity = false,
            swatchFunc = changed, cancelFunc = cancelled,
        })
    else
        ColorPickerFrame:Hide()
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.previousValues = { r = start[1], g = start[2], b = start[3] }
        ColorPickerFrame.func = changed
        ColorPickerFrame.cancelFunc = cancelled
        ColorPickerFrame:SetColorRGB(start[1], start[2], start[3])
        ShowUIPanel(ColorPickerFrame)
    end
end

local function selectedElement()
    return ns.ELEMENT_BY_KEY[state.selected]
end

local function colorControl()
    local holder = CreateFrame("Frame", nil, editor)
    holder:SetSize(FIELD_WIDTH, 22)
    local swatch = CreateFrame("Button", nil, holder)
    swatch:SetSize(22, 22)
    swatch:SetPoint("LEFT")
    outline(swatch, LINE)
    local chip = fill(swatch, "ARTWORK", { 1, 1, 1 })
    chip:SetPoint("TOPLEFT", 3, -3)
    chip:SetPoint("BOTTOMRIGHT", -3, 3)
    local status = text(holder, "GameFontHighlightSmall")
    status:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
    local automatic = flatButton(holder, "Automatic", 80, function()
        ns.setElementSetting(state.selected, "color", nil)
        refresh()
    end)
    automatic:SetPoint("RIGHT")
    swatch:SetScript("OnClick", function()
        local key = state.selected
        local saved = ns.elementSetting(key, "color")
        local start = type(saved) == "table" and saved or ns.ELEMENT_BY_KEY[key].color
        pickColor(start,
            function(color) ns.setElementSetting(key, "color", color) end,
            function() ns.setElementSetting(key, "color", saved) end)
    end)
    holder.refresh = function()
        local saved = ns.elementSetting(state.selected, "color")
        local custom = type(saved) == "table"
        local color = custom and saved or selectedElement().color
        chip:SetVertexColor(color[1], color[2], color[3], custom and 1 or .35)
        status:SetText(custom and "Custom" or "Automatic")
        automatic:SetShown(custom)
    end
    controls[#controls + 1] = holder
    return holder
end

local function checkbox(label, key, description, isAvailable)
    local button = CreateFrame("CheckButton", nil, editor, "UICheckButtonTemplate")
    button:SetSize(22, 22)
    local caption = text(button, "GameFontHighlightSmall", label)
    caption:SetPoint("LEFT", button, "RIGHT", 2, 1)
    button:SetHitRectInsets(0, -(caption:GetStringWidth() + 6), 0, 0)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label, 1, 1, 1)
        GameTooltip:AddLine(description, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- A key can depend on the kind shown.
    local function keyOf() return type(key) == "function" and key() or key end
    button:SetScript("OnClick", function(self)
        ns.setOption(keyOf(), self:GetChecked() and true or false)
        refresh()
    end)
    button.refresh = function()
        button:SetChecked(ns.option(keyOf()))
        local available = not isAvailable or isAvailable()
        button:SetEnabled(available)
        caption:SetFontObject(available and "GameFontHighlightSmall" or "GameFontDisableSmall")
    end
    controls[#controls + 1] = button
    return button
end

-- Looking up by ID -------------------------------------------------------------

local function applyLookup(entry)
    local kind = state.kind
    local id = entry:match("^%s*(%d+)%s*$")
    for _, candidate in ipairs(KIND_ORDER) do
        local linked = entry:match(KINDS[candidate].noun .. ":(%d+)")
        if linked then id, kind = linked, candidate break end
    end
    if kind ~= state.kind then switchKind(kind) end
    state.lookup = id and tonumber(id) or nil
    refresh()
end

local lookupLabel = text(editor, "GameFontHighlightSmall")
lookupLabel:SetPoint("BOTTOMLEFT", host, "TOPRIGHT", 18, 11)
local lookupBox = CreateFrame("EditBox", nil, editor)
lookupBox:SetSize(FIELD_WIDTH - 70, 22)
lookupBox:SetPoint("BOTTOMLEFT", host, "TOPRIGHT", 18 + LABEL_WIDTH, 6)
background(lookupBox, FIELD)
outline(lookupBox, LINE)
lookupBox:SetFontObject("GameFontHighlightSmall")
lookupBox:SetTextInsets(8, 8, 0, 0)
lookupBox:SetAutoFocus(false)
lookupBox:SetMaxLetters(255)
local lookupPlaceholder = text(lookupBox, "GameFontDisableSmall", "ID, or shift-click a link")
lookupPlaceholder:SetPoint("LEFT", 8, 0)
lookupBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    applyLookup(self:GetText())
end)
lookupBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    refresh()
end)
lookupBox:SetScript("OnEditFocusGained", function() lookupPlaceholder:Hide() end)
lookupBox:SetScript("OnEditFocusLost", function(self)
    lookupPlaceholder:SetShown(self:GetText() == "")
end)
local lookupClear = flatButton(editor, "Clear", 62, function()
    state.lookup = nil
    refresh()
end)
lookupClear:SetPoint("LEFT", lookupBox, "RIGHT", 8, 0)

if ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", function(link)
        if lookupBox:HasFocus() and type(link) == "string" then
            lookupBox:ClearFocus()
            applyLookup(link)
        end
    end)
end

refreshLookup = function()
    local hidden = KINDS[state.kind].noLookup == true
    lookupLabel:SetShown(not hidden)
    lookupBox:SetShown(not hidden)
    lookupLabel:SetText(KINDS[state.kind].label:sub(1, -2) .. " ID")
    if not lookupBox:HasFocus() then
        lookupBox:SetText(state.lookup and tostring(state.lookup) or "")
        lookupPlaceholder:SetShown(state.lookup == nil)
    end
    lookupClear:SetShown(state.lookup ~= nil and not hidden)
end

-- The controls column ----------------------------------------------------------

local y = -PREVIEW_TOP + 4

local function section(title)
    local label = text(editor, "GameFontNormal", title)
    label:SetPoint("TOPLEFT", CONTROLS_X, y)
    local rule = fill(editor, "ARTWORK", LINE)
    rule:SetPoint("TOPLEFT", CONTROLS_X, y - 16)
    rule:SetSize(CONTROLS_WIDTH, 1)
    y = y - 26
end

local function row(label, control)
    local caption = text(editor, "GameFontHighlightSmall", label)
    caption:SetPoint("TOPLEFT", CONTROLS_X, y - 5)
    control:SetPoint("TOPLEFT", CONTROLS_X + LABEL_WIDTH, y)
    y = y - 30
end

section("Selection Settings")
local partPicker = dropdown(CONTROLS_WIDTH, function()
    local items = {}
    for _, element in ipairs(ns.ELEMENTS) do
        local kind = element.kind or "item"
        if kind == state.kind or kind == "shared" then
            items[#items + 1] = { value = element.key, text = element.label }
        end
    end
    return items
end, function() return state.selected end, function(key) selectPart(key) end)
partPicker:SetPoint("TOPLEFT", CONTROLS_X, y)
y = y - 26
local partNote = text(editor, "GameFontDisableSmall")
partNote:SetPoint("TOPLEFT", CONTROLS_X, y)
partNote:SetWidth(CONTROLS_WIDTH)
partNote:SetHeight(24)
partNote:SetJustifyV("TOP")
y = y - 28

row("Font", dropdown(FIELD_WIDTH, function()
    return fontItems(selectedElement().title and "Name font" or "Text font")
end, function()
    return ns.elementSetting(state.selected, "font")
end, function(name)
    ns.setElementSetting(state.selected, "font", name)
end))

row("Size", slider(FIELD_WIDTH, function()
    return ns.elementSetting(state.selected, "size") or selectedElement().size
end, function(size)
    ns.setElementSetting(state.selected, "size", size ~= selectedElement().size and size or nil)
end))

row("Color", colorControl())

row("Outline", dropdown(FIELD_WIDTH, function()
    local items = { { text = "Same as global settings" } }
    for _, item in ipairs(OUTLINES) do items[#items + 1] = item end
    return items
end, function()
    return ns.elementSetting(state.selected, "outline")
end, function(value)
    ns.setElementSetting(state.selected, "outline", value)
end))

-- The part's default is saved as no setting.
local allCaps = CreateFrame("CheckButton", nil, editor, "UICheckButtonTemplate")
allCaps:SetSize(22, 22)
local allCapsLabel = text(allCaps, "GameFontHighlightSmall", "All caps")
allCapsLabel:SetPoint("LEFT", allCaps, "RIGHT", 2, 1)
allCaps:SetHitRectInsets(0, -(allCapsLabel:GetStringWidth() + 6), 0, 0)
allCaps:SetScript("OnClick", function(self)
    local checked = self:GetChecked() and true or false
    if checked == (selectedElement().title == true) then
        ns.setElementSetting(state.selected, "caps", nil)
    else
        ns.setElementSetting(state.selected, "caps", checked)
    end
    refresh()
end)
allCaps.refresh = function()
    local caps = ns.elementSetting(state.selected, "caps")
    if caps == nil then caps = selectedElement().title == true end
    allCaps:SetChecked(caps)
end
controls[#controls + 1] = allCaps
row("Letters", allCaps)

local resetPart = flatButton(editor, "Reset this part", 120, function()
    ns.resetElement(state.selected)
    refresh()
end)
resetPart:SetPoint("TOPLEFT", CONTROLS_X + LABEL_WIDTH, y)
y = y - 36

section("Global Settings")
row("Text font", dropdown(FIELD_WIDTH, function()
    return fontItems("Game default")
end, function() return ns.option("bodyFont") end, function(name)
    ns.setOption("bodyFont", name)
end))
row("Name font", dropdown(FIELD_WIDTH, function()
    return fontItems(ns.isInstalled("EllesmereUI") and "Expressway Bold (EllesmereUI)"
        or "Game default")
end, function() return ns.option("titleFont") end, function(name)
    ns.setOption("titleFont", name)
end))
row("Outline", dropdown(FIELD_WIDTH, function() return OUTLINES end, function()
    return ns.option("outline")
end, function(value)
    ns.setOption("outline", value ~= "NONE" and value or nil)
end))

section("Layout and color")
local function showingItems() return state.kind == "item" end
local TOGGLES = {
    { "Show icon", function() return "icon" .. ns.KIND_SUFFIX[state.kind] end,
        "The icon or portrait in the header, for the kind of tooltip shown." },
    { "Icon on the right", "iconRight",
        "Moves the item or spell icon, and the item level badge under it, to the right of the name." },
    { "Item level badge", "itemLevelBadge", "The small iLvl box under an equipment icon.",
        showingItems },
    { "Stat markers", "statMarkers", "The small diamond before each stat; enchants use a green one.",
        showingItems },
    { "Stat colors", "statColors",
        "Teal for attributes, orange for attack, blue for defense, purple for magic, green for "
            .. "healing, and the school colors. Off, every stat is parchment.", showingItems },
    { "Tint the panel", "qualityTint",
        "Washes the panel in the item's quality color, or the spell's school or resource. Off, "
            .. "every panel is neutral; the name keeps its quality color." },
    { "Separators", "separators",
        "The gold dividers between sections and the thin rules above other addons' rows. Off, "
            .. "they are hidden along with the space around them." },
    { "DialogueUI backdrop", "dialogueBackdrop",
        "Draws the panel on DialogueUI's dark textured background, read from that addon's folder. "
            .. "Needs DialogueUI installed; off, or without it, the panel is a plain dark gradient.",
        function() return ns.isInstalled("DialogueUI") end },
}
for index, toggle in ipairs(TOGGLES) do
    local box = checkbox(toggle[1], toggle[2], toggle[3], toggle[4])
    local column = (index - 1) % 2
    box:SetPoint("TOPLEFT", CONTROLS_X + column * (CONTROLS_WIDTH / 2), y)
    if column == 1 or index == #TOGGLES then y = y - 26 end
end
y = y - 4

-- A default value is saved as no setting, so it keeps following the backdrop.
local function bandOpacity(edge)
    local function key() return "header" .. edge .. "Alpha" .. ns.KIND_SUFFIX[state.kind] end
    -- What the kind shows with no setting of its own.
    local function fallback() return ns.option("header" .. edge .. "Alpha") or ui.defaultHeaderAlpha() end
    return slider(FIELD_WIDTH, function()
        return math.floor((ns.headerAlpha(state.kind, edge) or ui.defaultHeaderAlpha()) * 100 + .5)
    end, function(percent)
        local alpha = percent / 100
        ns.setOption(key(), math.abs(alpha - fallback()) > .001 and alpha or nil)
    end, 0, 100, "%")
end
row("Band top", bandOpacity("Top"))
row("Band bottom", bandOpacity("Bottom"))

-- Full opacity is saved as no setting.
local function kindOpacity(name)
    local function key() return name .. ns.KIND_SUFFIX[state.kind] end
    return slider(FIELD_WIDTH, function()
        return math.floor((ns.option(key()) or 1) * 100 + .5)
    end, function(percent)
        ns.setOption(key(), percent < 100 and percent / 100 or nil)
    end, 0, 100, "%")
end
row("Backdrop", kindOpacity("backdropAlpha"))
row("Glow", kindOpacity("glowAlpha"))
row("Footer", kindOpacity("footerAlpha"))

local resetAll = flatButton(editor, "Reset all fonts and colors", 170, function()
    ns.resetStyles()
    refresh()
end)
resetAll:SetPoint("BOTTOMLEFT", editor, "BOTTOMLEFT", CONTROLS_X, 16)
local moreOptions = flatButton(editor, "More options", 100, function()
    editor:Hide()
    ns.openSettings()
end)
moreOptions:SetPoint("BOTTOMRIGHT", editor, "BOTTOMRIGHT", -18, 16)

-- Wiring ---------------------------------------------------------------------

refresh = function()
    drawSample()
    for kind, tab in pairs(kindTabs) do tab:SetSelected(kind == state.kind) end
    for index, tab in ipairs(sampleTabs) do
        local sample = samples()[index]
        tab:SetShown(sample ~= nil)
        if sample then
            tab.label:SetText(sample.label)
            tab:SetSelected(not state.lookup and index == state.sample)
        end
    end
    refreshLookup()
    partNote:SetText(selectedElement().note or "")
    for _, control in ipairs(controls) do control.refresh() end
    paintHighlights()
    showHint()
end

editor:SetScript("OnShow", function() refresh() end)
editor:SetScript("OnHide", closeMenu)
editor:RegisterEvent("GET_ITEM_INFO_RECEIVED")
editor:SetScript("OnEvent", function(_, _, itemID)
    if editor:IsShown() and state.kind == "item" and itemID == state.lookup then refresh() end
end)

function ns.openEditor()
    editor:Show()
    editor:Raise()
end
