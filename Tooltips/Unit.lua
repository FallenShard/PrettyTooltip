-- Players and NPCs as a panel.
local _, ns = ...
local ui = ns.ui
local UNIT = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit
if not (ui and UNIT and ui.renderView) then
    return
end

local util = ns.util
local tooltipData = ns.TooltipData
local colors = ns.Palette.roles
local isSecret, safeText, trim, hex = util.isSecret, util.safeText, util.trim, util.hex
local unformat = util.unformat
local formats = ns.Locale.formats
local L = ns.L
local get = util.call
local LINE = Enum.TooltipDataLineType or {}
local WHITE = "Interface\\Buttons\\WHITE8X8"
local ICON_SIZE = 38
local TINT_STRENGTH = .7
local TAPPED = { .55, .55, .55 }
local DETAIL_COLOR = colors.detail
local MUTED = colors.caption
local EXTRAS_RULE = { .50, .50, .54 }
local UNMET_COLOR = colors.unmet
local REACTION = {
    { 1, .27, .22 }, { 1, .27, .22 }, { 1, .50, .20 }, { 1, .82, .20 },
    { .30, .85, .35 }, { .30, .85, .35 }, { .30, .85, .35 }, { .30, .85, .35 },
}
local BADGES = {
    elite = { ELITE, { .95, .78, .30 } },
    rareelite = { formats.rareElite, { .70, .80, .95 } },
    rare = { formats.rare, { .70, .80, .95 } },
    worldboss = { BOSS, { 1, .35, .25 } },
}
-- The rank the tooltip's level line names, as "Level ?? (Boss)". It outranks
-- UnitClassification, which answers "elite" for bosses such as faction
-- leaders that the tooltip and the target frame show as bosses.
local RANKS = {}
for _, rank in ipairs({ { BOSS, "worldboss" }, { ELITE, "elite" }, { formats.rare, "rare" },
    { formats.rareElite, "rareelite" } }) do
    if rank[1] then RANKS[rank[1]] = rank[2] end
end
-- Lines the badges and the faction crest show: "Alliance", "PvP", "Dead".
local SHOWN_ELSEWHERE = {}
for _, word in pairs({ FACTION_ALLIANCE, FACTION_HORDE, PVP_ENABLED, DEAD, CORPSE, UNIT_SKINNABLE_LEATHER }) do
    SHOWN_ELSEWHERE[word] = true
end

-- What the level line names in parentheses, then the level and race before
-- it: "Boss" in "Level ?? (Boss)", "Player" in "Level 12 Night Elf (Player)".
local function levelKind(text)
    local level, race, kind = unformat(text, TOOLTIP_UNIT_LEVEL_RACE_TYPE)
    if level then return kind, level, race end
    level, kind = unformat(text, TOOLTIP_UNIT_LEVEL_TYPE)
    return kind, level
end
local ART = "Interface\\AddOns\\PrettyTooltip\\art\\"
-- Watermarks in the panel's top right, the same size on every panel, so a
-- taller panel shows more of one: width by height, right and top the gaps to
-- the panel's edges (negative runs off them); coords, the part of the file
-- drawn. The faction crests are white silhouettes, tinted here.
local FACTION_SIZE = { width = 200, height = 200, right = -44, top = -24, alpha = .12,
    coords = { 0, 1, 0, 1 } }
local function factionArt(file, color)
    return setmetatable({ file = ART .. file, color = color }, { __index = FACTION_SIZE })
end
local FACTION_ART = {
    Alliance = factionArt("faction-alliance", { .40, .60, 1 }),
    Horde = factionArt("faction-horde", { .90, .25, .20 }),
}
-- Elites, rares, and bosses get the dragon from the game's target frame,
-- drawn from the client's own art. Every dragon shares the scale that makes
-- the elite's DRAGON_HEIGHT tall, and right and top place the elite's; x and
-- y move each other's top right corner from it, right and down, in atlas
-- pixels, as the target frame lines them up around its portrait.
local DRAGON_HEIGHT, DRAGON_RIGHT, DRAGON_TOP, DRAGON_ALPHA = 229, -19, 17, .35
local ATLAS = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-"
local DRAGONS = {
    elite = { atlas = ATLAS .. "Gold", x = 0, y = 0 },
    worldboss = { atlas = ATLAS .. "Gold-Winged", x = 11, y = 5 },
    rare = { atlas = ATLAS .. "Rare-Silver", x = 0, y = 0 },
    rareelite = { atlas = ATLAS .. "Rare-Silver-Winged", x = 8, y = 8 },
}
local NO_TINT = { 1, 1, 1 }
-- The game's health bar at the bottom of the panel: the space above it, and
-- its height.
local HEALTH_BEFORE, HEALTH_HEIGHT = 6, 6
local PARTS = { "unitName", "unitInfo", "unitBadges", "unitGuild", "unitSkinning", "unitDetails",
    "unitQuests", "extras" }

-- The mouseover token can still be the previous unit; the data's GUID cannot.
local function unitFor(tooltip, guid, game)
    if isSecret(guid) then guid = nil end
    local _, unit = get(tooltip.GetUnit, tooltip)
    if type(unit) == "string" and game.unitExists(unit) and (not guid or game.unitGUID(unit) == guid) then
        return unit
    end
    if guid then
        unit = game.unitToken(guid)
        if type(unit) == "string" and game.unitExists(unit) then return unit end
    end
    if guid and game.unitExists("mouseover") and game.unitGUID("mouseover") == guid then
        return "mouseover"
    end
end

local function unitColor(unit, game)
    if game.unitIsPlayer(unit) then
        local _, classFile = game.unitClass(unit)
        return ns.Palette.classColor(classFile, game)
    end
    local reaction = game.unitReaction(unit, "player")
    return reaction and REACTION[reaction]
end

-- Asked while drawing, until Phase 5 moves it into the model.
local function levelColor(level)
    if level == -1 then return UNMET_COLOR end
    return ns.Game.difficultyColor(level)
end

-- Skinning a corpse: the skill a creature's level needs, as Classic sets it,
-- and what it may give, by its ID from its GUID ("Creature-0-...-<ID>-...").
local SKINNABLE_COLOR = { .80, .62, .42 }
local LOOT_ICON = 14
local RARE = 5

local function skinningNeeded(level)
    if level <= 10 then return 1 end
    if level <= 20 then return (level - 10) * 10 end
    return level * 5
end

-- An NPC's ID from its GUID; nil for players.
local function npcID(guid)
    if type(guid) ~= "string" then return end
    return tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
        or guid:match("^Vehicle%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
end

local function skinning(model, game)
    if not (model.dead and ns.skinningLoot) then return end
    local creatureID = npcID(model.guid)
    local drops = creatureID and ns.skinningLoot(creatureID)
    if not drops then return end
    local needed = type(model.level) == "number" and model.level > 0 and skinningNeeded(model.level) or nil
    local rows = {}
    for _, drop in ipairs(drops) do
        local icon = game.itemIcon(drop[1])
        local count = drop[4] == drop[5] and "" or (" (" .. util.fill(L["%s to %s"], drop[4], drop[5]) .. ")")
        local name = game.itemName(drop[1]) or drop[2]
        rows[#rows + 1] = { left = (icon and ("|T" .. icon .. ":" .. LOOT_ICON .. "|t ") or "") .. name .. count,
            right = drop[3] .. "%", rare = drop[3] < RARE }
    end
    return { needed = needed, player = game.skill("Skinning"), rows = rows }
end

-- Retail unit enhancements; all optional data are guarded against 12.x secret values.
local function safeValue(value)
    return value ~= nil and not isSecret(value) and value
end
local function colored(text, color)
    if not text or text == "" or not color then return text end
    return "|cff" .. hex(color) .. text .. "|r"
end
-- Other players' average item level is not guaranteed to be available until
-- INSPECT_READY. Keep the value keyed by GUID, never by the volatile mouseover
-- unit token, and ask the panel to redraw once the inspected data is ready.
local inspectIlvlCache, inspectIlvlRequests = {}, {}
local INSPECT_ILVL_TTL, INSPECT_ILVL_RETRY = 180, 3
local inspectIlvlFrame = CreateFrame("Frame")
inspectIlvlFrame:RegisterEvent("INSPECT_READY")
inspectIlvlFrame:SetScript("OnEvent", function(_, _, guid)
    if not guid or isSecret(guid) or not inspectIlvlRequests[guid] then return end
    local request = inspectIlvlRequests[guid]
    local unit = request.unit
    if not (unit and UnitGUID and not isSecret(UnitGUID(unit)) and UnitGUID(unit) == guid) then return end
    if not (C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel) then return end
    local ok, value = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
    if not ok or isSecret(value) or type(value) ~= "number" or value <= 0 then return end
    inspectIlvlCache[guid] = { value = value, at = GetTime() }
    inspectIlvlRequests[guid] = nil
    if ns.Hooks and ns.Hooks.refreshUnit then
        C_Timer.After(0, function() ns.Hooks.refreshUnit(guid) end)
    end
end)
local function requestInspectIlvl(unit, guid)
    if not (guid and not isSecret(guid) and CanInspect and NotifyInspect and GetTime) then return end
    local cached = inspectIlvlCache[guid]
    if cached and GetTime() - cached.at < INSPECT_ILVL_TTL then return cached.value end
    if cached then inspectIlvlCache[guid] = nil end
    local requested = inspectIlvlRequests[guid]
    if requested and GetTime() - requested.at < INSPECT_ILVL_RETRY then return end
    local ok, can = pcall(CanInspect, unit)
    if not ok or isSecret(can) or not can then return end
    inspectIlvlRequests[guid] = { unit = unit, at = GetTime() }
    -- Let the tooltip settle before requesting inspection, like CaiseTip.
    C_Timer.After(.3, function()
        local pending = inspectIlvlRequests[guid]
        if not pending or pending.unit ~= unit then return end
        local current = UnitGUID(unit)
        if isSecret(current) or current ~= guid then return end
        local allowed, canNow = pcall(CanInspect, unit)
        if not allowed or isSecret(canNow) or not canNow then return end
        pcall(NotifyInspect, unit)
    end)
end

local function playerItemLevel(unit)
    if not unit or not UnitIsUnit then return end
    local ok, selfUnit = pcall(UnitIsUnit, unit, "player")
    if not ok or isSecret(selfUnit) then return end
    local value
    if selfUnit and GetAverageItemLevel then
        local success, _, equipped = pcall(GetAverageItemLevel)
        if success then value = equipped end
    elseif C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local guid = UnitGUID and UnitGUID(unit)
        if not isSecret(guid) and guid then
            value = requestInspectIlvl(unit, guid)
        end
        -- Existing inspect data may already be ready (e.g. inspect window).
        if not value then
            local success, result = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
            if success and not isSecret(result) and type(result) == "number" and result > 0 then
                value = result
                if guid and not isSecret(guid) then
                    inspectIlvlCache[guid] = { value = result, at = GetTime() }
                end
            end
        end
    end
    if not safeValue(value) or type(value) ~= "number" or value <= 0 then return end
    return math.floor(value * 10 + .5) / 10
end
-- Cache only stable mount metadata. Aura presence is still checked on every
-- tooltip build, so mounting/dismounting updates immediately. Bounded tables
-- avoid retaining one entry for every spell encountered over a long session.
local mountSpellIDs, mountDetails = {}, {}
local mountSpellCount, mountDetailCount = 0, 0
local MOUNT_CACHE_LIMIT = 256
local function mountIDForSpell(spellID)
    local cached = mountSpellIDs[spellID]
    if cached ~= nil then return cached ~= false and cached or nil end
    local found, mountID = pcall(C_MountJournal.GetMountFromSpell, spellID)
    if not found or isSecret(mountID) then return end
    if mountSpellCount >= MOUNT_CACHE_LIMIT then
        wipe(mountSpellIDs)
        mountSpellCount = 0
    end
    mountSpellCount = mountSpellCount + 1
    mountSpellIDs[spellID] = mountID or false
    return mountID
end
local function mountDetailsForID(mountID)
    local cached = mountDetails[mountID]
    if cached then return cached end
    local got, name, _, _, _, _, _, _, _, _, _, collected = pcall(C_MountJournal.GetMountInfoByID, mountID)
    if not got or not safeValue(name) then return end
    local source
    if C_MountJournal.GetMountInfoExtraByID then
        local extraOK, _, _, result = pcall(C_MountJournal.GetMountInfoExtraByID, mountID)
        if extraOK and safeValue(result) then source = result end
    end
    -- Collection state can change while playing; refresh it on each use.
    cached = { name = name, source = source }
    if mountDetailCount >= MOUNT_CACHE_LIMIT then
        wipe(mountDetails)
        mountDetailCount = 0
    end
    mountDetailCount = mountDetailCount + 1
    mountDetails[mountID] = cached
    return cached, collected
end
local function playerMount(unit)
    if not unit or not C_UnitAuras or not C_MountJournal or not C_MountJournal.GetMountFromSpell then return end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
        if not ok or secret then return end
    end
    for i = 1, 40 do
        if C_Secrets and C_Secrets.ShouldUnitAuraIndexBeSecret then
            local ok, secret = pcall(C_Secrets.ShouldUnitAuraIndexBeSecret, unit, i, "HELPFUL")
            if not ok or secret then return end
        end
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
        if not ok or not safeValue(aura) then break end
        local spellID = safeValue(aura.spellId)
        if spellID then
            local mountID = mountIDForSpell(spellID)
            if mountID then
                local details, collected = mountDetailsForID(mountID)
                if details then
                    -- Refresh collection status without repeating the more
                    -- expensive mount source lookup.
                    if collected == nil then
                        local got, _, _, _, _, _, _, _, _, _, _, state = pcall(C_MountJournal.GetMountInfoByID, mountID)
                        if got then collected = state end
                    end
                    return { name = details.name, collected = safeValue(collected), source = details.source }
                end
            end
        end
    end
end

local function completeModel(model, unit, game)
    if unit then
        model.isPlayer = game.unitIsPlayer(unit)
        model.level = game.unitLevel(unit)
        if model.isPlayer then
            model.className, model.classFile = game.unitClass(unit)
            model.race = game.unitRace(unit)
            model.guild, model.guildRank = game.unitGuild(unit)
            -- GetGuildInfo returns the guild realm as its fourth result.
            -- Do not substitute the character realm: cross-realm guilds may differ.
            model.guildRealm = nil
            if GetGuildInfo then
                local ok, guildName, _, _, guildRealm = pcall(GetGuildInfo, unit)
                if ok and not isSecret(guildName) and not isSecret(guildRealm)
                    and type(guildName) == "string" and type(guildRealm) == "string"
                    and guildName ~= "" and guildRealm ~= "" then
                    model.guildRealm = guildRealm
                end
            end
            model.faction = game.unitFaction(unit)
            model.afk, model.dnd = game.unitIsAFK(unit), game.unitIsDND(unit)
            model.itemLevel = playerItemLevel(unit)
            model.mount = playerMount(unit)
        else
            model.creature = game.unitCreatureType(unit)
            model.classification = game.unitClassification(unit)
        end
        model.pvp = game.unitIsPVP(unit)
        model.dead = game.unitIsDead(unit)
        model.reaction = game.unitReaction(unit, "player")
        model.tapped = game.unitIsTapDenied(unit)
        local target = unit .. "target"
        if game.unitExists(target) then
            model.target = game.unitName(target)
            model.targetIsYou = game.unitIsUnit(target, "player")
            model.targetColor = unitColor(target, game)
        end
    end
    -- An NPC's title, as "Herbalism Supplier", is the untyped line between its
    -- name and its level; Forever leaves out the brackets around it.
    if not model.isPlayer and not model.tag and model.levelIndex then
        for index, row in ipairs(model.extras) do
            if row.lineIndex and row.lineIndex < model.levelIndex and (row.right or "") == "" then
                model.tag = trim(row.left)
                table.remove(model.extras, index)
                break
            end
        end
    end
    local rank = not model.isPlayer and model.levelLine and RANKS[levelKind(model.levelLine) or ""]
    if rank then model.classification = rank end
    -- Forever puts the guild, unbracketed, and the class on lines of their own;
    -- the header already shows them.
    local shown = {}
    for _, value in ipairs({ model.guild or false, model.className or false, model.race or false,
        model.creature or false }) do
        if value then shown[value] = true end
    end
    for index = #model.extras, 1, -1 do
        local row = model.extras[index]
        if (row.right or "") == "" and shown[(trim(row.left):gsub("^<(.*)>$", "%1"))] then
            table.remove(model.extras, index)
        end
    end
    -- Retail player tooltips may append a duplicate guild line and a
    -- specialization/class line. Move the spec into the existing race/class
    -- header and remove only these redundant lines from the extras section.
    if model.isPlayer then
        local function normalize(text)
            text = trim(util.plainText(text or ""))
            return (text:gsub("^<(.*)>$", "%1"))
        end
        local guild = normalize(model.guild)
        local className = normalize(model.className)
        for index = #model.extras, 1, -1 do
            local row = model.extras[index]
            if (row.right or "") == "" then
                local value = normalize(row.left)
                local spec
                if className ~= "" and #value > #className
                    and value:sub(-#className) == className then
                    spec = trim(value:sub(1, #value - #className))
                end
                local guildWithRealm = guild
                if guild ~= "" and type(model.guildRealm) == "string" and model.guildRealm ~= "" then
                    guildWithRealm = guild .. "-" .. model.guildRealm
                end
                if guild ~= "" and (value == guild or value == guildWithRealm) then
                    table.remove(model.extras, index)
                elseif spec and spec ~= "" then
                    model.specName = model.specName or spec
                    table.remove(model.extras, index)
                end
            end
        end
    end
    -- An NPC's faction, as "Ironforge": the line right after its level. A
    -- player's class comes there, and the crest shows its faction.
    if not model.isPlayer and model.levelIndex then
        for index, row in ipairs(model.extras) do
            if row.lineIndex == model.levelIndex + 1 and (row.right or "") == ""
                and not unformat(trim(row.left), ITEM_REQ_SKILL) then
                model.factionName = trim(row.left)
                table.remove(model.extras, index)
                break
            end
        end
    end
    model.skinning = model.skinning or skinning(model, game)
    if model.isPlayer then
        model.color = ns.Palette.classColor(model.classFile, game)
    elseif model.tapped then
        model.color = TAPPED
    else
        model.color = model.reaction and REACTION[model.reaction]
    end
    return model
end

local function unitKey(_, data)
    if isSecret(data.guid) then return end
    return data.guid
end

local function readUnit(tooltip, data, game)
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local unit = unitFor(tooltip, data.guid, game)
    local model = { quests = {}, extras = {}, lineIndices = {}, unit = unit,
        guid = not isSecret(data.guid) and data.guid or nil }
    for _, line in ipairs(data.lines) do
        if isSecret(line) or not line or isSecret(line.type) or isSecret(line.lineIndex) then return end
        if line.lineIndex then
            local left, right = safeText(line.leftText), safeText(line.rightText)
            if not left or not right then return end
            model.lineIndices[line.lineIndex] = true
            local text = trim(left)
            if not model.name then
                model.name = text
            elseif text ~= "" or right ~= "" then
                if unformat(text, TOOLTIP_UNIT_LEVEL) then
                    -- The panel names a player as one by its colors and badges.
                    local kind, level, race = levelKind(text)
                    model.levelLine, model.levelIndex = text, line.lineIndex
                    if kind == PLAYER then
                        model.levelLine = race and util.fill(TOOLTIP_UNIT_LEVEL_RACE, level, race)
                            or util.fill(TOOLTIP_UNIT_LEVEL, level)
                    end
                elseif text:match("^<.+>$") and not model.tag then
                    model.tag = text
                elseif SHOWN_ELSEWHERE[text] then
                    -- Shown as badges.
                elseif LINE.UnitOwner and line.type == LINE.UnitOwner then
                    model.owner = text
                elseif LINE.QuestTitle and line.type == LINE.QuestTitle then
                    tooltipData.add(model.quests, left, right)
                    model.quests[#model.quests].title = true
                elseif (LINE.QuestObjective and line.type == LINE.QuestObjective)
                    or (LINE.QuestPlayer and line.type == LINE.QuestPlayer) then
                    tooltipData.add(model.quests, left, right)
                    if not isSecret(line.completed) then
                        model.quests[#model.quests].completed = line.completed == true
                    end
                else
                    tooltipData.add(model.extras, left, right)
                    local row = model.extras[#model.extras]
                    row.color, row.rightColor = tooltipData.colorOf(line.leftColor), tooltipData.colorOf(line.rightColor)
                    row.lineIndex = line.lineIndex
                end
            end
        end
    end
    if not model.name or model.name == "" then return end
    -- Merge appended native tooltip lines before deduplication. Retail guild
    -- and specialization lines may arrive here rather than in data.lines.
    local appended = tooltipData.appendedRows(tooltip, model.lineIndices)
    if appended then
        for _, row in ipairs(appended) do
            if trim(row.left) ~= "" or row.right ~= "" then model.extras[#model.extras + 1] = row end
        end
    end
    -- Resolve player information (including equipped item level) BEFORE adding
    -- rating rows. Previously completeModel ran at the very end, so
    -- model.itemLevel was always nil when the rating section was built.
    model = completeModel(model, unit, game)
    -- Integrate Mythic+ rating into the styled panel, not the hidden native tooltip.
    if unit and ns.MythicScore then
        local ratingRows = ns.MythicScore.rows(unit)
        if ratingRows then
            if model.itemLevel then
                local ilvl = model.itemLevel
                -- Item-level color thresholds (upper bounds, inclusive).
                local tint = ilvl <= 285 and "808080" or ilvl <= 298 and "1eff00"
                    or ilvl <= 311 and "0070ff" or ilvl <= 324 and "a335ee"
                    or ilvl <= 334 and "ff8000" or "e6cc80"
                model.extras[#model.extras + 1] = {
                    left = "物品等级：|cff" .. tint .. string.format("%.1f", ilvl) .. "|r", right = "" }
            end
            if ns.mythicScoreKeyDown() then
                for _, row in ipairs(ratingRows) do model.extras[#model.extras + 1] = row end
            end
        end
    end
    return model
end

-- The level on a plate under the portrait, as the game's target frame shows
-- it; nil without a portrait to put it under, or with the plate turned off,
-- and the info line shows it instead.
local function levelBadge(model, hasIcon)
    if not hasIcon or type(model.level) ~= "number" or not ns.option("unitLevelBadge") then return end
    return model.level == -1 and "??" or tostring(model.level)
end

-- The level and kind, then an NPC's title after a dot: "Humanoid · Herbalism Supplier".
local function infoText(model, plated)
    local raceColor = model.faction == "Alliance" and { .42, .66, 1 }
        or model.faction == "Horde" and { 1, .37, .33 } or NO_TINT
    local what = model.isPlayer and table.concat({
        colored(model.race or "", raceColor), colored(model.className or "", model.color or NO_TINT),
        colored(model.specName or "", { .60, .80, 1 }) -- CaiseTip SpecName #99CCFF
    }, " ") or (model.creature or "")
    local info
    if plated then
        info = trim(what)
    elseif not model.level then
        info = model.levelLine or ""
    else
        local level = model.level
        local levelText = level == -1 and "??" or tostring(level)
        local color = levelColor(level)
        if color then levelText = "|cff" .. hex(color) .. levelText .. "|r" end
        info = trim(util.fill(TOOLTIP_UNIT_LEVEL_RACE, levelText, what))
    end
    local tag = not model.isPlayer and model.tag and model.tag:gsub("^<(.*)>$", "%1")
    if tag and tag ~= "" then info = info ~= "" and (info .. " \194\183 " .. tag) or tag end
    return info ~= "" and info or nil
end

local function badges(model)
    local list = {}
    local classification = model.classification and BADGES[model.classification]
    if classification then list[#list + 1] = classification end
    if model.pvp then list[#list + 1] = { PVP_ENABLED, { 1, .45, .35 } } end
    if model.afk then list[#list + 1] = { L["AFK"], MUTED } end
    if model.dnd then list[#list + 1] = { L["DND"], MUTED } end
    if model.dead then list[#list + 1] = { DEAD, TAPPED } end
    if model.skinning then list[#list + 1] = { UNIT_SKINNABLE_LEATHER, SKINNABLE_COLOR } end
    return list
end

-- A player's guild; a bracketed line names it when the game does not.
local function guildText(model)
    if model.guild then
        local name = model.guild:gsub("^<(.*)>$", "%1")
        if type(model.guildRealm) == "string" and model.guildRealm ~= "" then
            -- Avoid appending the realm twice if the guild name already includes it.
            if name:sub(-#model.guildRealm - 1) ~= "-" .. model.guildRealm then
                name = name .. "-" .. model.guildRealm
            end
        end
        return name
    end
    if model.isPlayer then return model.tag and model.tag:gsub("^<(.*)>$", "%1") end
end

local function detailRows(model)
    local rows = {}
    if model.owner then rows[#rows + 1] = { left = model.owner, right = "" } end
    if model.target then
        rows[#rows + 1] = model.targetIsYou
            and { left = TARGET, right = YOU, rightColor = UNMET_COLOR }
            or { left = TARGET, right = model.target, rightColor = model.targetColor }
    end
    return rows
end

-- A watermark that runs off the top right is cut to the part over the panel,
-- since a panel cannot clip what it draws.
local function showWatermark(panel, art)
    local mark = panel.watermark
    if not mark then
        mark = panel:CreateTexture(nil, "BORDER", nil, 3)
        panel.watermark = mark
    end
    local inset = panel.inset or 1
    local width, height = panel:GetWidth(), panel:GetHeight()
    local w, h = art.width, art.height
    local left, top = width - w - art.right, art.top
    local x0, x1 = math.max(left, inset), math.min(left + w, width - inset)
    local y0, y1 = math.max(top, inset), math.min(top + h, height - inset)
    if x1 <= x0 or y1 <= y0 then
        mark:Hide()
        return
    end
    local u0, u1, v0, v1 = art.coords[1], art.coords[2], art.coords[3], art.coords[4]
    local function u(x) return u0 + (u1 - u0) * (x - left) / w end
    local function v(y) return v0 + (v1 - v0) * (y - top) / h end
    mark:SetTexture(art.file)
    mark:SetTexCoord(u(x0), u(x1), v(y0), v(y1))
    mark:ClearAllPoints()
    mark:SetPoint("TOPLEFT", panel, "TOPLEFT", x0, -y0)
    mark:SetSize(x1 - x0, y1 - y0)
    mark:SetVertexColor(art.color[1], art.color[2], art.color[3], art.alpha)
    mark:Show()
end

-- A classification's dragon as a watermark; nil without one, or where the
-- client has no such art.
local function dragonArt(classification, game)
    local dragon = DRAGONS[classification]
    local info = dragon and game.atlasInfo(dragon.atlas)
    local elite = info and game.atlasInfo(DRAGONS.elite.atlas)
    if not elite then return end
    local scale = DRAGON_HEIGHT / elite.height
    return {
        file = info.file,
        coords = { info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord },
        width = info.width * scale, height = info.height * scale,
        right = DRAGON_RIGHT - dragon.x * scale, top = DRAGON_TOP + dragon.y * scale,
        alpha = DRAGON_ALPHA, color = NO_TINT,
    }
end

-- The Skinning a dead creature needs, then what it may give.
local function skinningRows(skin)
    local rows = {}
    if skin.needed then
        rows[1] = { left = util.fill(L["Requires %s %s"], ns.Locale.skillName("Skinning"), skin.needed),
            right = skin.player and util.fill(L["Your skill %s"], skin.player) or "",
            color = ns.Palette.skillUpColor(skin.needed, skin.player) or DETAIL_COLOR, rightColor = colors.caption }
    end
    for _, row in ipairs(skin.rows) do
        rows[#rows + 1] = { left = row.left, right = row.right, color = row.rare and colors.caption or nil,
            rightColor = row.rare and colors.caption or nil }
    end
    return rows
end

-- What the panel shows, for Panel/Render.lua to draw.
local function unitView(panel, model, healthBar)
    local styles = {}
    for _, key in ipairs(PARTS) do styles[key] = ui.styleOf(key) end
    local color = model.color or colors.neutral
    local hasIcon = ns.option("iconUnits") and (model.unit or model.iconPath) and true or false
    local plate = levelBadge(model, hasIcon)

    local header = { { text = model.name, style = styles.unitName, color = color, gap = 2 } }
    local guild = guildText(model)
    if guild then
        header[#header + 1] = { text = guild, style = styles.unitGuild,
            color = model.isPlayer and { .92, .34, .84 } or { color[1] * .5 + .5, color[2] * .5 + .5, color[3] * .5 + .5 }, gap = 2 }
    end
    local info = infoText(model, plate ~= nil)
    if info then header[#header + 1] = { text = info, style = styles.unitInfo, color = DETAIL_COLOR, gap = 4 } end
    if model.factionName then
        header[#header + 1] = { text = model.factionName, style = styles.unitInfo, color = DETAIL_COLOR, gap = 4 }
    end
    header[#header + 1] = { badges = badges(model), style = styles.unitBadges, before = 1, gap = 4 }

    local sections = {}
    local details = detailRows(model)
    if #details > 0 then
        sections[#sections + 1] = { separator = { divider = ui.GOLD_RULE }, kind = "rows", rows = details,
            style = styles.unitDetails, color = DETAIL_COLOR, gap = 2 }
    end
    local skin = model.skinning
    if skin and ns.showsDetail("gatheringLoot", panel) then
        sections[#sections + 1] = { separator = { rule = EXTRAS_RULE }, kind = "rows",
            rows = skinningRows(skin), style = styles.unitSkinning, color = DETAIL_COLOR, gap = 2 }
    end
    if #model.quests > 0 then
        local quests = {}
        for index, row in ipairs(model.quests) do
            quests[index] = row.title and { left = row.left, right = row.right, color = colors.quest }
                or { left = row.left, right = row.right, color = row.completed and colors.done or colors.objective,
                    indent = 8 }
        end
        sections[#sections + 1] = { separator = { divider = ui.GOLD_RULE },
            kind = "rows", rows = quests, style = styles.unitQuests, gap = 2 }
    end
    local extras = ui.withID(panel, model.extras, L["NPC ID: %s"], npcID(model.guid))
    if #extras > 0 then
        sections[#sections + 1] = { separator = #sections > 0 and { rule = EXTRAS_RULE } or { space = 4 },
            kind = "rows", rows = extras, style = styles.extras, color = ui.EXTRA_COLOR, gap = 2, wrap = true }
    end
    -- Room at the bottom for the game's health bar, which the panel borrows
    -- once it is drawn.
    if healthBar then
        sections[#sections + 1] = { separator = { space = HEALTH_BEFORE }, kind = "custom", draw = function(p, y)
            p.healthTop = y
            return y + HEALTH_HEIGHT
        end }
    end
    if model.mount then
        local mount = model.mount
        local status = mount.collected == true and (" |cff00ff00【%s】|r"):format(L["Collected"])
            or mount.collected == false and (" |cffff5555【%s】|r"):format(L["Not collected"]) or ""
        local rows = { { left = L["Mount"] .. "：" .. mount.name .. status, right = "" } }
        if mount.source and mount.source ~= "" then
            rows[#rows + 1] = { left = L["Source"] .. "：" .. mount.source:gsub("|n%s*|n$", ""), right = "" }
        end
        sections[#sections + 1] = { separator = { space = 6 }, kind = "rows", rows = rows,
            style = styles.extras, color = DETAIL_COLOR, gap = 2, wrap = true }
    end
    return {
        tooltipType = "unit",
        color = color,
        tint = model.color,
        strength = TINT_STRENGTH,
        icon = hasIcon and (model.iconPath or WHITE) or nil,
        iconSize = ICON_SIZE,
        portrait = hasIcon and model.unit or nil,
        badge = plate,
        badgeColor = model.level and levelColor(model.level),
        header = header,
        sections = sections,
    }
end

-- The game's own health bar, which it fills from values the addon may not
-- read: lent to the panel while it shows a unit, into the room left for it
-- at the bottom, and given back to the game's tooltip as it was when the
-- panel hides or draws anything else.
local lent
local hookedHealthBars = setmetatable({}, { __mode = "k" })

-- A bar into the room left for it, as wide as the rows.
local function placeBar(bar, panel)
    local top = -ui.snap(panel, panel.healthTop)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", panel, "TOPLEFT", ui.pad(), top)
    bar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -ui.pad(), top)
    bar:SetHeight(HEALTH_HEIGHT)
end

local function placeHealthBar()
    if not (lent and lent.panel.healthTop and util.canModify(lent.bar)) then return end
    lent.placing = true
    pcall(placeBar, lent.bar, lent.panel)
    lent.placing = false
end

local function returnHealthBar(panel)
    panel.release = nil
    if panel.healthNumber then panel.healthNumber:Hide() end
    if not (lent and lent.panel == panel) then return end
    if not util.canModify(lent.bar) or not util.canModify(lent.parent) then
        lent.returnPending = true
        return
    end
    local bar = lent.bar
    lent.placing = true
    local ok = pcall(function()
        bar:SetParent(lent.parent)
        bar:ClearAllPoints()
        for _, point in ipairs(lent.points) do bar:SetPoint(unpack(point)) end
        bar:SetHeight(lent.height)
    end)
    lent.placing = false
    if ok then lent = nil else lent.returnPending = true end
end

local healthBarRestore = CreateFrame("Frame")
healthBarRestore:RegisterEvent("PLAYER_REGEN_ENABLED")
healthBarRestore:SetScript("OnEvent", function()
    if lent and lent.returnPending then returnHealthBar(lent.panel) end
end)

local function updateHealthText(panel, unit)
    if not panel.healthNumber then
        local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("BOTTOM", panel, "TOP", 0, 0)
        panel.healthNumber = fs
    end
    local label = panel.healthNumber
    label:Hide()
    if not unit or not UnitHealth or not UnitHealthMax then return end
    local ok, current, maximum = pcall(function() return UnitHealth(unit), UnitHealthMax(unit) end)
    if not ok or not safeValue(current) or not safeValue(maximum)
        or type(current) ~= "number" or type(maximum) ~= "number" or maximum <= 0 then return end
    local function compact(n)
        if n >= 1e8 then return string.format("%.1f亿", n / 1e8) end
        if n >= 1e4 then return string.format("%.1f万", n / 1e4) end
        return tostring(math.floor(n))
    end
    label:SetText(compact(current) .. " / " .. compact(maximum))
    label:ClearAllPoints()
    label:SetPoint("BOTTOM", panel, "TOPLEFT", panel:GetWidth() / 2, -(panel.healthTop or 0) + 1)
    label:SetTextColor(1, 1, 1)
    label:Show()
end

local function lendHealthBar(panel, bar)
    if not util.canModify(bar) then return end
    if not (lent and lent.panel == panel) then
        local points, height = util.framePoints(bar), util.number(bar:GetHeight())
        local parent = bar:GetParent()
        if not points or not height or not util.canModify(parent) then return end
        lent = { bar = bar, panel = panel, parent = parent, points = points, height = height }
        if not hookedHealthBars[bar] then
            -- The game may place its bar again while the panel has it.
            hooksecurefunc(bar, "SetPoint", function()
                if lent and lent.bar == bar and not lent.placing then placeHealthBar() end
            end)
            hookedHealthBars[bar] = true
        end
        if not panel.returnsHealthBar then
            panel:HookScript("OnHide", returnHealthBar)
            panel.returnsHealthBar = true
        end
    end
    lent.returnPending = nil
    panel.release = returnHealthBar
    local ok = pcall(bar.SetParent, bar, panel)
    if not ok then returnHealthBar(panel); return end
    placeHealthBar()
end

-- The editor's samples have no unit for the game to fill its bar from, so
-- they show one of their own, as the game's looks, filled to the sample's
-- health; it goes when the preview draws anything else.
local SAMPLE_BAR = "Interface\\TargetingFrame\\UI-StatusBar"

local function hideSampleHealth(panel)
    panel.release = nil
    if panel.sampleHealth then panel.sampleHealth:Hide() end
end

local function showSampleHealth(panel, share)
    local bar = panel.sampleHealth
    if not bar then
        bar = CreateFrame("StatusBar", nil, panel)
        local texture = GameTooltipStatusBar and GameTooltipStatusBar:GetStatusBarTexture()
        bar:SetStatusBarTexture(texture and texture:GetTexture() or SAMPLE_BAR)
        bar:SetStatusBarColor(0, 1, 0)
        bar:SetMinMaxValues(0, 1)
        panel.sampleHealth = bar
    end
    bar:SetValue(share)
    placeBar(bar, panel)
    bar:Show()
    panel.release = hideSampleHealth
end

local function renderUnit(panel, tooltip, model)
    -- Only the game's main tooltip has the bar, and the game hides it for
    -- units without one to show.
    local shown = ns.option("unitHealthBar")
    local bar = shown and tooltip == GameTooltip and GameTooltipStatusBar
    if not (bar and util.canModify(bar) and bar:IsShown()) then bar = nil end
    local sample = shown and panel.isPreview and model.healthShare
    panel.healthTop = nil
    if panel.healthNumber then panel.healthNumber:Hide() end
    ui.renderView(panel, tooltip, unitView(panel, model, bar ~= nil or sample ~= nil))
    local art
    if model.isPlayer then
        art = FACTION_ART[model.faction]
    else
        art = dragonArt(model.classification, ns.Game)
    end
    if art then showWatermark(panel, art) end
    if panel.healthTop then
        if bar then
            lendHealthBar(panel, bar)
            updateHealthText(panel, model.unit)
        elseif sample then
            showSampleHealth(panel, sample)
        end
    end
end

ui.unitModel = function(fields)
    for _, list in ipairs({ "quests", "extras" }) do fields[list] = fields[list] or {} end
    return completeModel(fields, nil, ns.Game)
end
-- Its target, tapped, and dead rows come from the game, not the tooltip's text.
local function details(model, context)
    local rows = {}
    if model.skinning and ns.showsDetail("gatheringLoot", context) then
        for _, row in ipairs(skinningRows(model.skinning)) do
            row.color = row.color or DETAIL_COLOR
            rows[#rows + 1] = row
        end
    end
    rows[#rows + 1] = ui.idRow(context, L["NPC ID: %s"], npcID(model.guid))
    return rows
end

ui.defineTooltipType(UNIT, { read = readUnit, render = renderUnit, key = unitKey, option = "unitPanels", alwaysRedraw = true,
    details = details, detailKeys = { "gatheringLoot", "showIDs" } })
