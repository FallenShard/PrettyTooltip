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

-- Reading text the game printed from its own strings ------------------------------

-- Color codes carry no meaning, a no-break space (as French puts before a
-- colon) reads as a space, and |n is a line break.
local function normalized(text)
    text = util.uncolored(text):gsub("\194\160", " "):gsub("\226\128\175", " ")
    return (text:gsub("|n", "\n"))
end

local function escapePattern(text)
    return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- What each conversion reads: "%s" any text, "%c" the sign the game passes
-- it, and the rest a number, with either separator (see util.parseNumber).
local NUMBER = "(%-?%d[%d%.,]*)"
local SIGN = "([%+%-])"
-- French "|2 " is "de " before a consonant and "d'" before a vowel.
local DE = { "de ", "d'", "d\226\128\153" }

-- A game string such as "Requires Level %d" as the patterns that read text
-- printed from it: one per choice its grammar escapes make ("|4hour:hours;",
-- Korean "|1으로부터;로부터;", French "|2 "), as patterns have no "or". order
-- holds, for each capture, the argument it is: "%2$s %1$d emplacements"
-- captures the second argument first.
local function compileFormat(format)
    local text = util.trim(normalized(format))
    local bodies, order, count = { "" }, {}, 0
    local function append(choices)
        local grown = {}
        for _, body in ipairs(bodies) do
            for _, choice in ipairs(choices) do grown[#grown + 1] = body .. choice end
        end
        bodies = grown
    end
    local pos = 1
    while pos <= #text do
        if text:sub(pos, pos) == "%" then
            local _, positional, index = text:find("^%%(%d+)%$", pos)
            local _, stop, kind = text:find("^[%-%+ #0]*%d*%.?%d*([%%sdicfgFu])", (positional or pos) + 1)
            if not stop or kind == "%" then
                append({ "%%" })
                pos = (stop or pos) + 1
            else
                local argument = tonumber(index) or #order + 1
                order[#order + 1] = argument
                count = math.max(count, argument)
                append({ kind == "s" and "(.-)" or kind == "c" and SIGN or NUMBER })
                pos = stop + 1
            end
        elseif text:find("^|4[^;]*;", pos) then
            local _, stop, forms = text:find("^|4([^;]*);", pos)
            local choices = {}
            for form in (forms .. ":"):gmatch("(.-):") do choices[#choices + 1] = escapePattern(form) end
            append(choices)
            pos = stop + 1
        elseif text:find("^|1[^;]*;[^;]*;", pos) then
            local _, stop, first, second = text:find("^|1([^;]*);([^;]*);", pos)
            append({ escapePattern(first), escapePattern(second) })
            pos = stop + 1
        elseif text:find("^|2", pos) then
            local _, stop = text:find("^|2 ?", pos)
            append(DE)
            pos = stop + 1
        else
            local stop = (text:find("[%%|]", pos + 1) or #text + 1) - 1
            append({ escapePattern(text:sub(pos, stop)) })
            pos = stop + 1
        end
    end
    local patterns = {}
    for index, body in ipairs(bodies) do patterns[index] = "^" .. body .. "$" end
    return { patterns = patterns, order = order, count = count }
end

local compiledFormats = {}

-- What the game's string format filled in to print text, in the order of its
-- arguments: util.unformat("Durability 34 / 100", DURABILITY_TEMPLATE) gives
-- "34", "100". true when it matches and has nothing to fill in; nil when the
-- text was not printed from it. Colors and the space around the text do not count.
function util.unformat(text, format)
    if type(text) ~= "string" or type(format) ~= "string" then return end
    local compiled = compiledFormats[format]
    if not compiled then
        compiled = compileFormat(format)
        compiledFormats[format] = compiled
    end
    text = util.trim(normalized(text))
    for _, pattern in ipairs(compiled.patterns) do
        local found = { text:match(pattern) }
        if found[1] then
            if compiled.count == 0 then return true end
            local values = {}
            for index, argument in ipairs(compiled.order) do values[argument] = found[index] end
            return unpack(values, 1, compiled.count)
        end
    end
end

-- The game's string format printed with values as text, kept as they were
-- printed: util.fill(SPELL_DURATION_SEC, "2.5") gives "2.5 sec", where
-- string.format would give "2.5" a precision of its own. A plural escape
-- takes the form its number asks for.
function util.fill(format, ...)
    local values, next = { ... }, 0
    local text = format:gsub("%%([%d%$%-%+ #%.]*)([%%sdicfgFu])", function(spec, kind)
        if kind == "%" then return "%" end
        local index = tonumber(spec:match("^(%d+)%$"))
        if not index then
            next = next + 1
            index = next
        end
        return tostring(values[index] or "")
    end)
    return resolvePlurals(text)
end

-- Whether the text opens with a label the game puts first, as "Use:". Colors
-- and the space around the label do not count.
function util.startsWith(text, label)
    if type(text) ~= "string" or type(label) ~= "string" then return false end
    label = util.trim(normalized(label))
    return label ~= "" and normalized(text):sub(1, #label) == label
end

-- A number as the client printed it. group is the client's group separator
-- (LARGE_NUMBER_SEPERATOR): "," on enUS, "." on deDE, none on frFR. Only a
-- group separator before three digits is one; any other "." or "," is the
-- decimal point, so "1.5" that Lua printed on a German client reads too.
function util.parseNumber(text, group)
    if type(text) ~= "string" then return end
    local number = text:match("^%s*([%+%-]?[%d%.,]*%d)%s*$")
    if not number then return end
    if group == "." or group == "," then
        number = number:gsub("%" .. group .. "(%d%d%d)%f[^%d]", "%1")
    end
    return tonumber((number:gsub(",", ".")))
end

-- Values the game may hide ------------------------------------------------------

-- The value, or nil when the game hides it.
function util.readable(value)
    if isSecret(value) then return nil end
    return value
end

-- The value when it is a number the game did not hide, else nil.
function util.number(value)
    if not isSecret(value) and type(value) == "number" then return value end
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
