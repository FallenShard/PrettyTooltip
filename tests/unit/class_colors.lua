-- Class overrides apply to player names, guilds, panel accents, and targets.
-- Unset colors continue following the game's table, including other addons.
return function(test)
    local UNIT = 2
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Unit.lua" },
        { enums = { TooltipDataType = { Item = 0, Unit = UNIT } } })
    local palette = ns.Palette
    local original = ns.Game.classColor("WARRIOR")
    test.check("no override follows the game's color", palette.classColor("WARRIOR"), original)
    test.check("an absent class has no color", palette.classColor(nil), nil)
    ns.setOption("classColorWARRIOR", { 1, 0, 0 })
    test.check("an override does not change the game's wrapper", ns.Game.classColor("WARRIOR"), original)
    test.check("the palette returns the override", palette.classColor("WARRIOR"), { 1, 0, 0 })

    local game = setmetatable({
        unitExists = function(unit) return unit == "mouseover" or unit == "mouseovertarget" end,
        unitGUID = function() return "Player-test" end,
        unitIsPlayer = function() return true end,
        unitClass = function(unit)
            if unit == "mouseovertarget" then return "Mage", "MAGE" end
            return "Warrior", "WARRIOR"
        end,
        unitGuild = function() return "Test guild" end,
        unitName = function() return "Target" end,
    }, { __index = ns.Game })
    world.main.GetUnit = function() return "Player", "mouseover" end
    local data = { guid = "Player-test", lines = { { lineIndex = 1, leftText = "Player" } } }
    ns.setOption("classColorMAGE", { 0, 0, 1 })
    local model = ns.TooltipTypes[UNIT].read(world.main, data, game)
    test.check("a player's model uses the class override", model.color, { 1, 0, 0 })
    test.check("its player target uses that class's override", model.targetColor, { 0, 0, 1 })

    local view
    ns.ui.renderView = function(_, _, value) view = value end
    ns.setOption("unitHealthBar", false)
    ns.TooltipTypes[UNIT].render({}, world.main, model)
    test.check("the player name follows its class color", view.header[1].color, { 1, 0, 0 })
    test.check("the panel tint follows its class color", view.tint, { 1, 0, 0 })
    test.check("the guild takes the lighter class shade", view.header[2].color, { 1, .5, .5 })

    ns.setOption("classColorWARRIOR", nil)
    RAID_CLASS_COLORS.WARRIOR = { r = .1, g = .2, b = .3 }
    test.check("an external class-color change remains visible", palette.classColor("WARRIOR"), { .1, .2, .3 })
    ns.setOption("classColorWARRIOR", { 0, 1, 0 })
    RAID_CLASS_COLORS.WARRIOR = { r = .3, g = .2, b = .1 }
    test.check("our override takes precedence", palette.classColor("WARRIOR"), { 0, 1, 0 })
    ns.setOption("classColorWARRIOR", { 1, "invalid", 0 })
    test.check("a malformed override falls back to the game", palette.classColor("WARRIOR"), { .3, .2, .1 })
    ns.setOption("classColorWARRIOR", nil)
    test.check("reset picks up the latest external color", palette.classColor("WARRIOR"), { .3, .2, .1 })
    ns.setOption("classColorWARRIOR", { 0, 1, 0 })
    ns.resetStyles()
    test.check("reset fonts and colors also clears class overrides", ns.savedOption("classColorWARRIOR"), nil)
end
