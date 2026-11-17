-- Row and section spacing shrink a panel's height, and their defaults draw it as before.
return function(test)
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua", "UI/Samples.lua" },
        { enums = { TooltipDataType = { Item = 0 } } })
    local item = ns.editorSampleTypes()[1]
    local function height()
        local panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), item.samples[1].build(), item.dataType)
        return panel:GetHeight()
    end
    local default = height()
    ns.setOption("rowSpacing", .5)
    local rows = height()
    ns.setOption("sectionSpacing", .5)
    local both = height()
    test.check("tighter rows make a shorter panel", rows < default, true)
    test.check("tighter sections make it shorter still", both < rows, true)
    ns.setOption("rowSpacing", 0)
    ns.setOption("sectionSpacing", 9)
    test.check("spacing stays in the slider's bounds", { ns.spacing("rowSpacing"), ns.spacing("sectionSpacing") }, { .5, 1.5 })
    ns.setOption("rowSpacing", nil)
    ns.setOption("sectionSpacing", nil)
    test.check("the defaults draw the panel as before", height(), default)
end
