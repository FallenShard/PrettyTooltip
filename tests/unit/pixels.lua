-- Hairlines are one screen pixel thick, on whole pixels, at any UI scale: at
-- 0.9 on a 1080p screen a unit is about 1.27 pixels, and a one-unit line
-- would round to one or two.
return function(test)
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Object.lua" },
        { enums = { TooltipDataType = { Item = 0, Object = 4 } } })
    local ui = ns.ui
    test.check("one pixel is one unit where the screen is unknown", ui.pixel(UIParent), 1)

    GetPhysicalScreenSize = function() return 1920, 1080 end
    local region = { GetEffectiveScale = function() return .9 end }
    local px = 768 / 1080 / .9
    test.check("one pixel at 0.9 on 1080p", string.format("%.4f", ui.pixel(region)), string.format("%.4f", px))
    local function pixels(value) return string.format("%.4f", value / px) end
    test.check("snapped to whole pixels", { pixels(ui.snap(region, 80.5)), pixels(ui.snap(region, 203.5)) },
        { "102.0000", "258.0000" })

    -- A rule drawn on a panel at that scale.
    local model = ui.objectModel({ name = "Mailbox", details = {}, quests = {}, extras = {} })
    local panel = ui.renderPreview(CreateFrame("Frame", nil, UIParent), model, 4)
    panel.GetEffectiveScale = region.GetEffectiveScale
    ui.rule(panel, 40.3, { 1, 1, 1 })
    local line = panel.texturePool[panel.texturesUsed]
    local _, _, _, _, y = line:GetPoint(1)
    test.check("a rule is one pixel thick, on a whole pixel",
        { pixels(line._height), pixels(-y) }, { "1.0000", "51.0000" })

    -- Where the client has PixelUtil, it is what measures and snaps.
    PixelUtil = {
        GetPixelToUIUnitFactor = function() return .5 end,
        GetNearestPixelSize = function(value, scale) return "game " .. value .. " at " .. scale end,
    }
    test.check("the game's PixelUtil is used", { ui.pixel(region), ui.snap(region, 80.5) },
        { .5 / .9, "game 80.5 at 0.9" })
end
