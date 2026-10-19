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
-- A spell's cost as a share of the caster's base mana: "15% of base mana".
formats.baseManaCost = "%d%% of base mana"
-- The talent window's line for a talent deeper in its tree than the points spent.
formats.talentPoints = "Spend %d more |4point:points; in %s"
-- Ranks a unit's level line names, as "Level 30 (Rare Elite)"; the game's
-- BOSS and ELITE name the others.
formats.rare = "Rare"
formats.rareElite = "Rare Elite"

-- How spell descriptions word what the spell power rows read, each spell in
-- its own text, so the game has no strings for these. In lower case.
locale.descriptions = {
    -- An amount from one number to another: "causes 135 to 154 damage".
    range = "%d to %d",
    -- An amount over the whole of a duration: "40 damage over 15 sec".
    over = "over %d sec",
    -- An amount each tick: "each second for 5 sec", "every 2 sec for 10 sec",
    -- or "every 3 sec. Lasts 15 sec."
    eachSecond = "each second for %d sec",
    every = "every %d sec",
    everyFor = "for %d sec",
    lasts = "lasts %d sec",
    -- Words after a number that make it a duration, distance, chance, or
    -- count, not an amount: "15 sec", "30 yd", "5 targets".
    units = { "sec", "min", "hour", "yd", "yard", "ft", "time", "target", "charge", "stack" },
    -- How a description names a school (schoolWords): "40 Fire damage", "your Fire spells".
    school = { "%s damage", "%s spell", "%s spells" },
    -- Words that say a spell heals, unlike "health".
    heals = { "heal", "heals", "healed", "healing" },
}
-- The schools by the words descriptions name them with.
locale.schoolWords = { Arcane = "Arcane", Fire = "Fire", Frost = "Frost", Holy = "Holy", Nature = "Nature",
    Shadow = "Shadow", Holyfire = "Holyfire", Frostfire = "Frostfire" }

-- What joins the parts of a list, as an enchant's name lists its stats:
-- "Stamina +2 and Armor +16". The longer first.
locale.listSeparators = { ", and ", " and ", ", " }

-- Older items' equip wordings. A wording with no stat takes it from its word.
locale.statWordings = {
    { "Equip: +%d Attack Power when fighting %s.", "ATTACK_POWER_VS", "creature" },
    { "Equip: Increases attack power by %d when fighting %s.", "ATTACK_POWER_VS", "creature" },
    { "Equip: Increases attack power by %d against %s.", "ATTACK_POWER_VS", "creature" },
    { "Equip: +%d Spell Power.", "SPELL_POWER" },
    { "Equip: +%d Spell Damage.", "SPELL_DAMAGE" },
    { "Equip: +%d Healing Power.", "HEALING_POWER" },
    { "Equip: Increases spell damage and healing by up to %d.", "SPELL_POWER" },
    { "Equip: Increases damage and healing done by spells and effects by up to %d.", "SPELL_POWER" },
    { "Equip: Increases healing done by spells and effects by up to %d.", "HEALING_POWER" },
    { "Equip: Increases healing done by up to %d for all magical spells and effects.", "HEALING_POWER" },
    { "Equip: Increases spell damage by up to %d.", "SPELL_DAMAGE" },
    { "Equip: Increases your %s rating by %d.", nil, "rating" },
    { "Equip: Improves %s rating by %d.", nil, "rating" },
    { "Equip: Increases your %s by %d.", nil, "attribute" },
    { "Equip: Increases %s by %d.", nil, "attribute" },
    { "Equip: Increases your chance to hit by %s%%.", "HIT_CHANCE" },
    { "Equip: Improves your chance to hit with spells by %s%%.", "SPELL_HIT_CHANCE" },
    { "Equip: Increases your chance to hit with spells by %s%%.", "SPELL_HIT_CHANCE" },
    { "Equip: Improves your chance to get a critical strike with spells by %s%%.", "SPELL_CRIT_CHANCE" },
    { "Equip: Increases your defense skill by %d.", "DEFENSE_SKILL" },
    { "Equip: Restores %d mana per 5 seconds.", "MANA_REGEN" },
    { "Equip: Restores %d health per 5 seconds.", "HEALTH_REGEN" },
    { "Equip: Decreases the magical resistances of your spell targets by %d.", "SPELL_PENETRATION" },
}
-- The words those wordings name a stat or a creature type with, in lower case.
locale.statWords = {
    rating = {
        ["hit"] = "HIT_RATING", ["spell hit"] = "SPELL_HIT_RATING", ["critical strike"] = "CRIT_RATING",
        ["spell critical strike"] = "SPELL_CRIT_RATING", ["haste"] = "HASTE_RATING",
        ["spell haste"] = "SPELL_HASTE_RATING", ["defense"] = "DEFENSE_RATING", ["dodge"] = "DODGE_RATING",
        ["parry"] = "PARRY_RATING", ["block"] = "BLOCK_RATING", ["resilience"] = "RESILIENCE_RATING",
        ["expertise"] = "EXPERTISE_RATING",
    },
    attribute = {
        ["strength"] = "STRENGTH", ["agility"] = "AGILITY", ["stamina"] = "STAMINA", ["intellect"] = "INTELLECT",
        ["spirit"] = "SPIRIT", ["armor"] = "ARMOR", ["attack power"] = "ATTACK_POWER",
        ["ranged attack power"] = "RANGED_ATTACK_POWER", ["spell power"] = "SPELL_POWER",
        ["spell penetration"] = "SPELL_PENETRATION", ["all stats"] = "ALL_STATS",
    },
    creature = {
        ["beasts"] = "BEAST", ["demons"] = "DEMON", ["dragonkin"] = "DRAGONKIN", ["elementals"] = "ELEMENTAL",
        ["giants"] = "GIANT", ["humanoids"] = "HUMANOID", ["mechanical units"] = "MECHANICAL", ["undead"] = "UNDEAD",
    },
}

-- The client's SkillLine names, which in English are the addon's keys.
for _, name in ipairs({ "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Leatherworking", "Tailoring",
    "Cooking", "First Aid", "Fishing", "Mining", "Herbalism", "Skinning", "Jewelcrafting", "Inscription",
    "Lockpicking" }) do
    locale.skills[name] = name
end

-- The client's SpellDispelType names, which in English are the aura API's.
for _, name in ipairs({ "Magic", "Curse", "Disease", "Poison" }) do locale.dispels[name] = name end

-- The client's QuestInfo names, and "Group", which Forever's table lacks.
for _, name in ipairs({ "Elite", "Dungeon", "Raid", "Group", "PvP" }) do locale.questTags[name] = true end
