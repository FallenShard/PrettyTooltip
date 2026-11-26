-- Forever unit specialization and talent-point row.
-- Forever only: talent trees and specialization display.
-- Ported from HuTip/TalentInfo.lua, with PrettyTooltip's unit-model integration.
local _, ns = ...
local UNIT = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit
local descriptor = ns.TooltipTypes and ns.TooltipTypes[UNIT]
if not descriptor then return end

local CACHE_LIFETIME = 180
local REQUEST_COOLDOWN = 3
local talentCache, pendingInspect, lastQueryAt = {}, {}, {}

local function IsProtectedValue(v)
    if v == nil then return false end
    if type(issecretvalue) == "function" then
        local ok, result = pcall(issecretvalue, v)
        if ok then return result end
    end
    return false
end

local function SafeString(v)
    if IsProtectedValue(v) or type(v) ~= "string" then return nil end
    return v
end

local function SafeNumber(v)
    if IsProtectedValue(v) or type(v) ~= "number" then return nil end
    return v
end

local ForeverSpecs = {
    WARRIOR = {
        { name = "武器", icon = "Interface\\Icons\\Ability_Rogue_Eviscerate" },
        { name = "狂怒", icon = "Interface\\Icons\\Ability_Warrior_InnerRage" },
        { name = "防护", icon = "Interface\\Icons\\INV_Shield_06" },
    },
    PALADIN = {
        { name = "神圣", icon = "Interface\\Icons\\Spell_Holy_HolyBolt" },
        { name = "防护", icon = "Interface\\Icons\\Spell_Holy_DevotionAura" },
        { name = "惩戒", icon = "Interface\\Icons\\Spell_Holy_AuraOfLight" },
    },
    HUNTER = {
        { name = "野兽控制", icon = "Interface\\Icons\\Ability_Hunter_BeastTaming" },
        { name = "射击", icon = "Interface\\Icons\\Ability_Marksmanship" },
        { name = "生存", icon = "Interface\\Icons\\Ability_Hunter_SwiftStrike" },
    },
    ROGUE = {
        { name = "刺杀", icon = "Interface\\Icons\\Ability_Rogue_Eviscerate" },
        { name = "战斗", icon = "Interface\\Icons\\Ability_BackStab" },
        { name = "敏锐", icon = "Interface\\Icons\\Ability_Stealth" },
    },
    PRIEST = {
        { name = "戒律", icon = "Interface\\Icons\\Spell_Holy_WordFortitude" },
        { name = "神圣", icon = "Interface\\Icons\\Spell_Holy_HolyBolt" },
        { name = "暗影", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain" },
    },
    SHAMAN = {
        { name = "元素", icon = "Interface\\Icons\\Spell_Nature_Lightning" },
        { name = "增强", icon = "Interface\\Icons\\Spell_Nature_LightningShield" },
        { name = "恢复", icon = "Interface\\Icons\\Spell_Nature_MagicImmunity" },
    },
    MAGE = {
        { name = "奥术", icon = "Interface\\Icons\\Spell_Holy_MagicalSentry" },
        { name = "火焰", icon = "Interface\\Icons\\Spell_Fire_FlameBolt" },
        { name = "冰霜", icon = "Interface\\Icons\\Spell_Frost_FrostBolt02" },
    },
    WARLOCK = {
        { name = "痛苦", icon = "Interface\\Icons\\Spell_Shadow_DeathCoil" },
        { name = "恶魔学识", icon = "Interface\\Icons\\Spell_Shadow_Metamorphosis" },
        { name = "毁灭", icon = "Interface\\Icons\\Spell_Shadow_RainOfFire" },
    },
    DRUID = {
        { name = "平衡", icon = "Interface\\Icons\\Spell_Nature_StarFall" },
        { name = "野性战斗", icon = "Interface\\Icons\\Ability_Racial_BearForm" },
        { name = "恢复", icon = "Interface\\Icons\\Spell_Nature_HealingTouch" },
    },
    DEATHKNIGHT = {
        { name = "鲜血", icon = "Interface\\Icons\\Spell_Deathknight_BloodPresence" },
        { name = "冰霜", icon = "Interface\\Icons\\Spell_Deathknight_FrostPresence" },
        { name = "邪恶", icon = "Interface\\Icons\\Spell_Deathknight_UnholyPresence" },
    },
}

local function classColor(unit)
    if not unit then return end
    local ok, _, class = pcall(UnitClass, unit)
    if not ok or IsProtectedValue(class) or type(class) ~= "string" then return end
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not color or IsProtectedValue(color.r) or IsProtectedValue(color.g) or IsProtectedValue(color.b) then
        return
    end
    return color
end

local function colorName(name, unit)
    local color = classColor(unit)
    if color then
        return string.format("|cff%02x%02x%02x%s|r",
            math.floor((color.r or 1) * 255 + .5),
            math.floor((color.g or 1) * 255 + .5),
            math.floor((color.b or 1) * 255 + .5), name)
    end
    return "|cff00ff00" .. name .. "|r"
end

local function GetTalentConfigID(isInspect)
    if isInspect then
        if not (C_Traits and C_Traits.HasValidInspectData
            and C_Traits.HasValidInspectData()) then
            return nil
        end
        return Constants and Constants.TraitConsts
            and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID
    end
    return C_ClassTalents and C_ClassTalents.GetActiveConfigID
        and C_ClassTalents.GetActiveConfigID()
end

local function SplitPointsByTree(configID, treeID)
    if not (C_Traits and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo) then return nil end

    local nodes, xCount, xList = {}, {}, {}
    local minX, maxX
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
        local info = C_Traits.GetNodeInfo(configID, nodeID)
        if type(info) == "table" then
            local x = SafeNumber(info.posX)
            local rank = SafeNumber(info.currentRank) or 0
            if x then
                nodes[#nodes + 1] = { x = x, rank = rank }
                if not xCount[x] then xCount[x] = 0; xList[#xList + 1] = x end
                xCount[x] = xCount[x] + 1
                minX = minX and math.min(minX, x) or x
                maxX = maxX and math.max(maxX, x) or x
            end
        end
    end
    if #nodes == 0 or not maxX or maxX <= minX then return nil end

    local perColumn = { 0, 0, 0 }
    table.sort(xList)
    if #xList >= 2 then
        local gaps = {}
        for i = 2, #xList do gaps[#gaps + 1] = xList[i] - xList[i - 1] end
        table.sort(gaps)
        local threshold = gaps[math.ceil(#gaps / 2)] * 2.5
        local clusters, current = {}, {
            minX = xList[1], maxX = xList[1], count = xCount[xList[1]],
        }
        clusters[1] = current
        for i = 2, #xList do
            if xList[i] - xList[i - 1] > threshold then
                current = { minX = xList[i], maxX = xList[i], count = 0 }
                clusters[#clusters + 1] = current
            end
            current.maxX = xList[i]
            current.count = current.count + xCount[xList[i]]
        end
        if #clusters >= 3 then
            local byCount = {}
            for _, cluster in ipairs(clusters) do byCount[#byCount + 1] = cluster end
            table.sort(byCount, function(a, b)
                if a.count ~= b.count then return a.count > b.count end
                return a.minX < b.minX
            end)
            local trees = { byCount[1], byCount[2], byCount[3] }
            table.sort(trees, function(a, b) return a.minX < b.minX end)
            for _, node in ipairs(nodes) do
                for column, tree in ipairs(trees) do
                    if node.x >= tree.minX and node.x <= tree.maxX then
                        perColumn[column] = perColumn[column] + node.rank
                        break
                    end
                end
            end
        end
    end
    if perColumn[1] + perColumn[2] + perColumn[3] == 0 then
        local width = (maxX - minX) / 3
        for _, node in ipairs(nodes) do
            local column = math.min(3, math.floor((node.x - minX) / width) + 1)
            perColumn[column] = perColumn[column] + node.rank
        end
    end
    if perColumn[1] + perColumn[2] + perColumn[3] > 0 then return perColumn end
end

local function SplitPointsByCurrency(configID, treeID, totalSpent)
    local currencies = C_Traits.GetTreeCurrencyInfo(configID, treeID, false)
    if type(currencies) ~= "table" or #currencies ~= 3 then return nil end
    local points, sum = {}, 0
    for _, item in ipairs(currencies) do
        local spent = SafeNumber(item.spent) or 0
        points[#points + 1] = spent
        sum = sum + spent
    end
    if sum == totalSpent then return points end
end

local SpecIDsByClass = {
    WARRIOR = { 71, 72, 73 },
    PALADIN = { 65, 66, 70 },
    HUNTER = { 253, 254, 255 },
    ROGUE = { 259, 260, 261 },
    PRIEST = { 256, 257, 258 },
    SHAMAN = { 262, 263, 264 },
    MAGE = { 62, 63, 64 },
    WARLOCK = { 265, 266, 267 },
    DRUID = { 102, 103, 104, 105 },
    DEATHKNIGHT = { 250, 251, 252 },
}

local function GetUnitSpecialization(unit, isInspect, classFile)
    local specID, specIndex

    if unit == "player" then
        if type(GetSpecialization) == "function" then
            local ok, value = pcall(GetSpecialization)
            if ok then specIndex = SafeNumber(value) end
        end
        if specIndex and type(GetSpecializationInfo) == "function" then
            local ok, value = pcall(GetSpecializationInfo, specIndex)
            if ok then specID = SafeNumber(value) end
        end
    elseif isInspect and type(GetInspectSpecialization) == "function" then
        local ok, value = pcall(GetInspectSpecialization, unit)
        if ok then specID = SafeNumber(value) end
    end

    if not specIndex and specID and classFile then
        for index, id in ipairs(SpecIDsByClass[classFile] or {}) do
            if id == specID then specIndex = index; break end
        end
    end

    if not specID and specIndex and type(GetSpecializationInfo) == "function" then
        local ok, value = pcall(GetSpecializationInfo, specIndex)
        if ok then specID = SafeNumber(value) end
    end

    return specIndex, specID
end

local function GetDisplayGroups(treeID)
    if not (C_Traits and type(C_Traits.GetGroupDisplayInfoByTreeID) == "function") then
        return nil
    end
    local ok, groups = pcall(C_Traits.GetGroupDisplayInfoByTreeID, treeID)
    if ok and type(groups) == "table" then return groups end
end

local function HasGroupID(groupIDs, wanted)
    if type(groupIDs) ~= "table" or not wanted then return false end
    for _, groupID in ipairs(groupIDs) do
        if groupID == wanted then return true end
    end
    return false
end

local function GetTalentInfo(unit, isInspect)
    if not (C_Traits and type(C_Traits.GetConfigInfo) == "function"
        and type(C_Traits.GetTreeCurrencyInfo) == "function") then
        return nil
    end

    local ok, result = pcall(function()
        local configID
        if unit == "player" then
            configID = C_ClassTalents and type(C_ClassTalents.GetActiveConfigID) == "function"
                and C_ClassTalents.GetActiveConfigID()
        else
            configID = GetTalentConfigID(isInspect)
        end
        if not configID then return nil end

        local configInfo = C_Traits.GetConfigInfo(configID)
        if type(configInfo) ~= "table" or type(configInfo.treeIDs) ~= "table"
            or not configInfo.treeIDs[1] then
            return nil
        end

        local _, classFile = UnitClass(unit)
        classFile = SafeString(classFile)
        local specIndex, specID = GetUnitSpecialization(unit, isInspect, classFile)

        -- In Forever, one class tree contains multiple specialization display
        -- groups. They are not separate treeIDs.
        local treeID = configInfo.treeIDs[1]
        local groups = GetDisplayGroups(treeID)
        local groupPoints, totalSpent = {}, 0

        local currencies = C_Traits.GetTreeCurrencyInfo(configID, treeID, false)
        if type(currencies) == "table" then
            for _, currency in ipairs(currencies) do
                local spent = type(currency) == "table" and SafeNumber(currency.spent)
                if spent then totalSpent = totalSpent + spent end
            end
        end

        local groupByOrder = {}
        if groups then
            for _, group in ipairs(groups) do
                if type(group) == "table" then
                    local order = SafeNumber(group.orderIndex)
                    local groupID = SafeNumber(group.groupID)
                    if order and groupID then
                        groupByOrder[order + 1] = group
                        groupPoints[order + 1] = 0
                    end
                end
            end
        end

        if C_Traits.GetTreeNodes and C_Traits.GetNodeInfo and groups then
            local nodeIDs = C_Traits.GetTreeNodes(treeID)
            if type(nodeIDs) == "table" then
                for _, nodeID in ipairs(nodeIDs) do
                    local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                    if type(nodeInfo) == "table" then
                        local rank = SafeNumber(nodeInfo.currentRank) or 0
                        if rank > 0 and type(nodeInfo.groupIDs) == "table" then
                            for index, group in pairs(groupByOrder) do
                                if HasGroupID(nodeInfo.groupIDs, group.groupID) then
                                    groupPoints[index] = (groupPoints[index] or 0) + rank
                                end
                            end
                        end
                    end
                end
            end
        end

        local points, maxPoints, selectedIndex = {}, -1, nil
        for index = 1, #(groups or {}) do
            local group = groupByOrder[index]
            if group then
                local spent = SafeNumber(groupPoints[index]) or 0
                points[index] = spent
                if spent > maxPoints then
                    maxPoints, selectedIndex = spent, index
                end
            end
        end

        -- Prefer the actual player/inspect specialization. If that API is
        -- unavailable, infer it only when one display group has the most ranks.
        if specIndex and groupByOrder[specIndex] then
            selectedIndex = specIndex
        elseif maxPoints <= 0 then
            selectedIndex = nil
        end

        local selectedGroup = selectedIndex and groupByOrder[selectedIndex]
        local specName, specIcon
        if selectedGroup then
            specName = SafeString(selectedGroup.displayName)
            specIcon = selectedGroup.iconFileID or selectedGroup.icon
        end

        if (not specName or specName == "") and specID
            and type(GetSpecializationInfoByID) == "function" then
            local okSpec, _, name, _, icon = pcall(GetSpecializationInfoByID, specID)
            if okSpec then
                specName = SafeString(name)
                specIcon = specIcon or icon
            end
        end

        if not specName and classFile and ForeverSpecs[classFile] then
            local fallback = ForeverSpecs[classFile][selectedIndex or specIndex or 1]
            if fallback then
                specName = fallback.name
                specIcon = specIcon or fallback.icon
            end
        end

        if #points == 0 then
            -- Keep a truthful total rather than inventing three per-spec values
            -- when this client build does not expose group membership.
            if totalSpent <= 0 then return nil end
            points = { totalSpent }
        end

        local hasPoints = false
        for _, value in ipairs(points) do
            if (SafeNumber(value) or 0) > 0 then hasPoints = true; break end
        end
        if not hasPoints then
            if totalSpent <= 0 then return nil end
            points = { totalSpent }
        end

        return {
            name = specName,
            icon = specIcon,
            points = points,
        }
    end)

    if ok and type(result) == "table" then return result end
end

local function BuildTalentLine(info, unit)
    if not info or type(info.points) ~= "table" then return nil end
    local parts = {}
    for _, value in ipairs(info.points) do
        local point = SafeNumber(value)
        if point then parts[#parts + 1] = tostring(point) end
    end
    if #parts == 0 then return nil end

    local name = SafeString(info.name)
    if not name then name = "未知" end
    local icon = info.icon
    local iconText = ""
    if icon and not IsProtectedValue(icon) then
        iconText = " |T" .. tostring(icon) .. ":12:12:0:0:10:10:0:10:0:10|t"
    end
    return "|cffffd200专精：|r" .. colorName(name, unit) .. iconText
        .. " |cffD1C7B5(" .. table.concat(parts, "/") .. ")|r"
end

local function safeGUID(unit)
    if not unit or not UnitGUID then return nil end
    local ok, guid = pcall(UnitGUID, unit)
    if ok and not IsProtectedValue(guid) and type(guid) == "string" then return guid end
end

local function addRow(model, line)
    if type(line) == "table" then
        -- Item-level rows already use the unit model's { left, right } shape.
        -- Append them as rows; wrapping the table in `left` makes Layout pass
        -- a table to FontString:SetText and breaks the entire preview.
        if type(line.left) == "string" then
            line.right = type(line.right) == "string" and line.right or ""
            model.extras[#model.extras + 1] = line
        end
        return
    end
    if type(line) ~= "string" or line == "" then return end
    model.extras[#model.extras + 1] = { left = line, right = "" }
end

local function requestInspect(unit, guid)
    if not (CanInspect and NotifyInspect) then return false end
    local now = GetTime()
    local last = lastQueryAt[guid]
    if last and now - last < REQUEST_COOLDOWN then return false end
    local ok, can = pcall(CanInspect, unit)
    if not ok or can ~= true then return false end
    lastQueryAt[guid] = now
    pendingInspect[guid] = { unit = unit, at = now }
    if C_Timer and C_Timer.After then
        C_Timer.After(.25, function()
            local pending = pendingInspect[guid]
            if not pending or safeGUID(unit) ~= guid then return end
            local canOK, allowed = pcall(CanInspect, unit)
            if canOK and allowed == true then
                pcall(NotifyInspect, unit)
            else
                pendingInspect[guid] = nil
            end
        end)
    else
        local notifyOK = pcall(NotifyInspect, unit)
        if not notifyOK then pendingInspect[guid] = nil end
    end
    return true
end

local function refreshTooltipFor(guid)
    if not (GameTooltip and GameTooltip.IsShown and GameTooltip.GetUnit) then return end
    local ok, _, unit = pcall(GameTooltip.GetUnit, GameTooltip)
    if not ok or not unit or safeGUID(unit) ~= guid then return end
    if GameTooltip.RefreshData then
        pcall(GameTooltip.RefreshData, GameTooltip)
    else
        pcall(GameTooltip.Show, GameTooltip)
    end
end

local function foreverItemLevel(unit)
    if unit == "player" and GetAverageItemLevel then
        local ok, _, equipped = pcall(GetAverageItemLevel)
        if ok and SafeNumber(equipped) and equipped > 0 then return equipped end
    end
    return nil
end

local function itemLevelRow(value)
    value = SafeNumber(value)
    if not value or value <= 0 then return nil end
    local color = value <= 285 and "808080" or value <= 298 and "1eff00"
        or value <= 311 and "0070ff" or value <= 324 and "a335ee"
        or value <= 334 and "ff8000" or "e6cc80"
    local locale = GetLocale and GetLocale() or "enUS"
    local label = (locale == "zhCN" or locale == "zhTW") and "物品等级：" or "ItemLevel: "
    return { left = label .. "|cff" .. color .. tostring(value) .. "|r", right = "" }
end

local function afterRead(model)
    if not model.isPlayer then return end
    local unit = model.unit

    -- The editor can complete the same preview model more than once.
    -- Keep the synthetic specialization/item-level rows idempotent.
    if model.isPreview then
        if model._prettyTooltipForeverPreviewAdded then return end
        model._prettyTooltipForeverPreviewAdded = true

        if ns.option("unitTalentEnabled") then
            local classFile = SafeString(model.classFile) or "WARRIOR"
            local fallback = ForeverSpecs[classFile] and ForeverSpecs[classFile][1]
            local name = fallback and fallback.name or "武器"
            local color = classColor(unit) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])
            local colorCode = color and string.format("%02x%02x%02x",
                math.floor((color.r or 1) * 255 + .5),
                math.floor((color.g or 1) * 255 + .5),
                math.floor((color.b or 1) * 255 + .5)) or "ffffff"
            addRow(model, "|cffffd200专精：|r|cff" .. colorCode .. name .. "|r"
                .. " |T" .. (fallback and fallback.icon or "Interface\\Icons\\Ability_Rogue_Eviscerate")
                .. ":12:12:0:0:10:10:0:10:0:10|t |cffD1C7B5(31/0/0)|r")
        end
        if ns.option("unitItemLevelEnabled") then
            addRow(model, itemLevelRow(61))
        end
        return
    end

    if not unit then return end
    local level = SafeNumber(model.level)
    if level and level < 10 then return end

    if ns.option("unitItemLevelEnabled") then
        local ilvl = foreverItemLevel(unit)
        if ilvl then addRow(model, itemLevelRow(ilvl)) end
    end

    if not ns.option("unitTalentEnabled") then return end

    if unit == "player" then
        addRow(model, BuildTalentLine(GetTalentInfo("player", false), "player"))
        return
    end

    local guid = model.guid or safeGUID(unit)
    if not guid then return end
    local cached = talentCache[guid]
    local now = GetTime()
    if cached and now - cached.time < CACHE_LIFETIME then
        addRow(model, cached.line)
        return
    end

    if requestInspect(unit, guid) then
        addRow(model, "|cffffd200专精：|r|cff888888加载中...|r")
    end
end

descriptor.extension = descriptor.extension or {}
descriptor.extension.afterRead = afterRead

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("INSPECT_READY")
eventFrame:SetScript("OnEvent", function(_, _, guid)
    if IsProtectedValue(guid) or type(guid) ~= "string" then return end
    local pending = pendingInspect[guid]
    if not pending then return end
    pendingInspect[guid] = nil
    local unit = pending.unit
    if safeGUID(unit) ~= guid then return end

    local info = GetTalentInfo(unit, true)
    local line = BuildTalentLine(info, unit)
    if line then
        talentCache[guid] = { time = GetTime(), line = line }
    else
        -- Inspect data may not be ready on the first event; allow a later retry.
        lastQueryAt[guid] = GetTime() - REQUEST_COOLDOWN
    end
    refreshTooltipFor(guid)
end)
