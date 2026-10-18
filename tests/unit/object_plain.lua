-- An object that is only its name, as a mailbox, is as wide as its name, and
-- as far from the panel's bottom as from its top.
return function(test)
    local OBJECT = 4
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Object.lua" },
        { enums = { TooltipDataType = { Item = 0, Object = OBJECT } } })
    local model = ns.ui.objectModel({ name = "Mailbox", details = {}, quests = {}, extras = {} })
    local anchor = CreateFrame("Frame", nil, UIParent)
    -- The title's inset, and its room above and below.
    local function drawn()
        local panel = ns.ui.renderPreview(anchor, model, OBJECT)
        local title
        for _, font in ipairs(panel.pool) do
            if font._shown and font._text == "MAILBOX" then title = font end
        end
        local _, _, _, x, y = title:GetPoint(1)
        return panel, x, -y, panel:GetHeight() - (-y + title:GetStringHeight())
    end
    local panel, x, top, bottom = drawn()
    test.check("as wide as its name", panel:GetWidth() < ns.ui.minWidth(), true)
    test.check("its name as far from the bottom as the top", bottom, top)
    test.check("its name at the usual inset", x, 19)

    ns.setOption("padding", 12)
    panel, x, top, bottom = drawn()
    test.check("the padding moves the inset and the room above and below", { x, top, bottom }, { 12, 14, 14 })
    local wide = panel:GetWidth()
    ns.setOption("padding", nil)
    test.check("and the width with it", drawn():GetWidth() - wide, 14)
end
