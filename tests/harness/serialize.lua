-- Deterministic text from Lua values. lua() writes Lua source that reads back
-- exactly, for fixtures; dump() writes indented "key: value" lines that people
-- read and diff, for the expected outputs. Keys are sorted, numbers before
-- strings, and functions, userdata, and cycles are left out.
local serialize = {}

local KEYWORDS = {}
for word in ([[and break do else elseif end false for function if in local nil not or repeat return
    then true until while]]):gmatch("%a+") do KEYWORDS[word] = true end

local function sortedKeys(t)
    local keys = {}
    for key in pairs(t) do
        local kind = type(key)
        if kind == "number" or kind == "string" or kind == "boolean" then keys[#keys + 1] = key end
    end
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then return ta < tb end
        if ta == "boolean" then return not a and b end
        return a < b
    end)
    return keys
end

-- A table whose keys are exactly 1..n.
local function isSequence(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    for index = 1, count do
        if t[index] == nil then return false end
    end
    return true
end

local function quote(text)
    return (string.format("%q", text):gsub("\\\n", "\\n"):gsub("\r", "\\r"))
end

local function number(value, precise)
    if value == math.floor(value) and math.abs(value) < 2 ^ 53 then return string.format("%d", value) end
    return string.format(precise and "%.17g" or "%.4g", value)
end

local function lua(value, indent, seen)
    local kind = type(value)
    if kind == "string" then return quote(value) end
    if kind == "number" then return number(value, true) end
    if kind == "boolean" or kind == "nil" then return tostring(value) end
    if kind ~= "table" or seen[value] then return "nil" end
    seen[value] = true
    local inner = indent .. "    "
    local parts = {}
    if isSequence(value) then
        for _, item in ipairs(value) do parts[#parts + 1] = inner .. lua(item, inner, seen) .. "," end
    else
        for _, key in ipairs(sortedKeys(value)) do
            local name = type(key) == "string" and key:match("^[%a_][%w_]*$") and not KEYWORDS[key]
                and key or ("[" .. lua(key, inner, seen) .. "]")
            parts[#parts + 1] = inner .. name .. " = " .. lua(value[key], inner, seen) .. ","
        end
    end
    seen[value] = nil
    if #parts == 0 then return "{}" end
    return "{\n" .. table.concat(parts, "\n") .. "\n" .. indent .. "}"
end

function serialize.lua(value)
    return lua(value, "", {})
end

local function dump(value, indent, out, seen)
    for _, key in ipairs(sortedKeys(value)) do
        local item = value[key]
        local kind = type(item)
        local label = indent .. tostring(key) .. ":"
        if kind == "table" then
            if seen[item] then
                out[#out + 1] = label .. " (cycle)"
            elseif next(item) == nil then
                out[#out + 1] = label .. " {}"
            else
                out[#out + 1] = label
                seen[item] = true
                dump(item, indent .. "  ", out, seen)
                seen[item] = nil
            end
        elseif kind == "string" then
            out[#out + 1] = label .. " " .. quote(item)
        elseif kind == "number" then
            out[#out + 1] = label .. " " .. number(item, false)
        elseif kind == "boolean" then
            out[#out + 1] = label .. " " .. tostring(item)
        end
    end
end

function serialize.dump(value)
    if type(value) ~= "table" then return tostring(value) end
    local out = {}
    dump(value, "", out, {})
    return table.concat(out, "\n")
end

return serialize
