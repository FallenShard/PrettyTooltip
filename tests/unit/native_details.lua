-- The game's own tooltip gets the panel's details while their key is held: in
-- the Blizzard layout and for a type not restyled, never under a panel or with
-- the original-tooltip key held. A key change refills it, but not in combat.
return function(test)
    local capture = {
        enums = { TooltipDataType = { Item = 0 }, TooltipDataLineType = { None = 0, ItemName = 1, ItemBinding = 2 } },
        data = { type = 0, id = 1307, quality = 1, lines = {
            { type = 1, lineIndex = 1, leftText = "Gold Pickup Schedule" },
            { type = 2, lineIndex = 2, leftText = "Soulbound" },
        } },
        lines = { { left = { text = "Gold Pickup Schedule" } }, { left = { text = "Soulbound" } } },
    }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua", "Integration/Details.lua" }, capture)
    ns.Details.register()
    local tooltip = world.main
    local function added()
        local before = tooltip:NumLines()
        world.postCalls[0][1](tooltip, capture.data)
        return tooltip:NumLines() - before
    end
    local function lastLine() return tooltip:GetLeftLine(tooltip:NumLines()):GetText() end

    test.check("under a panel the game's tooltip is left alone", added(), 0)
    ns.setOption("layout", "blizzard")
    test.check("the Blizzard layout appends a spacer and the ID", { added(), lastLine() }, { 2, "Item ID: 1307" })
    capture.shiftUp = true
    test.check("without Shift nothing is appended", added(), 0)
    capture.shiftUp = nil
    IsAltKeyDown = function() return true end
    test.check("the original-tooltip key keeps the game's tooltip as it was", added(), 0)
    IsAltKeyDown = function() return false end
    ns.setOption("layout", "pretty")
    ns.setOption("itemPanels", false)
    test.check("a type not restyled gets them too", added(), 2)
    -- Comparisons are cleared, then filled with append.
    tooltip.GetProcessingTooltipInfo = function() return { append = true } end
    test.check("a tooltip filled with append gets them", added(), 2)

    local refills = 0
    tooltip.RefreshData = function() refills = refills + 1 end
    tooltip:Show()
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
    test.check("the details key refills the tooltip", refills, 1)
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 1)
    test.check("so does the original-tooltip key", refills, 2)
    world.fireEvent("MODIFIER_STATE_CHANGED", "LCTRL", 1)
    test.check("other keys do not", refills, 2)
    InCombatLockdown = function() return true end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    test.check("in combat the details wait for the next tooltip", refills, 2)
    InCombatLockdown = function() return false end
    ns.setOption("itemPanels", true)
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
    test.check("a tooltip under a panel is not refilled", refills, 2)
    ns.setOption("itemPanels", false)
    local comparison = CreateFrame("GameTooltip", "ShoppingTooltip1", UIParent)
    comparison.GetTooltipData = tooltip.GetTooltipData
    comparison.IsTooltipType = function() return true end
    comparison.RefreshData = function() refills = refills + 10 end
    world.postCalls[0][1](comparison, capture.data)
    comparison:Show()
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    test.check("a comparison is not refilled, only what it compares against", refills, 3)

    PrettyTooltipDB = { itemLite = true }
    ns.migrateOptions()
    test.check("1.3's lite mode becomes items not restyled", { PrettyTooltipDB.itemPanels, PrettyTooltipDB.itemLite },
        { false, nil })
    PrettyTooltipDB = { itemLite = false }
    ns.migrateOptions()
    test.check("lite mode off leaves items restyled", { PrettyTooltipDB.itemPanels, PrettyTooltipDB.itemLite }, { nil, nil })
end
