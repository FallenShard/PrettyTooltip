-- The game's settings window does not open in combat: /ptip options and the
-- editor's More options say so instead of doing nothing, and open it otherwise.
return function(test)
    local opened, printed, combat = 0, {}, false
    Settings = {
        RegisterCanvasLayoutCategory = function() return { GetID = function() return 7 end } end,
        RegisterAddOnCategory = function() end,
        OpenToCategory = function() opened = opened + 1 end,
    }
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "UI/Options.lua" }, {})
    ns.Options.register()
    InCombatLockdown = function() return combat end
    print = function(text) printed[#printed + 1] = text end

    combat = true
    test.check("in combat the window stays shut and the player is told",
        { ns.openSettings(), opened, printed[1] },
        { false, 0, "PrettyTooltip: the options cannot open during combat. Try again once it ends." })
    combat = false
    test.check("out of combat it opens", { ns.openSettings(), opened, #printed }, { true, 1, 1 })
end
