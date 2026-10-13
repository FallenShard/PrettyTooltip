-- An item that begins a quest says so first, under the header in quest gold,
-- rather than among other addons' rows.
return function(test)
    local capture = {
        enums = { TooltipDataType = { Item = 0 }, TooltipDataLineType = { None = 0, ItemName = 1, ItemBinding = 2 } },
        data = { type = 0, id = 1307, quality = 1, lines = {
            { type = 1, lineIndex = 1, leftText = "Gold Pickup Schedule" },
            { type = 2, lineIndex = 2, leftText = "Soulbound" },
            { type = 0, lineIndex = 3, leftText = "This Item Begins a Quest" },
            { type = 0, lineIndex = 4, leftText = '"A schedule of gold pickups."' },
        } },
        lines = { { left = { text = "Gold Pickup Schedule" } }, { left = { text = "Soulbound" } },
            { left = { text = "This Item Begins a Quest" } }, { left = { text = '"A schedule of gold pickups."' } } },
    }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua" }, capture)
    local model = ns.TooltipTypes[0].read(world.main, capture.data, ns.Game)
    test.check("it is read as beginning a quest", { model.startsQuest, model.quest }, { "This Item Begins a Quest", true })
    test.check("and kept out of the extras", #model.extras, 0)

    local panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), model, 0)
    local rows = {}
    for _, font in ipairs(panel.pool) do
        if font._shown and font._text and font._text ~= "" then
            local _, _, _, _, y = font:GetPoint(1)
            rows[#rows + 1] = { text = ns.util.trim(ns.util.plainText(font._text)), y = -y, color = font._color }
        end
    end
    table.sort(rows, function(a, b) return a.y < b.y end)
    local order = {}
    for index, row in ipairs(rows) do order[index] = row.text end
    test.check("first under the header", order,
        { "GOLD PICKUP SCHEDULE", "Soulbound", "This Item Begins a Quest", '"A schedule of gold pickups."' })
    test.check("in quest gold", { rows[3].color[1], rows[3].color[2], rows[3].color[3] }, { 1, .82, 0 })
    local marked = false
    for _, font in ipairs(panel.pool) do
        if font._shown and (font._text or ""):find("AvailableQuestIcon", 1, true) then marked = true end
    end
    test.check("with the quest giver's mark", marked, true)
end
