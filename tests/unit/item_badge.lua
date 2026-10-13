-- The item level plate stays as wide as the icon's border; a larger plate
-- text grows the icon instead.
return function(test)
    local capture = {
        enums = { TooltipDataType = { Item = 0 }, TooltipDataLineType = { None = 0, ItemName = 1, EquipSlot = 2 } },
        calls = {
            ["C_Item.GetDetailedItemLevelInfo"] = { ["6953"] = { n = 1, 63 } },
            ["C_Item.GetItemIconByID"] = { ["6953"] = { n = 1, 133042 } },
        },
        data = { type = 0, id = 6953, quality = 3, lines = {
            { type = 1, lineIndex = 1, leftText = "Test Mace" },
            { type = 2, lineIndex = 2, leftText = "Two-Hand", rightText = "Mace" },
        } },
        lines = { { left = { text = "Test Mace" } }, { left = { text = "Two-Hand" }, right = { text = "Mace" } } },
    }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Data/Stats.lua", "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua" }, capture)
    local model = ns.TooltipTypes[0].read(world.main, capture.data, ns.Game)
    test.check("the item has a level to show", model.level, 63)
    local anchor = CreateFrame("Frame", nil, UIParent)
    local function sizes()
        local panel = ns.ui.renderPreview(anchor, model, 0)
        return { icon = panel.icon._width, border = panel.iconBorder._width, plate = panel.badge._width,
            shown = panel.badge._shown }
    end
    local default = sizes()
    test.check("the default icon keeps its size", default.icon, 43)
    test.check("the default plate is the border's width", default.plate, default.border)

    ns.setElementSetting("badge", "size", 16)
    local grown = sizes()
    test.check("a larger plate text grows the icon", grown.icon > default.icon, true)
    test.check("the grown plate is still the border's width", grown.plate, grown.border)

    ns.setOption("itemLevelBadge", false)
    local hidden = sizes()
    test.check("without the plate the icon keeps its size", hidden.icon, 43)
    test.check("without the plate it is hidden", hidden.shown, false)
end
