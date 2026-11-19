-- Retail's part in reading units, through the callbacks Tooltips/Unit.lua
-- offers a client (descriptor.extension). It loads just after that file;
-- Retail/Tooltips/Unit.lua, before it, holds what these use.
local _, ns = ...
local UNIT = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit
local descriptor = ns.TooltipTypes and ns.TooltipTypes[UNIT]
if not descriptor then return end
local unit = ns.Retail.Unit

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
local function itemLevelRow(value)
    if not usable(value) then return end
    local color = value <= 285 and "808080" or value <= 298 and "1eff00"
        or value <= 311 and "0070ff" or value <= 324 and "a335ee"
        or value <= 334 and "ff8000" or "e6cc80"
    local label = (ns.L and ns.L["Item Level"]) or "Item Level"
    return { left = label .. ": |cff" .. color .. string.format("%.1f", value) .. "|r", right = "" }
end

-- Ported from the 1.3.6 mount information feature. Read only public,
-- non-secret aura data; cache static journal metadata, not collection state.
local mountBySpell, mountDetails = {}, {}
local mountSpellCount, mountDetailCount, CACHE_LIMIT = 0, 0, 256
local function safe(v)
    return v ~= nil and not (issecretvalue and issecretvalue(v))
end
local function mountFromSpell(spellID)
    local cached = mountBySpell[spellID]
    if cached ~= nil then return cached ~= false and cached or nil end
    local ok, id = pcall(C_MountJournal.GetMountFromSpell, spellID)
    if not ok or not safe(id) then return end
    if mountSpellCount >= CACHE_LIMIT then wipe(mountBySpell); mountSpellCount = 0 end
    mountSpellCount = mountSpellCount + 1
    mountBySpell[spellID] = id or false
    return id
end
local function mountInfo(id)
    local details = mountDetails[id]
    if not details then
        local ok, name = pcall(C_MountJournal.GetMountInfoByID, id)
        if not ok or not safe(name) or type(name) ~= "string" then return end
        local source
        if C_MountJournal.GetMountInfoExtraByID then
            local extraOK, _, _, text = pcall(C_MountJournal.GetMountInfoExtraByID, id)
            if extraOK and safe(text) and type(text) == "string" then source = text end
        end
        details = { name = name, source = source }
        if mountDetailCount >= CACHE_LIMIT then wipe(mountDetails); mountDetailCount = 0 end
        mountDetailCount = mountDetailCount + 1
        mountDetails[id] = details
    end
    local ok, _, _, _, _, _, _, _, _, _, _, collected = pcall(C_MountJournal.GetMountInfoByID, id)
    if not ok or not safe(collected) then collected = nil end
    return details, collected
end
-- A short TTL avoids scanning up to 40 auras repeatedly during tooltip refresh.
-- Cache only the mount ID, never collection state (which can change).
local mountScan = {}
local mountScanEntries, MOUNT_SCAN_LIMIT = 0, 64
local MOUNT_SCAN_TTL = 0.35
local function scanKey(unitToken)
    return safeGUID(unitToken)
end
local function rememberMountScan(guid, id, now)
    if not guid then return end
    if not mountScan[guid] then
        if mountScanEntries >= MOUNT_SCAN_LIMIT then
            wipe(mountScan)
            mountScanEntries = 0
        end
        mountScanEntries = mountScanEntries + 1
    end
    mountScan[guid] = { id = id or false, at = now }
end
local function playerMount(unitToken)
    if not (unitToken and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and C_MountJournal
        and C_MountJournal.GetMountFromSpell and C_MountJournal.GetMountInfoByID) then return end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
        if not ok or not safe(secret) or secret then return end
    end
    local guid = scanKey(unitToken)
    local now = GetTime()
    local cached = guid and mountScan[guid]
    if cached and now - cached.at < MOUNT_SCAN_TTL then
        if cached.id == false then return end
        return mountInfo(cached.id)
    end
    for i = 1, 40 do
        if C_Secrets and C_Secrets.ShouldUnitAuraIndexBeSecret then
            local ok, secret = pcall(C_Secrets.ShouldUnitAuraIndexBeSecret, unitToken, i, "HELPFUL")
            if not ok or not safe(secret) or secret then return end
        end
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unitToken, i, "HELPFUL")
        if not ok or not safe(aura) or type(aura) ~= "table" then break end
        local spellID = aura.spellId
        if safe(spellID) and type(spellID) == "number" then
            local id = mountFromSpell(spellID)
            if id then
                local details, collected = mountInfo(id)
                if details then
                    rememberMountScan(guid, id, now)
                    return details, collected
                end
            end
        end
    end
    rememberMountScan(guid, false, now)
end
local function addMountRows(model)
    if not model.isPlayer or not model.unit then return end
    local info, collected = playerMount(model.unit)
    if not info then return end
    local L = ns.L or {}
    local mountLabel = L["Mount"] or "Mount"
    local sourceLabel = L["Source"] or "Source"
    local status = collected == true and (" |cff00ff00【%s】|r"):format(L["Collected"] or "Collected")
        or collected == false and (" |cffff5555【%s】|r"):format(L["Not collected"] or "Not collected") or ""
    model.mountRows = { { left = mountLabel .. "：" .. info.name .. status, right = "" } }
    if info.source and info.source ~= "" then
        model.mountRows[#model.mountRows + 1] = { left = sourceLabel .. "：" .. info.source:gsub("|n%s*|n$", ""), right = "" }
    end
end

descriptor.extension = {
    -- A player's specialization, named with the class.
    afterRead = function(model, context)
        if model.isPlayer then
            unit.readSpec(model, context.game)
            addMountRows(model)
            if model.unit then
                local row = itemLevelRow(playerItemLevel(model.unit))
                if row then model.extras[#model.extras + 1] = row end
            end
            if model.unit and ns.MythicScore and ns.mythicScoreKeyDown() then
                local rows = ns.MythicScore.rows(model.unit, true)
                if rows then
                    for _, row in ipairs(rows) do model.extras[#model.extras + 1] = row end
                end
            end
            if model.unit and ns.RaidProgress and ns.raidProgressKeyDown() then
                local raidRows = ns.RaidProgress.rows(model.unit)
                if raidRows then
                    for _, raidRow in ipairs(raidRows) do
                        model.extras[#model.extras + 1] = raidRow
                    end
                end
            end
        end
    end,
}
