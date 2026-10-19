-- The game can send a spell's name line twice, the second time empty. That
-- copy must not take the drawn line's right text, the rank, as a row of its own.
return function(test)
    local SPELL, NAME, DESCRIPTION = 1, 13, 34
    local capture = { enums = { TooltipDataType = { Item = 0, Spell = SPELL },
        TooltipDataLineType = { None = 0, SpellName = NAME, SpellDescription = DESCRIPTION } },
        data = { type = SPELL, id = 1259799, lines = {
            { type = NAME, lineIndex = 1, leftText = "Elune's Light", rightText = "Racial" },
            { type = 0, lineIndex = 1, leftText = "", rightText = "" },
            { type = 0, lineIndex = 2, leftText = "Instant", rightText = "3 min cooldown" },
            { type = DESCRIPTION, lineIndex = 3,
                leftText = "Increases your critical strike chance with all spells and attacks by 10% for 15 sec." },
        } },
        lines = { { left = { text = "Elune's Light" }, right = { text = "Racial" } },
            { left = { text = "Instant" }, right = { text = "3 min cooldown" } },
            { left = { text = "Increases your critical strike chance with all spells and attacks by 10% for 15 sec." } } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Spell.lua" }, capture)
    local model = ns.TooltipTypes[SPELL].read(world.main, capture.data, ns.Game)
    test.check("the rank is read once, as the rank", { model.name, model.rank, #model.extras },
        { "Elune's Light", "Racial", 0 })
end
