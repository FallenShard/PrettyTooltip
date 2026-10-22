-- Pretty owns screen geometry. Native tooltips supply content and input, not
-- dimensions for placement. All plans use UIParent units, including mixed scales.
local _, ns = ...
local ui, util = ns.ui, ns.util
if not (ui and ns.PlacementPlan and ns.Native) then return end

local placement = { enabled = true }
ns.Placement = placement
local roots = setmetatable({}, { __mode = "k" })
local owners = setmetatable({}, { __mode = "k" })

local function scale(frame)
    local value = util.number((util.call(frame.GetEffectiveScale, frame)))
    if value and value > 0 then return value end
end

local function rect(frame)
    -- Relative anchors may be protected action buttons. Read their geometry
    -- through guarded calls; never mutate those source frames.
    if util.isSecret(frame) or (type(frame) ~= "table" and type(frame) ~= "userdata")
        or util.call(frame.IsForbidden, frame) == true then return end
    local factor = scale(frame)
    local left, top = util.number((util.call(frame.GetLeft, frame))), util.number((util.call(frame.GetTop, frame)))
    local width, height = util.number((util.call(frame.GetWidth, frame))), util.number((util.call(frame.GetHeight, frame)))
    if not (factor and left and top and width and height) then return end
    return left * factor, top * factor, width * factor, height * factor
end

local function dragPosition(state)
    local drag = state.drag
    if not drag then return end
    if drag.cursorX then
        local x, y = util.call(GetCursorPosition)
        x, y = util.number(x), util.number(y)
        if x and y then return drag.left + x - drag.cursorX, drag.top + y - drag.cursorY end
    elseif drag.nativeLeft then
        local left, top = rect(state.tooltip)
        if left then return drag.left + left - drag.nativeLeft, drag.top + top - drag.nativeTop end
    end
end

local function fractions(point)
    local x = point:find("LEFT") and 0 or point:find("RIGHT") and 1 or .5
    local y = point:find("BOTTOM") and 0 or point:find("TOP") and 1 or .5
    return x, y
end

local function rootState(tooltip)
    local state = roots[tooltip]
    if not state then
        state = { tooltip = tooltip, members = {} }
        roots[tooltip] = state
    end
    return state
end

local function bind(owner, index, tooltip)
    local previous = owners[tooltip]
    if previous and previous ~= owner and roots[previous] then
        roots[previous].collecting = false
        for oldIndex, member in pairs(roots[previous].members) do
            if member == tooltip then roots[previous].members[oldIndex] = nil end
        end
    end
    owners[tooltip], rootState(owner).members[index] = owner, tooltip
end

local function ownerOf(tooltip)
    if not ui.isComparison(tooltip) then return tooltip end
    local name = util.call(tooltip.GetName, tooltip)
    local index = type(name) == "string" and tonumber(name:match("(%d)$"))
    local manager = util.readable(TooltipComparisonManager)
    local owner = type(manager) == "table" and util.readable(manager.tooltip)
    if util.canModify(owner) then
        local tooltips = util.readable(owner.shoppingTooltips)
        if type(tooltips) == "table" then
            for memberIndex, candidate in ipairs(tooltips) do
                if candidate == tooltip then
                    bind(owner, memberIndex, tooltip)
                    return owner
                end
            end
        end
    end
    owner = util.call(tooltip.GetOwner, tooltip)
    if not (owner and ui.panels[owner]) then owner = owners[tooltip] end
    if not (owner and ui.panels[owner]) and type(name) == "string" then
        owner = name:find("^ItemRef") and ItemRefTooltip or GameTooltip
    end
    if owner and ui.panels[owner] then
        if index then
            bind(owner, index, tooltip)
            return owner
        end
    end
end

function placement.owns(tooltip)
    local panel = ui.panels[tooltip]
    return placement.enabled and panel ~= nil and not panel.nativeOnly and not panel.parked
end

-- Offsets are in the native frame's units; relative anchors use their own
-- effective scale. The Pretty size replaces the native size in this equation.
local function sourceRect(state, panel, parentScale)
    local tooltip = state.tooltip
    local points = state.points
    if not points then
        points = util.framePoints(tooltip)
        state.points = points
    end
    local panelScale, nativeScale = scale(panel), scale(tooltip)
    local width, height = util.number(panel:GetWidth()), util.number(panel:GetHeight())
    if not (panelScale and nativeScale and width and height and width > 0 and height > 0) then return end
    width, height = width * panelScale, height * panelScale
    local left, top
    if state.drag then
        left, top = dragPosition(state)
        if not left then return end
    elseif state.manual then
        left, top = state.manual.left * parentScale, state.manual.top * parentScale
    elseif points and #points > 0 then
        local horizontal, vertical = points[1], points[1]
        for _, point in ipairs(points) do
            if point[1]:find("LEFT") or point[1]:find("RIGHT") then horizontal = point end
            if point[1]:find("TOP") or point[1]:find("BOTTOM") then vertical = point end
        end
        local function anchor(point)
            local target = point[2] or UIParent
            local x, y, w, h = rect(target)
            if not x then return end
            local fx, fy = fractions(point[3])
            return x + fx * w + point[4] * nativeScale,
                y - (1 - fy) * h + point[5] * nativeScale
        end
        local x = anchor(horizontal)
        local _, y = anchor(vertical)
        if not (x and y) then return end
        local fx = fractions(horizontal[1])
        local _, fy = fractions(vertical[1])
        left, top = x - fx * width, y + (1 - fy) * height
    else
        left, top = rect(tooltip)
        if not left then return end
    end
    return { left = left / parentScale, top = top / parentScale,
        width = width / parentScale, height = height / parentScale }
end

local function apply(panel, target)
    local old = panel.placementRect
    local parentScale, panelScale = scale(UIParent), scale(panel)
    if not (parentScale and panelScale) then return false end
    local ratio = parentScale / panelScale
    local x, y = ui.snap(panel, target.left * ratio), ui.snap(panel, target.top * ratio)
    local point, relative, relativePoint, oldX, oldY = panel:GetPoint(1)
    -- The engine can round offsets when storing/returning them. Exact equality
    -- would clear and replay an unchanged anchor every frame at some UI scales.
    local epsilon = ui.pixel(panel) * .01
    if old and math.abs(old.left - target.left) < .001 and math.abs(old.top - target.top) < .001
        and panel.placementScale == ratio and panel:GetNumPoints() == 1
        and point == "TOPLEFT" and relative == UIParent and relativePoint == "BOTTOMLEFT"
        and type(oldX) == "number" and type(oldY) == "number"
        and math.abs(oldX - x) < epsilon and math.abs(oldY - y) < epsilon then return true end
    panel:SetClampedToScreen(false) -- The complete group has already been clamped.
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    panel.placementRect = target
    panel.placementScale = ratio
    return true
end

local function syncMouse(tooltip, panel)
    if tooltip ~= ItemRefTooltip or not tooltip.SetHitRectInsets then return end
    local x, y, w, h = rect(tooltip)
    local px, py, pw, ph = rect(panel)
    local factor = scale(tooltip)
    if not (x and px and factor) then return end
    if not panel.placementMouse then
        local a, b, c, d = util.call(tooltip.GetHitRectInsets, tooltip)
        if not (util.number(a) and util.number(b) and util.number(c) and util.number(d)) then return end
        panel.placementMouse = { a, b, c, d }
    end
    local wanted = { (px - x) / factor, (x + w - px - pw) / factor,
        (y - py) / factor, (py - ph - y + h) / factor }
    local previous = panel.placementHitRect
    local changed = not previous
    for index = 1, 4 do
        if previous and math.abs(previous[index] - wanted[index]) > .01 then changed = true end
    end
    if changed then
        tooltip:SetHitRectInsets(unpack(wanted))
        panel.placementHitRect = wanted
    end
    -- Keep the invisible native close control over the visible X, rather than
    -- leaving another mouse target at the native tooltip's old corner.
    local close = util.readable(tooltip.CloseButton) or util.readable(_G.ItemRefCloseButton)
    if panel.close and util.canModify(close) and not panel.placementClose then
        local points = util.framePoints(close)
        if points and #points > 0 then
            panel.placementClose = { button = close, points = points }
            close:ClearAllPoints()
            close:SetPoint("CENTER", panel.close, "CENTER", 0, 0)
        end
    end
end

local function dismissOutsideComparisons(tooltip, panel)
    if tooltip ~= ItemRefTooltip or ns.originalKeyDown()
        or util.call(panel.IsMouseOver, panel) ~= false then return end
    tooltip.updateTooltipTimer = nil
    local tooltips = util.readable(tooltip.shoppingTooltips)
    if type(tooltips) ~= "table" then return end
    local hidden = false
    for _, comparison in ipairs(tooltips) do
        if util.canModify(comparison) and util.call(comparison.IsShown, comparison) == true then
            comparison:Hide()
            local view = ui.panels[comparison]
            if view then view:Hide() end
            hidden = true
        end
    end
    if not hidden then return end
    local manager = util.readable(TooltipComparisonManager)
    if type(manager) == "table" then util.call(manager.Clear, manager, tooltip) end
    return true
end

function placement.refresh(tooltip)
    if not placement.enabled or not util.canModify(tooltip) then return false end
    local owner = ownerOf(tooltip)
    if not util.canModify(owner) then return false end
    local state, panel = rootState(owner), ui.panels[owner]
    if state.running or state.collecting or not (panel and panel:IsShown() and placement.owns(owner))
        or panel.restorePending or not util.call(owner.IsShown, owner) then return false end
    local parentScale = scale(UIParent)
    if not parentScale then return false end
    local main = sourceRect(state, panel, parentScale)
    local width, height = util.number(UIParent:GetWidth()), util.number(UIParent:GetHeight())
    if not (main and width and height and width > 0 and height > 0) then return false end
    local comparisons, visible = {}, {}
    for index, native in pairs(state.members) do
        local comparison = ui.panels[native]
        if comparison and comparison:IsShown() and placement.owns(native) and util.call(native.IsShown, native) then
            if comparison.comparisonPending or comparison.restorePending then return false end
            local factor = scale(comparison)
            if not factor then return false end
            comparisons[#comparisons + 1] = { id = index, width = comparison:GetWidth() * factor / parentScale,
                height = comparison:GetHeight() * factor / parentScale }
            visible[index] = comparison
        end
    end
    table.sort(comparisons, function(a, b) return a.id < b.id end)
    local anchorType = util.call(owner.GetAnchorType, owner)
    local preferred = type(anchorType) == "string" and (anchorType:find("LEFT") and "left"
        or anchorType:find("RIGHT") and "right") or nil
    local plan = ns.PlacementPlan.solve({ main = main, comparisons = comparisons,
        screen = { left = 0, bottom = 0, right = width, top = height }, previousSide = state.side,
        preferredSide = preferred })
    if not plan then return false end
    state.running = true
    local ok, applied = pcall(function()
        if not apply(panel, plan.main) then return false end
        for index, comparison in pairs(visible) do
            if not apply(comparison, plan.comparisons[index]) then return false end
            comparison.comparisonAnchorPending, comparison.comparisonAnchorHeld = nil, nil
            comparison.side = plan.side == "left" and "RIGHT" or "LEFT"
        end
        syncMouse(owner, panel)
        return true
    end)
    state.running = false
    if not ok or not applied then return false end
    state.side, state.plan = plan.side, plan
    -- The game's initial fill can show comparisons before ItemRef's OnEnter.
    -- Check the finished Pretty bounds, then commit without comparisons in
    -- this same callback; no OnLeave or later frame is needed to dismiss them.
    if dismissOutsideComparisons(owner, panel) then return placement.refresh(owner) end
    return true
end

function placement.align(_, tooltip, force)
    if not placement.owns(tooltip) then return false end
    if force and not ui.isComparison(tooltip) then rootState(tooltip).points = util.framePoints(tooltip) end
    return placement.refresh(tooltip)
end

function placement.observe(tooltip, dataType)
    -- Native-only refills can use cached manager functions, bypassing their
    -- completion hooks. They must not leave a Pretty transaction open when
    -- the original-tooltip key is released.
    if ns.originalKeyDown() or not placement.owns(tooltip) then return end
    local owner = ownerOf(tooltip)
    if owner then
        local state = rootState(owner)
        if not state.points then state.points = util.framePoints(owner) end
        if ui.isComparison(tooltip) and dataType == Enum.TooltipDataType.Item
            and ns.Hooks and ns.Hooks.comparisonsBatched() then state.collecting = true end
    end
end

function placement.beginComparisons(owner)
    if ns.originalKeyDown() or not (placement.enabled and util.canModify(owner)) then return end
    local state = rootState(owner)
    if not state.points then state.points = util.framePoints(owner) end
    state.collecting = true
    local members = util.readable(owner.shoppingTooltips)
    if type(members) == "table" then
        for index, tooltip in ipairs(members) do
            if util.canModify(tooltip) then
                bind(owner, index, tooltip)
            end
        end
    end
end

function placement.finishComparisons(owner)
    if not (placement.enabled and util.canModify(owner)) then return end
    rootState(owner).collecting = false
    return placement.refresh(owner)
end

function placement.finish(tooltip)
    local owner = ownerOf(tooltip)
    if owner then return placement.finishComparisons(owner) end
end

function placement.moved(tooltip)
    if not placement.owns(tooltip) then return end
    local owner = ownerOf(tooltip)
    if not owner then return end
    local state = rootState(owner)
    if not ui.isComparison(tooltip) and not state.collecting and not state.drag then
        state.points, state.manual = util.framePoints(tooltip), nil
    end
    return placement.refresh(owner)
end

function placement.ownerChanged(tooltip)
    if not placement.enabled or ui.isComparison(tooltip) then return end
    local state = rootState(tooltip)
    state.points, state.side, state.collecting, state.awaitingOwner = nil, nil, false, true
    state.drag, state.manual = nil, nil
end

function placement.shown(tooltip)
    if not ui.isComparison(tooltip) then
        local state = rootState(tooltip)
        if state.awaitingOwner and not state.collecting then
            state.points, state.awaitingOwner = util.framePoints(tooltip), false
        end
    end
    return placement.refresh(tooltip)
end

function placement.release(tooltip, panel)
    if panel.placementMouse and util.canModify(tooltip) then
        pcall(tooltip.SetHitRectInsets, tooltip, unpack(panel.placementMouse))
    end
    local close = panel.placementClose
    if close and util.canModify(close.button) then
        pcall(function()
            close.button:ClearAllPoints()
            for _, point in ipairs(close.points) do close.button:SetPoint(unpack(point)) end
        end)
    end
    panel.placementMouse, panel.placementHitRect, panel.placementRect = nil, nil, nil
    panel.placementClose, panel.placementScale = nil, nil
    panel:SetClampedToScreen(true)
    if not ui.isComparison(tooltip) then roots[tooltip] = nil end
end

function placement.setEnabled(enabled)
    if placement.enabled == enabled then return end
    placement.enabled = enabled
    for tooltip in pairs(ui.panels) do ns.Native.restoreNative(tooltip) end
end

-- Source frames can move without SetPoint. Sticky dragging follows the cursor
-- from the visible grab point, independent of native drag anchor normalization.
-- This follows geometry only; it never guesses when content has finished.
local follower = CreateFrame("Frame")
follower:SetScript("OnUpdate", function()
    if not placement.enabled then return end
    for tooltip in pairs(roots) do
        local ok = pcall(placement.refresh, tooltip)
        if not ok then ns.Native.restoreNative(tooltip) end
    end
end)

function placement.hookInput(tooltip)
    if tooltip ~= ItemRefTooltip then return end
    tooltip:HookScript("OnDragStart", function()
        if not placement.owns(tooltip) then return end
        local panel = ui.panels[tooltip]
        local left, top = rect(panel)
        if not (panel:IsShown() and left) then return end
        local x, y = util.call(GetCursorPosition)
        x, y = util.number(x), util.number(y)
        local nativeLeft, nativeTop = rect(tooltip)
        local state = rootState(tooltip)
        state.drag = { left = left, top = top, cursorX = x and y and x or nil, cursorY = y,
            nativeLeft = nativeLeft, nativeTop = nativeTop }
    end)
    tooltip:HookScript("OnDragStop", function()
        local state = rootState(tooltip)
        if not state.drag then return end
        -- Process the last cursor delta before releasing. Keep the actual group
        -- placement after clamping, rather than reinterpreting native CENTER.
        local left, top = dragPosition(state)
        local parentScale = scale(UIParent)
        if placement.refresh(tooltip) and state.plan then
            state.manual = { left = state.plan.main.left, top = state.plan.main.top }
        elseif left and parentScale then
            state.manual = { left = left / parentScale, top = top / parentScale }
        end
        state.drag, state.points = nil, util.framePoints(tooltip)
        placement.refresh(tooltip)
    end)
end
