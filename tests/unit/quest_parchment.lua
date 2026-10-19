-- The opt-in paper treatment is confined to quests and quest items. A panel
-- lent to another kind must restore its normal artwork and text colors.
return function(test)
    local ITEM, QUEST = 0, 5
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua", "Panel/Render.lua",
        "Tooltips/Item.lua", "Tooltips/Quest.lua" }, { enums = { TooltipDataType = { Item = ITEM, Quest = QUEST },
        TooltipDataLineType = { None = 0, ItemName = 1, ItemBinding = 2 } } })
    local installed = true
    ns.Game.addonInstalled = function(addon) return installed and addon == "DialogueUI" end
    local anchor = CreateFrame("Frame", nil, UIParent)
    local quest = ns.ui.questModel({ name = "A paper quest", description = { "Bring back the letter." },
        objectives = { { left = "Letter", right = "0/1", completed = false } } })
    ns.setOption("backdropStyle", "native")
    local ordinary = ns.ui.itemModel({ name = "An ordinary item", quality = 1 })
    local normalPanel = ns.ui.renderPreview(anchor, ordinary, ITEM)
    local normalColor = { normalPanel.pool[1]:GetTextColor() }
    local panel = ns.ui.renderPreview(anchor, quest, QUEST)
    test.check("paper is off by default", panel.backdropMode, "native")
    ns.setOption("questParchment", true)
    panel = ns.ui.renderPreview(anchor, quest, QUEST)
    test.check("the toggle applies brown paper to quests", panel.backdropMode, "parchment")
    test.check("it uses DialogueUI's settings paper", panel.background:GetTexture(),
        "Interface\\AddOns\\DialogueUI\\Art\\Theme_Brown\\GenericFrame-Tiled-Large.png")
    test.check("paper suppresses the dark bands and halo",
        { panel.header:IsShown(), panel.halo:IsShown() }, { false, false })
    test.check("paper hides the native border", panel.nativeBorder:IsShown(), false)
    local title = panel.pool[1]
    test.check("the quest title becomes dark brown ink", { title:GetTextColor() }, { .11, .085, .055, 1 })

    ns.setElementSetting("questTitle", "color", { .9, .1, .8 })
    panel = ns.ui.renderPreview(anchor, quest, QUEST)
    test.check("an explicit part color takes precedence", { panel.pool[1]:GetTextColor() }, { .9, .1, .8, 1 })
    ns.setElementSetting("questTitle", "color", nil)

    local item = ns.ui.itemModel({ name = "A quest item", quality = 1, quest = true,
        flavor = { { left = "Read the letter.", right = "" } } })
    panel = ns.ui.renderPreview(anchor, item, ITEM)
    test.check("quest items get the same paper treatment", panel.backdropMode, "parchment")
    panel = ns.ui.renderPreview(anchor, ordinary, ITEM)
    test.check("an ordinary item restores its normal treatment", panel.backdropMode, "native")
    test.check("normal bands and halo return on a reused panel",
        { panel.header:IsShown(), panel.halo:IsShown() }, { true, true })
    test.check("normal text colors return", { panel.pool[1]:GetTextColor() }, normalColor)

    -- Quest-starter detection uses the item's actual reader, not just a sample.
    local data = { type = ITEM, quality = 1, lines = {
        { type = 1, lineIndex = 1, leftText = "A quest starter" },
        { type = 0, lineIndex = 2, leftText = "This Item Begins a Quest" },
    } }
    local starter = ns.TooltipTypes[ITEM].read(world.main, data, ns.Game)
    test.check("the reader marks quest-starter items", starter.quest, true)
    panel = ns.ui.renderPreview(anchor, starter, ITEM)
    test.check("quest-starter items use paper too", panel.backdropMode, "parchment")

    -- Bright inline colors must become readable without damaging link data.
    local style = ns.ui.styleOf("questText")
    local link = "|Hitem:1307:0:0:0|h[Letter]|h"
    ns.ui.styledAt(panel, "|cff00ff00" .. link .. "|r", 10, 10, 250, style, { 1, 1, 1 })
    local font = panel.pool[panel.used]
    test.check("inline links retain their link payload", font:GetText():find(link, 1, true) ~= nil, true)
    test.check("inline green is darkened for paper", font:GetText():find("|cff00ff00", 1, true), nil)
    test.check("automatic text uses dark ink", { font:GetTextColor() }, { .11, .085, .055, 1 })

    installed = false
    panel = ns.ui.renderPreview(anchor, quest, QUEST)
    test.check("without DialogueUI the chosen normal style is used", panel.backdropMode, "native")
    test.check("normal colors return when DialogueUI is absent", { panel.pool[1]:GetTextColor() }, { .96, .92, .84, 1 })
    installed = true
    ns.setOption("questParchment", false)
    panel = ns.ui.renderPreview(anchor, quest, QUEST)
    test.check("turning off the toggle restores the chosen panel style", panel.backdropMode, "native")
    ns.setOption("questParchment", true)
    ns.resetOptions()
    test.check("Defaults switches paper off", ns.option("questParchment"), false)
end
