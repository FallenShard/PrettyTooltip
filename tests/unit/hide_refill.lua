-- DialogueUI's reward buttons hide GameTooltip before every .2 s refill, and
-- EllesmereUI appends its rows after the item post-call. The frame drawn after
-- each refill must show the completed panel, not one without those rows.
return function(test)
    local data = { type = 0, id = 1, lines = { { lineIndex = 1, leftText = "Reward" } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Integration/Native.lua", "Integration/Placement.lua",
        "Integration/Hooks.lua" }, { enums = { TooltipDataType = { Item = 0 } }, data = data,
            lines = { { left = { text = "Reward" } } } })
    local pending = {}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    local tooltip = world.main
    local icon = world.new("Frame", nil, UIParent)
    local renders = 0
    ns.TooltipTypes[0] = {
        option = "itemPanels", key = function(_, item) return item.id end,
        read = function(native, item) return { id = item.id, rows = native:NumLines() } end,
        render = function(panel, _, model)
            renders = renders + 1
            panel:SetSize(200, model.rows * 50)
            panel.renderedID = model.id
            panel:Show()
        end,
    }
    ns.Hooks.install()
    local post = world.postCalls[0][1]
    local base = { tooltip._lines[1], tooltip._left[1], tooltip._right[1] }
    -- The scripts exist once the first handover installs the hooks.
    local function fire(script)
        local handler = tooltip:GetScript(script)
        if handler then handler(tooltip) end
    end
    local function hide()
        fire("OnTooltipCleared")
        tooltip:Hide()
        fire("OnHide")
    end
    local function refill()
        hide()
        tooltip:SetOwner(icon, "ANCHOR_NONE")
        tooltip:ClearAllPoints()
        tooltip:SetPoint("BOTTOMLEFT", icon, "TOPRIGHT", 0, 2)
        tooltip._lines, tooltip._left, tooltip._right = { base[1] }, { base[2] }, { base[3] }
        post(tooltip, data)
        tooltip:AddLine("Another addon's row", 1, 1, 1)
        tooltip:Show()
    end
    refill()
    flush()
    local panel = ns.ui.panels[tooltip]
    test.check("the first hover completes with the appended row", { panel:GetHeight(), renders }, { 100, 2 })
    local drawn = {}
    for _ = 1, 5 do
        refill()
        drawn[#drawn + 1] = panel:IsShown() and panel:GetHeight() or 0
        flush()
    end
    test.check("each hide-and-refill draws the completed panel", drawn, { 100, 100, 100, 100, 100 })
    test.check("unchanged refills are not read again", renders, 2)
    test.check("the native tooltip stays hidden under the panel", tooltip:GetAlpha(), 0)

    -- A different item after the hide is drawn at once, as any new tooltip.
    data.id = 2
    refill()
    test.check("a new item after a hide renders immediately", panel.renderedID, 2)
    flush()

    -- Hidden in an earlier frame, the same item is a new tooltip again.
    hide()
    flush()
    test.check("a hide that lasts a frame restores the native tooltip", { panel:IsShown(), tooltip:GetAlpha() }, { false, 1 })
    local before = renders
    refill()
    test.check("the same item shown again later renders afresh", renders, before + 1)
end
