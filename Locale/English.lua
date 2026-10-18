-- What the game has no string for, as the English client words it. A client
-- in another language loads its own file after this one, which replaces the
-- entries its language words otherwise; any it leaves out stay English.
local _, ns = ...
local locale = ns.Locale

local formats = locale.formats
-- Right of a weapon's damage: "Speed 3.20".
formats.weaponSpeed = "Speed %s"
-- A recipe's own effect: "Use: Teaches you how to make a Copper Chain Belt."
formats.recipeTeaches = "Use: Teaches you how to %s"
-- Lines about an item's appearance, kept in the footer.
formats.appearance = "Appearance %s"
-- A kind of item, shown in its subtitle.
formats.scarce = "Scarce"

-- The client's SkillLine names.
for _, name in ipairs({ "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Leatherworking", "Tailoring",
    "Cooking", "First Aid", "Fishing", "Mining", "Herbalism", "Skinning", "Jewelcrafting", "Inscription" }) do
    locale.professions[name] = true
end
