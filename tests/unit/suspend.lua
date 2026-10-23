-- /ptip perf ab and /ptip bench measure the game's tooltips with PrettyTooltip
-- suspended: panels give the game's tooltip back, every stage and key handler
-- is idle, details and follow cursor stop, and resuming draws the tooltip's
-- current data again.
return function(test)
    local capture = {
        enums = { TooltipDataType = { Item = 0 }, TooltipDataLineType = { None = 0, ItemName = 1, ItemBinding = 2 } },
        data = { type = 0, id = 1307, quality = 1, lines = {
            { type = 1, lineIndex = 1, leftText = "Gold Pickup Schedule" },
            { type = 2, lineIndex = 2, leftText = "Soulbound" },
        } },
        lines = { { left = { text = "Gold Pickup Schedule" } }, { left = { text = "Soulbound" } } },
    }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua", "Integration/Native.lua",
        "Integration/Placement.lua", "Integration/Hooks.lua", "Integration/Details.lua", "Integration/Cursor.lua" }, capture)
    local pending = {}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    local kind = ns.TooltipTypes[0]
    local reads, renders = 0, 0
    local read, render = kind.read, kind.render
    kind.read = function(...) reads = reads + 1; return read(...) end
    kind.render = function(...) renders = renders + 1; return render(...) end
    local before = {}
    for _, object in ipairs(world.objects) do before[object] = true end
    ns.Hooks.install()
    ns.Details.register()
    ns.Cursor.register()
    local follower
    for _, object in ipairs(world.objects) do
        if not before[object] and object._scripts and object._scripts.OnUpdate and object:GetParent() == UIParent then
            follower = object
        end
    end
    local keys = 0
    ns.Processor.onKey("cursor", function() keys = keys + 1 end)

    local tooltip = world.main
    tooltip._room = { padding = { 0, 0, 0, 0 }, minWidth = 0 }
    tooltip.GetPadding = function(self) return unpack(self._room.padding) end
    tooltip.SetPadding = function(self, ...) self._room.padding = { ... } end
    tooltip.GetMinimumWidth = function(self) return self._room.minWidth end
    tooltip.SetMinimumWidth = function(self, width) self._room.minWidth = width end
    tooltip:SetSize(300, 100)
    tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -100, 100)
    tooltip:Show()
    local function fill()
        local cleared = tooltip:GetScript("OnTooltipCleared")
        if cleared then cleared(tooltip) end
        world.postCalls[0][1](tooltip, capture.data)
        tooltip:Show()
        flush()
    end
    local function details()
        for _, child in ipairs(tooltip._children) do
            if child._kind == "Frame" and child._shown then
                for _, font in ipairs(child._children) do
                    if font._kind == "FontString" and font._shown then return font._text end
                end
            end
        end
    end

    fill()
    local panel = ns.ui.panels[tooltip]
    test.check("a Pretty panel covers the game's tooltip", { panel:IsShown(), tooltip:GetAlpha(), reads, renders },
        { true, 0, 1, 1 })
    ns.Hooks.setSuspended(true)
    test.check("suspending gives the game's tooltip back", { panel:IsShown(), tooltip:GetAlpha(),
        ns.restyles("itemPanels"), ns.suspended }, { false, 1, false, true })
    fill()
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    test.check("while suspended no stage, key handler, or hook draws",
        { reads, renders, keys, panel:IsShown(), tooltip:GetAlpha(), #pending, details() }, { 1, 1, 0, false, 1, 0, nil })
    ns.Hooks.setSuspended(false)
    flush()
    test.check("resuming draws the tooltip's current data at once",
        { reads, renders, panel:IsShown(), tooltip:GetAlpha(), ns.suspended }, { 2, 2, true, 0, nil })
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
    test.check("key handlers run again once resumed", keys, 1)

    -- The Blizzard layout puts the details under the game's own lines.
    ns.setOption("layout", "blizzard")
    fill()
    test.check("details show on the game's tooltip", details(), "Item ID: 1307")
    ns.Hooks.setSuspended(true)
    tooltip:Show()
    test.check("suspending takes the details' room back at the next show",
        { details(), tooltip._room.padding[2] }, { nil, 0 })
    fill()
    test.check("refills while suspended add no details", details(), nil)
    ns.Hooks.setSuspended(false)
    fill()
    test.check("details return once resumed", details(), "Item ID: 1307")

    -- Follow cursor lets go of the tooltip while suspended.
    ns.setOption("layout", "pretty")
    ns.setOption("cursorItems", true)
    GameTooltip_SetDefaultAnchor(tooltip, UIParent)
    fill()
    test.check("the tooltip follows the cursor", follower:IsShown(), true)
    ns.Hooks.setSuspended(true)
    follower:GetScript("OnUpdate")(follower, 0)
    test.check("suspending stops follow cursor and restores the anchor",
        { follower:IsShown(), select(2, tooltip:GetPoint(1)) == UIParent }, { false, true })
    ns.Hooks.setSuspended(false)
end
