-- A unit's level goes on a plate under its portrait; with the plate off, or no
-- portrait, it stays in the info line.
return function(test)
    local UNIT = 2
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Unit.lua" },
        { enums = { TooltipDataType = { Item = 0, Unit = UNIT } } })
    local model = ns.ui.unitModel({ name = "Thrall", isPlayer = true, level = 60, race = "Orc",
        className = "Shaman", classFile = "SHAMAN", iconPath = "Interface\\Icons\\Spell_Nature_BloodLust",
        quests = {} })
    local anchor = CreateFrame("Frame", nil, UIParent)
    local function drawn()
        local panel = ns.ui.renderPreview(anchor, model, UNIT)
        local info, targetLabel, targetValue
        for _, font in ipairs(panel.pool) do
            if font._shown then
                if (font._text or ""):find("Orc Shaman", 1, true) then info = font._text end
                local text = ns.util.plainText(font._text or "")
                if text == "Target" then targetLabel = text end
                if text == "-" then targetValue = text end
            end
        end
        return { plate = panel.badge._shown and panel.badgeText._text or false, info = info,
            target = { targetLabel, targetValue } }
    end

    test.check("the level is on the plate and a player always has a target row",
        drawn(), { plate = "60", info = "Orc Shaman", target = { "Target", "-" } })
    ns.setOption("unitLevelBadge", false)
    test.check("with the plate off, the info line has it", drawn(), { plate = false, info = "Level 60 Orc Shaman" })
    ns.setOption("unitLevelBadge", true)
    ns.setOption("iconUnits", false)
    test.check("without a portrait, the info line has it", drawn(), { plate = false, info = "Level 60 Orc Shaman" })
    ns.setOption("iconUnits", true)
    model.level = -1
    test.check("a skull level shows as ??", drawn().plate, "??")
end
