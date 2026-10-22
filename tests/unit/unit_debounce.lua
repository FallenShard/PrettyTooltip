-- A changed unit target waits for the configurable debounce; the latest target wins.
return function(test)
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Core/TooltipPlacement.lua", "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Panel/Layout.lua", "Panel/Render.lua", "Integration/Native.lua",
        "Integration/Placement.lua", "Integration/Hooks.lua" }, {
        enums = { TooltipDataType = { Item = 0, Unit = 2 } },
        data = { type = 2, guid = "first", lines = {} },
        lines = {},
    })
    local scheduled = {}
    C_Timer.After = function(delay, callback)
        scheduled[#scheduled + 1] = { delay = delay, callback = callback }
    end
    local renders, reads = 0, 0
    ns.ui.defineTooltipType(2, {
        key = function(_, data) return data.guid end,
        read = function(_, data) reads = reads + 1; return { guid = data.guid } end,
        render = function(panel, tooltip, model)
            renders = renders + 1
            panel.guid = model.guid
            ns.ui.finishPanel(panel, tooltip, 40)
        end,
        option = "unitPanels",
    })
    ns.Hooks.unitDebounce = .2
    ns.Hooks.install()
    local callback = world.postCalls[2][1]
    local tooltip = world.main
    tooltip:Show()
    local function handover(guid)
        local data = { type = 2, guid = guid, lines = {} }
        tooltip._data = data
        callback(tooltip, data)
    end
    handover("first")
    local panel = ns.ui.panels[tooltip]
    test.check("the first target renders without a switch debounce", { panel.guid, renders }, { "first", 1 })

    handover("second")
    test.check("a new target waits for the configurable debounce",
        { panel.guid, renders, scheduled[#scheduled].delay }, { "first", 1, .2 })
    handover("third")
    test.check("a later target replaces the pending target", #scheduled, 3)
    scheduled[2].callback()
    test.check("superseded target callback is ignored", { panel.guid, renders }, { "first", 1 })
    scheduled[3].callback()
    test.check("the latest stable target renders", { panel.guid, renders }, { "third", 2 })

    local readsBeforeCacheHit = reads
    handover("first")
    test.check("a recently seen target redraws immediately from cache",
        { panel.guid, reads }, { "first", readsBeforeCacheHit })

    local function showNewUnit(guid)
        handover(guid)
        for index = #scheduled, 1, -1 do
            if scheduled[index].delay == ns.Hooks.unitDebounce then
                local callbackToRun = scheduled[index].callback
                table.remove(scheduled, index)
                callbackToRun()
                return
            end
        end
        error("debounce callback not scheduled for " .. guid)
    end
    for index = 1, 14 do showNewUnit("recent-" .. index) end
    handover("first")
    test.check("the oldest cached unit remains available among the last 15", panel.guid, "first")
    for index = 15, 29 do showNewUnit("recent-" .. index) end
    handover("first")
    test.check("the unit outside the 15-entry cache waits for debounce", panel.guid, "recent-29")
    local snapshot = ns.Hooks.unitCacheSnapshot()
    test.check("cache snapshot exposes the current 15 units", #snapshot, 15)
    test.check("cache snapshot is ordered oldest to newest", snapshot[1]:find("%[15%]") ~= nil, true)
    test.check("cache snapshot has the most recently rendered unit last",
        snapshot[#snapshot]:find("%[29%]") ~= nil, true)

    handover("recent-29")
    test.check("refreshing the same target remains immediate", panel.guid, "recent-29")

    local output, originalPrint = {}, print
    print = function(message) output[#output + 1] = message end
    test.check("enabling cache debug starts live monitoring", ns.Hooks.debugUnitCache(true), true)
    showNewUnit("live-cache-entry")
    test.check("live monitoring reports cache changes",
        output[#output]:find("%[entry%]") ~= nil, true)
    test.check("disabling cache debug stops live monitoring", ns.Hooks.debugUnitCache(false), false)
    local messagesAfterDisable = #output
    showNewUnit("quiet-cache-entry")
    test.check("cache updates are silent after monitoring is disabled", #output, messagesAfterDisable)
    print = originalPrint
end
