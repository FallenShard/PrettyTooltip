-- Debug commands: /ptip anchors, /ptip perf, and /ptip pixel. Each shows its
-- findings in the report window, to copy into a bug report.
local addonName, ns = ...
local ui = ns.ui
if not ui then return end

local isSecret = ns.util.isSecret
local util = ns.util
local panels, perf = ui.panels, ui.perf

-- /ptip anchors: where each shown panel sits, left to right, and how its
-- hidden tooltip is anchored.
function ns.dumpAnchors()
    local shown = {}
    for tooltip, panel in pairs(panels) do
        if util.canModify(tooltip) and panel:IsShown() then
            local left, right = util.number(panel:GetLeft()), util.number(panel:GetRight())
            local nativeLeft, nativeRight = util.number(tooltip:GetLeft()), util.number(tooltip:GetRight())
            if left and right and nativeLeft and nativeRight then
                shown[#shown + 1] = { tooltip = tooltip, panel = panel,
                    left = left, right = right, nativeLeft = nativeLeft, nativeRight = nativeRight }
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
    local lines = {}
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
    if not (width and height and scale) then ns.showReport("pixel", { "Screen geometry is restricted." }); return end
    ns.showReport("pixel", { ("Snapping with %s; screen %dx%d, UI scale %.3f, one pixel = %.4f units."):format(
        native and "the game's PixelUtil" or "the addon's own math", width, height, scale, ui.pixel(UIParent)) })
end

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

function ns.perfCapture(seconds)
    perf.calls, perf.time, perf.on = {}, {}, true
    local memory = collectgarbage("count")
    local own = addonMemory()
    print("PrettyTooltip: measuring for " .. seconds .. " seconds; keep the tooltip open.")
    C_Timer.After(seconds, function()
        perf.on = false
        local names, counts = {}, {}
        for name, calls in pairs(perf.calls) do
            if perf.time[name] then
                names[#names + 1] = name
            else
                counts[#counts + 1] = name .. " " .. calls
            end
        end
        table.sort(names, function(a, b) return perf.time[a] > perf.time[b] end)
        table.sort(counts)
        local lines = { string.format("PrettyTooltip perf over %d s:", seconds) }
        local ownNow = addonMemory()
        if own and ownNow then
            lines[#lines + 1] = string.format("  memory: %.0f KB, %+.0f KB over the run", ownNow, ownNow - own)
        end
        lines[#lines + 1] = string.format("  all addons' Lua memory: %+.0f KB over the run",
            collectgarbage("count") - memory)
        if #counts > 0 then lines[#lines + 1] = "  counts: " .. table.concat(counts, ", ") end
        for _, name in ipairs(names) do
            lines[#lines + 1] = string.format("  %s: %d calls (%.0f/s), %.1f ms", name, perf.calls[name],
                perf.calls[name] / seconds, perf.time[name] or 0)
        end
        ns.showReport("perf", lines)
    end)
end
