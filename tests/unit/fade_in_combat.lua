-- A world unit's tooltip that starts fading: the game sets its alpha every
-- frame past the SetAlpha hook, so in combat and out the addon moves it off
-- the screen and fades the panel where it stands. It never hides the game's
-- tooltip, as that would run its OnHide under the addon's taint. New content,
-- or the game's own hide, gives the tooltip its clamping back.
return function(test)
    local fixture = { enums = { TooltipDataType = { Item = 0, Object = 33, UnitAura = 7 } },
        data = { type = 33, id = 1, lines = { { lineIndex = 1, leftText = "Mailbox" } } },
        lines = { { left = { text = "Mailbox" } } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Object.lua", "Integration/Native.lua",
        "Integration/Hooks.lua" }, fixture)
    local tooltip = world.main
    local combat = false
    InCombatLockdown = function() return combat end
    ns.Hooks.install()
    local callback = world.postCalls[33][1]
    local function show()
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        tooltip:SetClampedToScreen(true)
        tooltip:ClearAllPoints()
        tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
        tooltip:Show()
        tooltip:SetAlpha(1)
        callback(tooltip, fixture.data)
        return ns.ui.panels[tooltip]
    end
    local function anchor(frame)
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
        return { point, relativeTo == UIParent, relativePoint, x, y }
    end
    local home = { "BOTTOMRIGHT", true, "BOTTOMRIGHT", -20, 30 }

    for _, inCombat in ipairs({ true, false }) do
        local label = inCombat and "in combat" or "out of combat"
        combat = inCombat
        local panel = show()
        test.check(label .. ": the panel starts on its tooltip", panel:GetPoint(1) ~= nil
            and select(2, panel:GetPoint(1)) == tooltip, true)
        tooltip:FadeOut()
        test.check(label .. ": the game's tooltip is not hidden", tooltip:IsShown(), true)
        test.check(label .. ": it goes off the screen, unclamped",
            { anchor(tooltip), tooltip:IsClampedToScreen() }, { { "TOPRIGHT", true, "BOTTOMLEFT", -10000, -10000 }, false })
        test.check(label .. ": the panel stays where it stood and fades",
            { select(2, panel:GetPoint(1)) == UIParent, panel.fadePending, panel:IsShown() }, { true, true, true })
        ns.ui.alignPanel(panel, tooltip)
        test.check(label .. ": and is not pulled after it", select(2, panel:GetPoint(1)) == UIParent, true)
        if inCombat then
            -- The next world unit, as retail anchors it: a new owner, then its
            -- anchor added to whatever the tooltip had, without clearing it.
            tooltip:SetOwner(UIParent, "ANCHOR_NONE")
            test.check("a new owner gives the clamping back", tooltip:IsClampedToScreen(), true)
            tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
            test.check("and the owner's anchor is its only one, not added to the off-screen one",
                { tooltip:GetNumPoints(), anchor(tooltip) }, { 1, home })
            test.check("the fading panel stays where it stood", select(2, panel:GetPoint(1)) == UIParent, true)
            callback(tooltip, fixture.data)
            test.check("and the panel follows its tooltip again", select(2, panel:GetPoint(1)) == tooltip, true)
        else
            tooltip:Hide()
            tooltip:GetScript("OnHide")(tooltip)
            test.check("the game's own hide gives the clamping back", tooltip:IsClampedToScreen(), true)
            test.check("and its own anchor", { tooltip:GetNumPoints(), anchor(tooltip) }, { 1, home })
            test.check("and the fading panel stays where it stood", select(2, panel:GetPoint(1)) == UIParent, true)
        end
        ns.Native.restoreNative(tooltip)
    end

    -- New content with no new owner or anchor goes back where it stood.
    local panel = show()
    tooltip:FadeOut()
    callback(tooltip, fixture.data)
    test.check("new content alone puts the tooltip back at its anchor, clamped",
        { tooltip:GetNumPoints(), anchor(tooltip), tooltip:IsClampedToScreen() }, { 1, home, true })
    test.check("its panel on it, shown", { select(2, panel:GetPoint(1)) == tooltip, panel:IsShown() }, { true, true })
    test.check("and fading again parks it again", (tooltip:FadeOut() or anchor(tooltip))[4], -10000)
    tooltip:Hide()
    tooltip:GetScript("OnHide")(tooltip)
    ns.Native.restoreNative(tooltip)

    -- Anchored by someone else while off the screen, it keeps that anchor.
    panel = show()
    tooltip:FadeOut()
    tooltip:ClearAllPoints()
    tooltip:SetPoint("CENTER", UIParent, "CENTER", 5, 5)
    tooltip:Hide()
    tooltip:GetScript("OnHide")(tooltip)
    test.check("an anchor set by someone else while off the screen stays",
        { tooltip:GetNumPoints(), anchor(tooltip) }, { 1, { "CENTER", true, "CENTER", 5, 5 } })
    ns.Native.restoreNative(tooltip)

    -- After its fade the game leaves the tooltip shown, off the screen. New
    -- content then shows the panel again; when another addon hides the
    -- tooltip, the panel goes with it rather than waiting for the old fade.
    panel = show()
    tooltip:FadeOut()
    panel.fade:Stop()
    panel.fade:GetScript("OnFinished")()
    test.check("the panel is gone once its fade ends", panel:IsShown(), false)
    panel = show()
    test.check("new content shows it again", panel:IsShown(), true)
    tooltip:Hide()
    ns.Native.restoreNative(tooltip)
    test.check("and a later hide takes it away", panel:IsShown(), false)
end
