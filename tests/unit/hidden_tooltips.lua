-- Other addons read items through tooltips of their own that never show: Pawn fills PawnPrivateTooltip1 with
-- SetHyperlink dozens of times in every 0.2 s refresh of a bag item's tooltip. The item post-call reaches
-- each fill, but no panel is built for a tooltip that isn't shown and anchored. One that is, as an addon's
-- window shows one, is read and drawn a frame later, and at once after that.
return function(test)
    local item = { type = 0, id = 1, lines = { { lineIndex = 1, leftText = "Ring" } } }
    local other = { type = 0, id = 2, lines = { { lineIndex = 1, leftText = "Other ring" } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Core/TooltipPlacement.lua", "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Panel/Layout.lua", "Panel/Render.lua", "Integration/Native.lua",
        "Integration/Placement.lua", "Integration/Hooks.lua" }, {
        enums = { TooltipDataType = { Item = 0 } }, data = item,
        lines = { { left = { text = "Ring" } } },
    })
    local pending = {}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    local reads, renders = 0, 0
    ns.TooltipTypes[0] = {
        option = "itemPanels", key = function(_, data) return data.id end,
        read = function(native, data)
            reads = reads + 1
            return { rows = native:NumLines(), id = data.id }
        end,
        render = function(panel, _, model)
            renders = renders + 1
            panel.renderedID = model.id
            panel:SetSize(200, 50)
            panel:Show()
        end,
    }
    ns.Hooks.install()
    local postCall = world.postCalls[0][1]
    local function fill(tooltip, data)
        tooltip._lines, tooltip._left, tooltip._right = {}, {}, {}
        tooltip:AddLine("Ring", 1, 1, 1)
        tooltip._data = data
        postCall(tooltip, data)
    end
    local function skipped(name) return (ns.skippedTooltips or {})[name] end

    -- The game's own tooltip is read and drawn in the frame it is filled.
    fill(world.main, item)
    test.check("the game's own tooltip is read and drawn at once", { reads, renders }, { 1, 1 })
    flush()
    local baseReads, baseRenders = reads, renders

    -- Pawn's: filled sixty times in a frame, never shown.
    local scanner = CreateFrame("GameTooltip", "PawnPrivateTooltip1", UIParent, "GameTooltipTemplate")
    local queued = #pending
    for _ = 1, 60 do fill(scanner, item) end
    test.check("sixty fills of a tooltip that is never shown read and draw nothing",
        { reads - baseReads, renders - baseRenders }, { 0, 0 })
    test.check("they queue one check, not sixty", #pending - queued, 1)
    flush()
    test.check("the hidden tooltip still has no panel", ns.ui.panels[scanner], nil)
    test.check("and is counted as skipped, once", skipped("PawnPrivateTooltip1"), 1)

    -- Shown, but with no anchor point: still a tooltip nobody looks at.
    local unanchored = CreateFrame("GameTooltip", "UnanchoredScanTooltip", UIParent, "GameTooltipTemplate")
    unanchored:Show()
    fill(unanchored, item)
    flush()
    test.check("a shown tooltip with no anchor point has no panel", ns.ui.panels[unanchored], nil)
    test.check("and is counted as skipped", skipped("UnanchoredScanTooltip"), 1)
    test.check("nothing was read or drawn for either", { reads - baseReads, renders - baseRenders }, { 0, 0 })

    -- Shown and anchored, as an addon's own window shows one.
    local window = CreateFrame("GameTooltip", "AddonWindowTooltip", UIParent, "GameTooltipTemplate")
    window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -10)
    window:Show()
    fill(window, item)
    test.check("a shown, anchored tooltip of another addon waits a frame", reads - baseReads, 0)
    flush()
    test.check("then it is read and drawn", { reads - baseReads, renders - baseRenders }, { 1, 1 })
    test.check("and has its panel", ns.ui.panels[window] ~= nil, true)
    test.check("and is not counted as skipped", skipped("AddonWindowTooltip"), nil)
    fill(window, other)
    test.check("after that its fills are handled at once", { reads - baseReads, renders - baseRenders }, { 2, 2 })
end
