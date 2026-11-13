-- A herb or ore node's skill row takes the game's color, as Forever's bands
-- are not Classic's (#50: Kingsblood yellow at 175, Goldthorn at 226); the
-- shared bands stand in when the game gives none.
return function(test)
    local OBJECT = 4
    local capture = {
        enums = { TooltipDataType = { Item = 0, Object = OBJECT } },
        calls = {
            GetNumSkillLines = { [""] = { 2, n = 1 } },
            GetSkillLineInfo = { ["1"] = { "Herbalism", false, false, 226, n = 4 },
                ["2"] = { "Mining", false, false, 130, n = 4 } },
        },
    }
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Data/NodeSkills.lua", "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Object.lua" }, capture)
    local function rowColor(fields)
        fields.details, fields.quests, fields.extras = {}, {}, {}
        local panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), ns.ui.objectModel(fields), OBJECT)
        for _, font in ipairs(panel.pool) do
            if font._shown and font._text and font._text:find("^Requires ") then
                local c = font._color
                return { tonumber(string.format("%.2f", c[1])), tonumber(string.format("%.2f", c[2])),
                    tonumber(string.format("%.2f", c[3])) }
            end
        end
    end
    test.check("Goldthorn at 226, 56 past 170, in the game's yellow",
        rowColor({ name = "Goldthorn", skill = "Herbalism", skillColor = { 1, 1, 0 } }), { 1, 1, 0 })
    test.check("an Iron Deposit at 130 without the game's color: the bands' orange",
        rowColor({ name = "Iron Deposit", skill = "Mining" }), { 1, .5, .25 })
end
