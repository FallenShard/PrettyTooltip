-- Forever specialization display groups and talent-point totals.
-- The game tests separately verify the real class data; this unit test locks
-- down the API contract and the mapping from specialization IDs to groups.
return function(test)
    local UNIT = 2
    local files = {
        "Core/Util.lua",
        "Core/Palette.lua",
        "Core/Settings.lua",
        "Locale/Locale.lua",
        "Locale/English.lua",
        "Game/Game.lua",
        "Game/TooltipData.lua",
        "Panel/Layout.lua",
        "Panel/Render.lua",
        "Tooltips/Unit.lua",
        "Forever/Tooltips/UnitSpecialization.lua",
    }
    local fixture = {
        enums = { TooltipDataType = { Unit = UNIT } },
        data = { type = UNIT, lines = {} },
        lines = {},
    }

    local ns = test.load(files, fixture)
    ns.setOption("unitTalentEnabled", true)

    local function runCase(classFile, specIDs, activeIndex, groupCount, disableSpecAPI, disableGroups)
        local groups, nodeIDs, nodeInfo = {}, {}, {}
        local expectedPoints, total = {}, 0
        for index = 1, groupCount do
            local groupID = 20000 + index
            local rank = index + 1
            groups[index] = {
                orderIndex = index - 1,
                groupID = groupID,
                displayName = classFile .. "-Spec" .. index,
                iconFileID = 100000 + index,
            }
            expectedPoints[index] = rank
            total = total + rank
            local nodeID = 30000 + index
            nodeIDs[index] = nodeID
            nodeInfo[nodeID] = {
                currentRank = rank,
                groupIDs = { groupID },
                posX = index * 100,
            }
        end

        UnitClass = function(unit)
            return classFile, classFile
        end
        if disableSpecAPI then
            GetSpecialization = nil
            GetSpecializationInfo = nil
        else
            GetSpecialization = function() return activeIndex end
            GetSpecializationInfo = function(index) return specIDs[index] end
        end
        if disableGroups then
            GetSpecializationInfoByID = nil
        else
            GetSpecializationInfoByID = function(id)
                for index, specID in ipairs(specIDs) do
                    if specID == id then
                        return id, classFile .. "-Spec" .. index, nil, 100000 + index
                    end
                end
            end
        end
        C_ClassTalents = {
            GetActiveConfigID = function() return 6217555 end,
        }
        local getGroupDisplay
        if not disableGroups then
            getGroupDisplay = function(treeID) return groups end
        end
        C_Traits = {
            GetConfigInfo = function(configID)
                return { treeIDs = { 1116 } }
            end,
            GetTreeCurrencyInfo = function(configID, treeID, excludeStaged)
                return { { spent = total } }
            end,
            GetGroupDisplayInfoByTreeID = getGroupDisplay,
            GetTreeNodes = function(treeID) return nodeIDs end,
            GetNodeInfo = function(configID, nodeID) return nodeInfo[nodeID] end,
        }
        RAID_CLASS_COLORS = { [classFile] = { r = 1, g = 1, b = 1 } }

        local model = {
            isPlayer = true,
            isPreview = false,
            unit = "player",
            level = 60,
            classFile = classFile,
            extras = {},
        }
        ns.TooltipTypes[UNIT].extension.afterRead(model)
        local line = model.extras[1] and model.extras[1].left or ""
        return line, expectedPoints, groups
    end

    local cases = {
        { "WARRIOR", { 71, 72, 73 }, 1, 3 },
        { "PALADIN", { 65, 66, 70 }, 2, 3 },
        { "HUNTER", { 253, 254, 255 }, 3, 3 },
        { "ROGUE", { 259, 260, 261 }, 1, 3 },
        { "PRIEST", { 256, 257, 258 }, 2, 3 },
        { "SHAMAN", { 262, 263, 264 }, 3, 3 },
        { "MAGE", { 62, 63, 64 }, 1, 3 },
        { "WARLOCK", { 265, 266, 267 }, 2, 3 },
        { "DRUID", { 102, 103, 104, 105 }, 4, 4 },
        { "DEATHKNIGHT", { 250, 251, 252 }, 3, 3 },
    }

    for _, case in ipairs(cases) do
        local classFile, specIDs, activeIndex, groupCount = unpack(case)
        local line, points, groups = runCase(classFile, specIDs, activeIndex, groupCount)
        local expectedName = groups[activeIndex].displayName
        local expectedPointText = table.concat(points, "/")
        test.check(classFile .. ": specialization follows the active spec index",
            line:find(expectedName, 1, true) ~= nil, true)
        test.check(classFile .. ": all display-group point totals are retained",
            line:find("(" .. expectedPointText .. ")", 1, true) ~= nil, true)
        test.check(classFile .. ": matching specialization icon is used",
            line:find("|T" .. tostring(groups[activeIndex].iconFileID) .. ":12:12", 1, true) ~= nil, true)
    end

    -- Without a specialization API result, the group with the most purchased
    -- ranks is the deterministic fallback.
    local line, points, groups = runCase("WARLOCK", { 265, 266, 267 }, nil, 3, true)
    test.check("missing specialization API result: highest-ranked group is selected",
        line:find(groups[3].displayName, 1, true) ~= nil, true)

    -- If this client build cannot provide display groups, the extension keeps
    -- the truthful total and uses the class's known specialization label.
    line = runCase("WARLOCK", { 265, 266, 267 }, 2, 3, false, true)
    test.check("missing group-display API: a safe total is still displayed",
        line:find("(9)", 1, true) ~= nil, true)
    test.check("missing group-display API: class fallback label is used",
        line:find("恶魔学识", 1, true) ~= nil, true)
end
