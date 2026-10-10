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

-- Without color codes.
function util.uncolored(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Without color codes or inline textures.
function util.plainText(text)
    return (text:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
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
