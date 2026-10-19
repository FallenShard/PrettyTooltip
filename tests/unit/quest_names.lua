-- Quest previews use client titles by ID, including titles loaded later.
return function(test)
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Locale/ruRU.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua", "Panel/Render.lua",
        "Tooltips/Quest.lua", "UI/Samples.lua", "UI/EditorSkin.lua", "UI/Editor.lua" },
        { client = { locale = "ruRU" }, enums = { TooltipDataType = { Quest = 23 } } })
    C_QuestLog = nil
    test.check("a client without the quest API returns no title", ns.Game.questName(378), nil)
    C_QuestLog = { GetQuestInfo = function() return "Localized legacy title" end }
    test.check("the older title getter is supported", ns.Game.questName(378), "Localized legacy title")

    local titles, requests = {}, {}
    C_QuestLog = {
        GetTitleForQuestID = function(id) return titles[id] end,
        RequestLoadQuestByID = function(id) requests[#requests + 1] = id end,
    }
    local samples = ns.editorSamples.tooltipTypes.quest.samples
    test.check("uncached titles retain their translated fallback", samples[1].build().name, ns.L["The Fury Runs Deep"])
    test.check("the uncached preview requests the actual quest", requests, { 378 })
    titles[378] = "Localized client title for quest 378"
    titles[33] = "Localized client title for quest 33"
    titles[1014] = "Localized client title for quest 1014"
    for index, id in ipairs({ 378, 33, 1014 }) do
        test.check("preview title comes from quest " .. id, samples[index].build().name, titles[id])
        test.check("preview exposes quest " .. id .. " for load events", samples[index].questID, id)
    end
    test.check("cached titles do not request more data", requests, { 378 })

    -- Count selected-preview builds to verify that only its successful load
    -- event redraws it, and that hidden editors do not draw on load events.
    local builds = 0
    local build = samples[1].build
    samples[1].build = function() builds = builds + 1 return build() end
    local editor = PrettyTooltipEditor
    local questTab
    for _, child in ipairs({ editor:GetChildren() }) do
        if child.label and child.label:GetText() == ns.L["Quests"] then questTab = child end
    end
    questTab:GetScript("OnClick")(questTab)
    editor:Show()
    builds = 0
    world.fireEvent("QUEST_DATA_LOAD_RESULT", 378, true)
    test.check("loading the selected quest redraws its preview", builds, 1)
    world.fireEvent("QUEST_DATA_LOAD_RESULT", 33, true)
    world.fireEvent("QUEST_DATA_LOAD_RESULT", 378, false)
    world.fireEvent("GET_ITEM_INFO_RECEIVED", 378, true)
    test.check("unrelated and failed loads do not redraw the quest", builds, 1)
    editor:Hide()
    world.fireEvent("QUEST_DATA_LOAD_RESULT", 378, true)
    test.check("a hidden editor does not redraw on quest loads", builds, 1)

    C_QuestLog.GetTitleForQuestID = function() return "" end
    test.check("an empty title is treated as uncached", ns.Game.questName(378), nil)
    test.check("an empty title requests loading", requests[#requests], 378)
    C_QuestLog.GetTitleForQuestID = function() error("unavailable") end
    C_QuestLog.RequestLoadQuestByID = function() error("unavailable") end
    test.check("API failures preserve the fallback path", ns.Game.questName(378), nil)
    C_QuestLog = {}
    test.check("missing title getters are tolerated", ns.Game.questName(378), nil)
end
