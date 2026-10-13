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

palette.schools = {
    Arcane = { .92, .38, .84 },
    Fire = { 1, .43, .11 },
    Frost = { .30, .78, .97 },
    Holy = { .98, .73, .22 },
    Nature = { .50, .80, .28 },
    -- Lifted from a darker violet that read poorly on the panel.
    Shadow = { .76, .45, 1 },
}
-- Frostfire is picked by hand: blending frost and fire gives grey.
palette.schools.Holyfire = { .99, .58, .165 }
palette.schools.Frostfire = { .18, .78, .72 }

-- Left to right.
local DUAL_SCHOOLS = { Frostfire = { "Frost", "Fire" }, Holyfire = { "Holy", "Fire" } }

function palette.gradient(school)
    local parts = school and DUAL_SCHOOLS[school]
    if parts then return { palette.schools[parts[1]], palette.schools[parts[2]] } end
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
    local known = name and ns.spellSchools and ns.spellSchools[name]
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
