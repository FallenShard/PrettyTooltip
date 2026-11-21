-- Retail's player tooltips name the specialization with the class, as
-- "Restoration Shaman", on a line of its own or with the level and race. The
-- spec moves into the info line, in the client's words and order, and a line
-- saying nothing more goes. It reads them through the callback Tooltips/Unit.lua
-- offers a client (descriptor.extension), and loads just after that file.
local _, ns = ...
local UNIT = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit
local descriptor = ns.TooltipTypes and ns.TooltipTypes[UNIT]
if not descriptor then return end
local util = ns.util
local isSecret, trim, escapePattern = util.isSecret, util.trim, util.escapePattern

-- Sets model.spec, the spec's name, and model.specClass, the spec and class
-- as the client wrote them; game asks the client for the class's specs.
local function readSpec(model, game)
    if model.spec or type(model.className) ~= "string" then return end
    local specs = game.classSpecs and game.classSpecs(model.classID)
    if not specs then return end
    local function specIn(text)
        if isSecret(text) or type(text) ~= "string" then return end
        local plain = trim(util.plainText(text))
        for _, name in ipairs(specs) do
            for _, phrase in ipairs({ name .. " " .. model.className, model.className .. " " .. name }) do
                -- Whole words; %w knows only ASCII letters, so other scripts match as they are.
                local pattern = escapePattern(phrase)
                if not phrase:find("[\128-\255]") then pattern = "%f[%w]" .. pattern .. "%f[%W]" end
                local from, to = plain:find(pattern)
                if from then
                    local rest = plain:sub(1, from - 1) .. plain:sub(to + 1)
                    if model.race then rest = rest:gsub(escapePattern(model.race), "", 1) end
                    -- The level line can end in the unit's kind, "(Player)".
                    return name, phrase, trim((rest:gsub("%s*%b()%s*$", "")))
                end
            end
        end
    end
    if model.levelLine then model.spec, model.specClass = specIn(model.levelLine) end
    if model.spec then return end
    for index, row in ipairs(model.extras) do
        local name, phrase, rest = specIn(row.left)
        if name then
            model.spec, model.specClass = name, phrase
            if rest == "" and (row.right or "") == "" then table.remove(model.extras, index) end
            return
        end
    end
end


-- Item level is intentionally read separately from Mythic+ rating: players
-- without a rating must still have their inspected item level displayed.
local inspectCache, inspectPending = {}, {}
-- Bound inspect history: only nearby/recently inspected players are useful.
local inspectEntries, INSPECT_LIMIT = 0, 128
local function rememberInspect(guid, value, now)
    if not inspectCache[guid] then
        if inspectEntries >= INSPECT_LIMIT then
            wipe(inspectCache)
            inspectEntries = 0
        end
        inspectEntries = inspectEntries + 1
    end
    inspectCache[guid] = { value = value, at = now }
end
local TTL, RETRY = 180, 3
local function usable(v)
    return type(v) == "number" and v > 0 and not (issecretvalue and issecretvalue(v))
end
local function safeGUID(unit)
    if not (unit and UnitGUID) then return end
    local ok, guid = pcall(UnitGUID, unit)
    if ok and type(guid) == "string" and not (issecretvalue and issecretvalue(guid)) then return guid end
end
local inspectFrame = CreateFrame("Frame")
inspectFrame:RegisterEvent("INSPECT_READY")
inspectFrame:SetScript("OnEvent", function(_, _, guid)
    if type(guid) ~= "string" or not inspectPending[guid] then return end
    local pending = inspectPending[guid]
    inspectPending[guid] = nil
    local unitToken = pending.unit
    if safeGUID(unitToken) ~= guid then return end
    if not (C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel) then return end
    local ok, ilvl = pcall(C_PaperDollInfo.GetInspectItemLevel, unitToken)
    if ok and usable(ilvl) then
        rememberInspect(guid, ilvl, GetTime())
        -- The current tooltip may still show this unit; refresh it safely.
        if C_Timer and C_Timer.After then C_Timer.After(0, function()
            if GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown()
                and GameTooltip.RefreshData then pcall(GameTooltip.RefreshData, GameTooltip) end
        end) end
    end
end)
local function playerItemLevel(unitToken)
    if not unitToken then return end
    local ok, isSelf = pcall(UnitIsUnit, unitToken, "player")
    if not ok or type(isSelf) ~= "boolean" then return end
    if isSelf and GetAverageItemLevel then
        local success, _, equipped = pcall(GetAverageItemLevel)
        if success and usable(equipped) then return equipped end
        return
    end
    local guid = safeGUID(unitToken)
    if not guid then return end
    local now = GetTime()
    local cached = inspectCache[guid]
    if cached and now - cached.at < TTL then return cached.value end
    if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local success, value = pcall(C_PaperDollInfo.GetInspectItemLevel, unitToken)
        if success and usable(value) then
            rememberInspect(guid, value, now)
            return value
        end
    end
    if not (CanInspect and NotifyInspect and C_Timer and C_Timer.After) then return end
    local pending = inspectPending[guid]
    if pending and now - pending.at < RETRY then return end
    local canOk, allowed = pcall(CanInspect, unitToken)
    if not canOk or allowed ~= true then return end
    inspectPending[guid] = { unit = unitToken, at = now }
    C_Timer.After(.3, function()
        if not inspectPending[guid] or safeGUID(unitToken) ~= guid then return end
        local canNowOk, canNow = pcall(CanInspect, unitToken)
        if canNowOk and canNow == true then pcall(NotifyInspect, unitToken) end
    end)
end
local function itemLevelRow(value, preview)
    if not usable(value) then return end
    local color = value <= 285 and "808080" or value <= 298 and "1eff00"
        or value <= 311 and "0070ff" or value <= 324 and "a335ee"
        or value <= 334 and "ff8000" or "e6cc80"
    local locale = GetLocale and GetLocale() or "enUS"
    local label = (locale == "zhCN" or locale == "zhTW") and "物品等级：" or "ItemLevel: "
    local shownValue = preview and tostring(value) or string.format("%.1f", value)
    return { left = label .. "|cff" .. color .. shownValue .. "|r", right = "" }
end

-- Optional Mythic+ and raid progression rows. The Unit Details checkboxes
-- are the master switches; modifier keys only control rows that are enabled.
local function modifierDown(option)
    local key = ns.option(option)
    -- Older builds stored NONE. Migrate that legacy value to the former default
    -- modifier rather than leaving an enabled section permanently inaccessible.
    if key == "NONE" or key == nil then key = "ALT" end
    if key == "CTRL" then return IsControlKeyDown() end
    if key == "ALT" then return IsAltKeyDown() end
    if key == "SHIFT" then return IsShiftKeyDown() end
    return key == "ALWAYS"
end

local function appendRows(model, rows)
    if type(rows) ~= "table" then return end
    for _, row in ipairs(rows) do
        if type(row) == "table" then model.extras[#model.extras + 1] = row end
    end
end

local function appendPreviewRows(model)
    -- The editor may complete/render the same sample model more than once.
    -- Keep this operation idempotent so progression sections never duplicate.
    if model._prettyTooltipProgressPreviewAdded then return end
    model._prettyTooltipProgressPreviewAdded = true

    local L = ns.L or {}
    -- A stable sample specialization keeps the editor preview independent of
    -- the current character's inspected/native tooltip data.
    if ns.option("unitTalentEnabled") then
        local specName = "Restoration"
        local className = "Shaman"
        local sample = "|cffffd200" .. (L["Specialization"] or "专精") .. "：|r"
            .. "|cff0070dd" .. specName .. " " .. className .. "|r"
        appendRows(model, { { left = sample, right = "" } })
    end
    -- Keep the unit preview representative of the live player tooltip.
    if ns.option("unitItemLevelEnabled") then
        local row = itemLevelRow(61, true)
        if row then appendRows(model, { row }) end
    end

    if ns.option("mythicScoreEnabled") and ns.MythicScore and ns.MythicScore.previewRows then
        appendRows(model, ns.MythicScore.previewRows())
    end

    if ns.option("raidProgressEnabled") then
        local raidRows = {
            { left = "|cffe6cc80" .. (L["Raid Progress"] or "团队副本") .. "|r", right = "" },
            { left = "潮缚石窟", right = "|cffa335eeH 1/1|r  |cff888888M --|r" },
            { left = "烈毒之渊", right = "|cffa335eeH 2/8|r  |cff888888M --|r" },
            { left = "基希克斯破封", right = "|cffa335eeH 1/1|r  |cff888888M --|r" },
        }
        appendRows(model, raidRows)
    end
end

descriptor.extension = {
    -- A player's specialization, named with the class.
    afterRead = function(model, context)
        if model.isPlayer then
            if ns.option("unitTalentEnabled") then readSpec(model, context.game) end
            -- Item level is independently configurable from Mythic+ and raid rows.
            if model.unit and not model.isPreview and ns.option("unitItemLevelEnabled") then
                local row = itemLevelRow(playerItemLevel(model.unit))
                if row then model.extras[#model.extras + 1] = row end
            end
            if model.isPreview then
                appendPreviewRows(model)
            else
                if ns.option("mythicScoreEnabled") and modifierDown("mythicScoreKey") and ns.MythicScore then
                    appendRows(model, ns.MythicScore.rows(model.unit, true))
                end
                if ns.option("raidProgressEnabled") and modifierDown("raidProgressKey") and ns.RaidProgress then
                    appendRows(model, ns.RaidProgress.rows(model.unit))
                end
            end
        end
    end,
}
