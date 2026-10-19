-- Shared colors by role and the rules for highlighting descriptions.
local _, ns = ...
local util = ns.util
local palette = {}
ns.Palette = palette

-- Shared tables are read-only; per-tooltip tints are built separately.
palette.roles = {
    title = { .96, .92, .84 },
    detail = { .82, .78, .71 },
    description = { .92, .87, .76 },
    caption = { .60, .57, .52 },
    neutral = { .62, .66, .74 },
    unmet = { 1, .34, .28 },
    quest = { 1, .82, 0 },
    objective = { .90, .85, .74 },
    done = { .45, .80, .40 },
    flavor = { .86, .74, .45 },
    extras = { .60, .60, .63 },
}

-- The original item tones have slightly different rounding and hand-picked
-- label shades. Keep them alongside the panel colors so defaults stay exact.
palette.SCHOOLS = {
    { key = "Arcane", label = "Arcane", color = { .92, .38, .84 }, statValue = "EB60D6", statName = "F0ADE6" },
    { key = "Fire", label = "Fire", color = { 1, .43, .11 }, statValue = "FF6D1B", statName = "EE9F72" },
    { key = "Frost", label = "Frost", color = { .30, .78, .97 }, statValue = "4CC6F7", statName = "9EDCF5" },
    { key = "Holy", label = "Holy", color = { .98, .73, .22 }, statValue = "FBBA38", statName = "F6D28A" },
    { key = "Nature", label = "Nature", color = { .50, .80, .28 }, statValue = "7FCD48", statName = "A6D783" },
    -- Lifted from a darker violet that read poorly on the panel.
    { key = "Shadow", label = "Shadow", color = { .76, .45, 1 }, statValue = "C174FF", statName = "C9A2EE" },
    { key = "Holyfire", label = "Holyfire", color = { .99, .58, .165 } },
    -- Frostfire is picked by hand: blending frost and fire gives grey.
    { key = "Frostfire", label = "Frostfire", color = { .18, .78, .72 } },
}
palette.schools = {}
local SCHOOL = {}
for _, school in ipairs(palette.SCHOOLS) do
    palette.schools[school.key] = school.color
    SCHOOL[school.key] = school
end

palette.CLASSES = {
    { key = "WARRIOR", label = "Warrior" }, { key = "PALADIN", label = "Paladin" },
    { key = "HUNTER", label = "Hunter" }, { key = "ROGUE", label = "Rogue" },
    { key = "PRIEST", label = "Priest" }, { key = "SHAMAN", label = "Shaman" },
    { key = "MAGE", label = "Mage" }, { key = "WARLOCK", label = "Warlock" },
    { key = "DRUID", label = "Druid" },
}

local function customColor(key)
    local color = ns.option and ns.option(key)
    if type(color) ~= "table" then return end
    for index = 1, 3 do
        if type(color[index]) ~= "number" or not (color[index] >= 0 and color[index] <= 1) then return end
    end
    return color
end

-- Read settings when drawing; saved variables and picker changes arrive
-- after these files load. Shared defaults are never changed by a picker.
function palette.school(name)
    local default = name and palette.schools[name]
    if default then return customColor("schoolColor" .. name) or default end
end

function palette.schoolStatColors(name)
    local color = palette.school(name)
    if not color then return end
    local school = SCHOOL[name]
    if color == school.color and school.statValue then return school.statValue, school.statName end
    local shade = {}
    for index = 1, 3 do shade[index] = color[index] + (1 - color[index]) * .45 end
    return util.hex(color), util.hex(shade)
end

function palette.classColor(classFile, game)
    if type(classFile) ~= "string" then return end
    local color = customColor("classColor" .. classFile)
    if color then return color end
    game = game or ns.Game
    if game and game.classColor then return game.classColor(classFile) end
end

-- Left to right.
local DUAL_SCHOOLS = { Frostfire = { "Frost", "Fire" }, Holyfire = { "Holy", "Fire" } }

function palette.gradient(school)
    local parts = school and DUAL_SCHOOLS[school]
    if parts then return { palette.school(parts[1]), palette.school(parts[2]) } end
end

-- Gathering's skill-up colors, by how far the player's skill is past what a
-- node or corpse needs: red below it, then orange, yellow, green, and grey.
local SKILL_UP = { { 25, { 1, .50, .25 } }, { 50, { 1, 1, 0 } }, { 100, { .25, .75, .25 } } }
local TRIVIAL = { .50, .50, .50 }

function palette.skillUpColor(level, player)
    if type(level) ~= "number" or type(player) ~= "number" then return end
    if player < level then return palette.roles.unmet end
    for _, step in ipairs(SKILL_UP) do
        if player < level + step[1] then return step[2] end
    end
    return TRIVIAL
end

local schoolNames = {}
for name in pairs(palette.schools) do schoolNames[name:lower()] = name end

-- A class spell's school comes from Data/Schools.lua, by its name. Otherwise
-- the text must name damage or spells, as "40 Fire damage" or "your Fire
-- spells", so "Fire Elementals" and "Rapid Fire" cannot change the color.
-- Spell names may supply a leading school instead.
local SCHOOL_PATTERNS = { "%f[%a](%a+)%s+damage%f[%A]", "%f[%a](%a+)%s+spells?%f[%A]" }

function palette.detectSchool(description, name)
    local known = ns.spellSchool and ns.spellSchool(name)
    if known then return known end
    for _, text in ipairs(description) do
        local plain = util.plainText(text):lower()
        -- The earliest mention wins, whichever wording it uses.
        local found, at
        for _, pattern in ipairs(SCHOOL_PATTERNS) do
            local position = 1
            while true do
                local start, stop, word = plain:find(pattern, position)
                if not start then break end
                if schoolNames[word] then
                    if not at or start < at then found, at = schoolNames[word], start end
                    break
                end
                position = stop + 1
            end
        end
        if found then return found end
    end
    local first = name and name:match("^(%a+)")
    return first and schoolNames[first:lower()] or nil
end

-- The lighter description tint shared by spells, auras, and weapon procs.
function palette.numberCode(color)
    return color and util.hex({ color[1] * .7 + .3, color[2] * .7 + .3, color[3] * .7 + .3 }) or "FFF6E4"
end
