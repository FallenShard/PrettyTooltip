-- A macro shows the spell its first casting command names, by any name the
-- client takes for that command: its own language's, as German "/wirken".
return function(test)
    local function spell(locale, body)
        local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
            "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Panel/Layout.lua", "Panel/Render.lua",
            "Tooltips/Spell.lua", "Tooltips/Macro.lua" },
            { client = { locale = locale }, enums = { TooltipDataType = { Item = 0, Spell = 1, Macro = 25 } } })
        return ns.ui.macroModel({ name = "Heal", body = body }).spell
    end

    test.check("enUS: /cast", spell("enUS", { "/cast [@mouseover] Flash of Light(Rank 2)" }), "Flash of Light")
    test.check("enUS: another name for it", spell("enUS", { "/spell Flash of Light" }), "Flash of Light")
    test.check("enUS: a command that casts nothing first", spell("enUS", { "/say Healing!", "/use Healing Potion" }),
        "Healing Potion")
end
