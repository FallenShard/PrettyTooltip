-- luacheck settings: `luacheck .` from here, or `python tests/run.py --lint`.
-- It reports names used but never defined, which a rename or a move leaves
-- behind, whether or not a test runs that code.
std = "lua51"
-- The harness defines the game's globals rather than using them.
exclude_files = { "tests/**", ".release/**" }

-- Style, not correctness: long data lines, as the cast time table, are fine.
max_line_length = false
ignore = {
    "542", -- An empty if branch, with a comment saying where the case is handled.
}

-- What the addon sets: its saved variables, its slash command, and the fields
-- the style editor gives the color picker.
globals = {
    "PrettyTooltipDB",
    "PrettyTooltipCaptures",
    "SLASH_PRETTYTOOLTIP1",
    "SLASH_PRETTYTOOLTIP2",
    SlashCmdList = { other_fields = true },
    ColorPickerFrame = { other_fields = true },
}

-- The game's functions, objects, and constants the addon reads.
read_globals = {
    -- Lua the game adds
    "date", "tinsert", "issecretvalue", "debugprofilestop", "hooksecurefunc",
    -- Frames and UI
    "CreateFrame", "CreateColor", "UIParent", "GameTooltip", "ItemRefTooltip", "GameTooltipText",
    "GameTooltipHeaderText", "GameFontHighlightSmall", "UISpecialFrames", "ShowUIPanel", "HideUIPanel",
    "SetPortraitTexture", "ChatEdit_InsertLink", "GetCursorPosition", "NUM_CHAT_WINDOWS",
    "Settings", "SettingsPanel", "InterfaceOptions_AddCategory", "InterfaceOptionsFrame_OpenToCategory",
    "STANDARD_TEXT_FONT", "RAID_CLASS_COLORS", "ITEM_DELTA_DESCRIPTION",
    -- Tooltip data
    "TooltipDataProcessor", "Enum",
    -- Game state
    "C_Item", "C_Spell", "C_AddOns", "C_QuestLog", "C_UnitAuras", "C_Timer", "C_CurrencyInfo",
    "GetLocale", "GetBuildInfo", "GetTime", "IsAltKeyDown", "IsControlKeyDown",
    "GetSpellInfo", "GetSpellTexture", "GetSpellBonusDamage", "GetSpellBonusHealing",
    "GetSkillLineInfo", "GetNumSkillLines", "GetProfessions", "GetProfessionInfo",
    "GetQuestDifficultyColor", "GetGuildInfo", "GetCoinTextureString", "BreakUpLargeNumbers",
    "UnitName", "UnitExists", "UnitGUID", "UnitTokenFromGUID", "UnitLevel", "UnitEffectiveLevel",
    "UnitClass", "UnitRace", "UnitFactionGroup", "UnitReaction", "UnitIsUnit", "UnitIsPlayer",
    "UnitHealth", "UnitHealthMax", "UnitIsTapDenied", "UnitIsPVP", "UnitIsDeadOrGhost", "UnitIsDND",
    "UnitIsAFK", "UnitCreatureType", "UnitClassification",
    -- Other addons, used when installed
    "LibStub", "Auctionator",
}
