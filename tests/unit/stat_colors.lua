-- A stat category's color can be replaced; the stat's name takes a lighter
-- shade of it, and without a setting the defaults come back.
return function(test)
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Data/Stats.lua" })
    local function styled(text) return select(2, ns.Stats.styleStat(text, true, false)) end
    test.check("the default magic color", styled("+12 Spell Power"), "|cffC6A9FC+12|r |cffD7C8F7Spell Power|r")
    ns.setOption("statColorMagic", { 1, 0, 0 })
    test.check("a custom color, its shade lifted toward white", styled("+12 Spell Power"),
        "|cffFF0000+12|r |cffFF7373Spell Power|r")
    test.check("other categories keep theirs", styled("+6 Intellect"), "|cffE9DDC4+6|r |cffEEE7DAIntellect|r")
    ns.setOption("statColorNegative", { 0, 0, 1 })
    test.check("negative values too", styled("-5 Agility"), "|cff0000FF-5|r |cffEEE7DAAgility|r")
    ns.setOption("statColorMagic", nil)
    test.check("reset to the default", styled("+12 Spell Power"), "|cffC6A9FC+12|r |cffD7C8F7Spell Power|r")
end
