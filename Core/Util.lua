-- Small helpers the other files share, as ns.util. Loads first. They read only
-- their arguments, apart from issecretvalue, the game's test for a value it
-- hides.
local _, ns = ...
local util = {}
ns.util = util

-- True for a value the game hides, which cannot be compared, counted, or shown.
util.isSecret = issecretvalue or function() return false end
local isSecret = util.isSecret

-- A function's results as a table, with their count in n, nils included.
function util.pack(...)
    return { n = select("#", ...), ... }
end

-- Text ------------------------------------------------------------------------

function util.trim(text)
    return text:match("^%s*(.-)%s*$")
end

-- Sentences end at . ! or ? followed by a space and a capital, so decimals
-- such as "1.5 sec" stay whole.
function util.splitSentences(text)
    local sentences = {}
    for paragraph in (text:gsub("\r?\n", "|n") .. "|n"):gmatch("(.-)|n") do
        local from = 1
        while true do
            local stop, resume = paragraph:find("[%.!?]%s+%f[%u]", from)
            if not stop then break end
            sentences[#sentences + 1] = util.trim(paragraph:sub(from, stop))
            from = resume + 1
        end
        local rest = util.trim(paragraph:sub(from))
        if rest ~= "" then sentences[#sentences + 1] = rest end
    end
    return sentences
end

-- Without color codes.
function util.uncolored(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Without color codes or inline textures.
function util.plainText(text)
    return (text:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- The game's own escapes; digits inside them (color codes, icon sizes, the
-- plural escape "|4hour:hrs;") must not be recolored.
local ESCAPES = { "|c%x%x%x%x%x%x%x%x", "|r", "|T.-|t", "|A.-|a", "|H.-|h", "|K.-|k", "|4[^;]*;", "|n" }

-- "1 |4hour:hrs;" picks its word from the number before it. Coloring that
-- number would separate the two, so resolve the escape first: singular for 1.
local function resolvePlurals(text)
    return (text:gsub("(%d+)(%s*)|4([^:;]*):([^;]*);", function(number, space, one, many)
        return number .. space .. (tonumber(number) == 1 and one or many)
    end))
end

local function colorPlainNumbers(text, code)
    -- A number must start a word, so "x2" is left alone; a sentence's final
    -- period stays outside the color.
    return (text:gsub("%f[%w](%d+%.?%d*%%?)", function(number)
        local trailing = ""
        if number:sub(-1) == "." then number, trailing = number:sub(1, -2), "." end
        return "|cff" .. code .. number .. "|r" .. trailing
    end))
end

function util.colorNumbers(text, code)
    text = resolvePlurals(text)
    local out, plainStart, pos = {}, 1, 1
    while true do
        local bar = text:find("|", pos, true)
        if not bar then break end
        local escapeEnd
        for _, pattern in ipairs(ESCAPES) do
            local _, stop = text:find("^" .. pattern, bar)
            if stop then escapeEnd = stop break end
        end
        -- An escape this list does not know still protects its first character.
        escapeEnd = escapeEnd or math.min(bar + 1, #text)
        out[#out + 1] = colorPlainNumbers(text:sub(plainStart, bar - 1), code)
        out[#out + 1] = text:sub(bar, escapeEnd)
        plainStart, pos = escapeEnd + 1, escapeEnd + 1
    end
    out[#out + 1] = colorPlainNumbers(text:sub(plainStart), code)
    return table.concat(out)
end

-- Values the game may hide ------------------------------------------------------

-- The value, or nil when the game hides it.
function util.readable(value)
    if isSecret(value) then return nil end
    return value
end

-- A line's text: "" for none, nil when hidden or not text.
function util.safeText(value)
    if isSecret(value) then return nil end
    if value == nil then return "" end
    if type(value) ~= "string" then return nil end
    return value
end

-- Calls fn and gives back up to four of its results; nothing when fn is
-- missing, fails, or any of them is hidden.
function util.call(fn, ...)
    if not fn then return end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok or isSecret(a) or isSecret(b) or isSecret(c) or isSecret(d) then return end
    return a, b, c, d
end

-- Colors ------------------------------------------------------------------------

-- A color from the game (r, g, and b fields) as a plain { r, g, b }; nil when
-- hidden or not a color.
function util.rgb(color)
    if isSecret(color) or type(color) ~= "table" then return end
    local r, g, b = color.r, color.g, color.b
    if isSecret(r) or isSecret(g) or isSecret(b) or type(r) ~= "number" then return end
    return { r, g, b }
end

-- "RRGGBB" for a { r, g, b } color, each part capped at 1.
function util.hex(color)
    local function byte(value) return math.floor(math.min(1, value) * 255 + .5) end
    return string.format("%02X%02X%02X", byte(color[1]), byte(color[2]), byte(color[3]))
end
