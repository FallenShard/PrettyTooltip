-- A dual-school spell's accent runs from its first school to its second.
return function(test)
    local SPELL = 1
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Game/Game.lua", "Data/Schools.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Spell.lua" },
        { enums = { TooltipDataType = { Item = 0, Spell = SPELL } } })
    local frost, fire = ns.Palette.schools.Frost, ns.Palette.schools.Fire
    local function spell(name, description)
        return { name = name, rank = "Rank 1", icon = 135812, cast = { "3 sec", "Cast" }, cells = { { "3 sec", "Cast" } },
            details = {}, requirements = {}, description = { description }, extras = {} }
    end
    local function rgba(color) return { color[1], color[2], color[3], 1 } end
    local anchor = CreateFrame("Frame", nil, UIParent)
    local panel = ns.ui.renderPreview(anchor, spell("Frostfire Bolt",
        "Launches a bolt of frostfire at the enemy, causing 40 Frostfire damage."), SPELL)
    local border = panel.nativeBorder
    test.check("the left side is the first school", border.LeftEdge._color, rgba(frost))
    test.check("the right side is the second", border.RightEdge._color, rgba(fire))
    test.check("the top edge blends across", border.TopEdge._gradient, { "HORIZONTAL", rgba(frost), rgba(fire) })
    test.check("the header band runs across", panel.header._gradient[1], "HORIZONTAL")
    test.check("the glow runs across", panel.halo._gradient[1], "HORIZONTAL")

    ns.ui.renderPreview(anchor, spell("Frostbolt", "Launches a bolt of frost at the enemy, causing 20 Frost damage."), SPELL)
    test.check("a single school clears the edge's gradient", border.TopEdge._gradient, nil)
    test.check("a single school's edge is one color", border.TopEdge._color, rgba(frost))
    test.check("a single school's band runs down again", panel.header._gradient[1], "VERTICAL")
end
