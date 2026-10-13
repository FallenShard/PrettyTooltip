-- A herb or ore node lists what it holds, and the option hides it.
return function(test)
    local OBJECT = 4
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Data/Nodes.lua", "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Object.lua" },
        { enums = { TooltipDataType = { Item = 0, Object = OBJECT } } })
    local model = ns.ui.objectModel({ name = "Copper Vein", skill = "Mining", details = {}, quests = {}, extras = {} })
    local function shown()
        local panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), model, OBJECT)
        local texts = {}
        for _, font in ipairs(panel.pool) do
            if font._shown and font._text and font._text ~= "" then texts[#texts + 1] = ns.util.plainText(font._text) end
        end
        return table.concat(texts, " | ")
    end
    test.check("the yield over all taps, then the chance of the rest", { model.loot[1].right, model.loot[2].right },
        { "2 to 4", "44%" })
    test.check("shown by default", shown():find("Rough Stone", 1, true) ~= nil, true)
    ns.setOption("gatheringLoot", false)
    test.check("hidden when turned off", shown():find("Rough Stone", 1, true) ~= nil, false)
end
