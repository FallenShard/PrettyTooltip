-- Shared spell-school colors and the rules for highlighting descriptions.
local _, ns = ...
local util = ns.util
local palette = {}
ns.Palette = palette

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

-- The lighter school tint used by spell descriptions; neutral when unknown.
function palette.numberCode(school)
    local color = school and palette.schools[school]
    return color and util.hex({ color[1] * .7 + .3, color[2] * .7 + .3, color[3] * .7 + .3 }) or "FFF6E4"
end
