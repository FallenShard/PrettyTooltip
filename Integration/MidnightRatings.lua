-- Read the text MidnightRatings has already produced on Blizzard tooltip lines.
-- MidnightRatings exposes no public Convert API; do not duplicate its formulas.
local _, ns = ...
local bridge = {}
ns.MidnightRatingsBridge = bridge

local function safeString(value)
    return type(value) == "string" and not ns.util.isSecret(value)
end

local function nativeText(tooltip, index, right)
    if not tooltip or type(index) ~= "number" or index < 1 then return end
    local ok, font = pcall(function()
        if right then
            if tooltip.GetRightLine then return tooltip:GetRightLine(index) end
            local name = tooltip:GetName()
            return name and _G[name .. "TextRight" .. index]
        end
        if tooltip.GetLeftLine then return tooltip:GetLeftLine(index) end
        local name = tooltip:GetName()
        return name and _G[name .. "TextLeft" .. index]
    end)
    if not ok or not font or not font.GetText then return end
    local good, text = pcall(font.GetText, font)
    if good and safeString(text) then return text end
end

local function stripped(text)
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

-- Only take an already converted line when it is recognizably the same stat.
-- Avoid borrowing text from a different tooltip line or replacing set bonuses.
function bridge.Convert(text, _, _, _, index, tooltip, right)
    if not safeString(text) then return text end
    if not IsAddOnLoaded and not C_AddOns then return text end
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("MidnightRatings"))
        or (IsAddOnLoaded and IsAddOnLoaded("MidnightRatings"))
    if not loaded then return text end
    local rendered = nativeText(tooltip, index, right)
    if not rendered or rendered == text then return text end
    local original = stripped(text)
    local candidate = stripped(rendered)
    if not original:find("%d") or not candidate:find("%%") then return text end
    -- MidnightRatings APPEND/REPLACE both retain the stat name.
    local stat = original:gsub("[%d%.,%+%-%s%%]", "")
    if #stat < 2 or not candidate:find(stat, 1, true) then return text end
    return rendered
end
