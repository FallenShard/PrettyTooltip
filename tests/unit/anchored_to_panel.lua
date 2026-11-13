-- Another addon's tooltip anchored to GameTooltip's edge goes by GameTooltip's
-- panel, which is wider than the game's tooltip under it: ForeverDungeonJournal
-- puts its comparisons 6 to the right of GameTooltip's TOPRIGHT.
return function(test)
    local data = { type = 0, id = 1, lines = { { lineIndex = 1, leftText = "Spaulders" } } }
    local lines = { { left = { text = "Spaulders" } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Core/TooltipPlacement.lua", "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Panel/Layout.lua", "Panel/Render.lua", "Integration/Native.lua",
        "Integration/Placement.lua", "Integration/Hooks.lua" }, {
        enums = { TooltipDataType = { Item = 0 } }, data = data, lines = lines,
        comparisons = { { tooltip = "ForeverDungeonJournalCompareTooltip1", data = data, lines = lines } },
    })
    local pending = {}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    UIParent:SetSize(1200, 800)
    -- Screen rectangles from the frames' anchors, as the game resolves them.
    local function rectangle(frame)
        local width, height = frame:GetWidth(), frame:GetHeight()
        if frame == UIParent then return 0, 800, 1200, 800 end
        local point = frame._points[1]
        if not point then return end
        local x, y, w, h = rectangle(point[2] or UIParent)
        if not x then return end
        local rx = point[3]:find("LEFT") and 0 or point[3]:find("RIGHT") and 1 or .5
        local ry = point[3]:find("BOTTOM") and 0 or point[3]:find("TOP") and 1 or .5
        local px = point[1]:find("LEFT") and 0 or point[1]:find("RIGHT") and 1 or .5
        local py = point[1]:find("BOTTOM") and 0 or point[1]:find("TOP") and 1 or .5
        local left = x + rx * w + point[4] - px * width
        local top = y - (1 - ry) * h + point[5] + (1 - py) * height
        return left, top, width, height
    end
    for _, object in ipairs(world.objects) do
        object.GetScaledRect = function(self)
            local x, y, w, h = rectangle(self)
            if x then return x, y - h, w, h end
        end
    end
    ns.TooltipTypes[0] = {
        option = "itemPanels", key = function(native) return native end,
        read = function(_, item) return { id = item.id } end,
        render = function(panel, native)
            panel:SetSize(native == GameTooltip and 312 or 296, 300)
            ns.ui.alignPanel(panel, native)
            panel:Show()
        end,
    }
    ns.Hooks.install()
    local main, compare = GameTooltip, _G["ForeverDungeonJournalCompareTooltip1"]
    main:SetSize(257, 280)
    main:ClearAllPoints()
    main:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 300, 300)
    world.postCalls[0][1](main, data)
    flush()
    compare:SetSize(251, 280)
    compare:ClearAllPoints()
    compare:SetPoint("TOPLEFT", main, "TOPRIGHT", 6, 0)
    world.postCalls[0][1](compare, data)
    flush()
    local mainLeft, mainTop, mainWidth = rectangle(ns.ui.panels[main])
    local left, top = rectangle(ns.ui.panels[compare])
    test.check("the comparison starts 6 right of the panel, not of the narrower tooltip",
        { left - (mainLeft + mainWidth), top - mainTop }, { 6, 0 })
end
