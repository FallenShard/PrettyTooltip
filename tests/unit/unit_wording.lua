-- A unit's lines are read by their wording, which is the game's own strings in
-- the client's language: the level line and the rank it names, and the lines
-- the badges and faction crest show instead.
return function(test)
    local UNIT = 2

    -- The unit's model from its lines, the first its name.
    local function read(lines)
        local capture = { enums = { TooltipDataType = { Item = 0, Unit = UNIT } },
            data = { type = UNIT, lines = {} }, lines = {} }
        for index, left in ipairs(lines) do
            capture.data.lines[index] = { type = 0, lineIndex = index, leftText = left }
            capture.lines[index] = { left = { text = left } }
        end
        local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
            "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
            "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Unit.lua" }, capture)
        local model = ns.TooltipTypes[UNIT].read(world.main, capture.data, ns.Game)
        local extras = {}
        for index, row in ipairs(model.extras) do extras[index] = row.left end
        return { levelLine = model.levelLine, rank = model.classification, tag = model.tag, extras = extras }
    end

    test.check("enUS: a boss", read({ "Ragnaros", "Level ?? (Boss)" }),
        { levelLine = "Level ?? (Boss)", rank = "worldboss", extras = {} })
    test.check("enUS: a rare elite with its creature type", read({ "Kurzen Commando", "Level 30 Humanoid (Rare Elite)" }),
        { levelLine = "Level 30 Humanoid (Rare Elite)", rank = "rareelite", extras = {} })
    test.check("enUS: a rare", read({ "Mor'Ladim", "Level 35 (Rare)" }),
        { levelLine = "Level 35 (Rare)", rank = "rare", extras = {} })
    test.check("enUS: a player, the badges' lines left out", read({
        "Thrall", "<Horde Leaders>", "Level 12 Night Elf (Player)", "Alliance", "PvP", "Dead",
    }), { levelLine = "Level 12 Night Elf", tag = "<Horde Leaders>", extras = {} })
    test.check("enUS: a player without a race", read({ "Thrall", "Level 12 (Player)" }),
        { levelLine = "Level 12", extras = {} })
    test.check("enUS: a corpse's lines", read({ "Plainstrider", "Level 8 Beast", "Corpse", "Skinnable", "Requires Mining" }),
        { levelLine = "Level 8 Beast", extras = { "Requires Mining" } })
end
