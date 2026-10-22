-- A unit's level goes on a plate under its portrait; with the plate off, or no
-- portrait, it stays in the info line.
return function(test)
    local UNIT = 2
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Unit.lua" },
        { enums = { TooltipDataType = { Item = 0, Unit = UNIT } } })
    local model = ns.ui.unitModel({ name = "Thrall", isPlayer = true, level = 60, race = "Orc",
        className = "Shaman", classFile = "SHAMAN", iconPath = "Interface\\Icons\\Spell_Nature_BloodLust",
        quests = {} })
    local anchor = CreateFrame("Frame", nil, UIParent)
    local function drawn()
        local panel = ns.ui.renderPreview(anchor, model, UNIT)
        local info, targetLabel, targetValue
        for _, font in ipairs(panel.pool) do
            if font._shown then
                if (font._text or ""):find("Orc Shaman", 1, true) then info = font._text end
                local text = ns.util.plainText(font._text or "")
                if text == "Target" then targetLabel = text end
                if text == "-" then targetValue = text end
            end
        end
        return { plate = panel.badge._shown and panel.badgeText._text or false, info = info,
            target = { targetLabel, targetValue } }
    end

    test.check("the level is on the plate and a player always has a target row",
        drawn(), { plate = "60", info = "Orc Shaman", target = { "Target", "-" } })
    local function targetText(unitModel)
        local panel = ns.ui.renderPreview(anchor, unitModel, UNIT)
        local texts = {}
        for _, font in ipairs(panel.pool) do
            if font._shown then texts[#texts + 1] = ns.util.plainText(font._text or "") end
        end
        return table.concat(texts, " ")
    end
    local function panelWidth(unitModel)
        return ns.ui.renderPreview(anchor, unitModel, UNIT).width
    end
    local function unitLayoutKey(unitModel)
        local panel = ns.ui.renderPreview(anchor, unitModel, UNIT)
        return ns.ui.unitLayoutKey(panel, unitModel), panel:GetHeight()
    end
    local function includes(list, value)
        for _, candidate in ipairs(list) do
            if candidate == value then return true end
        end
        return false
    end
    local neutral = ns.ui.unitModel({ name = "Wandering Beast", guid = "Creature-neutral",
        creature = "Beast", reaction = 4, isPlayer = false, target = "Thrall", targetIsYou = true, quests = {} })
    local neutralText = targetText(neutral)
    test.check("neutral NPCs always get a short, playful target field",
        { neutral.targetFlavor, #neutral.targetFlavor <= 24, neutralText:find("Target", 1, true) ~= nil,
            neutralText:find(neutral.targetFlavor, 1, true) ~= nil,
            neutralText:find("You", 1, true) == nil,
            neutral.targetFlavor:match("^%u") ~= nil,
            includes({ "Grazing", "Frolicking", "Day-dreaming", "Wandering", "Humming" }, neutral.targetFlavor) },
        { neutral.targetFlavor, true, true, true, true, true, true })
    local playerWidth = panelWidth(model)
    local neutralWidth = panelWidth(neutral)
    test.check("unit tooltips keep one width sized for a two-word, 12-character name",
        { playerWidth, neutralWidth, playerWidth == neutralWidth }, { playerWidth, playerWidth, true })
    local hostile = ns.ui.unitModel({ name = "Hostile Humanoid", guid = "Creature-hostile",
        creature = "Humanoid", reaction = 2, isPlayer = false, quests = {} })
    local hostileText = targetText(hostile)
    test.check("humanoid NPCs show an everyday activity even when hostile",
        { hostile.targetFlavor, #hostile.targetFlavor <= 24, hostileText:find("Target", 1, true) ~= nil,
            hostileText:find(hostile.targetFlavor, 1, true) ~= nil,
            hostile.targetFlavor:match("^%u") ~= nil,
            includes({ "Stretching their legs", "Checking their pockets", "Muttering to themself", "Taking a break" },
                hostile.targetFlavor) },
        { hostile.targetFlavor, true, true, true, true, true })
    local hostileBeast = ns.ui.unitModel({ name = "Hostile Beast", guid = "Creature-hostile-beast",
        creature = "Beast", reaction = 2, isPlayer = false, quests = {} })
    test.check("hostile creature wording follows its type",
        { hostileBeast.targetFlavor:match("^%u") ~= nil,
            includes({ "Prowling", "Stalking", "Circling", "Hunting" }, hostileBeast.targetFlavor) },
        { true, true })
    local friendlyBeast = ns.ui.unitModel({ name = "Friendly Beast", guid = "Creature-friendly-beast",
        creature = "Beast", reaction = 5, isPlayer = false, quests = {} })
    test.check("friendly NPCs get a short everyday target activity",
        { friendlyBeast.targetFlavor, #friendlyBeast.targetFlavor <= 24,
            friendlyBeast.targetFlavor:match("^%u") ~= nil,
            includes({ "Taking a stroll", "Enjoying the sunshine", "Chatting with a neighbor",
                "Practicing a hobby", "Taking a short break", "Watching the clouds",
                "Browsing the market", "Savoring a snack" }, friendlyBeast.targetFlavor) },
        { friendlyBeast.targetFlavor, true, true, true })
    local pveLayout, pveHeight = unitLayoutKey(friendlyBeast)
    local pvpBeast = ns.ui.unitModel({ name = "PvP Beast", guid = "Creature-pvp-beast",
        creature = "Beast", reaction = 5, pvp = true, isPlayer = false, quests = {} })
    local pvpLayout, pvpHeight = unitLayoutKey(pvpBeast)
    test.check("NPC headers label PvP and non-PvP units without changing layout height",
        { pveLayout:find("PvE", 1, true) ~= nil, pveLayout:find("PvP", 1, true) == nil,
            pvpLayout:find("PvP", 1, true) ~= nil, pvpLayout:find("PvE", 1, true) == nil,
            pveHeight == pvpHeight },
        { true, true, true, true, true })
    local playerWithoutPvp = ns.ui.unitModel({ name = "Friendly Player", isPlayer = true, quests = {} })
    local playerLayout = unitLayoutKey(playerWithoutPvp)
    test.check("PvE labels are limited to NPCs",
        { playerLayout:find("PvE", 1, true) == nil, playerLayout:find("PvP", 1, true) == nil },
        { true, true })
    local bodyguard = ns.ui.unitModel({ name = "Jorb", creature = "Humanoid", tag = "Bodyguard",
        target = "Lizarrik", isPlayer = false, quests = {} })
    local bodyguardText = targetText(bodyguard)
    test.check("a humanoid bodyguard shows the actual unit it is guarding",
        { bodyguard.targetRole, #bodyguard.targetFlavor <= 24,
            bodyguardText:find("Lizarrik", 1, true) ~= nil,
            bodyguardText:find("You", 1, true) == nil },
        { "bodyguard", true, true, true })
    local unassignedBodyguard = ns.ui.unitModel({ name = "Jorb", creature = "Humanoid", tag = "Bodyguard",
        isPlayer = false, quests = {} })
    test.check("a bodyguard without a current target describes its role",
        { unassignedBodyguard.targetRole, #unassignedBodyguard.targetFlavor <= 24,
            targetText(unassignedBodyguard):find(unassignedBodyguard.targetFlavor, 1, true) ~= nil,
            includes({ "Checking the perimeter", "Watching the door", "Standing guard" },
                unassignedBodyguard.targetFlavor) },
        { "bodyguard", true, true, true })
    local weaponVendor = ns.ui.unitModel({ name = "Merchant", creature = "Humanoid", tag = "Weapon Vendor",
        isPlayer = false, quests = {} })
    test.check("humanoid vendors get an activity matching their role",
        { weaponVendor.targetRole, #weaponVendor.targetFlavor <= 24,
            includes({ "Polishing wares", "Checking the stock", "Counting coins", "Haggling" },
                weaponVendor.targetFlavor) },
        { "weaponVendor", true, true })
    local deadBeast = ns.ui.unitModel({ name = "Dead Beast", guid = "Creature-dead",
        creature = "Beast", reaction = 2, dead = true, isPlayer = false, quests = {} })
    local deadText = targetText(deadBeast)
    test.check("dead NPCs get a funny target message while awaiting despawn or skinning",
        { deadBeast.targetFlavor, #deadBeast.targetFlavor <= 24,
            deadText:find("Target", 1, true) ~= nil, deadText:find(deadBeast.targetFlavor, 1, true) ~= nil,
            deadBeast.targetFlavor:match("^%u") ~= nil,
            includes({ "Taking a dirt nap", "Off-duty forever", "Waiting for a skinning",
                "Practicing stillness", "Loot-window shopping" }, deadBeast.targetFlavor) },
        { deadBeast.targetFlavor, true, true, true, true, true })
    ns.setOption("unitLevelBadge", false)
    test.check("with the plate off, the info line has it", drawn(),
        { plate = false, info = "Level 60 Orc Shaman", target = { "Target", "-" } })
    ns.setOption("unitLevelBadge", true)
    ns.setOption("iconUnits", false)
    test.check("without a portrait, the info line has it", drawn(),
        { plate = false, info = "Level 60 Orc Shaman", target = { "Target", "-" } })
    ns.setOption("iconUnits", true)
    model.level = -1
    test.check("a skull level shows as ??", drawn().plate, "??")
end
