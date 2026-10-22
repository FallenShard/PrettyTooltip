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
                if text == "None" then targetValue = text end
            end
        end
        return { plate = panel.badge._shown and panel.badgeText._text or false, info = info,
            target = { targetLabel, targetValue } }
    end

    test.check("the level is on the plate and a player always has a target row",
        drawn(), { plate = "60", info = "Orc Shaman", target = { "Target", "None" } })
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
    local function headerHeight(unitModel)
        return ns.ui.renderPreview(anchor, unitModel, UNIT).header:GetHeight()
    end
    local function unitLayoutKey(unitModel)
        local panel = ns.ui.renderPreview(anchor, unitModel, UNIT)
        return ns.ui.unitLayoutKey(panel, unitModel), panel:GetHeight()
    end
    local shortHeaderHeight = headerHeight(model)
    model.factionName, model.pvp = "Stormwind", true
    test.check("unit headers reserve the same height for five rows",
        { headerHeight(model), shortHeaderHeight }, { shortHeaderHeight, shortHeaderHeight })
    model.factionName, model.pvp = nil, nil
    local minion = ns.ui.unitModel({ name = "Warlock's Minion", guid = "Creature-minion",
        creature = "Demon", reaction = 5, isPlayer = false, owner = "Warlock", quests = {} })
    local minionWithoutTarget = targetText(minion)
    minion.target, minion.targetColor = "Enemy", { 1, .27, .22 }
    local minionWithTarget = targetText(minion)
    test.check("an owned unit omits an empty target and shows its current target",
        { minionWithoutTarget:find("Target", 1, true) == nil,
            minionWithTarget:find("Target", 1, true) ~= nil,
            minionWithTarget:find("Enemy", 1, true) ~= nil },
        { true, true, true })
    local playerWidth = panelWidth(model)
    local npc = ns.ui.unitModel({ name = "Wandering Beast", guid = "Creature-neutral",
        creature = "Beast", reaction = 4, isPlayer = false, quests = {} })
    local npcWidth = panelWidth(npc)
    test.check("unit tooltips keep one width sized for a two-word, 12-character name",
        { playerWidth, npcWidth, playerWidth == npcWidth }, { playerWidth, playerWidth, true })
    local pveLayout, pveHeight = unitLayoutKey(npc)
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
    ns.setOption("unitLevelBadge", false)
    test.check("with the plate off, the info line has it", drawn(),
        { plate = false, info = "Level 60 Orc Shaman", target = { "Target", "None" } })
    ns.setOption("unitLevelBadge", true)
    ns.setOption("iconUnits", false)
    test.check("without a portrait, the info line has it", drawn(),
        { plate = false, info = "Level 60 Orc Shaman", target = { "Target", "None" } })
    ns.setOption("iconUnits", true)
    model.level = -1
    test.check("a skull level shows as ??", drawn().plate, "??")
end
