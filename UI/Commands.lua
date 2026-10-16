-- Slash-command parsing and dispatch, registered by the entry file.
local _, ns = ...

-- Prints the shown tooltip's raw data, to see what a type of tooltip carries.
local function dumpTooltip()
    -- A clicked chat link opens in its own tooltip.
    local tooltip = GameTooltip:IsShown() and GameTooltip or ItemRefTooltip
    if not (tooltip and tooltip:IsShown()) then
        print("PrettyTooltip: hover something first; there is no tooltip to dump.")
        return
    end
    -- Who filled it, to tell which frame or addon a lines-only tooltip is from.
    local owner = tooltip:GetOwner()
    print("PrettyTooltip dump: owned by " .. tostring(owner and owner.GetDebugName and owner:GetDebugName() or owner))
    local data = tooltip.GetTooltipData and tooltip:GetTooltipData()
    if type(data) ~= "table" then
        -- Filled by an addon with lines alone, as Questie's quest links.
        print("PrettyTooltip dump: no tooltip data; the lines shown:")
        for index = 1, tooltip:NumLines() do
            local left = _G[tooltip:GetName() .. "TextLeft" .. index]
            local right = _G[tooltip:GetName() .. "TextRight" .. index]
            local text = (left and left:GetText() or "") .. (right and right:GetText() and "  ||  " .. right:GetText() or "")
            print(index .. ". " .. text:gsub("|", "||"))
        end
        return
    end
    local function names(enum)
        local found = {}
        for name, value in pairs(enum or {}) do found[value] = name end
        return found
    end
    local types, lineTypes = names(Enum.TooltipDataType), names(Enum.TooltipDataLineType)
    local function show(value)
        if type(value) == "table" and value.GenerateHexColor then return "#" .. value:GenerateHexColor() end
        if type(value) == "table" then return "{...}" end
        return tostring(value)
    end
    local fields = {}
    for key, value in pairs(data) do
        if key ~= "lines" then fields[#fields + 1] = key .. "=" .. show(value) end
    end
    print("PrettyTooltip dump: " .. tostring(types[data.type] or data.type) .. "  " .. table.concat(fields, "  "))
    for index, line in ipairs(data.lines or {}) do
        local parts = {}
        for key, value in pairs(line) do
            if key ~= "type" then parts[#parts + 1] = key .. "=" .. show(value) end
        end
        table.sort(parts)
        print(index .. ". " .. tostring(lineTypes[line.type] or line.type) .. "  " .. table.concat(parts, "  "))
    end
end

local function handleCommand(message)
    local wanted = (message or ""):match("^%s*(.-)%s*$"):lower()
    if wanted == "perf" then
        if ns.perfCapture then ns.perfCapture(5) end
        return
    end
    if wanted == "anchors" then
        if ns.dumpAnchors then pcall(ns.dumpAnchors) end
        return
    end
    if wanted == "pixel" then
        if ns.dumpPixel then pcall(ns.dumpPixel) end
        return
    end
    -- /ptip capture <name>, list, or clear: tooltips saved as test fixtures.
    local command, argument = wanted:match("^(%S+)%s*(.-)$")
    if command == "capture" and ns.capture then
        if argument == "list" then
            ns.listCaptures()
        elseif argument == "clear" then
            ns.clearCaptures()
        else
            ns.capture(argument)
        end
        return
    end
    if wanted == "dump" then
        -- Secret values cannot be printed in some situations.
        local ok, problem = pcall(dumpTooltip)
        if not ok then print("PrettyTooltip: this tooltip cannot be read right now (" .. tostring(problem) .. ").") end
        return
    end
    if wanted ~= "options" and ns.openEditor then
        ns.openEditor()
    else
        ns.openSettings()
    end
end

ns.Commands = {}
local commandsRegistered = false
function ns.Commands.register()
    if commandsRegistered then return end
    commandsRegistered = true
    SLASH_PRETTYTOOLTIP1 = "/prettytooltip"
    SLASH_PRETTYTOOLTIP2 = "/ptip"
    SlashCmdList.PRETTYTOOLTIP = handleCommand
end
