-- A dead creature that can be skinned shows the Skinning it needs, in its
-- skill-up color, and what it may give; the option hides it.
return function(test)
    local UNIT = 2
    local capture = {
        enums = { TooltipDataType = { Item = 0, Unit = UNIT } },
        calls = {
            GetNumSkillLines = { [""] = { 1, n = 1 } },
            GetSkillLineInfo = { ["1"] = { "Skinning", false, false, 120, n = 4 } },
        },
    }
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Data/Skinning.lua", "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Unit.lua" },
        capture)
    -- Highland Raptor, level 20: Skinning 100.
    local guid = "Creature-0-1-0-1-1015-0000ABCDEF"
    local model = ns.ui.unitModel({ name = "Highland Raptor", level = 20, dead = true, guid = guid })
    local skin = model.skinning
    test.check("the skill a level 20 creature needs, and the player's",
        { skin and skin.needed, skin and skin.player }, { 100, 120 })
    test.check("what it may give, the likeliest first", { skin.rows[1].left, skin.rows[1].right, #skin.rows },
        { "Medium Leather", "50%", 4 })
    local function shown()
        local panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), model, UNIT)
        local texts = {}
        for _, font in ipairs(panel.pool) do
            if font._shown and font._text and font._text ~= "" then texts[#texts + 1] = ns.util.plainText(font._text) end
        end
        return table.concat(texts, " | ")
    end
    test.check("a Skinnable badge and the section", { shown():find("Skinnable", 1, true) ~= nil,
        shown():find("Requires Skinning 100", 1, true) ~= nil }, { true, true })
    test.check("20 past what it needs is orange", ns.Palette.skillUpColor(100, 120), { 1, .50, .25 })
    ns.setOption("gatheringLoot", false)
    test.check("hidden when turned off", shown():find("Requires Skinning", 1, true) ~= nil, false)

    local alive = ns.ui.unitModel({ name = "Highland Raptor", level = 20, guid = guid })
    test.check("a living creature shows nothing of it", alive.skinning, nil)
end
