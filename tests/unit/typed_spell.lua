-- A spell's passive line is read by its type, so it needs no English word.
return function(test)
    local SPELL, NAME, PASSIVE, DESCRIPTION = 1, 13, 33, 34
    local capture = {
        enums = { TooltipDataType = { Item = 0, Spell = SPELL },
            TooltipDataLineType = { None = 0, SpellName = NAME, SpellPassive = PASSIVE, SpellDescription = DESCRIPTION } },
        data = { type = SPELL, id = 11160, lines = {
            { type = NAME, lineIndex = 1, leftText = "Éclats de glace" },
            { type = PASSIVE, lineIndex = 2, leftText = "Passif" },
            { type = DESCRIPTION, lineIndex = 3, leftText = "Augmente les dégâts critiques de vos sorts de Givre de 20%." },
        } },
        lines = { { left = { text = "Éclats de glace" } }, { left = { text = "Passif" } },
            { left = { text = "Augmente les dégâts critiques de vos sorts de Givre de 20%." } } },
    }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Spell.lua" }, capture)
    local model = ns.TooltipTypes[SPELL].read(world.main, capture.data, ns.Game)
    test.check("the passive line, by its type", { model.passive, #model.extras }, { "Passif", 0 })
end
