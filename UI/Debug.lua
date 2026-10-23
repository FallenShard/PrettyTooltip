-- Debug commands: /ptip anchors, /ptip pixel, /ptip trace, /ptip perf, and
-- /ptip bench. Each shows its findings in the report window, to copy into a
-- bug report.
local addonName, ns = ...
local ui = ns.ui
if not ui then return end
local placement = ns.Placement

local isSecret = ns.util.isSecret
local util = ns.util
local panels = ui.panels

-- /ptip anchors: where each shown panel sits, left to right, and how its
-- hidden tooltip is anchored.
function ns.dumpAnchors()
    local shown = {}
    for tooltip, panel in pairs(panels) do
        if util.canModify(tooltip) and panel:IsShown() then
            local left, right = util.number(panel:GetLeft()), util.number(panel:GetRight())
            local nativeLeft, nativeRight = util.number(tooltip:GetLeft()), util.number(tooltip:GetRight())
            if left and right and nativeLeft and nativeRight then
                shown[#shown + 1] = {
                    tooltip = tooltip,
                    panel = panel,
                    left = left,
                    right = right,
                    nativeLeft = nativeLeft,
                    nativeRight = nativeRight
                }
            end
        end
    end
    table.sort(shown, function(a, b) return a.left < b.left end)
    local function nameOf(frame)
        if not frame then return "nil" end
        if not util.canModify(frame) then return "<restricted>" end
        for tooltip, panel in pairs(panels) do
            if frame == panel then return (tooltip:GetName() or "?") .. "'s panel" end
        end
        return frame:GetName() or tostring(frame)
    end
    if #shown == 0 then
        print("PrettyTooltip: no panel is shown.")
        return
    end
    local lines = { "Placement: " .. placement.strategy }
    for index, entry in ipairs(shown) do
        local tooltip, panel = entry.tooltip, entry.panel
        local line = ("%s: panel %.1f to %.1f (pinned %s), hidden %.1f to %.1f"):format(tooltip:GetName() or "?",
            entry.left, entry.right, tostring(panel.side), entry.nativeLeft, entry.nativeRight)
        if index > 1 then
            line = line .. (", gap %.1f"):format(entry.left - shown[index - 1].right)
        end
        lines[#lines + 1] = line
        for _, point in ipairs(util.framePoints(tooltip) or {}) do
            lines[#lines + 1] = ("    %s to %s %s, offset %s, %s"):format(point[1], nameOf(point[2]),
                point[3], tostring(point[4]), tostring(point[5]))
        end
    end
    ns.showReport("anchors", lines)
end

-- /ptip pixel: whether lines are snapped by the game's PixelUtil or the
-- addon's own math, and what one screen pixel is at the current scale.
function ns.dumpPixel()
    local native = PixelUtil and PixelUtil.GetNearestPixelSize and PixelUtil.GetPixelToUIUnitFactor
    local width, height = GetPhysicalScreenSize()
    local scale = UIParent:GetEffectiveScale()
    width, height, scale = util.number(width), util.number(height), util.number(scale)
    if not (width and height and scale) then
        ns.showReport("pixel", { "Screen geometry is restricted." }); return
    end
    ns.showReport("pixel", { ("Snapping with %s; screen %dx%d, UI scale %.3f, one pixel = %.4f units."):format(
        native and "the game's PixelUtil" or "the addon's own math", width, height, scale, ui.pixel(UIParent)) })
end

-- /ptip trace: every frame for a few seconds, each game tooltip's and its
-- panel's visibility, opacity, size, and anchors, written when they change,
-- and the calls that move, show, hide, or fade a game tooltip, with the line
-- that made each. Values the game hides read "secret".
local TRACED = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
    "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2" }
local MAX_EVENTS = 4000
local tracing, traceLines, traceStart, traceFrame
local hookedForTrace = {}
local hookedManagers = setmetatable({}, { __mode = "k" })
local lastAlpha, suppressed, eventCount, omittedEvents

local function shown(value)
    if isSecret(value) then return "secret" end
    if type(value) == "number" then return ("%.1f"):format(value) end
    return tostring(value)
end

local function traceLine(text)
    traceLines[#traceLines + 1] = ("%7.3f  %s"):format(debugprofilestop() / 1000 - traceStart, text)
end

-- Bound noisy method logs while retaining samples and lifecycle events.
local function takeEvent(essential)
    if not tracing then return false end
    if essential then return true end
    if eventCount >= MAX_EVENTS then
        omittedEvents = omittedEvents + 1
        return false
    end
    eventCount = eventCount + 1
    return true
end

local function pendingOf(panel)
    if not panel then return "no panel" end
    local flags = {}
    for _, flag in ipairs({ "restorePending", "contentPending", "comparisonPending", "comparisonFitPending",
        "comparisonAnchorPending" }) do
        if panel[flag] then flags[#flags + 1] = flag end
    end
    return "pending " .. (#flags > 0 and table.concat(flags, ",") or "none")
end

local function nameOf(frame)
    if isSecret(frame) then return "secret" end
    if not frame then return "nil" end
    if type(frame) ~= "table" and type(frame) ~= "userdata" then return shown(frame) end
    for tooltip, panel in pairs(panels) do
        if frame == panel then return (util.call(tooltip.GetName, tooltip) or "?") .. ".panel" end
        if frame == panel.close then return (util.call(tooltip.GetName, tooltip) or "?") .. ".panel.close" end
    end
    return util.call(frame.GetName, frame) or util.call(frame.GetDebugName, frame) or tostring(frame)
end

local function anchorsOf(frame)
    local count = util.call(frame.GetNumPoints, frame)
    if not count then return "points secret" end
    local parts = {}
    for index = 1, count do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(index)
        parts[#parts + 1] = ("%s>%s.%s(%s,%s)"):format(shown(point), nameOf(relativeTo), shown(relativePoint),
            shown(x), shown(y))
    end
    return #parts > 0 and table.concat(parts, " ") or "no points"
end

local function stateOf(frame, isTooltip)
    if not frame then return "missing" end
    if not util.canModify(frame) then return "restricted" end
    local parts = { frame:IsShown() and (frame:IsVisible() and "shown" or "shown, out of sight") or "hidden" }
    if not frame:IsShown() then return parts[1] end
    parts[#parts + 1] = "alpha " .. shown(frame:GetAlpha())
    if frame.GetEffectiveAlpha then parts[#parts + 1] = "eff " .. shown(frame:GetEffectiveAlpha()) end
    parts[#parts + 1] = "size " .. shown(frame:GetWidth()) .. "x" .. shown(frame:GetHeight())
    parts[#parts + 1] = "pos " .. shown(frame:GetLeft()) .. "," .. shown(frame:GetTop())
    parts[#parts + 1] = "scale " .. shown(frame:GetScale())
    if frame.IsMouseOver then parts[#parts + 1] = "hover " .. shown(util.call(frame.IsMouseOver, frame)) end
    if isTooltip and frame.GetPadding then
        local right, bottom, left, top = frame:GetPadding()
        parts[#parts + 1] = ("pad %s/%s/%s/%s"):format(shown(right), shown(bottom), shown(left), shown(top))
    end
    if isTooltip and frame.IsClampedToScreen then parts[#parts + 1] = "clamped " .. shown(frame:IsClampedToScreen()) end
    parts[#parts + 1] = anchorsOf(frame)
    return table.concat(parts, "  ")
end

-- An invisible native child can receive mouse motion over the visible panel.
-- Log its identity, parent and bounds when focus changes, including alpha 0.
local function mouseState()
    local foci
    if type(GetMouseFoci) == "function" then
        foci = util.call(GetMouseFoci)
        if type(foci) ~= "table" then return "focus restricted" end
    elseif type(GetMouseFocus) == "function" then
        foci = { util.call(GetMouseFocus) }
    else
        return "focus API unavailable"
    end
    local parts = {}
    for index, frame in ipairs(foci) do
        if index > 6 then break end
        if util.canModify(frame) then
            local parent = util.call(frame.GetParent, frame)
            parts[#parts + 1] = nameOf(frame) .. " parent " .. nameOf(parent) .. " {" .. stateOf(frame, false) .. "}"
        else
            parts[#parts + 1] = "restricted"
        end
    end
    return #parts > 0 and table.concat(parts, " | ") or "no focus"
end

local function mousePosition()
    local x, y = util.call(GetCursorPosition)
    return "cursor " .. shown(x) .. "," .. shown(y)
end

local function hookForTrace(tooltip, name, isPanel)
    if hookedForTrace[tooltip] then return end
    hookedForTrace[tooltip] = true
    -- The first line of the stack that is neither the game's C nor this file.
    local function caller()
        for line in ((debugstack(2, 12, 0) or ""):gsub("\\", "/")):gmatch("[^\n]+") do
            if not line:find("^%s*%[C%]") and not line:find("UI/Debug.lua", 1, true) then
                return (line:gsub("^%s+", ""):gsub("Interface/AddOns/", ""):gsub("^%[string \"@?", ""))
            end
        end
        return "the game"
    end
    local function record(method, describe)
        if not tooltip[method] then return end
        hooksecurefunc(tooltip, method, function(_, ...)
            if not tracing then return end
            if method == "SetAlpha" then
                local alpha = ...
                if not isSecret(alpha) and alpha == 0 and lastAlpha[tooltip] == 0 then
                    suppressed = suppressed + 1
                    return
                end
                lastAlpha[tooltip] = util.number(alpha)
            end
            if not takeEvent() then return end
            local panel = isPanel and tooltip or panels[tooltip]
            if not isPanel and panel then hookForTrace(panel, name .. ".panel", true) end
            traceLine(("%s:%s(%s)  from %s  [%s]"):format(name, method, describe and describe(...) or "", caller(),
                pendingOf(panel)))
        end)
    end
    local function first(value) return shown(value) end
    record("SetAlpha", first)
    record("Show")
    -- Wrapping Hide makes the game's GameTooltip_Hide fail on the 1.60 beta
    -- client ("attempt to call a nil value") for the rest of the session.
    local events = isPanel and { "OnHide", "OnShow" } or { "OnHide", "OnShow", "OnTooltipCleared" }
    if util.call(tooltip.IsMouseEnabled, tooltip) == true then
        events[#events + 1], events[#events + 2] = "OnEnter", "OnLeave"
    end
    for _, event in ipairs(events) do
        tooltip:HookScript(event, function()
            if takeEvent(true) then
                local mouse = ""
                if event == "OnEnter" or event == "OnLeave" then
                    local ok, state = pcall(mouseState)
                    mouse = "  " .. mousePosition() .. "  " .. (ok and state or "focus unreadable")
                end
                traceLine(("%s %s  from %s  [%s]%s"):format(name, event, caller(),
                    pendingOf(isPanel and tooltip or panels[tooltip]), mouse))
            end
        end)
    end
    record("SetShown", first)
    record("FadeOut")
    record("ClearAllPoints")
    record("SetPoint", function(point, relativeTo, relativePoint, x, y)
        return ("%s, %s, %s, %s, %s"):format(shown(point), nameOf(relativeTo), shown(relativePoint), shown(x), shown(y))
    end)
    record("SetOwner", function(owner, anchor) return nameOf(owner) .. ", " .. shown(anchor) end)
    record("SetPadding", function(...)
        local values = {}
        for index = 1, select("#", ...) do values[index] = shown((select(index, ...))) end
        return table.concat(values, ", ")
    end)
    record("SetScale", first)
end

local function hookComparisonTrace()
    local manager = TooltipComparisonManager
    if isSecret(manager) or type(manager) ~= "table" then return end
    local hooked = hookedManagers[manager]
    if not hooked then hooked = {}; hookedManagers[manager] = hooked end
    for _, method in ipairs({ "Initialize", "SetItemTooltip", "AnchorShoppingTooltips", "Clear" }) do
        if not hooked[method] and type(manager[method]) == "function" then
            hooked[method] = true
            hooksecurefunc(manager, method, function(self, first, second)
                if isSecret(self) or not takeEvent(true) then return end
                traceLine(("TooltipComparisonManager:%s(%s, %s)  owner %s"):format(method,
                    shown(first), shown(second), nameOf(self.tooltip)))
            end)
        end
    end
end

-- Who handed a tooltip its data: the first lines of the stack past the game's
-- tooltip data handler and this addon.
local function dataSource()
    local parts = {}
    for line in ((debugstack(3, 30, 0) or ""):gsub("\\", "/")):gmatch("[^\n]+") do
        if not line:find("^%s*%[C%]") and not line:find("PrettyTooltip/", 1, true)
            and not line:find("TooltipDataHandler.lua", 1, true) then
            parts[#parts + 1] = (line:gsub("^%s+", ""):gsub("Interface/AddOns/", ""):gsub("^%[string \"@?", ""))
            if #parts == 3 then break end
        end
    end
    return #parts > 0 and table.concat(parts, " < ") or "the game"
end

local function traceData(tooltip)
    if tracing and takeEvent(true) then traceLine(("%s data handed over  from %s"):format(nameOf(tooltip), dataSource())) end
end

function ns.traceTooltips(seconds)
    if tracing then
        print("PrettyTooltip: a trace is already running.")
        return
    end
    traceLines, traceStart, tracing = {}, debugprofilestop() / 1000, true
    traceLine("layout: " .. ns.option("layout"))
    traceLine("placement strategy: " .. placement.strategy)
    lastAlpha, suppressed = {}, 0
    eventCount, omittedEvents = 0, 0
    local previous, combat, previousMouse = {}, nil, nil
    for _, name in ipairs(TRACED) do
        local tooltip = _G[name]
        if tooltip and util.canModify(tooltip) then
            hookForTrace(tooltip, name)
            if panels[tooltip] then hookForTrace(panels[tooltip], name .. ".panel", true) end
        end
    end
    hookComparisonTrace()
    ns.Processor.watcher = traceData
    traceFrame = traceFrame or CreateFrame("Frame")
    local frameCount = 0
    -- The two faults to catch: the game's tooltip showing under a shown panel,
    -- and a panel shown while its tooltip is out of sight.
    local visible, visibleInCombat, orphaned, flagged = 0, 0, 0, 0
    local function check(name, tooltip, panel, inCombat)
        if not (panel and panel:IsVisible() and util.canModify(tooltip)) then return end
        if not tooltip:IsVisible() then
            orphaned = orphaned + 1
            if flagged < 40 then
                flagged = flagged + 1
                traceLine(("!! frame %d  %s.panel shown without its tooltip, at %s,%s"):format(frameCount, name,
                    shown(panel:GetLeft()), shown(panel:GetTop())))
            end
            return
        end
        -- A tooltip moved off the screen while it fades is out of sight, whatever its alpha.
        local right, top = util.number(tooltip:GetRight()), util.number(tooltip:GetTop())
        if right and top and (right < 0 or top < 0) then return end
        local alpha = tooltip.GetEffectiveAlpha and tooltip:GetEffectiveAlpha() or tooltip:GetAlpha()
        if isSecret(alpha) or alpha > .01 then
            visible = visible + 1
            if inCombat then visibleInCombat = visibleInCombat + 1 end
            if flagged < 40 then
                flagged = flagged + 1
                traceLine(("!! frame %d  %s VISIBLE under its panel, alpha %s, %s by %s"):format(frameCount, name,
                    shown(alpha), shown(tooltip:GetWidth()) .. "x" .. shown(tooltip:GetHeight()),
                    shown(panel:GetWidth()) .. "x" .. shown(panel:GetHeight())))
            end
        end
    end
    traceFrame:SetScript("OnUpdate", function()
        if not tracing then return end
        frameCount = frameCount + 1
        -- Frames, panels and the comparison manager can appear after tracing starts.
        hookComparisonTrace()
        local inCombat = InCombatLockdown() and true or false
        if inCombat ~= combat then
            combat = inCombat
            traceLine(inCombat and "-- in combat" or "-- out of combat")
        end
        local mouseOK, mouse = pcall(mouseState)
        mouse = mouseOK and mouse or "focus unreadable"
        if mouse ~= previousMouse then
            previousMouse = mouse
            traceLine(("frame %d  mouse %s  %s"):format(frameCount, mousePosition(), mouse))
        end
        for _, name in ipairs(TRACED) do
            local tooltip = _G[name]
            local panel = tooltip and panels[tooltip]
            if tooltip and not hookedForTrace[tooltip] and util.canModify(tooltip) then
                hookForTrace(tooltip, name)
            end
            if panel and not hookedForTrace[panel] then hookForTrace(panel, name .. ".panel", true) end
            pcall(check, name, tooltip, panel, inCombat)
            for _, entry in ipairs({ { name, tooltip, true }, { name .. ".panel", panel, false } }) do
                local ok, state = pcall(stateOf, entry[2], entry[3])
                state = ok and state or ("unreadable: " .. tostring(state))
                if not entry[3] and entry[2] then state = state .. "  [" .. pendingOf(entry[2]) .. "]" end
                if previous[entry[1]] ~= state then
                    previous[entry[1]] = state
                    traceLine(("frame %d  %s  %s"):format(frameCount, entry[1], state))
                end
            end
        end
    end)
    print("PrettyTooltip: tracing tooltips for " .. seconds .. " seconds; hover what shows the problem now.")
    C_Timer.After(seconds, function()
        tracing = false
        traceFrame:SetScript("OnUpdate", nil)
        if ns.Processor.watcher == traceData then ns.Processor.watcher = nil end
        local lines = { ("PrettyTooltip trace over %d s, %d frames%s:"):format(seconds, frameCount,
            omittedEvents > 0 and " (event log capped at " .. MAX_EVENTS .. " calls)" or ""),
            ("  the game's tooltip visible under a panel: %d frames, %d of them in combat"):format(visible,
                visibleInCombat),
            ("  a panel shown without its tooltip: %d frames"):format(orphaned),
            ("  redundant zero-alpha calls omitted: %d"):format(suppressed),
            ("  calls omitted after the event limit: %d; frame samples and lifecycle events cover the full duration")
                :format(omittedEvents) }
        for _, line in ipairs(traceLines) do lines[#lines + 1] = line end
        ns.showReport("trace", lines)
    end)
end

-- /ptip perf, /ptip perf ab, and /ptip bench -------------------------------------

local profiler = ns.Profiler
local sampler, running
-- /ptip perf ab leaves out the start of each window, while panels restore or
-- draw again after the switch.
local WINDOW, SETTLE = 2500, 500
-- /ptip bench measures refreshes in blocks, each after a few warm-up ones.
local BLOCK, WARMUP = 8, 2
local THRESHOLDS = { 1, 5, 10, 50 }
local CLASSES = { { "data", "with tooltip data" }, { "after", "right after those" }, { "other", "all others" } }
local WHO = { { "game", "whole game" }, { "addons", "all addons" }, { "own", "PrettyTooltip" } }

-- The addon's own memory in KB, as the game counts it; nil where it cannot.
local function addonMemory()
    local getter = GetAddOnMemoryUsage or (C_AddOns and C_AddOns.GetAddOnMemoryUsage)
    if not (UpdateAddOnMemoryUsage and getter) then return end
    local ok, usage = pcall(function()
        UpdateAddOnMemoryUsage()
        return getter(addonName)
    end)
    if ok and not isSecret(usage) and type(usage) == "number" then return usage end
end

local function sortedCopy(values)
    local copy = {}
    for index = 1, #values do copy[index] = values[index] end
    table.sort(copy)
    return copy
end

-- Nearest rank: the value with the given share of the values at or below it.
local function quantile(sorted, share)
    if #sorted == 0 then return end
    return sorted[math.max(1, math.min(#sorted, math.ceil(share * #sorted)))]
end

local function mean(values)
    if #values == 0 then return end
    local sum = 0
    for _, value in ipairs(values) do sum = sum + value end
    return sum / #values
end

local function fmt(value, format)
    if value == nil then return "-" end
    return (format or "%.2f"):format(value)
end

local function quoted(label)
    return label ~= "" and (' "' .. label .. '"') or ""
end

-- Frames in which the game handed tooltips their data, the frames right after
-- those, where deferred work runs, and the rest. keep(index) picks frames.
local function frameClasses(frames, keep)
    local classes = {}
    for _, class in ipairs(CLASSES) do classes[class[1]] = { interval = {}, work = {} } end
    for index = 1, frames.n do
        if not keep or keep(index) then
            local class = frames.data[index] > 0 and "data"
                or (index > 1 and frames.data[index - 1] > 0) and "after" or "other"
            local list = classes[class]
            list.interval[#list.interval + 1] = frames.interval[index]
            list.work[#list.work + 1] = frames.work[index]
        end
    end
    return classes
end

local function metricName(threshold) return "CountTimeOver" .. threshold .. "Ms" end

-- The game's frame counters between two snapshots, added into total.
local function addEngine(total, before, after)
    if not (before and after) then return total end
    total = total or { game = {}, addons = {}, own = {} }
    for _, who in ipairs(WHO) do
        for _, threshold in ipairs(THRESHOLDS) do
            local metric = metricName(threshold)
            local from, to = before[who[1]][metric], after[who[1]][metric]
            if from and to then total[who[1]][metric] = (total[who[1]][metric] or 0) + to - from end
        end
    end
    return total
end

local function framesOver(intervals)
    local counts = {}
    for _, threshold in ipairs(THRESHOLDS) do
        local count = 0
        for _, interval in ipairs(intervals) do
            if interval > threshold then count = count + 1 end
        end
        counts[metricName(threshold)] = count
    end
    return counts
end

local function overCounts(counts, scale, format)
    local parts = {}
    for index, threshold in ipairs(THRESHOLDS) do
        local count = counts[metricName(threshold)]
        parts[index] = fmt(count and count * (scale or 1), format or "%d")
    end
    return table.concat(parts, " / ")
end

local function engineLines(lines, engine, intervals)
    if not engine then
        lines[#lines + 1] = "Game profiler: not available on this client."
        return
    end
    lines[#lines + 1] = "Game profiler (C_AddOnProfiler), frames over 1 / 5 / 10 / 50 ms:"
    for _, who in ipairs(WHO) do
        lines[#lines + 1] = ("  %-14s %s"):format(who[2], overCounts(engine[who[1]]))
    end
    if intervals then lines[#lines + 1] = ("  %-14s %s"):format("this sampler", overCounts(framesOver(intervals))) end
    lines[#lines + 1] = "  The game counts hooks that run inside its own code as its time, so the addon rows leave"
    lines[#lines + 1] = "  out most tooltip work. /ptip bench measures that work directly."
end

local function frameTable(lines, classes)
    lines[#lines + 1] = ("  %-18s %7s %8s %8s %8s %10s %9s"):format("frames", "count", "p50 ms", "p95 ms", "max ms",
        "ours mean", "ours max")
    for _, class in ipairs(CLASSES) do
        local list = classes[class[1]]
        local intervals, work = sortedCopy(list.interval), sortedCopy(list.work)
        lines[#lines + 1] = ("  %-18s %7d %8s %8s %8s %10s %9s"):format(class[2], #intervals,
            fmt(quantile(intervals, .5)), fmt(quantile(intervals, .95)), fmt(intervals[#intervals]),
            fmt(mean(work), "%.3f"), fmt(work[#work], "%.3f"))
    end
end

-- Measured scopes, most own time first, then the counts with no time.
local function scopeTable(lines, divisor)
    local names = {}
    for name in pairs(profiler.total) do names[#names + 1] = name end
    table.sort(names, function(a, b) return profiler.self[a] > profiler.self[b] end)
    lines[#lines + 1] = ("  %-32s %7s %9s %9s %9s"):format("scope", "calls", "own ms", "total ms", "max ms")
    for _, name in ipairs(names) do
        lines[#lines + 1] = ("  %-32s %7.1f %9.3f %9.3f %9.3f"):format(name, profiler.calls[name] / divisor,
            profiler.self[name] / divisor, profiler.total[name] / divisor, profiler.max[name])
    end
    local counts = {}
    for name, calls in pairs(profiler.calls) do
        if not profiler.total[name] then counts[#counts + 1] = ("%s %.1f"):format(name, calls / divisor) end
    end
    table.sort(counts)
    if #counts > 0 then lines[#lines + 1] = "  counts: " .. table.concat(counts, ", ") end
end

local function busy()
    if not running then return false end
    print("PrettyTooltip: " .. running .. " is already running.")
    return true
end

-- /ptip perf: where PrettyTooltip's time goes while tooltips are used as usual.
function ns.perfCapture(seconds, label)
    if busy() then return end
    running = "/ptip perf"
    label = label or ""
    profiler.reset()
    profiler.startFrames()
    local layout, items = ns.option("layout"), ns.restyles("itemPanels")
    local before, memory, luaMemory = profiler.engineMetrics(), addonMemory(), collectgarbage("count")
    local busiest, samples, nextSample = {}, 0, 0
    local started = debugprofilestop()
    sampler = sampler or CreateFrame("Frame")
    sampler:SetScript("OnUpdate", function()
        profiler.frame()
        local now = debugprofilestop()
        if now < nextSample then return end
        nextSample, samples = now + 1000, samples + 1
        for _, addon in ipairs(profiler.busiestAddOns(5)) do
            busiest[addon.name] = (busiest[addon.name] or 0) + addon.ms
        end
    end)
    profiler.on = true
    print(("PrettyTooltip: measuring for %d seconds; use tooltips as you want them measured."):format(seconds))
    C_Timer.After(seconds, function()
        profiler.on = false
        sampler:SetScript("OnUpdate", nil)
        running = nil
        local elapsed = math.max(.001, (debugprofilestop() - started) / 1000)
        local frames = profiler.stopFrames()
        local classes = frameClasses(frames)
        local updates = #classes.data.interval
        local lines = {
            ("PrettyTooltip perf%s: %.2f s, layout %s, items %s, %d frames (%.1f/s), probes on."):format(quoted(label),
                elapsed, layout, items and "restyled" or "as the game draws them", frames.n, frames.n / elapsed),
            ("Tooltip data arrived in %d frames (%.1f/s): %d main and %d comparison handovers."):format(updates,
                updates / elapsed, profiler.calls["data: main"] or 0, profiler.calls["data: comparison"] or 0),
        }
        if ns.option("layout") ~= layout or ns.restyles("itemPanels") ~= items then
            lines[#lines + 1] = "Settings changed during the capture; repeat it."
        end
        frameTable(lines, classes)
        local divisor, unit = updates, "update"
        if updates == 0 then divisor, unit = elapsed, "second" end
        lines[#lines + 1] = ("PrettyTooltip's work: %.3f ms in all, %.3f ms per %s, %.4f ms per frame."):format(
            profiler.work, profiler.work / divisor, unit, frames.n > 0 and profiler.work / frames.n or 0)
        if unit == "update" then
            lines[#lines + 1] = "Per update: all the work measured, divided by the frames with tooltip data."
        end
        lines[#lines + 1] = ("By scope, per %s; own time leaves out the scopes a scope calls, totals overlap:"):format(unit)
        scopeTable(lines, divisor)
        engineLines(lines, addEngine(nil, before, profiler.engineMetrics()), frames.interval)
        if samples > 0 then
            local names = {}
            for name in pairs(busiest) do names[#names + 1] = name end
            table.sort(names, function(a, b) return busiest[a] > busiest[b] end)
            local parts = {}
            for index = 1, math.min(5, #names) do
                parts[index] = ("%s %.3f"):format(names[index], busiest[names[index]] / samples)
            end
            if #parts > 0 then
                lines[#lines + 1] = "  Busiest addons, ms per frame over the last 60 frames, sampled each second: "
                    .. table.concat(parts, ", ")
            end
        end
        local memoryNow = addonMemory()
        if memory and memoryNow then
            lines[#lines + 1] = ("Memory: PrettyTooltip %.1f MB, %+.1f MB during the capture; all addons %+.1f MB."):format(
                memoryNow / 1024, (memoryNow - memory) / 1024, (collectgarbage("count") - luaMemory) / 1024)
            lines[#lines + 1] = "  These include garbage not yet collected; /ptip bench measures allocation."
        end
        ns.showReport("perf", lines)
    end)
end

local function impactReport(label, frames, windows, measured, engine, reason)
    local lines = {
        ("PrettyTooltip perf ab%s: %d windows of %.1f s, PrettyTooltip on and off in turn, %.1f s after each switch left out; probes off.")
            :format(quoted(label), windows, WINDOW / 1000, SETTLE / 1000),
    }
    if reason then lines[#lines + 1] = "Stopped early: " .. reason .. "." end
    local byMode, data = {}, {}
    for _, mode in ipairs({ "on", "off" }) do
        byMode[mode] = frameClasses(frames, function(index) return frames.mode[index] == mode end)
        data[mode] = sortedCopy(byMode[mode].data.interval)
    end
    lines[#lines + 1] = ("  %-18s %6s %7s %7s  %6s %7s %7s  %8s %8s"):format("frame time ms", "on", "p50", "p95",
        "off", "p50", "p95", "p50 diff", "p95 diff")
    local medians = {}
    for _, class in ipairs(CLASSES) do
        local on, off = sortedCopy(byMode.on[class[1]].interval), sortedCopy(byMode.off[class[1]].interval)
        local on50, on95, off50, off95 = quantile(on, .5), quantile(on, .95), quantile(off, .5), quantile(off, .95)
        medians[class[1]] = on50 and off50 and on50 - off50
        lines[#lines + 1] = ("  %-18s %6d %7s %7s  %6d %7s %7s  %8s %8s"):format(class[2], #on, fmt(on50), fmt(on95),
            #off, fmt(off50), fmt(off95), fmt(medians[class[1]], "%+.2f"), fmt(on95 and off95 and on95 - off95, "%+.2f"))
    end
    local perWindow = { on = {}, off = {} }
    for window = 1, windows do
        local values = {}
        for index = 1, frames.n do
            if frames.window[index] == window and frames.data[index] > 0 then values[#values + 1] = frames.interval[index] end
        end
        local list = perWindow[window % 2 == 1 and "on" or "off"]
        if #values > 0 then list[#list + 1] = quantile(sortedCopy(values), .5) end
    end
    local function listed(values)
        local parts = {}
        for index, value in ipairs(values) do parts[index] = fmt(value) end
        return #parts > 0 and table.concat(parts, " ") or "-"
    end
    lines[#lines + 1] = ("  p50 of frames with tooltip data, by window: on %s; off %s"):format(listed(perWindow.on),
        listed(perWindow.off))
    if #data.on < 5 or #data.off < 5 then
        lines[#lines + 1] = "Result: too few frames with tooltip data to compare. Hover a tooltip that refreshes, as an"
        lines[#lines + 1] = "  item in your bags, for the whole run."
    else
        local slower, compared = 0, 0
        for _, on in ipairs(perWindow.on) do
            for _, off in ipairs(perWindow.off) do
                compared = compared + 1
                if on > off then slower = slower + 1 end
            end
        end
        local base = quantile(data.off, .5)
        lines[#lines + 1] = ("Result: frames with tooltip data took %+.2f ms (%+.0f%%) at the median with PrettyTooltip on,"):format(
            medians.data, medians.data / base * 100)
        lines[#lines + 1] = ("  slower in %d of %d window pairs; frames right after them %s ms, all others %s ms."):format(
            slower, compared, fmt(medians.after, "%+.2f"), fmt(medians.other, "%+.2f"))
    end
    if engine.on or engine.off then
        lines[#lines + 1] = "Game profiler (C_AddOnProfiler), frames over 1 / 5 / 10 / 50 ms per measured second:"
        for _, who in ipairs(WHO) do
            local parts = {}
            for _, mode in ipairs({ "on", "off" }) do
                local counts = engine[mode] and engine[mode][who[1]]
                local scale = measured[mode] > 0 and 1000 / measured[mode] or nil
                parts[#parts + 1] = mode .. " " .. (counts and scale and overCounts(counts, scale, "%.1f") or "-")
            end
            lines[#lines + 1] = ("  %-14s %s"):format(who[2], table.concat(parts, "   "))
        end
    end
    return lines
end

-- /ptip perf ab: frame times with PrettyTooltip on and off in turn, without
-- probes, while the same tooltip refreshes.
function ns.perfImpact(seconds, label)
    if busy() then return end
    if InCombatLockdown() then
        print("PrettyTooltip: /ptip perf ab runs outside combat; try again once it ends.")
        return
    end
    if not (ns.Hooks and ns.Hooks.setSuspended) then return end
    running = "/ptip perf ab"
    label = label or ""
    local windows = math.max(4, math.floor(seconds * 1000 / WINDOW / 2) * 2)
    profiler.reset()
    profiler.startFrames()
    local frames = profiler.frames
    frames.mode, frames.window = {}, {}
    local window, mode, measuring, tagged = 0, nil, false, 0
    local windowEnd, settleEnd, snapshot, snapshotAt = 0, 0, nil, 0
    local measured, engine = { on = 0, off = 0 }, {}
    local function closeWindow(now)
        if mode and snapshot then
            engine[mode] = addEngine(engine[mode], snapshot, profiler.engineMetrics())
            measured[mode] = measured[mode] + now - snapshotAt
        end
        snapshot = nil
    end
    local function finish(reason)
        sampler:SetScript("OnUpdate", nil)
        profiler.stopFrames()
        ns.Hooks.setSuspended(false)
        running = nil
        ns.showReport("perf ab", impactReport(label, frames, windows, measured, engine, reason))
    end
    sampler = sampler or CreateFrame("Frame")
    sampler:SetScript("OnUpdate", function()
        profiler.frame()
        for index = tagged + 1, frames.n do
            frames.mode[index], frames.window[index] = measuring and mode or nil, measuring and window or nil
        end
        tagged = frames.n
        local now = debugprofilestop()
        if InCombatLockdown() then
            closeWindow(now)
            finish("combat started")
        elseif now >= windowEnd then
            closeWindow(now)
            if window == windows then return finish() end
            window = window + 1
            mode = window % 2 == 1 and "on" or "off"
            ns.Hooks.setSuspended(mode == "off")
            measuring, settleEnd, windowEnd = false, now + SETTLE, now + WINDOW
        elseif not measuring and now >= settleEnd then
            measuring, snapshot, snapshotAt = true, profiler.engineMetrics(), now
        end
    end)
    print(("PrettyTooltip: comparing frames with PrettyTooltip on and off for %.0f seconds; keep hovering the same tooltip.")
        :format(windows * WINDOW / 1000))
end

-- Unnamed frames, as other addons' bag buttons, have long debug names.
local function shortName(frame)
    local name = nameOf(frame)
    if #name <= 48 then return name end
    return name:sub(1, 24) .. "..." .. name:sub(-20)
end

-- What /ptip bench refreshes: the hovered button's own tooltip update, as the
-- game runs it every .2 s, or the comparisons of a tooltip that has them.
local function benchTarget()
    for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
        if util.canModify(tooltip) and util.call(tooltip.IsShown, tooltip) == true then
            local owner = util.call(tooltip.GetOwner, tooltip)
            local refresh = tooltip == GameTooltip and util.canModify(owner) and util.readable(owner.UpdateTooltip)
            if type(refresh) == "function" then
                return { tooltip = tooltip, owner = owner, fn = refresh, arg = owner,
                    label = shortName(owner) .. ":UpdateTooltip()" }
            end
            local manager = util.readable(TooltipComparisonManager)
            if type(manager) == "table" and util.readable(manager.tooltip) == tooltip
                and type(GameTooltip_ShowCompareItem) == "function" then
                return { tooltip = tooltip, owner = owner, fn = GameTooltip_ShowCompareItem, arg = tooltip,
                    label = "GameTooltip_ShowCompareItem(" .. nameOf(tooltip) .. ")" }
            end
        end
    end
end

local function benchReport(label, target, results, scopes, refreshes, unpaired, silent, reason)
    local events = results.events
    local lines = {
        ("PrettyTooltip bench%s: %s, timed by the game (C_AddOnProfiler.MeasureCall); PrettyTooltip off and on in"):format(
            quoted(label), target.label),
        ("  turn, blocks of up to %d refreshes after %d warm-up ones. The times include the game's own work and every"):format(
            BLOCK, WARMUP),
        "  addon's hooks in the refresh.",
    }
    if reason then lines[#lines + 1] = "Stopped early: " .. reason .. "." end
    lines[#lines + 1] = ("  %-18s %7s %8s %8s %8s   %12s %8s"):format("per refresh", "count", "p10 ms", "p50 ms",
        "p90 ms", "allocated KB", "mean KB")
    local stats = {}
    for _, row in ipairs({ { "off", "PrettyTooltip off" }, { "on", "PrettyTooltip on" } }) do
        local ms, kb = sortedCopy(results[row[1]].ms), sortedCopy(results[row[1]].kb)
        stats[row[1]] = { ms = quantile(ms, .5), kb = quantile(kb, .5) }
        lines[#lines + 1] = ("  %-18s %7d %8s %8s %8s   %12s %8s"):format(row[2], #ms, fmt(quantile(ms, .1), "%.3f"),
            fmt(stats[row[1]].ms, "%.3f"), fmt(quantile(ms, .9), "%.3f"), fmt(stats[row[1]].kb, "%.1f"),
            fmt(mean(kb), "%.1f"))
    end
    if stats.on.ms and stats.off.ms then
        local added = stats.on.ms - stats.off.ms
        lines[#lines + 1] = ("Result: PrettyTooltip adds %+.3f ms (%+.0f%%) and %+.1f KB to each refresh at the median."):format(
            added, stats.off.ms > 0 and added / stats.off.ms * 100 or 0, stats.on.kb - stats.off.kb)
    end
    if #events.inside > 0 then
        local inside, insideKB = quantile(sortedCopy(events.inside), .5), quantile(sortedCopy(events.insideKB), .5)
        lines[#lines + 1] = ("  Inside PrettyTooltip's own code: %.3f ms and %.1f KB per refresh at the median, from the"):format(
            inside, insideKB)
        lines[#lines + 1] = "  game's events at each scope (separate refreshes; the events themselves add a little time)."
        local deferred = 0
        for name, total in pairs(profiler.total) do
            if name:find("^timer ") or name == "finish tooltip" then deferred = deferred + total end
        end
        if refreshes > 0 then
            lines[#lines + 1] = ("  Deferred to the next frame: %.3f ms per refresh, by PrettyTooltip's probes."):format(
                deferred / refreshes)
        end
        local count = #events.inside
        local names = {}
        for name in pairs(scopes) do names[#names + 1] = name end
        table.sort(names, function(a, b) return scopes[a].self > scopes[b].self end)
        lines[#lines + 1] = "By scope, per refresh, most own time first (own leaves out the scopes a scope calls):"
        lines[#lines + 1] = ("  %-32s %7s %9s %9s %8s %8s"):format("scope", "calls", "own ms", "total ms", "own KB",
            "total KB")
        for _, name in ipairs(names) do
            local scope = scopes[name]
            lines[#lines + 1] = ("  %-32s %7.1f %9.3f %9.3f %8.1f %8.1f"):format(name, scope.calls / count,
                scope.self / count, scope.ms / count, scope.selfBytes / 1024 / count, scope.bytes / 1024 / count)
        end
        if refreshes > 0 then
            lines[#lines + 1] = ("  Handovers per refresh: %.1f main, %.1f comparison."):format(
                (profiler.calls["data: main"] or 0) / refreshes, (profiler.calls["data: comparison"] or 0) / refreshes)
        end
    elseif silent > 0 then
        lines[#lines + 1] = "The game recorded no events, so there is no breakdown by scope."
    end
    if unpaired > 0 then
        lines[#lines + 1] = ("%d refreshes had events that did not pair up, as when another addon adds its own; they are"):format(
            unpaired)
        lines[#lines + 1] = "  left out of the breakdown."
    end
    return lines
end

-- /ptip bench: the hovered tooltip's refresh, timed by the game with
-- PrettyTooltip off, on, and on with an event at each of its scopes.
function ns.perfBench(count, label)
    if busy() then return end
    if InCombatLockdown() then
        print("PrettyTooltip: /ptip bench runs outside combat; try again once it ends.")
        return
    end
    if not profiler.canMeasure() then
        print("PrettyTooltip: the game's profiler (C_AddOnProfiler) is not available on this client.")
        return
    end
    local target = benchTarget()
    if not (target and ns.Hooks and ns.Hooks.setSuspended) then
        print("PrettyTooltip: hover an item in your bags or on your character, or one with comparisons beside it, then")
        print("  run /ptip bench.")
        return
    end
    running = "/ptip bench"
    label = label or ""
    local rounds = math.ceil(count / BLOCK)
    local size = math.ceil(count / rounds)
    local blocks = {}
    for _ = 1, rounds do
        for _, mode in ipairs({ "off", "on", "events" }) do blocks[#blocks + 1] = mode end
    end
    local results = { off = { ms = {}, kb = {} }, on = { ms = {}, kb = {} },
        events = { ms = {}, kb = {}, inside = {}, insideKB = {} } }
    local scopes, unpaired, silent, refreshes, block, step = {}, 0, 0, 0, 1, 0
    profiler.reset()
    local function finish(reason)
        sampler:SetScript("OnUpdate", nil)
        profiler.on = false
        profiler.stopEvents()
        ns.Hooks.setSuspended(false)
        running = nil
        ns.showReport("bench", benchReport(label, target, results, scopes, refreshes, unpaired, silent, reason))
    end
    sampler = sampler or CreateFrame("Frame")
    sampler:SetScript("OnUpdate", function()
        if InCombatLockdown() then return finish("combat started") end
        if util.call(target.tooltip.IsShown, target.tooltip) ~= true
            or util.call(target.tooltip.GetOwner, target.tooltip) ~= target.owner then
            return finish("the tooltip changed; keep the mouse still while it runs")
        end
        local mode = blocks[block]
        if step == 0 then
            profiler.on = mode == "events"
            if profiler.on then profiler.startEvents() else profiler.stopEvents() end
            ns.Hooks.setSuspended(mode == "off")
        end
        step = step + 1
        if mode == "events" then refreshes = refreshes + 1 end
        local measured, failure = profiler.measure(target.fn, target.arg)
        if not measured then return finish("the refresh failed (" .. tostring(failure) .. ")") end
        if step > WARMUP then
            local result = results[mode]
            result.ms[#result.ms + 1] = measured.elapsedMilliseconds
            result.kb[#result.kb + 1] = measured.allocatedBytes / 1024
            local events = mode == "events" and measured.events
            if type(events) ~= "table" or #events == 0 then
                if events ~= false then silent = silent + 1 end
            else
                local found = {}
                local paired, ms, bytes = profiler.addEvents(events, found)
                if paired then
                    for name, scope in pairs(found) do
                        local total = scopes[name]
                        if not total then
                            total = { calls = 0, ms = 0, self = 0, bytes = 0, selfBytes = 0 }
                            scopes[name] = total
                        end
                        for field, value in pairs(scope) do total[field] = total[field] + value end
                    end
                    result.inside[#result.inside + 1] = ms
                    result.insideKB[#result.insideKB + 1] = bytes / 1024
                else
                    unpaired = unpaired + 1
                end
            end
        end
        if step == WARMUP + size then
            step, block = 0, block + 1
            if block > #blocks then return finish() end
        end
    end)
    print(("PrettyTooltip: timing %d refreshes of %s with PrettyTooltip off and on; keep the mouse still."):format(
        (WARMUP + size) * rounds * 3, target.label))
end
