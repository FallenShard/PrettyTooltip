-- When panels read and draw: on the game's handover of a tooltip's data, on
-- refreshes, when lines are added or rewritten, and when the original-tooltip
-- key is pressed. The entry file installs them.
local _, ns = ...
local ui = ns.ui
if not (ui and ns.Native) then return end

local isSecret = ns.util.isSecret
local util = ns.util
local TooltipTypes = ns.TooltipTypes
local panels, getPanel, isComparison, alignPanel = ui.panels, ui.getPanel, ui.isComparison, ui.alignPanel
local probe, tally = ui.probe, ui.tally
local native = ns.Native
local anchorToPanels, refitNative, refitUnlessPartial = native.anchorToPanels, native.refitNative, native.refitUnlessPartial
local restoreNative, showsDataType = native.restoreNative, native.showsDataType
local hooks = {}
ns.Hooks = hooks
local batchComparisons = false

local function showsOriginal(panel)
    local tooltipType = TooltipTypes[panel.dataType]
    return ns.originalKeyDown() or not (tooltipType and ns.restyles(tooltipType.option))
end

-- What the tooltip shows, as one string; nil when a line cannot be read.
local function fingerprint(tooltip, data)
    if isSecret(data) or type(data) ~= "table" or isSecret(data.lines) then return end
    local parts = { ns.settingsVersion or 0, isComparison(tooltip) and 1 or 0,
        ns.detailsKeyDown() and 1 or 0 }
    local name = tooltip:GetName()
    for index = 1, tooltip:NumLines() do
        local left = tooltip:GetLeftLine(index)
        local right = tooltip.GetRightLine and tooltip:GetRightLine(index)
            or (name and _G[name .. "TextRight" .. index])
        for _, font in ipairs({ left, right }) do
            if font and font:IsShown() then
                local text = font:GetText()
                local r, g, b = font:GetTextColor()
                if isSecret(text) or isSecret(r) or isSecret(g) or isSecret(b)
                    or (text ~= nil and type(text) ~= "string") or type(r) ~= "number"
                    or type(g) ~= "number" or type(b) ~= "number" then return end
                parts[#parts + 1] = text or ""
                parts[#parts + 1] = r
                parts[#parts + 1] = g
                parts[#parts + 1] = b
            end
        end
    end
    -- Sell prices are drawn by a money frame, not as text.
    for _, line in ipairs(data.lines or {}) do
        if isSecret(line) or type(line) ~= "table" or isSecret(line.price) then return end
        if line.price ~= nil and type(line.price) ~= "number" then return end
        if line.price then parts[#parts + 1] = line.price end
    end
    return table.concat(parts, "\031")
end

local function keyOf(tooltipType, tooltip, data)
    local ok, key = pcall(tooltipType.key, tooltip, data)
    if ok and not isSecret(key) then return key, true end
end

-- The type that draws this tooltip in its data type's place, while it is
-- restyled: an imbue's, for the weapon tooltip its buff button shows.
local function claimantOf(dataType, tooltip, data)
    for claimant, tooltipType in pairs(TooltipTypes) do
        if tooltipType.claims == dataType and ns.restyles(tooltipType.option) then
            local ok, claimed = pcall(tooltipType.claim, tooltip, data)
            if ok and claimed then return claimant end
        end
    end
    return dataType
end

local function update(tooltip, data, model)
    if not util.canModify(tooltip) or native.isParked(tooltip) then return end
    local panel = getPanel(tooltip)
    local tooltipType = TooltipTypes[panel.dataType]
    if showsOriginal(panel) or not tooltipType then restoreNative(tooltip); return end
    panel.nativeOnly = nil
    local ok = true
    if not model then ok, model = pcall(tooltipType.read, tooltip, data, ns.Game) end
    if not ok or not model then restoreNative(tooltip); return end
    if not panel.nativeAlpha then panel.nativeAlpha = util.number((util.call(tooltip.GetAlpha, tooltip))) end
    if not panel.nativeAlpha then restoreNative(tooltip); return end
    local wasShown = panel:IsShown()
    local rendered = pcall(tooltipType.render, panel, tooltip, model)
    if not rendered then restoreNative(tooltip); return end
    if panel.dataType == Enum.TooltipDataType.Unit then panel.unitDead = model.dead end
    tally("refit from render")
    refitNative(tooltip, panel)
    panel.data = data
    local key, valid = keyOf(tooltipType, tooltip, data)
    if not valid then restoreNative(tooltip); return end
    -- A fresh render was fitted to whatever the tooltip measured mid-fill (an
    -- early Show can be taller); the final Show must not wait as "smaller".
    if key ~= panel.key or not wasShown then
        panel.fullLines, panel.naturalWidth, panel.naturalHeight = nil, nil, nil
    end
    panel.key = key
    if panel.dataType == Enum.TooltipDataType.Item then
        panel.model, panel.modelDataType = model, panel.dataType
        panel.modelVersion, panel.modelDetails = ns.settingsVersion or 0, ns.detailsKeyDown()
    else
        panel.model = nil
    end
    panel.renderedDataType = panel.dataType
    panel.lineCount = tooltip:NumLines()
    panel.fingerprint = not tooltipType.alwaysRedraw and fingerprint(tooltip, data) or nil
    panel.elapsed = 0
    tooltip:SetAlpha(0)
    native.suppressChildMouse(tooltip, panel)
end
update = probe("update", update)

local function fitComparison(tooltip, panel)
    panel.comparisonFitPending = nil
    -- A completed comparison may legitimately have fewer rows now.
    panel.fullLines = tooltip:NumLines()
    panel.forceFit = true
    refitNative(tooltip, panel)
    panel.forceFit = false
end

-- The comparison manager fills the item, shows it, then appends the delta
-- rows. Read the completed content after SetItemTooltip, but wait for its
-- final SetShown to measure it: appended rows are not laid out until then.
local function finishComparison(tooltip, panel, deferFit)
    if not panel.comparisonPending then return end
    if not util.canModify(tooltip) or native.isParked(tooltip) or panel.restorePending or not tooltip:IsShown()
        or not showsDataType(tooltip, panel) or showsOriginal(panel) then
        panel.comparisonPending = nil
        panel.comparisonFitPending = nil
        return
    end
    local key, valid = keyOf(TooltipTypes[panel.dataType], tooltip, panel.data)
    if valid and panel:IsShown() and panel.renderedDataType == panel.dataType and key == panel.key
        and panel.fingerprint and panel.fingerprint == util.call(fingerprint, tooltip, panel.data) then
        tally("render skipped")
    else
        -- Deferred work also runs outside the protected reader/renderer;
        -- native font strings can become unreadable while it is queued.
        if not pcall(update, tooltip, panel.data) then restoreNative(tooltip); return end
    end
    panel.comparisonPending = nil
    if panel:IsShown() then
        panel.elapsed = 0
        panel.comparisonFitPending = true
        if not deferFit then fitComparison(tooltip, panel) end
    end
end

local function finishComparisonAnchor(tooltip, panel)
    panel.comparisonAnchorPending = nil
    if not util.canModify(tooltip) or panel.restorePending or not tooltip:IsShown() or not panel:IsShown() then return end
    anchorToPanels(tooltip)
    panel.comparisonAnchorHeld = nil
    pcall(alignPanel, panel, tooltip)
end

local function scheduleComparisonAnchor(tooltip, panel)
    panel.comparisonAnchorPending = true
    if panel.comparisonAnchorQueued then return end
    panel.comparisonAnchorQueued = true
    -- Also handles comparisons anchored by an addon outside the manager.
    C_Timer.After(0, function()
        panel.comparisonAnchorQueued = nil
        if panel.comparisonAnchorPending then finishComparisonAnchor(tooltip, panel) end
    end)
end

-- Shared Blizzard UI can become available after this addon's startup. Retry
-- on data handover until the manager is ready, then leave its hooks in place.
local function installComparisonHooks()
    if batchComparisons or not ns.restyles("itemPanels") then return end
    local manager = TooltipComparisonManager
    if isSecret(manager) or type(manager) ~= "table" or type(manager.SetItemTooltip) ~= "function"
        or type(manager.AnchorShoppingTooltips) ~= "function" then return end
    batchComparisons = true
    hooksecurefunc(manager, "SetItemTooltip", function(self, isPrimary)
        if not ns.restyles("itemPanels") then return end
        if isSecret(isPrimary) or type(isPrimary) ~= "boolean" then return end
        local owner = self.tooltip
        if not util.canModify(owner) then return end
        local tooltips = owner.shoppingTooltips
        if isSecret(tooltips) or type(tooltips) ~= "table" then return end
        local tooltip = tooltips[isPrimary and 1 or 2]
        if not util.canModify(tooltip) then return end
        local panel = panels[tooltip]
        if panel then finishComparison(tooltip, panel, true) end
    end)
    -- Retarget after all points, including the neighbour and side, are set.
    hooksecurefunc(manager, "AnchorShoppingTooltips", function()
        for tooltip, panel in pairs(panels) do
            if panel.comparisonAnchorPending and util.canModify(tooltip) and isComparison(tooltip) then
                finishComparisonAnchor(tooltip, panel)
            end
        end
    end)
end

function hooks.comparisonsBatched() return batchComparisons end

-- Keep the previous panel across a clear while its native tooltip is still
-- shown. Hides dismiss it unless it is a retained unit; native cleanup waits
-- until no new item post-call replaces it in that frame.
local function scheduleRestore(tooltip)
    local panel = panels[tooltip]
    if not panel or panel.nativeOnly or panel.stickyUnit then return end
    if batchComparisons then native.holdComparison(tooltip) end
    native.beginRefresh(tooltip)
    if panel.data and panel.data.fromLines then panel.data = nil end
    panel.restorePending = true
    panel.refreshToken = (panel.refreshToken or 0) + 1
    local token = panel.refreshToken
    C_Timer.After(0, function()
        if panel.refreshToken == token and panel.restorePending then
            restoreNative(tooltip)
        end
    end)
end

local engagedEnemies, disregardedEnemies = {}, {}

local function combatUnitTokens()
    local tokens, seen = {}, {}
    for _, unit in ipairs(ns.Game.NEARBY_UNITS) do
        for _, candidate in ipairs({ unit, unit .. "target" }) do
            if not seen[candidate] then
                seen[candidate] = true
                tokens[#tokens + 1] = candidate
            end
        end
    end
    return tokens
end

local function findUnit(guid)
    local engaged = engagedEnemies[guid]
    if type(engaged) == "string" and ns.Game.unitExists(engaged) and ns.Game.unitGUID(engaged) == guid then
        return engaged
    end
    local token = ns.Game.unitToken(guid)
    if type(token) == "string" and ns.Game.unitExists(token) and ns.Game.unitGUID(token) == guid then
        return token
    end
    for _, unit in ipairs(combatUnitTokens()) do
        if ns.Game.unitExists(unit) and ns.Game.unitGUID(unit) == guid then return unit end
    end
end

local function collectCombatUnits()
    local units = {}
    for _, unit in ipairs(combatUnitTokens()) do
        if ns.Game.unitExists(unit) then
            local guid = ns.Game.unitGUID(unit)
            if not isSecret(guid) and type(guid) == "string" then units[guid] = unit end
        end
    end
    return units
end

local function scanEngagedEnemies()
    if not InCombatLockdown() then
        for guid in pairs(engagedEnemies) do engagedEnemies[guid] = nil end
        for guid in pairs(disregardedEnemies) do disregardedEnemies[guid] = nil end
        return false
    end
    local units = collectCombatUnits()
    for guid, previousUnit in pairs(engagedEnemies) do
        local unit = units[guid] or previousUnit
        if ns.Game.unitGUID(unit) ~= guid then
            unit = ns.Game.unitToken(guid)
            if type(unit) ~= "string" or ns.Game.unitGUID(unit) ~= guid then unit = nil end
        end
        if unit and ns.Game.unitIsDead(unit) == true then
            engagedEnemies[guid] = nil
            disregardedEnemies[guid] = true
        elseif unit then
            engagedEnemies[guid] = unit
        end
    end
    for guid, unit in pairs(units) do
        if ns.Game.unitIsDead(unit) == true then
            disregardedEnemies[guid] = true
        elseif not disregardedEnemies[guid] and ns.Game.unitIsPlayer(unit) == false
            and ns.Game.unitCanAttack("player", unit) == true
            and ns.Game.unitAffectingCombat(unit) == true then
            engagedEnemies[guid] = unit
        end
    end
    return next(engagedEnemies) ~= nil
end

local function isNonPlayerTooltip(tooltip, data)
    if isSecret(data) or type(data) ~= "table" or isSecret(data.guid) or type(data.guid) ~= "string" then
        return false
    end
    local _, unit = util.call(tooltip.GetUnit, tooltip)
    if type(unit) ~= "string" or ns.Game.unitGUID(unit) ~= data.guid then unit = findUnit(data.guid) end
    return type(unit) == "string" and ns.Game.unitIsPlayer(unit) == false
end

local function updateUnitTextFields(tooltip, panel, data, key, token)
    local tooltipType = TooltipTypes[Enum.TooltipDataType.Unit]
    if not (tooltipType and ns.ui.unitTextFields and ns.ui.updateUnitTextField) then return false end
    local ok, model = pcall(tooltipType.read, tooltip, data, ns.Game)
    if not ok or not model then return false end
    local fieldsOK, fields, tint, strength = pcall(ns.ui.unitTextFields, panel, model)
    if not fieldsOK or type(fields) ~= "table" then return false, model end
    if ns.ui.updateUnitPortrait then ns.ui.updateUnitPortrait(panel, model) end
    for fieldKey in pairs(fields) do
        if not (panel.unitTextFields and panel.unitTextFields[fieldKey]) then return false, model end
    end
    for fieldKey in pairs(panel.unitTextFields or {}) do
        if not fields[fieldKey] then return false, model end
    end
    for fieldKey, previous in pairs(panel.unitTextFields or {}) do
        local field = fields[fieldKey]
        local text = field and field.text or ""
        local color = field and field.color
        local previousColor = previous.color
        local colorChanged = color ~= previousColor
            and (not color or not previousColor or color[1] ~= previousColor[1]
                or color[2] ~= previousColor[2] or color[3] ~= previousColor[3])
        if previous.text ~= text or colorChanged then
            ns.ui.updateUnitTextField(panel, fieldKey, text, color)
        end
    end
    ns.ui.updatePanelTint(panel, tint, strength, "unit")
    panel.data, panel.key, panel.unitDead = data, key, model.dead
    panel.model = nil
    panel.lineCount = util.call(tooltip.NumLines, tooltip)
    panel.elapsed = 0
    panel.textOnlyRefreshToken = token
    return true
end

local function onTooltipData(dataType, tooltip, data)
    if not util.canModify(tooltip) then return end
    local panel = panels[tooltip]
    if dataType == Enum.TooltipDataType.Unit and InCombatLockdown() and isNonPlayerTooltip(tooltip, data) then
        local hasEngagedEnemies = scanEngagedEnemies()
        local guid = data.guid
        local unit = findUnit(guid)
        if unit and ns.Game.unitIsDead(unit) == true then
            engagedEnemies[guid] = nil
            disregardedEnemies[guid] = true
        end
        if disregardedEnemies[guid] or (hasEngagedEnemies and not engagedEnemies[guid]) then
            if panel then
                panel.refreshToken = (panel.refreshToken or 0) + 1
                if panel.nativeAlpha and util.call(tooltip.GetAlpha, tooltip) ~= 0 then tooltip:SetAlpha(0) end
            end
            return
        end
    end
    if panel and panel.stickyUnit and dataType ~= Enum.TooltipDataType.Unit then return end
    if isSecret(data) or type(data) ~= "table" or isSecret(data.lines) or type(data.lines) ~= "table" then
        restoreNative(tooltip)
        return
    end
    -- The editor reads this one itself.
    if tooltip.prettyTooltipScanner then return end
    -- A type drawn in this one's place (an imbue's, for its weapon) goes by its own setting.
    dataType = claimantOf(dataType, tooltip, data)
    if panel and panel.stickyUnit then panel.stickyUnit = nil end
    -- A native presentation needs no panel, geometry hooks, or restore work.
    -- Existing hooks stay installed across settings changes but become idle.
    if not ns.restyles(TooltipTypes[dataType].option) then
        local panel = panels[tooltip]
        if panel then
            if not panel.nativeOnly then
                panel.nativeOnly = true
                native.unpark(tooltip)
                restoreNative(tooltip)
            end
            panel.dataType, panel.data = dataType, data
            panel.refreshToken = (panel.refreshToken or 0) + 1
        end
        return
    end
    installComparisonHooks()
    native.unpark(tooltip)
    local panel = getPanel(tooltip)
    panel.nativeOnly = nil
    local previousKey, previousDataType = panel.key, panel.dataType
    local key, valid = keyOf(TooltipTypes[dataType], tooltip, data)
    if not valid then restoreNative(tooltip); return end
    panel.dataType = dataType
    panel.data = data
    panel.refreshToken = (panel.refreshToken or 0) + 1
    local token = panel.refreshToken
    panel.restorePending = false
    if not panel.hooked then
        tooltip:HookScript("OnHide", function(hidden)
            if panel.nativeOnly or panel.stickyUnit then return end
            -- Keep native cleanup deferred, but never draw the old panel at
            -- an anchor reset by an action button's hide/clear sequence.
            panel.refreshPending = nil
            panel.comparisonAnchorHeld = nil
            panel:Hide()
            scheduleRestore(hidden)
        end)
        tooltip:HookScript("OnTooltipCleared", scheduleRestore)
        -- Every refresh re-shows the tooltip at its natural size and full
        -- opacity. Waiting for the next OnUpdate lets one frame of it draw.
        local function onNativeShown(shown, source)
            if panel.nativeOnly then return end
            if not util.canModify(shown) then return end
            if panel.stickyUnit then
                if panel.nativeAlpha then shown:SetAlpha(0) end
                return
            end
            tally(isComparison(shown) and "show hook (comparison)" or "show hook")
            if panel.refreshPending or panel.restorePending or panel.comparisonPending then
                if panel.nativeAlpha then shown:SetAlpha(0) end
                return
            end
            if panel.comparisonFitPending and panel:IsShown() then
                fitComparison(shown, panel)
            else
                if not (panel.nativeSize and panel:IsShown()) then return end
                tally("refit from " .. source)
                refitUnlessPartial(shown, panel)
            end
            -- Comparisons are anchored after they are shown, so align here.
            if batchComparisons and isComparison(shown) then
                scheduleComparisonAnchor(shown, panel)
            else
                pcall(alignPanel, panel, shown)
                if isComparison(shown) then pcall(anchorToPanels, shown) end
            end
            local alpha = util.number((util.call(shown.GetAlpha, shown)))
            if panel.nativeAlpha and alpha and alpha ~= 0 then
                shown:SetAlpha(0)
            end
            native.suppressChildMouse(shown, panel)
        end
        hooksecurefunc(tooltip, "Show", function(shown)
            if not panel.fitting then onNativeShown(shown, "Show") end
        end)
        -- The comparison manager re-shows its tooltips with SetShown, which
        -- resets them the same way but never goes through Show.
        hooksecurefunc(tooltip, "SetShown", function(shown, visible)
            if not isSecret(visible) and visible and not panel.fitting then onNativeShown(shown, "SetShown") end
        end)
        tooltip:HookScript("OnShow", function(shown) onNativeShown(shown, "OnShow") end)
        -- The comparison code anchors a comparison after showing it, a point at
        -- a time; it belongs beside the panels, not the hidden tooltips under
        -- them, and its panel pinned to the edge those points place.
        hooksecurefunc(tooltip, "SetPoint", function(moved)
            if panel.nativeOnly or native.anchoring then return end
            if not util.canModify(moved) then return end
            if panel:IsShown() and isComparison(moved) then
                if batchComparisons then scheduleComparisonAnchor(moved, panel); return end
                tally("re-anchor after SetPoint")
                anchorToPanels(moved)
                pcall(alignPanel, panel, moved)
            end
        end)
        hooksecurefunc(tooltip, "SetAlpha", function(faded, alpha)
            if panel.nativeOnly or panel.settingAlpha then return end
            if not isSecret(alpha) and alpha == 0 then return end
            if not util.canModify(faded) then return end
            if isSecret(alpha) or type(alpha) ~= "number" then
                panel.nativeAlpha = nil
                restoreNative(faded)
                return
            end
            if not (panel.nativeAlpha and panel:IsShown()) then return end
            panel.nativeAlpha = alpha
            panel.settingAlpha = true
            pcall(faded.SetAlpha, faded, 0)
            panel.settingAlpha = false
        end)
        -- Hooked after follow cursor's, which stops following first.
        if tooltip.FadeOut then
            hooksecurefunc(tooltip, "FadeOut", function(faded)
                if not panel.nativeOnly then native.fadeOut(faded) end
            end)
        end
        hooksecurefunc(tooltip, "SetOwner", function(owned)
            if panel.nativeOnly then return end
            native.unpark(owned)
            if batchComparisons then native.holdComparison(owned) end
            native.beginRefresh(owned)
        end)
        tooltip:HookScript("OnHide", native.unpark)
        panel.hooked = true
        panel:SetScript("OnUpdate", function(self, elapsed)
            if not util.canModify(tooltip) then self:Hide(); return end
            local alpha = util.number((util.call(tooltip.GetAlpha, tooltip)))
            if self.nativeAlpha and not alpha then
                self.nativeAlpha = nil
                restoreNative(tooltip)
                return
            end
            if self.nativeAlpha and alpha ~= 0 then
                tooltip:SetAlpha(0)
            end
            self.elapsed = (self.elapsed or 0) + elapsed
            if self.elapsed < .25 then return end
            self.elapsed = 0
            -- Lines added, or rewritten in place, as the talent window does
            -- after the game fills the tooltip.
            local function changed()
                return tooltip:IsShown() and self.data and (tooltip:NumLines() ~= self.lineCount
                    or (self.fingerprint and self.fingerprint ~= fingerprint(tooltip, self.data)))
            end
            if changed() then
                C_Timer.After(0, function()
                    if showsDataType(tooltip, self) and changed() then update(tooltip, self.data) end
                end)
            end
        end)
    end
    if showsOriginal(panel) then
        panel.comparisonPending = nil
        restoreNative(tooltip)
        return
    end
    if batchComparisons and isComparison(tooltip) and dataType == Enum.TooltipDataType.Item then
        if not panel.nativeAlpha then panel.nativeAlpha = util.number((util.call(tooltip.GetAlpha, tooltip))) end
        if not panel.nativeAlpha then restoreNative(tooltip); return end
        tooltip:SetAlpha(0)
        panel.comparisonFitPending = nil
        panel.comparisonPending = true
        if not panel.comparisonCheckQueued then
            panel.comparisonCheckQueued = true
            -- A fallback for direct fills, and a check for rows appended by
            -- addons after the manager's post-hook. Keep only one per frame.
            C_Timer.After(0, function()
                panel.comparisonCheckQueued = nil
                if panel.comparisonPending or panel.comparisonFitPending or (util.canModify(tooltip) and panel:IsShown()
                    and panel.fingerprint and panel.fingerprint ~= util.call(fingerprint, tooltip, panel.data)) then
                    panel.comparisonPending = true
                    finishComparison(tooltip, panel)
                    finishComparisonAnchor(tooltip, panel)
                end
            end)
        end
        return
    end
    -- The first render shows the new item promptly. On refresh, retain the
    -- complete old panel until other addons have appended their rows.
    local changedUnit = dataType == Enum.TooltipDataType.Unit
        and previousDataType == Enum.TooltipDataType.Unit and panel:IsShown()
        and key ~= previousKey
    local textOnly, unitModel
    if changedUnit then textOnly, unitModel = updateUnitTextFields(tooltip, panel, data, key, token) end
    if not textOnly and (not panel:IsShown() or dataType ~= previousDataType or (key and key ~= previousKey)) then
        update(tooltip, data, unitModel)
    elseif not textOnly then
        if not panel.nativeAlpha then panel.nativeAlpha = util.number((util.call(tooltip.GetAlpha, tooltip))) end
        if not panel.nativeAlpha then restoreNative(tooltip); return end
        tooltip:SetAlpha(0)
        tally("refit from same item's data")
        refitUnlessPartial(tooltip, panel)
    end
    C_Timer.After(0, function()
        if util.canModify(tooltip) and panel.refreshToken == token and util.call(tooltip.IsShown, tooltip)
            and showsDataType(tooltip, panel) then
            if panel.textOnlyRefreshToken == token then
                panel.textOnlyRefreshToken = nil
                return
            end
            -- The game re-sets shown tooltips often, comparisons most; a panel
            -- already showing the same text needs no new render.
            if panel:IsShown() and panel.fingerprint and panel.fingerprint == fingerprint(tooltip, data) then
                -- A completed handover just checked the same native content
                -- the periodic poll watches. Keep polling for quiet tooltips.
                panel.elapsed = 0
                tally("render skipped")
                return
            end
            update(tooltip, data)
        end
    end)
end
onTooltipData = probe("tooltip data", onTooltipData)

-- Mouseover can already refer to another unit; the event token lets a parked
-- panel refresh only when its own unit's dead state changes.
local unitStatus = CreateFrame("Frame")
unitStatus:RegisterEvent("UNIT_FLAGS")
unitStatus:RegisterEvent("UNIT_HEALTH")
unitStatus:RegisterEvent("UNIT_COMBAT")
unitStatus:RegisterEvent("UNIT_TARGET")
unitStatus:RegisterEvent("PLAYER_REGEN_DISABLED")
unitStatus:RegisterEvent("PLAYER_REGEN_ENABLED")
unitStatus:RegisterEvent("PLAYER_TARGET_CHANGED")
unitStatus:RegisterEvent("PLAYER_FOCUS_CHANGED")
unitStatus:RegisterEvent("GROUP_ROSTER_UPDATE")
unitStatus:RegisterEvent("NAME_PLATE_UNIT_ADDED")
unitStatus:SetScript("OnEvent", function(_, event, unit)
    if type(unit) == "string" then
        local guid = util.call(ns.Game.unitGUID, unit)
        if InCombatLockdown() and not isSecret(guid) and type(guid) == "string"
            and util.call(ns.Game.unitIsPlayer, unit) == false and util.call(ns.Game.unitIsDead, unit) == true then
            engagedEnemies[guid] = nil
            disregardedEnemies[guid] = true
        end
    end
    if event ~= "UNIT_HEALTH" then scanEngagedEnemies() end
    if type(unit) ~= "string" then return end
    local guid = util.call(ns.Game.unitGUID, unit)
    if isSecret(guid) or type(guid) ~= "string" then return end
    for tooltip, panel in pairs(panels) do
        if panel.stickyUnit and panel.dataType == Enum.TooltipDataType.Unit and panel.key == guid
            and panel.data and util.canModify(tooltip) then
            local dead = util.call(ns.Game.unitIsDead, unit)
            if type(dead) ~= "boolean" or dead ~= panel.unitDead then
                local tooltipType = TooltipTypes[panel.dataType]
                local ok, model = pcall(tooltipType.read, tooltip, panel.data, ns.Game, unit)
                if ok and model then
                    local rendered = pcall(tooltipType.render, panel, tooltip, model)
                    if rendered then panel.unitDead = model.dead else restoreNative(tooltip) end
                end
            end
        end
    end
end)

local installed = false
function hooks.install()
    if installed then return end
    installed = true
    installComparisonHooks()
    -- A type drawn from lines alone has no data for the game to hand over.
    for dataType, tooltipType in pairs(TooltipTypes) do
        if not tooltipType.linesOnly then
            ns.Processor.onData("panel", dataType, function(tooltip, data)
                onTooltipData(dataType, tooltip, data)
            end)
        end
    end

    -- The original-tooltip key swaps the panel for the game's tooltip; Shift
    -- shows or hides the details.
    ns.Processor.onKey("panel", function(key)
        if not (ns.isOriginalKey(key) or ns.isDetailsKey(key)) then return end
        for tooltip, panel in pairs(panels) do
            if util.canModify(tooltip) and tooltip:IsShown() and showsDataType(tooltip, panel) then
                if showsOriginal(panel) then
                    restoreNative(tooltip)
                elseif panel.data then
                    local model
                    -- Other addons' Alt-only rows remain until the next
                    -- native refill. Resume our last item model immediately;
                    -- the normal data/line hooks still read fresh models.
                    if ns.isOriginalKey(key) and panel.dataType == Enum.TooltipDataType.Item
                        and panel.model and panel.modelDataType == panel.dataType
                        and panel.modelVersion == (ns.settingsVersion or 0)
                        and panel.modelDetails == ns.detailsKeyDown() then
                        local currentKey, valid = keyOf(TooltipTypes[panel.dataType], tooltip, panel.data)
                        if valid and currentKey and currentKey == panel.key
                            and util.call(fingerprint, tooltip, panel.data) then
                            model = panel.model
                        end
                    end
                    update(tooltip, panel.data, model)
                end
            end
        end
        if ns.isOriginalKey(key) and not ns.originalKeyDown() then
            -- Restore the whole pair in this event. The native tooltip can be
            -- wider than its panel, so waiting for the manager leaves a gap.
            for tooltip, panel in pairs(panels) do
                if util.canModify(tooltip) and tooltip:IsShown() and panel:IsShown() and isComparison(tooltip) then
                    pcall(anchorToPanels, tooltip)
                    pcall(alignPanel, panel, tooltip)
                end
            end
        end
    end)
end

-- Draws a tooltip type from a tooltip another addon filled with lines alone.
function hooks.renderLines(tooltip, dataType, id)
    onTooltipData(dataType, tooltip, { type = dataType, id = id, lines = {}, fromLines = true })
end
