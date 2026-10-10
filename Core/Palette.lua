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
    Shadow = { .64, .31, .89 },
}
-- Holyfire uses a blend of the Holy and Fire hues.
local holy, fire = palette.schools.Holy, palette.schools.Fire
palette.schools.Holyfire = { (holy[1] + fire[1]) / 2, (holy[2] + fire[2]) / 2, (holy[3] + fire[3]) / 2 }

local schoolNames = {}
for name in pairs(palette.schools) do schoolNames[name:lower()] = name end

-- A school must describe damage, so "Fire Elementals" and "Rapid Fire"
-- cannot change the color. Spell names may supply a leading school instead.
function palette.detectSchool(description, name)
    for _, text in ipairs(description) do
        for word in util.plainText(text):lower():gmatch("%f[%a](%a+)%s+damage%f[%A]") do
            if schoolNames[word] then return schoolNames[word] end
        end
    end
    local first = name and name:match("^(%a+)")
    return first and schoolNames[first:lower()] or nil
end

-- The lighter description tint shared by spells, auras, and weapon procs.
function palette.numberCode(color)
    return color and util.hex({ color[1] * .7 + .3, color[2] * .7 + .3, color[3] * .7 + .3 }) or "FFF6E4"
end
