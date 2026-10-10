-- Other settings each fixture of a type of tooltip also runs with, beside the defaults.
-- A variant's output is compared against tests/outputs/<fixture>.<variant>.txt.
-- settings: saved settings to run with. native: describe the game's own
-- tooltip instead of the panel, for settings that leave the game's showing.
return {
    Item = {
        -- The game's tooltip, its Equip effects shortened and stats colored.
        lite = { settings = { itemLite = true }, native = true },
        -- The panel with its optional parts and colors turned off.
        plain = { settings = { statMarkers = false, statColors = false, qualityTint = false, separators = false,
            iconItems = false, itemLevelBadge = false, disenchant = false, sellPrice = false } },
    },
    Spell = {
        plain = { settings = { iconSpells = false, spellPower = false, qualityTint = false, separators = false } },
    },
}
