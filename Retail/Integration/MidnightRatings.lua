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
-- Use the addon's saved, character-level-specific conversion rates only as a
-- fallback when its native tooltip callback has not populated a converted line.
-- Do not use static level-90 constants on low-level characters.
local function savedRateFallback(text)
    local db = MidnightRatingsDB
    if type(db) ~= "table" then return end
    if text:find("%%") then return end
    if db.enableItems == false then return end

    local specs = {
        { CR_CRIT_MELEE, ITEM_MOD_CRIT_RATING_SHORT },
        { CR_HASTE_MELEE, ITEM_MOD_HASTE_RATING_SHORT },
        { CR_MASTERY, ITEM_MOD_MASTERY_RATING_SHORT },
        { CR_VERSATILITY_DAMAGE_DONE, ITEM_MOD_VERSATILITY },
    }
    local plain = stripped(text)
    local amount, tail = plain:match("^%s*%+([%d,%.]+)%s*(.-)%s*$")
    if not amount then return end
    local value = tonumber((amount:gsub(",", "")))
    if not value then return end

    for _, spec in ipairs(specs) do
        local id, stat = spec[1], spec[2]
        if type(stat) == "string" and stat ~= "" and tail == stat then
            -- Use MidnightRatings' saved, level-dependent rate when present.
            -- When it has not saved a rate yet, derive the live character's
            -- rating/bonus; never use a fixed max-level conversion constant.
            local rate = type(db.savedRates) == "table" and db.savedRates[id]
            if (type(rate) ~= "number" or rate <= 0) and
                type(GetCombatRating) == "function" and
                type(GetCombatRatingBonus) == "function" then
                local ok, rating, bonus = pcall(function()
                    return GetCombatRating(id), GetCombatRatingBonus(id)
                end)
                if ok and type(rating) == "number" and type(bonus) == "number" and
                    rating > 0 and bonus > 0 then
                    rate = rating / bonus
                end
            end
            if type(rate) ~= "number" or rate <= 0 then return end
            local percent = value / rate
            local pct = (id == CR_VERSATILITY_DAMAGE_DONE and db.splitVersatility)
                and string.format("%.2f%%/%.2f%%", percent, percent / 2)
                or string.format("%.2f%%", percent)
            if db.displayMode == "REPLACE" then
                return "+" .. pct .. " " .. stat .. (db.showRating and (" (" .. amount .. ")") or "")
            end
            return text .. " (" .. pct .. ")"
        end
    end
end

function bridge.Convert(text, _, _, _, index, tooltip, right)
    if not safeString(text) then return text end
    if not IsAddOnLoaded and not C_AddOns then return text end
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("MidnightRatings"))
        or (IsAddOnLoaded and IsAddOnLoaded("MidnightRatings"))
    if not loaded then return text end
    local rendered = nativeText(tooltip, index, right)
    -- MidnightRatings stores its post-processed line text on the tooltip.
    -- It can be newer than the font string when the tooltip is being rebuilt.
    local cache = tooltip and tooltip.MR_Cache
    if cache and type(index) == "number" then
        local saved = right and cache.textR and cache.textR[index] or cache.textL and cache.textL[index]
        if safeString(saved) and saved:find("%", 1, true) then rendered = saved end
    end
    if not rendered or rendered == text then return savedRateFallback(text) or text end
    local original = stripped(text)
    local candidate = stripped(rendered)
    if not original:find("%d") or not candidate:find("%%") then return savedRateFallback(text) or text end
    -- MidnightRatings APPEND/REPLACE both retain the stat name.
    local stat = original:gsub("[%d%.,%+%-%s%%]", "")
    if #stat < 2 or not candidate:find(stat, 1, true) then return savedRateFallback(text) or text end
    return rendered
end


-- Temporary in-game diagnostic. No conversion or rendering behavior is changed.
SLASH_PRETTYTOOLTIPMRDEBUG1 = "/ptipmrdebug"
SlashCmdList.PRETTYTOOLTIPMRDEBUG = function()
    local function say(msg) print("|cff33ccff[PrettyTooltip MR]|r " .. tostring(msg)) end
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("MidnightRatings"))
        or (IsAddOnLoaded and IsAddOnLoaded("MidnightRatings"))
    say("bridge=loaded, MidnightRatings=" .. tostring(loaded))
    local db = MidnightRatingsDB
    say("DB=" .. type(db) .. ", mode=" .. tostring(db and db.displayMode) .. ", enableItems=" .. tostring(db and db.enableItems))
    local stats = {
        {"Crit", CR_CRIT_MELEE, ITEM_MOD_CRIT_RATING_SHORT},
        {"Haste", CR_HASTE_MELEE, ITEM_MOD_HASTE_RATING_SHORT},
        {"Mastery", CR_MASTERY, ITEM_MOD_MASTERY_RATING_SHORT},
        {"Vers", CR_VERSATILITY_DAMAGE_DONE, ITEM_MOD_VERSATILITY},
    }
    for _, st in ipairs(stats) do
        local name, id, label = st[1], st[2], st[3]
        local saved = db and db.savedRates and db.savedRates[id]
        local ok, rating, bonus = pcall(function() return GetCombatRating(id), GetCombatRatingBonus(id) end)
        local sample = "+105 " .. tostring(label)
        local converted = bridge.Convert(sample)
        say(name .. " id=" .. tostring(id) .. " label=" .. tostring(label)
            .. " saved=" .. tostring(saved) .. " rating=" .. tostring(ok and rating or "error")
            .. " bonus=" .. tostring(ok and bonus or "error"))
        say("test " .. sample .. " => " .. tostring(converted))
    end
    local tt = GameTooltip
    say("GameTooltip lines=" .. tostring(tt and tt.NumLines and tt:NumLines())
        .. " MR_Cache=" .. tostring(tt and tt.MR_Cache ~= nil))
    if tt and tt.GetName and tt.NumLines then
        local n = math.min(tt:NumLines() or 0, 25)
        for i = 1, n do
            local name = tt:GetName()
            local fs = name and _G[name .. "TextLeft" .. i]
            local ok, value = pcall(function() return fs and fs:GetText() end)
            if ok and type(value) == "string" and not ns.util.isSecret(value)
                and (value:find("+", 1, true) or value:find("%%")) then
                say("tooltip line " .. i .. ": " .. value)
            end
        end
    end
end
