-- A hearthstone names where it returns you, the player's bind location; that
-- place is drawn in the place color, and only that place.
return function(test)
    local USE = "Use: Returns you to Stormwind City.  Speak to an Innkeeper in a different place to change your home location."
    local function load(home)
        local capture = {
            enums = { TooltipDataType = { Item = 0 }, TooltipDataLineType = { None = 0, ItemName = 1, ItemBinding = 2 } },
            calls = { GetBindLocation = { [""] = { n = 1, home } } },
            data = { type = 0, id = 6948, quality = 1, lines = {
                { type = 1, lineIndex = 1, leftText = "Hearthstone" },
                { type = 2, lineIndex = 2, leftText = "Soulbound" },
                { type = 0, lineIndex = 3, leftText = USE },
            } },
            lines = { { left = { text = "Hearthstone" } }, { left = { text = "Soulbound" } }, { left = { text = USE } } },
        }
        local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
            "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
            "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua",
            "Integration/Native.lua", "Integration/Placement.lua" }, capture)
        local model = ns.TooltipTypes[0].read(world.main, capture.data, ns.Game)
        local panel = ns.ui.getPanel(world.main)
        ns.TooltipTypes[0].render(panel, world.main, model)
        for _, font in ipairs(panel.pool) do
            if font._shown and type(font._text) == "string" and font._text:find("Innkeeper", 1, true) then
                return model, font._text, ns
            end
        end
        return model, nil, ns
    end

    local model, text, ns = load("Stormwind City")
    local code = "|cff" .. ns.util.hex(ns.Palette.roles.place)
    test.check("the use effect knows the home it names", model.effects[1].place, "Stormwind City")
    test.check("the home is drawn in the place color, the rest as it was",
        text, "Returns you to " .. code .. "Stormwind City|r.  Speak to an Innkeeper in a different place to change your home location.")

    model, text = load("Ironforge")
    test.check("an effect that names another place is left alone",
        { model.effects[1].place, text }, { nil, "Returns you to Stormwind City.  Speak to an Innkeeper in a different place to change your home location." })
end
