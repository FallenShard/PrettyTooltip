-- How to read this client's tooltips where the game has no string of its own
-- to read them by. Most of what the readers match are the game's strings,
-- which every client defines in its own language (ITEM_MIN_LEVEL); these are
-- the rest. Locale\English.lua fills them in English, and the client's own
-- language file, when there is one, replaces what its language words otherwise.
local _, ns = ...

ns.Locale = {
    -- Whether the addon reads this client's tooltips at all, and which of its
    -- features that rest on more than the game's strings: coefficients, the
    -- spell power and rate rows, which read spell descriptions. A language's
    -- file turns them on once captures of its tooltips show them working.
    supported = false,
    features = {},
    -- Wordings, written as the game writes its own strings: "Speed %s".
    -- util.unformat reads text printed from them.
    formats = {},
    -- What joins the parts of a list, as in an enchant's name.
    listSeparators = {},
    -- Spell descriptions' wordings the spell power rows read, and the words
    -- descriptions name schools with.
    descriptions = {},
    schoolWords = {},
    -- Whether school phrases must stand apart as words. Chinese joins them
    -- directly to the surrounding text, without spaces.
    schoolBoundaries = true,
    -- Equip wordings of stats the game's own strings do not word, each with
    -- the stat it gives (Data/Stats.lua's keys) and, for one with a word in
    -- it, the statWords table that word comes from.
    statWordings = {},
    statWords = {},
    -- Skills and professions by the client's names for them (its SkillLine
    -- table), keyed by the addon's: skills.Mining is "Bergbau" on deDE. A
    -- skill the client names two ways has a list, the first the one to print.
    skills = {},
    -- Dispel types by the client's names for them (its SpellDispelType table),
    -- keyed by the aura API's: dispels.Poison is "Gift" on deDE.
    dispels = {},
    -- The kinds of quest a quest's tooltip names on a line of its own, by the
    -- names in the client's QuestInfo table: "Dungeon".
    questTags = {},
}

-- Every name the client gives a skill, the one to print first.
function ns.Locale.skillNames(key)
    local names = ns.Locale.skills[key] or key
    return type(names) == "table" and names or { names }
end

function ns.Locale.skillName(key)
    return ns.Locale.skillNames(key)[1]
end

-- The addon's own words, the ones the game has none for, by their English:
-- L["Sell Price"]. A language file gives its own; any it leaves out reads in
-- English. A word with a value in it is a format, filled by util.fill:
-- L["Your skill %s"].
ns.L = setmetatable({}, { __index = function(_, english) return english end })
