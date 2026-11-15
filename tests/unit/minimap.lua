-- The minimap's tooltip shows the game's text as it wrote it: readable, a row
-- a blip; secret, as Forever keeps it, unread at the game's own tooltip size.
return function(test)
    local MINIMAP = 21
    local ARROW = "|TInterface\\Minimap\\Minimap-PositionArrows:0:0:0:0:16:32:0:16:0:16|t"
    local text = "Peacebloom\n" .. ARROW .. "Copper Vein\n|cffb0b0b0Thrall|r"
    local function load(leftText, extra)
        local lines = { { type = 0, lineIndex = 1, leftText = leftText } }
        local shown = { { left = { text = leftText } } }
        if extra then
            lines[2] = { type = 0, lineIndex = 2, leftText = extra }
            shown[2] = { left = { text = extra } }
        end
        local capture = {
            enums = { TooltipDataType = { Item = 0, Object = 4, MinimapMouseover = MINIMAP } },
            data = { type = MINIMAP, lines = lines },
            lines = shown,
        }
        local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
            "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
            "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Minimap.lua" }, capture)
        return ns, world, capture
    end

    local ns, world, capture = load(text)
    local model = ns.TooltipTypes[MINIMAP].read(world.main, capture.data, ns.Game)
    test.check("a readable line is a row a blip, as the game wrote it", model.lines,
        { "Peacebloom", ARROW .. "Copper Vein", "|cffb0b0b0Thrall|r" })
    local panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), model, MINIMAP)
    local shown = {}
    for _, font in ipairs(panel.pool) do
        if font._shown and font._text and font._text ~= "" then shown[#shown + 1] = ns.util.plainText(font._text) end
    end
    test.check("no skill, class color or arrow of its own", shown, { "Peacebloom", "Copper Vein", "Thrall" })

    local secret = { __secret = true }
    ns, world, capture = load(secret)
    world.main:SetWidth(66)
    world.main:SetHeight(33)
    model = ns.TooltipTypes[MINIMAP].read(world.main, capture.data, ns.Game)
    test.check("a secret line is kept unread", issecretvalue(model.hidden), true)
    test.check("in the room the game's tooltip gives it", { model.block.width, model.block.height, model.block.size },
        { 46, 13, 12 })
    panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), model, MINIMAP)
    local hidden = panel.hiddenPool and panel.hiddenPool[1]
    test.check("drawn unread, every line of it", { hidden and hidden._shown, hidden and issecretvalue(hidden._text),
        hidden and hidden:CanWordWrap(), hidden and hidden:GetMaxLines() }, { true, true, true, 0 })
    test.check("as wide as the game's text, with the panel's padding",
        panel.width, ns.ui.snap(panel, 46 + 4 + 2 * ns.ui.pad()))

    ns, world, capture = load(secret, "Another addon's line")
    world.main:SetWidth(66)
    world.main:SetHeight(33)
    test.check("a secret line beside others leaves the game's tooltip",
        ns.TooltipTypes[MINIMAP].read(world.main, capture.data, ns.Game), nil)
    ns, world, capture = load(secret)
    test.check("and so does one the game's tooltip has no size for",
        ns.TooltipTypes[MINIMAP].read(world.main, capture.data, ns.Game), nil)
end
