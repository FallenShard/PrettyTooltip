-- PrettyTooltip: Mythic+ season rating and individual dungeon scores (12.1.5+).
-- Ported from CaiseTip/Modules/MythicScore.lua; details are always displayed.
local _, ns = ...
local M = {}
ns.MythicScore = M

local function secret(value)
    return issecretvalue and issecretvalue(value)
end
local function safeNumber(value)
    if secret(value) or type(value) ~= "number" then return nil end
    return value
end
local function wrap(value, color)
    if color and not secret(color) then
        local ok, result = pcall(function() return color:WrapTextInColorCode(tostring(value)) end)
        if ok and type(result) == "string" then return result end
    end
    return tostring(value)
end
local function levelColor(level, overTime)
    if overTime then return "ff999999" end
    if level >= 15 then return "ffffd700" end
    if level >= 12 then return "ffff77cc" end
    if level >= 10 then return "ffff8000" end
    if level >= 9 then return "ffa335ee" end
    if level >= 7 then return "ff0070dd" end
    if level >= 1 then return "ff1eff00" end
    return "ffffffff"
end
local function colored(value, level, overTime)
    return "|c" .. levelColor(level, overTime) .. tostring(value) .. "|r"
end

-- Localized dungeon short names: prefer explicit locale overrides, then use
-- an acronym of the Blizzard-localized name for non-Chinese clients.
local function shortDungeon(name)
    local L = ns.L or {}
    local explicit = L["Dungeon Short: " .. name]
    if type(explicit) == "string" and explicit ~= "" then
        -- Some locale tables return the lookup key when a translation is absent.
        -- Never expose the internal "Dungeon Short:" prefix in tooltips.
        if explicit:sub(1, 15) ~= "Dungeon Short: " then return explicit end
    end
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "zhCN" or locale == "zhTW" or locale == "koKR" then return name end
    local letters = {}
    for word in name:gmatch("[%a]+") do
        local lower = word:lower()
        if lower ~= "the" and lower ~= "of" and lower ~= "de" and lower ~= "del" and lower ~= "la" and lower ~= "le" and lower ~= "des" and lower ~= "du" and lower ~= "der" and lower ~= "die" and lower ~= "das" and lower ~= "and" and lower ~= "et" and lower ~= "und" and lower ~= "do" and lower ~= "da" then
            letters[#letters + 1] = word:sub(1, 1):upper()
        end
    end
    if #letters >= 2 and #letters <= 5 then return table.concat(letters) end
    return name
end

local function read(unit, showDungeons)
    if not (C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary and C_ChallengeMode) then return end
    if C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then return end
    if not UnitIsPlayer(unit) then return end
    local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
    if not summary or secret(summary) then return end
    local score = safeNumber(summary.currentSeasonScore)
    if not score or score <= 0 then return end

    local ratingColor
    if C_ChallengeMode.GetDungeonScoreRarityColor then
        ratingColor = C_ChallengeMode.GetDungeonScoreRarityColor(score)
    end
    local total = wrap(score, ratingColor)
    local rows, maxLevel = {}, 0
    local runs = summary.runs
    if showDungeons and type(runs) == "table" and not secret(runs) then
        for _, run in ipairs(runs) do
            if type(run) == "table" and not secret(run) then
                local level = safeNumber(run.bestRunLevel)
                local mapScore = safeNumber(run.mapScore)
                local success = not secret(run.finishedSuccess) and run.finishedSuccess == true
                if success and level and level > maxLevel then maxLevel = level end
                -- Show every available dungeon result, including overtime runs.
                if level and level > 0 and mapScore and mapScore > 0 then
                    local mapID = safeNumber(run.challengeModeID)
                    if mapID and C_ChallengeMode.GetMapUIInfo then
                        local name, _, _, texture = C_ChallengeMode.GetMapUIInfo(mapID)
                        if type(name) == "string" and not secret(name) and name ~= "" then
                            rows[#rows + 1] = {
                                left = (type(texture) == "number" and not secret(texture) and texture > 0)
                                    and ("|T" .. texture .. ":14:14:0:0|t " .. shortDungeon(name)) or shortDungeon(name),
                                right = colored(mapScore, level, not success) .. " " .. colored("(" .. level .. ")", level, not success),
                            }
                        end
                    end
                end
            end
        end
    end
    if maxLevel > 0 then
        local levelHex = levelColor(maxLevel, false)
        total = total .. " |c" .. levelHex .. "(" .. maxLevel .. ")|r"
    end
    table.insert(rows, 1, { left = (ns.L and ns.L["Mythic+ Rating"]) or "Mythic+ Rating", right = total })
    return rows
end

function M.rows(unit, showDungeons)
    if type(unit) ~= "string" or secret(unit) then return end
    local ok, rows = pcall(read, unit, showDungeons)
    if ok then return rows end
end
