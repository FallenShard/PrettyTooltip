-- Ordinary tooltips hide on fade; the last hovered unit stays until another
-- unit replaces it. Parked native tooltips restore their anchors on reuse.
return function(test)
    local fixture = { enums = { TooltipDataType = { Item = 0, Object = 33, UnitAura = 7 } },
        data = { type = 33, id = 1, lines = { { lineIndex = 1, leftText = "Mailbox" } } },
        lines = { { left = { text = "Mailbox" } } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Object.lua", "Integration/Native.lua", "Integration/Placement.lua",
        "Integration/Hooks.lua", "Integration/Cursor.lua" }, fixture)
    local tooltip = world.main
    local combat = false
    InCombatLockdown = function() return combat end
    local pending = {}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    ns.Hooks.install()
    local callback = world.postCalls[33][1]
    GameTooltip_SetDefaultAnchor = function(frame)
        frame:SetOwner(UIParent, "ANCHOR_NONE")
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
    end
    GetCursorPosition = function() return 500, 400 end
    ns.Cursor.register()
    local follower = world.objects[#world.objects]
    ns.setOption("cursorObjects", false)
    local function show()
        GameTooltip_SetDefaultAnchor(tooltip)
        tooltip:SetClampedToScreen(true)
        tooltip:Show()
        tooltip:SetAlpha(1)
        callback(tooltip, fixture.data)
        return ns.ui.panels[tooltip]
    end
    local function anchor(frame)
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
        return { point, relativeTo == UIParent, relativePoint, x, y }
    end
    local default = { "BOTTOMRIGHT", true, "BOTTOMRIGHT", -20, 30 }
    local parked = { "TOPRIGHT", true, "BOTTOMLEFT", -10000, -10000 }
    local PARKED_DRIFT = -9999.999023

    for _, inCombat in ipairs({ true, false }) do
        local label = inCombat and "in combat" or "out of combat"
        combat = inCombat
        local panel = show()
        tooltip:FadeOut()
        test.check(label .. ": only the panel disappears immediately",
            { tooltip:IsShown(), panel:IsShown() }, { true, false })
        test.check(label .. ": the native tooltip stays off screen, unclamped",
            { anchor(tooltip), tooltip:IsClampedToScreen() }, { parked, false })
        flush()
        test.check(label .. ": queued renders cannot revive the old panel", panel:IsShown(), false)
        tooltip:FadeOut()
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        test.check(label .. ": reuse restores the original anchor and clamping",
            { anchor(tooltip), tooltip:IsClampedToScreen(), ns.Native.isParked(tooltip) }, { default, true, false })
        callback(tooltip, fixture.data)
        test.check(label .. ": new content reconnects the panel to its source anchor",
            { panel:IsShown(), select(2, panel:GetPoint(1)) == UIParent }, { true, true })
    end

    local panel = show()
    tooltip:FadeOut()
    callback(tooltip, fixture.data)
    test.check("a same-owner data handover also restores the position",
        { anchor(tooltip), tooltip:IsClampedToScreen(), panel:IsShown() }, { default, true, true })

    tooltip:FadeOut()
    tooltip:ClearAllPoints()
    tooltip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -60)
    callback(tooltip, fixture.data)
    test.check("a fresh anchor from the game or another addon is preserved", anchor(tooltip),
        { "TOPLEFT", true, "TOPLEFT", 40, -60 })

    show()
    tooltip:SetClampedToScreen(false)
    tooltip:FadeOut()
    callback(tooltip, fixture.data)
    test.check("reuse preserves an originally unclamped tooltip",
        { anchor(tooltip), tooltip:IsClampedToScreen() }, { default, false })

    show()
    tooltip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -10)
    local points = ns.util.framePoints(tooltip)
    tooltip:FadeOut()
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    test.check("all saved anchor points are restored", ns.util.framePoints(tooltip), points)

    show()
    tooltip:FadeOut()
    tooltip._points[1][4], tooltip._points[1][5] = PARKED_DRIFT, PARKED_DRIFT
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    test.check("reuse restores the anchor when the parked offsets read back slightly off",
        { anchor(tooltip), tooltip:GetNumPoints(), ns.Native.isParked(tooltip) }, { default, 1, false })

    -- The game re-anchors a shown tooltip without clearing its points first.
    show()
    tooltip:FadeOut()
    tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
    callback(tooltip, fixture.data)
    test.check("a game anchor added beside the parked one replaces it",
        { anchor(tooltip), tooltip:GetNumPoints(), tooltip:IsClampedToScreen() }, { default, 1, true })

    show()
    tooltip:FadeOut()
    tooltip:Hide()
    tooltip:GetScript("OnHide")(tooltip)
    flush()
    test.check("the game's own hide releases the parked position",
        { anchor(tooltip), tooltip:IsClampedToScreen(), panel:IsShown() }, { default, true, false })

    show()
    local getPoint = tooltip.GetPoint
    tooltip.GetPoint = function() return "TOPLEFT", UIParent, "TOPLEFT", world.secret, 0 end
    tooltip:FadeOut()
    tooltip.GetPoint = getPoint
    test.check("unreadable anchors are not parked, and the panel still disappears",
        { anchor(tooltip), ns.Native.isParked(tooltip), panel:IsShown() }, { default, false, false })

    -- Follow cursor must save the actual default anchor before parking, and
    -- resume on a same-owner handover even after a clear or combat transition.
    ns.setOption("cursorObjects", true)
    ns.setOption("cursorDisableInCombat", true)
    combat = false
    show()
    test.check("the integrated tooltip starts following",
        { select(2, tooltip:GetPoint(1)) == follower, follower:IsShown() }, { true, true })
    tooltip:FadeOut()
    test.check("fading hides the panel and stops following",
        { panel:IsShown(), follower:IsShown(), anchor(tooltip) }, { false, false, parked })
    tooltip:GetScript("OnTooltipCleared")(tooltip)
    flush()
    combat = true
    world.fireEvent("PLAYER_REGEN_DISABLED")
    combat = false
    world.fireEvent("PLAYER_REGEN_ENABLED")
    test.check("clearing and combat transitions leave the old tooltip parked",
        { panel:IsShown(), follower:IsShown(), anchor(tooltip) }, { false, false, parked })
    callback(tooltip, fixture.data)
    test.check("same-owner content resumes following",
        { panel:IsShown(), follower:IsShown(), select(2, tooltip:GetPoint(1)) == follower }, { true, true, true })
    combat = true
    world.fireEvent("PLAYER_REGEN_DISABLED")
    test.check("combat still restores the real default anchor after reuse",
        { anchor(tooltip), tooltip:IsClampedToScreen() }, { default, true })

    local unitNs, unitWorld = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Object.lua", "Integration/Native.lua",
        "Integration/Placement.lua", "Integration/Hooks.lua" }, {
        enums = { TooltipDataType = { Item = 0, Unit = 2, Object = 33 } },
        data = { type = 33, id = 1, lines = { { lineIndex = 1, leftText = "Object" } } },
        lines = { { left = { text = "Object" } } },
    })
    InCombatLockdown = function() return combat end
    local unitDead = false
    local unitRenderCount = 0
    unitNs.ui.defineTooltipType(2, {
        read = function(_, data, _, unit)
            if unit then return { guid = data.guid, dead = unitDead, reaction = data.reaction } end
            return { guid = data.guid, dead = unitDead, reaction = data.reaction, isPlayer = data.isPlayer, color = data.color,
                omitInfo = data.omitInfo, portrait = data.portrait, wide = data.wide }
        end,
        render = function(panel, tooltip, model)
            unitRenderCount = unitRenderCount + 1
            panel.unitGuid = model.guid
            panel.unitReaction = model.reaction
            panel.renderedOmitInfo = model.omitInfo
            panel.unitDead = model.dead
            panel.unitTextFields = { name = { text = model.guid } }
            if not model.omitInfo then panel.unitTextFields.info = { text = "unchanged" } end
            unitNs.ui.finishPanel(panel, tooltip, 40)
        end,
        key = function(_, data) return data.guid end,
        option = "unitPanels",
    })
    unitNs.Hooks.install()
    local unitGuids = { mouseover = "friendly" }
    unitNs.Game.unitGUID = function(unit) return unitGuids[unit] end
    local unitTooltip = unitWorld.main
    local unitCallback = unitWorld.postCalls[2][1]
    local objectCallback = unitWorld.postCalls[33][1]
    unitTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    unitTooltip:ClearAllPoints()
    unitTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
    unitTooltip:Show()
    unitTooltip:SetAlpha(1)
    unitCallback(unitTooltip, { guid = "friendly", reaction = 5, lines = {} })
    local unitPanel = unitNs.ui.panels[unitTooltip]
    unitTooltip:FadeOut()
    test.check("a hovered unit panel stays visible after the cursor leaves",
        { unitPanel:IsShown(), unitPanel.unitGuid, unitNs.Native.isParked(unitTooltip) },
        { true, "friendly", true })
    unitTooltip:Hide()
    unitTooltip:GetScript("OnHide")(unitTooltip)
    test.check("the game's completed tooltip hide retains the last unit",
        unitPanel:IsShown(), true)
    unitGuids.eventunit = "friendly"
    unitDead = true
    unitWorld.fireEvent("UNIT_FLAGS", "eventunit")
    test.check("the retained tooltip updates when its unit dies",
        { unitPanel:IsShown(), unitPanel.unitDead }, { true, true })
    unitTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    unitTooltip:Show()
    unitTooltip:SetAlpha(1)
    objectCallback(unitTooltip, { id = 3, lines = {} })
    test.check("non-unit hovers do not replace the retained unit",
        { unitPanel:IsShown(), unitPanel.unitGuid, select(2, unitPanel:GetPoint(1)) == UIParent },
        { true, "friendly", true })
    for _, target in ipairs({ { guid = "friendly-next", reaction = 5 }, { guid = "neutral", reaction = 4 },
        { guid = "enemy", reaction = 2 } }) do
        unitTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        unitTooltip:Show()
        unitTooltip:SetAlpha(1)
        unitCallback(unitTooltip, { guid = target.guid, reaction = target.reaction, lines = {} })
        test.check("hovering a new unit replaces the retained one: " .. target.guid,
            { unitPanel:IsShown(), unitPanel.unitGuid, unitPanel.unitReaction,
                unitNs.Native.isParked(unitTooltip) },
            { true, target.guid, target.reaction, false })
    end

    local updatedFields = {}
    local updatedTint
    local updatedPortrait
    local unitUpdateOrder = {}
    local fieldRegion = unitPanel:CreateFontString(nil, "OVERLAY")
    unitNs.ui.unitTextFields = function(_, model)
        local fields = { name = { text = model.guid } }
        if not model.omitInfo then fields.info = { text = "unchanged" } end
        return fields, model.color, .5
    end
    unitNs.ui.unitLayoutKey = function(_, model)
        if model.wide then return "wide" end
        return model.omitInfo and "without-info" or "with-info"
    end
    unitNs.ui.updatePanelTint = function(_, tint, strength, tooltipType)
        updatedTint = { tint, strength, tooltipType }
    end
    unitNs.ui.updateUnitTextField = function(_, key, text)
        unitUpdateOrder[#unitUpdateOrder + 1] = "text"
        updatedFields[key] = text
        fieldRegion:SetAlpha(1)
    end
    unitNs.ui.updateUnitPortrait = function(_, model)
        unitUpdateOrder[#unitUpdateOrder + 1] = "portrait"
        updatedPortrait = model.portrait
    end
    unitPanel.unitTextFields = { name = { text = unitPanel.unitGuid }, info = { text = "unchanged" } }
    unitPanel.unitLayoutKey = "with-info"
    local renderCountBeforeTextUpdate = unitRenderCount
    local hostileTint = { .9, .1, .1 }
    unitCallback(unitTooltip, { guid = "text-only", reaction = 2, color = hostileTint,
        portrait = "text-only-portrait", lines = {} })
    test.check("a unit hover updates only the differing header text field",
        { unitRenderCount, updatedFields, unitPanel:GetAlpha(), updatedTint },
        { renderCountBeforeTextUpdate, { name = "text-only" }, 1,
            { hostileTint, .5, "unit" } })
    test.check("the differing text field updates without a fade", fieldRegion:GetAlpha(), 1)
    test.check("a text-only unit update refreshes the portrait", updatedPortrait, "text-only-portrait")
    test.check("the portrait update is requested before other unit text changes",
        unitUpdateOrder, { "portrait", "text" })
    local renderCountBeforeMissingField = unitRenderCount
    unitCallback(unitTooltip, { guid = "without-info", omitInfo = true, lines = {} })
    test.check("missing target fields trigger a full redraw that clears the old field",
        { unitRenderCount, unitPanel.unitGuid, unitPanel.renderedOmitInfo, unitPanel.unitTextFields.info },
        { renderCountBeforeMissingField + 1, "without-info", true, nil })
    local renderCountBeforeSizeChange = unitRenderCount
    unitCallback(unitTooltip, { guid = "wider", wide = true, lines = {} })
    test.check("a unit with a different measured size gets a full redraw",
        { unitRenderCount, unitPanel.unitGuid }, { renderCountBeforeSizeChange + 1, "wider" })
    unitNs.ui.unitTextFields = nil
    unitNs.ui.updateUnitTextField = nil
    local unitTokens = { mouseover = "engaged-a", nameplate1 = "engaged-a", nameplate2 = "engaged-b",
        target = "unengaged" }
    local dead = {}
    unitNs.Game.NEARBY_UNITS = { "target", "mouseover", "nameplate1", "nameplate2" }
    unitNs.Game.unitExists = function(unit) return unitTokens[unit] ~= nil end
    unitNs.Game.unitGUID = function(unit) return unitTokens[unit] end
    unitNs.Game.unitToken = function(guid)
        for token, tokenGuid in pairs(unitTokens) do
            if tokenGuid == guid then return token end
        end
    end
    unitNs.Game.unitIsPlayer = function(unit) return unit == "player" end
    unitNs.Game.unitCanAttack = function(_, unit) return unit ~= "player" end
    unitNs.Game.unitAffectingCombat = function(unit) return unit == "nameplate1" or unit == "nameplate2" end
    unitNs.Game.unitIsDead = function(unit) return dead[unitTokens[unit]] == true end
    unitTooltip.GetUnit = function() return "Creature", "mouseover" end
    combat = true
    unitWorld.fireEvent("PLAYER_REGEN_DISABLED")
    unitTokens.mouseover = "engaged-a"
    unitCallback(unitTooltip, { guid = "engaged-a", reaction = 2, lines = {} })
    test.check("combat hovers update the tooltip for a living engaged enemy", unitPanel.unitGuid, "engaged-a")
    unitTokens.nameplate3 = "engaged-c"
    unitNs.Game.NEARBY_UNITS = { "target", "mouseover", "nameplate1", "nameplate2", "nameplate3" }
    unitNs.Game.unitAffectingCombat = function(unit)
        return unit == "nameplate1" or unit == "nameplate2" or unit == "nameplate3"
    end
    unitWorld.fireEvent("UNIT_COMBAT", "nameplate3")
    unitTokens.mouseover = "engaged-c"
    unitCallback(unitTooltip, { guid = "engaged-c", reaction = 2, lines = {} })
    test.check("a new enemy joining the encounter is added to the engaged list", unitPanel.unitGuid, "engaged-c")
    unitTokens.mouseover = "unengaged"
    unitCallback(unitTooltip, { guid = "unengaged", reaction = 2, lines = {} })
    test.check("combat hovers ignore enemies that are not engaged", unitPanel.unitGuid, "engaged-c")
    dead["engaged-a"] = true
    unitWorld.fireEvent("UNIT_HEALTH", "nameplate1")
    unitTokens.mouseover = "engaged-b"
    unitCallback(unitTooltip, { guid = "engaged-b", reaction = 2, lines = {} })
    test.check("a different living engaged enemy can update the tooltip", unitPanel.unitGuid, "engaged-b")
    dead["engaged-a"] = false
    unitTokens.mouseover = "engaged-a"
    unitCallback(unitTooltip, { guid = "engaged-a", reaction = 2, lines = {} })
    test.check("a dead enemy stays disregarded for the rest of combat", unitPanel.unitGuid, "engaged-b")
    dead["engaged-b"] = true
    unitWorld.fireEvent("UNIT_HEALTH", "nameplate2")
    dead["engaged-c"] = true
    unitWorld.fireEvent("UNIT_HEALTH", "nameplate3")
    unitTokens.mouseover = "unengaged"
    unitCallback(unitTooltip, { guid = "unengaged", reaction = 2, lines = {} })
    test.check("other units can update once no living engaged enemies remain", unitPanel.unitGuid, "unengaged")
    unitTokens.mouseover = "engaged-a"
    unitCallback(unitTooltip, { guid = "engaged-a", reaction = 2, lines = {} })
    test.check("dead enemies remain ignored even after the gate opens", unitPanel.unitGuid, "unengaged")
    combat = false
    unitWorld.fireEvent("PLAYER_REGEN_ENABLED")
    unitCallback(unitTooltip, { guid = "engaged-a", reaction = 2, lines = {} })
    test.check("dead enemies are eligible again after combat ends", unitPanel.unitGuid, "engaged-a")
end
