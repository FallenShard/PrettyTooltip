-- Every question the addon asks the game about items, spells, units, auras,
-- quests, the player, and other addons, as ns.Game. Answers the game hides
-- come back as nil, and a missing API answers nothing. Readers receive this
-- table as an argument, so a test can pass its own.
local _, ns = ...
local util = ns.util
local isSecret, readable, call, number, rgb = util.isSecret, util.readable, util.call, util.number, util.rgb
local game = {}
ns.Game = game

-- Items -----------------------------------------------------------------------

-- An item's name, link, quality, icon, and unit sell price, by ID, link, or
-- name; fields the client has not loaded are nil.
function game.itemInfo(item)
    if not (item and C_Item and C_Item.GetItemInfo) then return end
    local ok, name, link, quality, _, _, _, _, _, _, icon, price = pcall(C_Item.GetItemInfo, item)
    if not ok then return end
    return { name = readable(name), link = readable(link), quality = readable(quality), icon = readable(icon),
        price = readable(price) }
end

-- The item's id, type and subtype names, equip slot, and class ID, from data
-- the client always has; nil when any is hidden.
function game.itemType(item)
    if not (item and C_Item and C_Item.GetItemInfoInstant) then return end
    local ok, id, className, subClassName, equipLoc, _, classID = pcall(C_Item.GetItemInfoInstant, item)
    if not ok or isSecret(id) or isSecret(className) or isSecret(subClassName) or isSecret(equipLoc)
        or isSecret(classID) then return end
    return { id = id, className = className, subClassName = subClassName, equipLoc = equipLoc, classID = classID }
end

-- Asks the client to load an item it has not seen, for a later hover.
function game.loadItem(itemID)
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
end

function game.itemName(itemID)
    if not (C_Item and C_Item.GetItemNameByID) then return end
    local name = call(C_Item.GetItemNameByID, itemID)
    if type(name) == "string" then return name end
end

function game.itemIcon(item)
    if not (item and C_Item and C_Item.GetItemIconByID) then return end
    return (call(C_Item.GetItemIconByID, item))
end

function game.itemLevel(item)
    if not (item and C_Item and C_Item.GetDetailedItemLevelInfo) then return end
    return number((call(C_Item.GetDetailedItemLevelInfo, item)))
end

-- How many the player carries.
function game.itemCount(item)
    if not (C_Item and C_Item.GetItemCount) then return end
    return number((call(C_Item.GetItemCount, item)))
end

-- How many the stack in a bag slot holds, by the item's GUID.
function game.stackCount(guid)
    if isSecret(guid) or type(guid) ~= "string" or not (C_Item and C_Item.GetItemLocation and C_Item.GetStackCount) then
        return
    end
    local ok, count = pcall(function() return C_Item.GetStackCount(C_Item.GetItemLocation(guid)) end)
    count = ok and number(count)
    if count and count > 0 then return count end
end

-- true or false; nil when the game cannot tell.
function game.isEquipped(link)
    if not (link and C_Item and C_Item.IsEquippedItem) then return end
    local ok, equipped = pcall(C_Item.IsEquippedItem, link)
    if ok and not isSecret(equipped) then return equipped == true end
end

-- Auctionator's last seen price, in copper.
function game.auctionPrice(itemID)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not (api and api.GetAuctionPriceByItemID) then return end
    local ok, price = pcall(api.GetAuctionPriceByItemID, "PrettyTooltip", itemID)
    price = ok and number(price)
    if price and price > 0 then return price end
end

-- Spells ----------------------------------------------------------------------

function game.spellIcon(spellID)
    if isSecret(spellID) or type(spellID) ~= "number" then return end
    local getter = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
    if not getter then return end
    local ok, icon = pcall(getter, spellID)
    if ok and not isSecret(icon) and icon then return icon end
end

function game.spellName(spellID)
    if isSecret(spellID) or type(spellID) ~= "number" then return end
    local getter = C_Spell and C_Spell.GetSpellName or GetSpellInfo
    if not getter then return end
    local ok, name = pcall(getter, spellID)
    if ok and not isSecret(name) and type(name) == "string" then return name end
end

-- The player ------------------------------------------------------------------

function game.playerLevel()
    if not UnitLevel then return end
    return number((call(UnitLevel, "player")))
end

-- The player's bonus damage for a school, by the game's school index.
function game.spellDamage(school)
    if not GetSpellBonusDamage then return end
    return number((call(GetSpellBonusDamage, school)))
end

function game.spellHealing()
    if not GetSpellBonusHealing then return end
    return number((call(GetSpellBonusHealing)))
end

-- The player's rank in a skill or profession, by name. Older clients list
-- skills; newer ones, like Forever's, only list professions.
function game.skill(name)
    if GetNumSkillLines and GetSkillLineInfo then
        for index = 1, number((call(GetNumSkillLines))) or 0 do
            local skillName, isHeader, _, rank = call(GetSkillLineInfo, index)
            if not isHeader and skillName == name and type(rank) == "number" then return rank end
        end
    end
    if GetProfessions and GetProfessionInfo then
        local found = util.pack(pcall(GetProfessions))
        for position = 2, found[1] and found.n or 1 do
            local index = found[position]
            if index ~= nil and not isSecret(index) then
                local skillName, _, rank = call(GetProfessionInfo, index)
                if skillName == name and type(rank) == "number" then return rank end
            end
        end
    end
end

-- Units -----------------------------------------------------------------------

function game.unitExists(unit) return call(UnitExists, unit) end
function game.unitGUID(unit) return call(UnitGUID, unit) end
function game.unitToken(guid) return UnitTokenFromGUID and call(UnitTokenFromGUID, guid) or nil end
function game.unitName(unit) return (call(UnitName, unit)) end
function game.unitIsUnit(unit, other) return call(UnitIsUnit, unit, other) end
function game.unitIsPlayer(unit) return call(UnitIsPlayer, unit) end
function game.unitLevel(unit) return call(UnitEffectiveLevel or UnitLevel, unit) end
-- The localized class name, then the class file name.
function game.unitClass(unit) return call(UnitClass, unit) end
function game.unitRace(unit) return call(UnitRace, unit) end
-- The guild's name, then the unit's rank in it.
function game.unitGuild(unit) return call(GetGuildInfo, unit) end
function game.unitFaction(unit) return call(UnitFactionGroup, unit) end
function game.unitIsAFK(unit) return call(UnitIsAFK, unit) end
function game.unitIsDND(unit) return call(UnitIsDND, unit) end
function game.unitCreatureType(unit) return call(UnitCreatureType, unit) end
function game.unitClassification(unit) return call(UnitClassification, unit) end
function game.unitIsPVP(unit) return call(UnitIsPVP, unit) end
function game.unitIsDead(unit) return call(UnitIsDeadOrGhost, unit) end
function game.unitReaction(unit, other) return call(UnitReaction, unit, other) end
function game.unitIsTapDenied(unit) return call(UnitIsTapDenied, unit) end
function game.unitHealth(unit) return call(UnitHealth, unit), call(UnitHealthMax, unit) end

-- A class's color, by its file name, as { r, g, b }.
function game.classColor(classFile)
    if classFile and RAID_CLASS_COLORS then return rgb(RAID_CLASS_COLORS[classFile]) end
end

-- The color the game gives a level, relative to the player's, as { r, g, b }.
function game.difficultyColor(level)
    if type(level) ~= "number" or not GetQuestDifficultyColor then return end
    return rgb((call(GetQuestDifficultyColor, level)))
end

-- Auras -----------------------------------------------------------------------

-- An aura on a unit, by its instance ID or by its index under a filter.
function game.aura(unit, which, filter, byInstance)
    if not C_UnitAuras then return end
    local ok, aura
    if byInstance and C_UnitAuras.GetAuraDataByAuraInstanceID then
        ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, which)
    elseif C_UnitAuras.GetAuraDataByIndex then
        ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, which, filter)
    end
    if ok and not isSecret(aura) and type(aura) == "table" then return aura end
end

-- Quests ----------------------------------------------------------------------

-- true or false; nil without a quest log to ask.
function game.questCompleted(questID)
    if C_QuestLog then return call(C_QuestLog.IsQuestFlaggedCompleted, questID) == true end
end

function game.onQuest(questID)
    if C_QuestLog then return call(C_QuestLog.IsOnQuest, questID) == true end
end

-- Other addons ----------------------------------------------------------------

-- Installed, whether enabled or not.
function game.addonInstalled(addon)
    if not (C_AddOns and C_AddOns.GetAddOnInfo) then return false end
    local ok, name, _, _, _, reason = pcall(C_AddOns.GetAddOnInfo, addon)
    return ok and name ~= nil and reason ~= "MISSING"
end
