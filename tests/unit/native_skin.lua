-- The game's own tooltips the addon does not redraw take the panel style's
-- backdrop and border in place of the game's, once the setting is on; the
-- native style leaves them as the game draws them.
return function(test)
    SharedTooltip_SetBackdropStyle = function() end
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Game/Game.lua", "Panel/Layout.lua", "Integration/NativeSkin.lua" },
        { enums = { TooltipDataType = { Item = 0 } } })
    local tooltip = CreateFrame("GameTooltip")
    tooltip:SetFrameLevel(3)
    tooltip:SetFrameStrata("DIALOG")
    tooltip.NineSlice = CreateFrame("Frame", nil, tooltip)
    SettingsTooltip = tooltip
    ns.NativeSkin.register()
    ns.setOption("skinGameTooltips", true)
    local function skin()
        for _, child in ipairs({ tooltip:GetChildren() }) do
            if child ~= tooltip.NineSlice then return child end
        end
    end
    local function state(panel)
        return { panel and panel._shown, panel and panel.backdropMode, tooltip.NineSlice:GetAlpha() }
    end

    ns.setOption("backdropStyle", "native")
    SharedTooltip_SetBackdropStyle(tooltip)
    test.check("the native style keeps the game's backdrop", { skin(), tooltip.NineSlice:GetAlpha() }, { nil, 1 })

    ns.setOption("backdropStyle", "flat")
    SharedTooltip_SetBackdropStyle(tooltip)
    local panel = skin()
    test.check("flat draws the panel's backdrop under the text, hiding the game's",
        { panel._shown, panel.backdropMode, tooltip.NineSlice:GetAlpha(), panel:GetFrameStrata(),
            panel:GetFrameLevel(), panel.header._shown },
        { true, "flat", 0, "DIALOG", 1, false })

    ns.setOption("backdropStyle", "classic")
    SharedTooltip_SetBackdropStyle(tooltip)
    test.check("Classic draws its stone and the dialogs' bronze border", { state(panel), panel.grain._texture },
        { { true, "classic", 0 }, "Interface\\FrameGeneral\\UI-Background-Rock" })
    test.check("Classic's thicker border sits outside the text", { select(4, panel:GetPoint(1)) }, { -3, 3 })

    ns.setOption("skinGameTooltips", false)
    SharedTooltip_SetBackdropStyle(tooltip)
    test.check("turned off, the game's backdrop comes back", state(panel), { false, "classic", 1 })
    ns.setOption("skinGameTooltips", true)

    tooltip._forbidden = true
    SharedTooltip_SetBackdropStyle(tooltip)
    test.check("a forbidden tooltip is left alone", state(panel), { false, "classic", 1 })
    tooltip._forbidden = nil

    SharedTooltip_SetBackdropStyle(tooltip)
    tooltip.NineSlice:Hide()
    SharedTooltip_SetBackdropStyle(tooltip)
    test.check("an embedded tooltip, its backdrop hidden, is left alone", state(panel), { false, "classic", 1 })
    tooltip.NineSlice:Show()

    ns.setOption("skinGameTooltips", false)
    tooltip.NineSlice:SetAlpha(0)
    SharedTooltip_SetBackdropStyle(tooltip)
    test.check("once restored, another addon's hiding of the game's backdrop stays",
        tooltip.NineSlice:GetAlpha(), 0)
    tooltip.NineSlice:SetAlpha(1)
    ns.setOption("skinGameTooltips", true)

    -- The settings window's tooltip sets its backdrop once, before the addon loads.
    tooltip:GetScript("OnShow")(tooltip)
    test.check("the settings tooltip takes the backdrop as it shows", state(panel), { true, "classic", 0 })
end
