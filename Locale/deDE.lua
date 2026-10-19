-- The German client: what the game has no string for, in German, and the
-- client's own names for skills, dispel types, quest kinds, and schools. It
-- loads after Locale\English.lua, so whatever it leaves out stays English.
-- Wordings marked "unconfirmed" are guesses until a German capture shows them.
local _, ns = ...
local locale = ns.Locale

locale.supported = true
-- Descriptions name the duration before the amount ("18 Sek. lang 30 Punkt(e)
-- Schattenschaden"), which the spell power rows do not read yet.
locale.features = { coefficients = false }

local formats = locale.formats
-- Unconfirmed: the game names a weapon's speed SPEED, "Tempo".
formats.weaponSpeed = "Tempo %s"
-- Recipes teach in two wordings: "Lehrt Euch die Herstellung eines
-- Elixiers ..." and "Lehrt Euch, wie man ein Elixier ... herstellt".
formats.recipeTeaches = { "Benutzen: Lehrt Euch die Herstellung %s", "Benutzen: Lehrt Euch, wie man %s herstellt" }
-- Unconfirmed.
formats.baseManaCost = "%d%% des Grundmanas"
-- Unconfirmed: as the map's legend names them.
formats.rare = "Selten"
formats.rareElite = "Selten - Elite"

-- "Ausdauer +16 und Rüstung +100".
locale.listSeparators = { ", und ", " und ", ", " }

-- Descriptions join the school to its word: "Feuerschaden", "Eure Feuerzauber".
locale.descriptions.school = { "%sschaden", "%szauber" }
locale.schoolWords = { Arcane = "Arkan", Fire = "Feuer", Frost = "Frost", Holy = "Heilig", Nature = "Natur",
    Shadow = "Schatten", Holyfire = "Heiligfeuer", Frostfire = "Frostfeuer" }

-- Older English equip wordings; the German client prints the game's own.
locale.statWordings = {}

local skills = locale.skills
skills.Alchemy = "Alchimie"
skills.Blacksmithing = "Schmiedekunst"
skills.Enchanting = "Verzauberkunst"
skills.Engineering = "Ingenieurskunst"
skills.Leatherworking = "Lederverarbeitung"
skills.Tailoring = "Schneiderei"
skills.Cooking = "Kochkunst"
skills["First Aid"] = "Erste Hilfe"
skills.Fishing = "Angeln"
skills.Mining = "Bergbau"
skills.Herbalism = "Kräuterkunde"
skills.Skinning = "Kürschnerei"
skills.Lockpicking = "Schlossknacken"

local dispels = locale.dispels
dispels.Magic = "Magie"
dispels.Curse = "Fluch"
dispels.Disease = "Krankheit"
dispels.Poison = "Gift"

locale.questTags = { Elite = true, Dungeon = true, Schlachtzug = true, Gruppe = true, PvP = true }

-- The addon's own words. German spells measure their range in meters.
local L = ns.L
L["%s yd"] = "%s m"
-- A spell without a cooldown.
L["None"] = "Keine"
