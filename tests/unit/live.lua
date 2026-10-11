-- Live parts follow the game while their panel shows: a unit's health row and
-- bar update when its health changes. (Its name has no digits, so only the
-- health row's two halves are compared.)
return function(test)
    local UNIT = 2
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Game/Game.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Unit.lua" }, {
        enums = { TooltipDataType = { Item = 0, Unit = UNIT } },
        calls = { UnitHealth = { mouseover = { n = 1, 25 } }, UnitHealthMax = { mouseover = { n = 1, 100 } } },
    })
    local model = ns.ui.unitModel({ name = "Hogger", level = 11, creature = "Humanoid", health = 50, healthMax = 100 })
    model.unit = "mouseover"
    local anchor = CreateFrame("Frame", nil, UIParent)
    local panel = ns.ui.renderPreview(anchor, model, UNIT)
    local function shownTexts()
        local texts = {}
        for _, font in ipairs(panel.pool) do
            if font._shown and font._text and font._text:find("%d") then texts[#texts + 1] = font._text end
        end
        return texts
    end
    local function tick()
        for _, object in ipairs(world.objects) do
            if object._scripts.OnUpdate then object._scripts.OnUpdate(object, .2) end
        end
    end
    test.check("drawn with the model's health", shownTexts(), { "50 / 100", "50%" })
    tick()
    test.check("a tick follows the unit's health", shownTexts(), { "25 / 100", "25%" })

    -- A redraw of the same panel drops the update the last drawing left: a
    -- fresh panel drawn for the unit, then at once for a unit-less copy.
    anchor = CreateFrame("Frame", nil, UIParent)
    ns.ui.renderPreview(anchor, model, UNIT)
    panel = ns.ui.renderPreview(anchor, ns.ui.unitModel({ name = "Hogger", level = 11, creature = "Humanoid",
        health = 50, healthMax = 100 }), UNIT)
    tick()
    -- Without a unit there is no portrait, so the level is back in the info line.
    test.check("a redraw clears the last update", shownTexts(), { "Level 11 Humanoid", "50 / 100", "50%" })
end
