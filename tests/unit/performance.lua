-- The profiler counts nested work once and keeps functions' results. /ptip perf
-- splits frames where its sampler runs and reports per tooltip update; /ptip
-- perf ab and /ptip bench compare PrettyTooltip on and off.
return function(test)
    local FILES = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Panel/Layout.lua",
        "Panel/Render.lua", "Integration/Native.lua", "Integration/Placement.lua", "Integration/Hooks.lua",
        "UI/Debug.lua", "UI/Commands.lua" }
    local METRICS = { CountTimeOver1Ms = 5, CountTimeOver5Ms = 6, CountTimeOver10Ms = 7, CountTimeOver50Ms = 8,
        RecentAverageTime = 1 }
    local now, allocated, timers, report, messages
    local engine
    local function load()
        local ns, world = test.load(FILES, { enums = { TooltipDataType = { Item = 0 }, AddOnProfilerMetric = METRICS } })
        now, allocated, timers, report, messages = 0, 0, {}, nil, {}
        engine = { game = {}, addons = {}, own = {} }
        for _, values in pairs(engine) do
            for _, id in pairs(METRICS) do values[id] = 0 end
        end
        debugprofilestop = function() return now end
        InCombatLockdown = function() return false end
        C_Timer.After = function(seconds, callback) timers[#timers + 1] = { seconds = seconds, callback = callback } end
        print = function(message) messages[#messages + 1] = message end
        C_AddOnProfiler = {
            IsEnabled = function() return true end,
            GetApplicationMetric = function(id) return engine.game[id] end,
            GetOverallMetric = function(id) return engine.addons[id] end,
            GetAddOnMetric = function(name, id) return name == "PrettyTooltip" and engine.own[id] or 0 end,
            GetTopKAddOnsForMetric = function()
                return { { addOnName = "Busy", metricValue = .25 }, { addOnName = "PrettyTooltip", metricValue = .05 } }
            end,
        }
        ns.showReport = function(title, lines) report = { title = title, text = table.concat(lines, "\n") } end
        ns.Commands.register()
        return ns, world
    end
    local function has(text) return report ~= nil and report.text:find(text, 1, true) ~= nil end
    local function updaters(world)
        local found = {}
        for _, object in ipairs(world.objects) do
            if object._scripts and object._scripts.OnUpdate then found[object] = object._scripts.OnUpdate end
        end
        return found
    end
    -- The OnUpdate a command set on the frame it runs on.
    local function started(world, before)
        for object, script in pairs(updaters(world)) do
            if before[object] ~= script then return function() script(object, 0) end, object end
        end
    end

    local ns, world = load()
    local profiler = ns.Profiler
    profiler.reset()
    profiler.on = true
    local inner = profiler.probe("inner", function() now = now + 2; return "ok", nil, 7 end)
    local outer = profiler.probe("outer", function()
        now = now + 1
        local a, b, c = inner()
        now = now + 1
        return a, b, c
    end)
    local a, b, c = outer()
    test.check("probes keep results that contain nil", { a, b == nil, c }, { "ok", true, 7 })
    test.check("own time leaves out the scopes a scope calls; totals include them",
        { profiler.self.inner, profiler.total.inner, profiler.self.outer, profiler.total.outer }, { 2, 2, 2, 4 })
    test.check("work counts nested scopes once", profiler.work, 4)
    test.check("a scope's longest call is inclusive", profiler.max.outer, 4)
    local failing = profiler.probe("failure", function() now = now + 1; error("profiled failure") end)
    local ok, failure = pcall(failing)
    test.check("errors pass through and unwind the scope depth",
        { ok, profiler.depth, failure:find("profiled failure", 1, true) ~= nil, profiler.calls.failure },
        { false, 0, true, 1 })
    profiler.tally("counted")
    profiler.on = false
    profiler.tally("counted")
    outer()
    test.check("nothing is counted while profiling is off", { profiler.calls.counted, profiler.calls.outer }, { 1, 1 })

    -- /ptip perf: every tenth frame hands GameTooltip its data, and a stage
    -- spends a millisecond on it.
    ns.Processor.onData("panel", 0, function() now = now + 1 end)
    local handOver = world.postCalls[0][1]
    local data = { type = 0, lines = {} }
    local before = updaters(world)
    SlashCmdList.PRETTYTOOLTIP("perf 10 bag test")
    test.check("perf takes a duration and a label", { #timers, timers[1].seconds }, { 1, 10 })
    local tick, sampler = started(world, before)
    for frame = 1, 100 do
        if frame % 10 == 0 then handOver(GameTooltip, data) end
        now = now + 5
        engine.game[METRICS.CountTimeOver1Ms] = engine.game[METRICS.CountTimeOver1Ms] + 1
        engine.game[METRICS.CountTimeOver5Ms] = engine.game[METRICS.CountTimeOver5Ms] + 1
        if frame % 10 == 0 then engine.game[METRICS.CountTimeOver10Ms] = engine.game[METRICS.CountTimeOver10Ms] + 1 end
        tick()
    end
    SlashCmdList.PRETTYTOOLTIP("perf")
    test.check("a second measurement waits for the first", messages[#messages], "PrettyTooltip: /ptip perf is already running.")
    timers[1].callback()
    test.check("the capture names itself, its label, and the actual duration", has('PrettyTooltip perf "bag test": 0.51 s'), true)
    test.check("frames with tooltip data are counted apart", has("Tooltip data arrived in 10 frames (19.6/s): 10 main and 0 comparison handovers."), true)
    test.check("frame times split into data, following, and other frames", {
        has("  with tooltip data       10     6.00     6.00     6.00      1.000     1.000"),
        has("  right after those        9     5.00     5.00     5.00      0.000     0.000"),
        has("  all others              80     5.00     5.00     5.00      0.000     0.000") }, { true, true, true })
    test.check("work is reported per update", has("PrettyTooltip's work: 10.000 ms in all, 1.000 ms per update, 0.1010 ms per frame."), true)
    test.check("each scope is reported per update",
        has("  panel data                           1.0     1.000     1.000     1.000"), true)
    test.check("counts without time follow the scopes", has("  counts: data: main 1.0"), true)
    test.check("the game's frame counters cover the capture", {
        has("  whole game     100 / 100 / 10 / 0"), has("  this sampler   99 / 10 / 0 / 0"),
        has("  PrettyTooltip  0 / 0 / 0 / 0") }, { true, true, true })
    test.check("the busiest addons are named", has("Busy 0.250, PrettyTooltip 0.050"), true)
    test.check("the capture stops sampling and profiling",
        { profiler.on, profiler.frames == nil, sampler._scripts.OnUpdate == nil }, { false, true, true })
    for _, case in ipairs({ { "perf", 5 }, { "perf 99", 30 }, { "perf 0", 1 } }) do
        SlashCmdList.PRETTYTOOLTIP(case[1])
        test.check("perf durations stay within bounds: " .. case[1], timers[#timers].seconds, case[2])
        timers[#timers].callback()
    end
    C_AddOnProfiler = nil
    SlashCmdList.PRETTYTOOLTIP("perf 2")
    timers[#timers].callback()
    test.check("captures work without the game's profiler", has("Game profiler: not available on this client."), true)

    -- /ptip perf ab: a stage costs 2 ms while PrettyTooltip is on; the windows
    -- alternate and suspend PrettyTooltip's stages and panels.
    ns, world = load()
    local reads, renders = 0, 0
    ns.TooltipTypes[0] = {
        option = "itemPanels", key = function(_, item) return item.id end,
        read = function() reads = reads + 1; return {} end,
        render = function(panel)
            renders = renders + 1
            panel:SetSize(200, 100)
            panel:Show()
        end,
    }
    ns.Hooks.install()
    ns.Processor.onData("details", 0, function() now = now + 2 end)
    handOver = world.postCalls[0][1]
    data = { type = 0, id = 1, lines = {} }
    GameTooltip._data = data
    GameTooltip:SetSize(300, 200)
    GameTooltip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)
    GameTooltip:Show()
    handOver(GameTooltip, data)
    for _, timer in ipairs(timers) do timer.callback() end
    local panel = ns.ui.panels[GameTooltip]
    test.check("the panel draws before the comparison", { panel:IsShown(), GameTooltip:GetAlpha(), renders }, { true, 0, 1 })
    before = updaters(world)
    SlashCmdList.PRETTYTOOLTIP("perf ab 10 bags")
    tick = started(world, before)
    local states, last = {}, nil
    for frame = 1, 3000 do
        if frame % 8 == 0 then handOver(GameTooltip, data) end
        now = now + 5
        tick()
        local state = (ns.suspended and "off" or "on") .. (panel:IsShown() and ", panel" or ", game's tooltip")
            .. " at alpha " .. GameTooltip:GetAlpha() .. (ns.restyles("itemPanels") and ", restyled" or "")
        if state ~= last then states[#states + 1], last = state, state end
        if report then break end
    end
    test.check("windows alternate, suspending panels and stages, and end with PrettyTooltip on", states, {
        "on, panel at alpha 0, restyled", "off, game's tooltip at alpha 1", "on, panel at alpha 0, restyled",
        "off, game's tooltip at alpha 1", "on, panel at alpha 0, restyled" })
    test.check("the comparison names its windows and label", { report.title,
        has('PrettyTooltip perf ab "bags": 4 windows of 2.5 s') }, { "perf ab", true })
    test.check("frames with tooltip data are compared by mode",
        report.text:find("with tooltip data +%d+ +7%.00 +7%.00 +%d+ +5%.00 +5%.00 +%+2%.00 +%+2%.00") ~= nil, true)
    test.check("frames without tooltip data show no difference",
        report.text:find("all others +%d+ +5%.00 +5%.00 +%d+ +5%.00 +5%.00 +%+0%.00 +%+0%.00") ~= nil, true)
    test.check("each window's median is listed", has("by window: on 7.00 7.00; off 5.00 5.00"), true)
    test.check("every window pair agrees", has("slower in 4 of 4 window pairs"), true)
    test.check("the result states the difference",
        has("Result: frames with tooltip data took +2.00 ms (+40%) at the median with PrettyTooltip on,"), true)
    test.check("the run ends with PrettyTooltip on and the panel drawn",
        { ns.suspended == nil, panel:IsShown(), GameTooltip:GetAlpha(), ns.Profiler.frames == nil }, { true, true, 0, true })
    report = nil
    before = updaters(world)
    SlashCmdList.PRETTYTOOLTIP("perf ab")
    tick = started(world, before)
    for _ = 1, 700 do now = now + 5; tick() end
    InCombatLockdown = function() return true end
    tick()
    test.check("combat stops the comparison and resumes PrettyTooltip",
        { has("Stopped early: combat started."), ns.suspended == nil }, { true, true })
    report = nil
    SlashCmdList.PRETTYTOOLTIP("perf ab")
    test.check("the comparison does not start in combat", { report, messages[#messages] },
        { nil, "PrettyTooltip: /ptip perf ab runs outside combat; try again once it ends." })

    -- /ptip bench: the game times the hovered button's refresh. Its own work
    -- takes 3 ms and 2 KB; a stage adds 1 ms and 512 bytes while PrettyTooltip is on.
    ns, world = load()
    ns.Hooks.install()
    ns.Processor.onData("details", 0, function() now, allocated = now + 1, allocated + 512 end)
    handOver = world.postCalls[0][1]
    local owner = CreateFrame("Button", "ContainerFrame1Item1", UIParent)
    local refreshes = 0
    owner.UpdateTooltip = function()
        refreshes = refreshes + 1
        now, allocated = now + 3, allocated + 2048
        handOver(GameTooltip, { type = 0, lines = {} })
    end
    GameTooltip.GetOwner = function() return owner end
    GameTooltip:Show()
    local recording
    C_AddOnProfiler.MeasureCall = function(fn, ...)
        local call = { time = now, bytes = allocated, events = {} }
        recording = call
        fn(...)
        recording = nil
        return { elapsedMilliseconds = now - call.time, allocatedBytes = allocated - call.bytes, events = call.events }
    end
    C_AddOnProfiler.AddMeasuredCallEvent = function(name)
        if recording then
            table.insert(recording.events, { name = name, elapsedMilliseconds = now - recording.time,
                allocatedBytes = allocated - recording.bytes })
        end
    end
    before = updaters(world)
    SlashCmdList.PRETTYTOOLTIP("bench 8 bag")
    tick = started(world, before)
    test.check("the bench says what it times", messages[#messages],
        "PrettyTooltip: timing 30 refreshes of ContainerFrame1Item1:UpdateTooltip() with PrettyTooltip off and on; keep the mouse still.")
    local suspendedDuring = {}
    for step = 1, 40 do
        tick()
        if step == 5 or step == 15 then suspendedDuring[#suspendedDuring + 1] = ns.suspended == true end
        if report then break end
    end
    test.check("the bench suspends PrettyTooltip only for its off blocks", suspendedDuring, { true, false })
    test.check("every refresh ran inside the game's measure", refreshes, 30)
    test.check("the bench reports both modes", {
        has("  PrettyTooltip off        8    3.000    3.000    3.000            2.0      2.0"),
        has("  PrettyTooltip on         8    4.000    4.000    4.000            2.5      2.5") }, { true, true })
    test.check("the difference is the result",
        has("Result: PrettyTooltip adds +1.000 ms (+33%) and +0.5 KB to each refresh at the median."), true)
    test.check("the game's events measure the addon's own code",
        has("Inside PrettyTooltip's own code: 1.000 ms and 0.5 KB per refresh at the median"), true)
    test.check("each scope is reported per refresh with its allocation",
        has("  details data                         1.0     1.000     1.000      0.5      0.5"), true)
    test.check("handovers are counted per refresh", has("Handovers per refresh: 1.0 main, 0.0 comparison."), true)
    test.check("the bench ends with profiling off and PrettyTooltip on",
        { ns.Profiler.on, ns.Profiler.mark == nil, ns.suspended == nil }, { false, true, true })
    report = nil
    before = updaters(world)
    SlashCmdList.PRETTYTOOLTIP("bench")
    tick = started(world, before)
    for _ = 1, 4 do tick() end
    GameTooltip.GetOwner = function() return UIParent end
    tick()
    test.check("moving the mouse stops the bench and resumes PrettyTooltip",
        { has("Stopped early: the tooltip changed; keep the mouse still while it runs."), ns.suspended == nil },
        { true, true })
    report = nil
    GameTooltip:Hide()
    SlashCmdList.PRETTYTOOLTIP("bench")
    test.check("the bench needs a tooltip it can refresh", { report, messages[#messages - 1]:find("hover an item", 1, true) ~= nil },
        { nil, true })
    C_AddOnProfiler.MeasureCall = nil
    GameTooltip:Show()
    SlashCmdList.PRETTYTOOLTIP("bench")
    test.check("the bench needs the game's profiler", messages[#messages],
        "PrettyTooltip: the game's profiler (C_AddOnProfiler) is not available on this client.")
end
