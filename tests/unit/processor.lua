-- The processor runs each data type's stages from one post-call, in its own
-- order whatever order they were added in, and one failing stage leaves the
-- rest to run. One key watcher serves every stage.
return function(test)
    local ns, world = test.load({ "Core/Util.lua", "Game/Game.lua" },
        { enums = { TooltipDataType = { Item = 0, Spell = 1 } } })
    local processor = ns.Processor
    local ran = {}
    local function stage(name) return function() ran[#ran + 1] = name end end
    processor.onData("cursor", 0, stage("cursor"))
    processor.onData("details", 0, stage("details"))
    processor.onData("wording", 0, stage("wording"))
    processor.onData("panel", 0, function() error("panel failed", 0) end)
    processor.onData("panel", 1, stage("spell panel"))
    test.check("one post-call for each data type", { #world.postCalls[0], #world.postCalls[1] }, { 1, 1 })
    test.check("stages in their order", processor.stages(0), { "wording", "panel", "details", "cursor" })

    local reported
    geterrorhandler = function() return function(failure) reported = failure end end
    world.postCalls[0][1](world.main, {})
    test.check("a failing stage is reported and the rest run", { ran, reported },
        { { "wording", "details", "cursor" }, "panel failed" })
    ran = {}
    world.postCalls[1][1](world.main, {})
    test.check("a data type runs only its own stages", ran, { "spell panel" })

    local keys = {}
    processor.onKey("details", function(key) keys[#keys + 1] = "details " .. key end)
    processor.onKey("wording", function(key) keys[#keys + 1] = "wording " .. key end)
    local watchers = 0
    for _, object in ipairs(world.objects) do
        if object:IsEventRegistered("MODIFIER_STATE_CHANGED") then watchers = watchers + 1 end
    end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    test.check("one key watcher, its stages in order", { watchers, keys }, { 1, { "wording LSHIFT", "details LSHIFT" } })
    test.check("an unknown stage is refused", pcall(processor.onData, "extra", 0, stage("extra")), false)
end
