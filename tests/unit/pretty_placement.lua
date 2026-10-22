-- Exercise Pretty-owned placement through the live hook boundaries, with a
-- dynamic anchor resolver rather than the harness's fixed frame coordinates.
return function(test)
    local data = { type = 0, id = 1, lines = { { lineIndex = 1, leftText = "Ring" } } }
    local lines = { { left = { text = "Ring" } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Core/TooltipPlacement.lua", "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Panel/Layout.lua", "Panel/Render.lua", "Integration/Native.lua",
        "Integration/Placement.lua", "Integration/Hooks.lua" }, {
        enums = { TooltipDataType = { Item = 0, Spell = 1 } }, tooltip = "ItemRefTooltip", data = data, lines = lines,
        comparisons = {
            { tooltip = "ItemRefShoppingTooltip1", data = data, lines = lines },
            { tooltip = "ItemRefShoppingTooltip2", data = data, lines = lines },
        },
    })
    local pending = {}
    C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function flush()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end

    UIParent:SetSize(1200, 800)
    local function fractions(point)
        return point:find("LEFT") and 0 or point:find("RIGHT") and 1 or .5,
            point:find("BOTTOM") and 0 or point:find("TOP") and 1 or .5
    end
    -- Resolve geometry in screen pixels. Public Get* coordinates remain in
    -- each frame's own effective-scale units, like the game's API.
    local function rectangle(frame, visiting)
        local factor = frame:GetEffectiveScale()
        local width, height = frame:GetWidth() * factor, frame:GetHeight() * factor
        if frame == UIParent then return 0, height, width, height end
        if frame:GetNumPoints() == 0 then return end
        visiting = visiting or {}
        if visiting[frame] then error("cyclic test anchors") end
        visiting[frame] = true
        local horizontal, vertical = frame._points[1], frame._points[1]
        for _, point in ipairs(frame._points) do
            if point[1]:find("LEFT") or point[1]:find("RIGHT") then horizontal = point end
            if point[1]:find("TOP") or point[1]:find("BOTTOM") then vertical = point end
        end
        local function anchor(point)
            local x, y, w, h = rectangle(point[2] or UIParent, visiting)
            if not x then return end
            local fx, fy = fractions(point[3])
            return x + fx * w + point[4] * factor, y - (1 - fy) * h + point[5] * factor
        end
        local x = anchor(horizontal)
        local _, y = anchor(vertical)
        visiting[frame] = nil
        if not x or not y then return end
        local fx = fractions(horizontal[1])
        local _, fy = fractions(vertical[1])
        return x - fx * width, y + (1 - fy) * height, width, height
    end
    local function geometry(frame)
        if frame._dynamicGeometry then return end
        frame._dynamicGeometry = true
        frame.GetLeft = function(self)
            local x = rectangle(self)
            return x and x / self:GetEffectiveScale()
        end
        frame.GetTop = function(self)
            local x, y = rectangle(self)
            return x and y / self:GetEffectiveScale()
        end
        frame.GetRight = function(self)
            local x, _, w = rectangle(self)
            return x and (x + w) / self:GetEffectiveScale()
        end
        frame.GetBottom = function(self)
            local x, y, _, h = rectangle(self)
            return x and (y - h) / self:GetEffectiveScale()
        end
        -- SetPoint replaces an existing constraint with the same point.
        local setPoint = frame.SetPoint
        frame.SetPoint = function(self, point, ...)
            for index = #self._points, 1, -1 do
                if self._points[index][1] == point then table.remove(self._points, index) end
            end
            return setPoint(self, point, ...)
        end
    end
    for _, object in ipairs(world.objects) do geometry(object) end
    local owner, primary, secondary = ItemRefTooltip, ItemRefShoppingTooltip1, ItemRefShoppingTooltip2
    local cursorX, cursorY = 500, 480
    GetCursorPosition = function() return cursorX, cursorY end
    -- Blizzard's native drag scripts run before our HookScript callbacks.
    -- StartMoving changes anchor representation while retaining native bounds;
    -- StopMovingOrSizing can change it again without moving the native frame.
    owner:SetScript("OnDragStart", function(self)
        local x, y = rectangle(self)
        local factor = self:GetEffectiveScale()
        self._points = { { "TOPLEFT", UIParent, "BOTTOMLEFT", x / factor, y / factor } }
    end)
    owner:SetScript("OnDragStop", function(self)
        local x, y, w, h = rectangle(self)
        local factor = self:GetEffectiveScale()
        self._points = { { "CENTER", UIParent, "BOTTOMLEFT", (x + w / 2) / factor, (y - h / 2) / factor } }
    end)
    owner.shoppingTooltips = { primary, secondary }
    local paddingWrites, renders, reads = 0, 0, 0
    for _, tooltip in ipairs({ owner, primary, secondary }) do
        tooltip:SetSize(100, 40)
        tooltip.GetPadding = function() return 0, 0, 0, 0 end
        tooltip.SetPadding = function() paddingWrites = paddingWrites + 1 end
        tooltip.SetOwner = function(self)
            self:ClearAllPoints()
            local cleared = self:GetScript("OnTooltipCleared")
            if cleared then cleared(self) end
            if self._ownerPoint then self._points = { self._ownerPoint } end
        end
    end
    owner:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 650, 600)
    owner:SetHitRectInsets(2, 3, 4, 5)
    local closed = 0
    local close = CreateFrame("Button", "ItemRefCloseButton", owner)
    geometry(close)
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -2, -2)
    close.Click = function()
        closed = closed + 1
        owner:Hide()
        owner:GetScript("OnHide")(owner)
    end
    owner.SetAnchorType = function(self)
        if self._anchorTypePoint then
            self._points = { self._anchorTypePoint }
            return
        end
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 100, 600)
    end
    owner._prettyWidth, primary._prettyWidth, secondary._prettyWidth = 240, 310, 190
    ns.TooltipTypes[0] = {
        option = "itemPanels", key = function(_, item) return item.id end,
        read = function(tooltip, item)
            reads = reads + 1
            return { rows = tooltip:NumLines(), id = item.id, width = tooltip._prettyWidth }
        end,
        render = function(panel, tooltip, model)
            renders = renders + 1
            geometry(panel)
            -- Comparison-focused geometry checks deliberately hover the main
            -- panel; sticky hover visibility has its own integration suite.
            if tooltip == owner then panel.IsMouseOver = function() return true end end
            ns.ui.drawChrome(panel, tooltip, { tooltipType = "item", color = { 1, 1, 1 } })
            panel:SetSize(model.width, model.rows * 70)
            panel.renderedRows, panel.renderedID = model.rows, model.id
            ns.ui.alignPanel(panel, tooltip)
            panel:Show()
        end,
    }
    ns.TooltipTypes[1] = ns.TooltipTypes[0]
    local tailRows, currentID, slideOwner = 2, 1, true
    local probePartialPoll, partialPollSafe = false, true
    local partialRenders, fullRenders
    TooltipComparisonManager = {
        tooltip = owner,
        SetItemTooltip = function(_, isPrimary)
            local tooltip = isPrimary and primary or secondary
            tooltip._lines, tooltip._left, tooltip._right = {}, {}, {}
            tooltip:AddLine("Ring", 1, 1, 1)
            local cleared = tooltip:GetScript("OnTooltipCleared")
            if cleared then cleared(tooltip) end
            partialRenders = renders
            tooltip._data = { type = 0, id = currentID, lines = data.lines }
            world.postCalls[0][1](tooltip, tooltip._data)
            tooltip:Show()
            fullRenders = renders
            if probePartialPoll then
                local panel = ns.ui.panels[tooltip]
                local beforeReads, beforeCallbacks = reads, #pending
                panel:GetScript("OnUpdate")(panel, .3)
                partialPollSafe = partialPollSafe and reads == beforeReads and #pending == beforeCallbacks
            end
            for index = 1, tailRows do tooltip:AddLine("Delta " .. index, 1, 1, 1) end
            return true
        end,
        AnchorShoppingTooltips = function()
            primary:SetShown(true)
            secondary:SetShown(true)
            if slideOwner then owner:SetAnchorType("ANCHOR_LEFT", -550, 0) end
            primary:SetPoint("TOP", owner, "TOP", 0, 0)
            secondary:SetPoint("TOP", owner, "TOP", 0, 0)
            secondary:SetPoint("LEFT", owner, "RIGHT", 0, 0)
            primary:SetPoint("TOPLEFT", secondary, "TOPRIGHT", 0, 0)
        end,
    }
    local cachedFill, cachedAnchor = TooltipComparisonManager.SetItemTooltip, TooltipComparisonManager.AnchorShoppingTooltips
    ns.Hooks.install()
    world.postCalls[0][1](owner, data)
    owner:Show()
    local main = ns.ui.panels[owner]
    local function refresh(cached)
        for _, tooltip in ipairs({ primary, secondary }) do tooltip:SetOwner(owner, "ANCHOR_NONE") end
        local manager = TooltipComparisonManager
        local fill, anchor = cached and cachedFill or manager.SetItemTooltip, cached and cachedAnchor or manager.AnchorShoppingTooltips
        fill(manager, true)
        fill(manager, false)
        anchor(manager)
    end
    local function bounds(panel)
        local x, y, width, height = rectangle(panel)
        if not x then return end
        return { math.floor(x + .5), math.floor(y + .5), math.floor(width + .5), math.floor(height + .5) }
    end
    refresh()
    local first, second = ns.ui.panels[primary], ns.ui.panels[secondary]
    test.check("Pretty-owned placement is active by default", ns.Placement.enabled, true)
    test.check("partial data/show callbacks never render comparison fragments", fullRenders, partialRenders)
    test.check("completed comparison tails are included before any timer", { first.renderedRows, second.renderedRows }, { 3, 3 })
    test.check("the main tooltip ignores Blizzard's comparison-owner slide", bounds(main), { 650, 600, 240, 70 })
    test.check("Pretty widths determine the side despite opposite native anchors",
        { bounds(first), bounds(second), first.side, second.side },
        { { 340, 600, 310, 210 }, { 150, 600, 190, 210 }, "RIGHT", "RIGHT" })
    test.check("normal content and comparison placement never pad native frames", paddingWrites, 0)
    test.check("native presentation remains transparent", { owner:GetAlpha(), primary:GetAlpha(), secondary:GetAlpha() }, { 0, 0, 0 })
    test.check("the native close button is aligned to Pretty's visible X", select(2, close:GetPoint(1)) == main.close, true)
    local completedRenders = renders
    flush()
    test.check("deferred compatibility work does not rebuild completed content", renders, completedRenders)

    -- Native anchor offsets can round during their C/API round trip. Noise
    -- below a visible pixel must not turn the geometry follower into writes
    -- every frame. The actual anchor tree remains unchanged in this probe.
    local originalMethods, anchorWrites = {}, { 0, 0, 0 }
    for index, panel in ipairs({ main, first, second }) do
        local getPoint, setPoint = panel.GetPoint, panel.SetPoint
        originalMethods[index] = { getPoint, setPoint }
        panel.GetPoint = function(self, pointIndex)
            local point, target, relativePoint, x, y = getPoint(self, pointIndex)
            return point, target, relativePoint, x and x + .00004, y and y - .00003
        end
        panel.SetPoint = function(self, ...)
            anchorWrites[index] = anchorWrites[index] + 1
            return setPoint(self, ...)
        end
    end
    for _ = 1, 80 do ns.Placement.refresh(owner) end
    test.check("subpixel GetPoint readback noise never rewrites stable main or comparison anchors", anchorWrites, { 0, 0, 0 })
    for index, panel in ipairs({ main, first, second }) do
        panel.GetPoint, panel.SetPoint = unpack(originalMethods[index])
    end
    local beforeOffsetOverwrite = bounds(main)
    main._points[1][4] = main._points[1][4] + 2
    ns.Placement.refresh(owner)
    test.check("a meaningful externally overwritten anchor offset is still repaired", bounds(main), beforeOffsetOverwrite)

    local positioned = true
    for _ = 1, 12 do
        refresh()
        for _, panel in ipairs({ main, first, second }) do
            positioned = positioned and panel:IsShown() and panel:GetNumPoints() == 1 and panel:GetLeft() ~= nil
        end
        flush()
    end
    test.check("repeated sticky clears retain completed positions", positioned, true)
    test.check("identical refills reuse completed models", renders, completedRenders)
    test.check("native sliding never replaces the original Pretty source anchor", bounds(main), { 650, 600, 240, 70 })

    probePartialPoll = true
    refresh()
    probePartialPoll = false
    test.check("content polling never schedules a redraw during an incomplete comparison fill", partialPollSafe, true)
    flush()
    local beforeReads = reads
    main.refreshPending = {}
    owner:GetLeftLine(1):SetText("An incomplete main-tooltip rewrite")
    main:GetScript("OnUpdate")(main, .3)
    flush()
    test.check("content polling never reads a main tooltip with a refresh hold", reads, beforeReads)
    main.refreshPending = nil
    owner:GetLeftLine(1):SetText("Ring")

    local oldFirst, oldSecond = bounds(first), bounds(second)
    refresh(true)
    test.check("cached manager callbacks preserve the last completed positions", { bounds(first), bounds(second) }, { oldFirst, oldSecond })
    flush()
    test.check("cached manager callbacks settle through the compatibility completion", { first.comparisonPending == nil,
        second.comparisonPending == nil, bounds(first), bounds(second) }, { true, true, oldFirst, oldSecond })

    tailRows = 0
    refresh()
    test.check("a completed shorter comparison shrinks immediately", { first.renderedRows, bounds(first)[4], bounds(second)[4] }, { 1, 70, 70 })
    -- A source anchor changed outside a comparison transaction is intentional.
    slideOwner = false
    owner:ClearAllPoints()
    owner:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 10, 40)
    refresh()
    test.check("the group clamps as one unit at the lower-left edge",
        { bounds(main), bounds(second), bounds(first) },
        { { 10, 70, 240, 70 }, { 250, 70, 190, 70 }, { 440, 70, 310, 70 } })
    owner:ClearAllPoints()
    owner:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 1190, 900)
    refresh()
    test.check("the group clamps at the upper-right edge without individual overlap",
        { bounds(main), bounds(first), bounds(second) },
        { { 960, 800, 240, 70 }, { 650, 800, 310, 70 }, { 460, 800, 190, 70 } })

    -- Mixed UIParent/native/Pretty scales must still produce abutting edges.
    UIParent:SetScale(.8)
    owner:SetScale(1.25)
    main:SetScale(.75)
    first:SetScale(1.5)
    second:SetScale(.8)
    owner:ClearAllPoints()
    owner:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 650, 600)
    refresh()
    local a, b, c = bounds(main), bounds(first), bounds(second)
    test.check("mixed scales preserve the main source anchor in screen pixels", { a[1], a[2], a[3] }, { 650, 600, 144 })
    test.check("mixed-scale comparison edges meet without gaps", { b[1] + b[3], c[1] + c[3], b[2], c[2] }, { a[1], b[1], a[2], a[2] })
    test.check("mixed-scale group stays within the scaled screen", c[1] >= 0 and a[1] + a[3] <= 960 and a[2] <= 640, true)

    -- A moving relative frame has no SetPoint callback on the tooltip itself.
    local source = CreateFrame("Frame", nil, UIParent)
    geometry(source)
    source:SetSize(10, 10)
    source:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 200, 500)
    owner:ClearAllPoints()
    owner:SetPoint("TOPLEFT", source, "TOPLEFT", 0, 0)
    local follower
    for _, object in ipairs(world.objects) do
        if object ~= main and object ~= first and object ~= second and object:GetScript("OnUpdate") then follower = object end
    end
    local originalX = bounds(main)[1]
    source:ClearAllPoints()
    source:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 250, 500)
    if follower then follower:GetScript("OnUpdate")(follower, .016) end
    test.check("moving the relative source updates Pretty without another content read", bounds(main)[1] - originalX, 40)
    owner:SetSize(100, 20)
    owner:ClearAllPoints()
    owner:SetPoint("TOP", UIParent, "BOTTOMLEFT", 600, 480)
    cursorX, cursorY = 580, 470
    local beforeDrag, beforeNativeDrag = bounds(main), bounds(owner)
    beforeReads = reads
    owner:GetScript("OnDragStart")(owner)
    if follower then follower:GetScript("OnUpdate")(follower, .016) end
    test.check("StartMoving changes native anchor semantics without moving the native frame", bounds(owner), beforeNativeDrag)
    test.check("drag start preserves the visible grab offset across TOP to TOPLEFT conversion", bounds(main), beforeDrag)
    cursorX, cursorY = cursorX + 30, cursorY + 20
    -- Moving the native frame simulates the engine; Pretty follows the cursor
    -- displacement from its own completed rectangle, not the new native corner.
    owner._points[1][4] = owner._points[1][4] + 30 / owner:GetEffectiveScale()
    owner._points[1][5] = owner._points[1][5] + 20 / owner:GetEffectiveScale()
    if follower then follower:GetScript("OnUpdate")(follower, .016) end
    local dragged = bounds(main)
    test.check("mixed-scale sticky dragging follows cursor displacement without reading content",
        { dragged[1] - beforeDrag[1], dragged[2] - beforeDrag[2], reads }, { 30, 20, beforeReads })
    local beforeNativeStop = bounds(owner)
    owner:GetScript("OnDragStop")(owner)
    if follower then follower:GetScript("OnUpdate")(follower, .016) end
    test.check("StopMoving changes native anchor semantics without moving the native frame", bounds(owner), beforeNativeStop)
    test.check("drag release preserves Pretty's final rectangle across TOPLEFT to CENTER conversion", bounds(main), dragged)

    owner:Show()
    refresh()
    flush()
    test.check("ordinary Show and comparison refresh retain the manually dragged Pretty position", bounds(main), dragged)
    local beforeSecondDrag = bounds(main)
    beforeReads = reads
    owner:GetScript("OnDragStart")(owner)
    if follower then follower:GetScript("OnUpdate")(follower, .016) end
    test.check("a second drag starts from the manual Pretty position without another jump", bounds(main), beforeSecondDrag)
    cursorX, cursorY = cursorX + 12, cursorY - 8
    owner._points[1][4] = owner._points[1][4] + 12 / owner:GetEffectiveScale()
    owner._points[1][5] = owner._points[1][5] - 8 / owner:GetEffectiveScale()
    if follower then follower:GetScript("OnUpdate")(follower, .016) end
    local secondDragged = bounds(main)
    owner:GetScript("OnDragStop")(owner)
    if follower then follower:GetScript("OnUpdate")(follower, .016) end
    test.check("a second drag follows its cursor delta and releases stably without new content reads",
        { secondDragged[1] - beforeSecondDrag[1], secondDragged[2] - beforeSecondDrag[2], bounds(main), reads },
        { 12, -8, secondDragged, beforeReads })

    local nativeX, nativeY, nativeW, nativeH = rectangle(owner)
    local prettyX, prettyY, prettyW, prettyH = rectangle(main)
    local left, right, top, bottom = owner:GetHitRectInsets()
    local factor = owner:GetEffectiveScale()
    test.check("sticky hover hit bounds follow the visible Pretty panel",
        { math.abs(nativeX + left * factor - prettyX) < .01,
            math.abs(nativeX + nativeW - right * factor - prettyX - prettyW) < .01,
            math.abs(nativeY - top * factor - prettyY) < .01,
            math.abs(nativeY - nativeH + bottom * factor - prettyY + prettyH) < .01 },
        { true, true, true, true })

    -- Hide/clear work from a previous lifetime must not restore a reused item.
    owner:Hide()
    owner:GetScript("OnHide")(owner)
    currentID = 2
    owner._data = { type = 0, id = currentID, lines = data.lines }
    owner:Show()
    world.postCalls[0][1](owner, owner._data)
    flush()
    test.check("old deferred cleanup cannot restore a newly populated sticky tooltip",
        { main:IsShown(), main.renderedID, owner:GetAlpha() }, { true, 2, 0 })
    ns.Native.restoreNative(owner)
    test.check("restoring native presentation releases original sticky hit bounds", { owner:GetHitRectInsets() }, { 2, 3, 4, 5 })
    test.check("restoring native presentation restores the native close anchor",
        { close:GetPoint(1) }, { "TOPRIGHT", owner, "TOPRIGHT", -2, -2 })
    test.check("restoring native presentation hides Pretty and restores opacity", { main:IsShown(), owner:GetAlpha() }, { false, 1 })
    owner:Show()
    world.postCalls[0][1](owner, owner._data)
    main.close:GetScript("OnClick")(main.close)
    test.check("Pretty's X still closes sticky tooltips through the native action", { closed, owner:IsShown(), main:IsShown() }, { 1, false, false })
    flush()
    test.check("closing releases the sticky native hit rectangle", { owner:GetHitRectInsets() }, { 2, 3, 4, 5 })

    owner:Show()
    world.postCalls[0][1](owner, owner._data)
    flush()
    TooltipComparisonManager.tooltip = nil
    primary:SetOwner(owner, "ANCHOR_NONE")
    primary._data = { type = 0, id = 42, lines = data.lines }
    world.postCalls[0][1](primary, primary._data)
    primary:Show()
    flush()
    test.check("a direct comparison fill completes even without the manager's active owner",
        { first.renderedID, first.comparisonPending == nil, first:IsShown(), first:GetNumPoints() }, { 42, true, true, 1 })
    primary._data = { type = 1, id = 43, lines = data.lines }
    world.postCalls[1][1](primary, primary._data)
    primary:Show()
    test.check("a non-item comparison does not leave its owner collecting forever",
        { first.renderedID, ns.Placement.refresh(owner) }, { 43, true })
    flush()

    ns.Placement.setEnabled(false)
    ns.Placement.setEnabled(true)
    owner:Show()
    world.postCalls[0][1](owner, owner._data)
    TooltipComparisonManager.tooltip = owner
    refresh(true)
    flush()
    test.check("cached manager calls rejoin the correct group after placement is toggled",
        { main:IsShown(), first:IsShown(), second:IsShown(), first.comparisonPending == nil,
            second.comparisonPending == nil, ns.Placement.refresh(owner) }, { true, true, true, true, true, true })
    local mainX, _, mainWidth = rectangle(main)
    local firstX, _, firstWidth = rectangle(first)
    local secondX = rectangle(second)
    test.check("restored group members have valid abutting placements", math.abs(firstX + firstWidth - mainX) <= 1
        or math.abs(secondX - mainX - mainWidth) <= 1, true)

    local expectedMain = bounds(main)
    main:ClearAllPoints()
    main:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -10)
    ns.Placement.refresh(owner)
    test.check("a replaced single-point Pretty anchor is repaired even with unchanged cached geometry",
        { select(1, main:GetPoint(1)), select(2, main:GetPoint(1)) == UIParent,
            select(3, main:GetPoint(1)), bounds(main) }, { "TOPLEFT", true, "BOTTOMLEFT", expectedMain })

    local protectedSource = CreateFrame("Button", nil, UIParent)
    geometry(protectedSource)
    protectedSource:SetSize(20, 20)
    protectedSource:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 250, 500)
    protectedSource._protected = true
    local protectedWrites = 0
    protectedSource.SetPoint = function() protectedWrites = protectedWrites + 1 end
    owner._ownerPoint = { "TOPLEFT", protectedSource, "TOPLEFT", 0, 0 }
    owner:SetOwner(protectedSource, "ANCHOR_RIGHT")
    world.postCalls[0][1](owner, owner._data)
    owner:Show()
    test.check("SetOwner invalidates cached source points when the engine changes anchors internally",
        { bounds(main)[1], bounds(main)[2] }, { 200, 400 })
    test.check("protected relative frames are readable positioning sources without writes", protectedWrites, 0)
    flush()

    owner._anchorTypePoint = { "TOPLEFT", UIParent, "BOTTOMLEFT", 300, 480 }
    owner:SetAnchorType("ANCHOR_LEFT", 0, 0)
    test.check("an external SetAnchorType engine anchor update is observed without a Lua SetPoint",
        { bounds(main)[1], bounds(main)[2] }, { 300, 480 })
    owner._ownerPoint, owner._anchorTypePoint = nil, nil

    -- Native mode can still run cached Blizzard fills, which bypass manager
    -- posthooks. They must not begin a Pretty batch with no completion signal.
    flush()
    IsAltKeyDown = function() return true end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 1)
    refresh(true)
    flush()
    owner._points = { { "TOPLEFT", UIParent, "BOTTOMLEFT", 200, 450 } }
    IsAltKeyDown = function() return false end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 0)
    test.check("native-mode cached comparison fills cannot strand a Pretty collection", ns.Placement.refresh(owner), true)
    test.check("original modifier release immediately places Pretty at its current source",
        { bounds(main)[1], bounds(main)[2] }, { 200, 450 })
    IsAltKeyDown = function() return true end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 1)
    for _, tooltip in ipairs({ primary, secondary }) do tooltip:SetOwner(owner, "ANCHOR_NONE") end
    TooltipComparisonManager:SetItemTooltip(true)
    TooltipComparisonManager:SetItemTooltip(false)
    cachedAnchor(TooltipComparisonManager)
    flush()
    owner._points = { { "TOPLEFT", UIParent, "BOTTOMLEFT", 250, 430 } }
    IsAltKeyDown = function() return false end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 0)
    test.check("native-mode wrapped fills and cached anchoring cannot strand a Pretty collection",
        { ns.Placement.refresh(owner), bounds(main)[1], bounds(main)[2] }, { true, 250, 430 })
    test.check("all exercised Pretty placement paths avoid native padding", paddingWrites, 0)
    TooltipComparisonManager = nil
end
