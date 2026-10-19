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
    -- The professions, by the names the client gives its skill lines, as
    -- requirements print them: "Requires Blacksmithing (80)".
    professions = {},
    -- The kinds of quest a quest's tooltip names on a line of its own, by the
    -- names in the client's QuestInfo table: "Dungeon".
    questTags = {},
}
