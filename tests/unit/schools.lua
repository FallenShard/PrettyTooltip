-- A class spell's school comes from Data/Schools.lua by its name, ahead of
-- its wording; names the table lacks fall back to the wording.
return function(test)
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Game/Game.lua", "Data/Schools.lua" })
    local detect = ns.Palette.detectSchool
    test.check("a heal names no school, the table does", detect({ "Heals a friendly target for 45 over 15 sec." }, "Renew"),
        "Holy")
    test.check("the table wins over the wording", detect({ "Causes 102 to 128 Fire damage." }, "Holy Fire"), "Holy")
    test.check("a name the table lacks falls back to the wording",
        detect({ "Increases the critical strike damage bonus of your Frost spells by 40%." }, "Ice Shards"), "Frost")
    test.check("a physical ability stays without a school",
        detect({ "An instant strike that causes 3 damage in addition to your normal weapon damage." }, "Sinister Strike"),
        nil)
    test.check("every rank shares its name's entry", ns.spellSchool("Frostbolt"), "Frost")
    test.check("a spell of two schools has its own", ns.spellSchool("Frostfire Bolt"), "Frostfire")
    test.check("and its own color", ns.util.hex(ns.Palette.schools.Frostfire), "2EC7B8")
end
