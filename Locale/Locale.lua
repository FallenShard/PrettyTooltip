-- How to read this client's tooltips where the game has no string of its own
-- to read them by. Most of what the readers match are the game's strings,
-- which every client defines in its own language (ITEM_MIN_LEVEL); these are
-- the rest. Locale\English.lua fills them in English, and the client's own
-- language file, when there is one, replaces what its language words otherwise.
local _, ns = ...

ns.Locale = {
    -- Wordings, written as the game writes its own strings: "Speed %s".
    -- util.unformat reads text printed from them.
    formats = {},
    -- Spell descriptions' wordings the spell power rows read, and the words
    -- descriptions name schools with.
    descriptions = {},
    schoolWords = {},
    -- Equip wordings of stats the game's own strings do not word, each with
    -- the stat it gives (Data/Stats.lua's keys) and, for one with a word in
    -- it, the statWords table that word comes from.
    statWordings = {},
    statWords = {},
    -- Skills and professions by the client's names for them (its SkillLine
    -- table), keyed by the addon's: skills.Mining is "Bergbau" on deDE.
    skills = {},
    -- Dispel types by the client's names for them (its SpellDispelType table),
    -- keyed by the aura API's: dispels.Poison is "Gift" on deDE.
    dispels = {},
    -- The kinds of quest a quest's tooltip names on a line of its own, by the
    -- names in the client's QuestInfo table: "Dungeon".
    questTags = {},
}
