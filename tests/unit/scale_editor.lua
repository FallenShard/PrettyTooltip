-- Scaled previews keep their controls, scroll ranges, and clickable parts
-- in the same coordinate system as what is drawn.
return function(test)
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua", "UI/Samples.lua",
        "UI/EditorSkin.lua", "UI/Editor.lua" }, { enums = { TooltipDataType = { Item = 0 } } })
    local editor = PrettyTooltipEditor
    ns.setOption("tooltipScale", 1.5)
    ns.openEditor()
    editor:GetScript("OnShow")(editor)
    local panel, scaleSlider
    for _, object in ipairs(world.objects) do
        if object.prettyTooltipPreview then panel = object.prettyTooltipPreview end
        if object:GetObjectType() == "Slider" then
            local low, high = object:GetMinMaxValues()
            if low == 50 and high == 150 then scaleSlider = object end
        end
    end
    test.check("the editor draws the sample at the saved global scale", panel:GetScale(), 1.5)
    test.check("All Tooltips shows the same saved percentage", scaleSlider:GetValue(), 150)
    local host = panel:GetParent():GetParent()
    local horizontal, vertical, overlay
    for _, child in ipairs({ host:GetChildren() }) do
        if child:GetObjectType() == "Slider" then
            if child:GetPoint(1) == "BOTTOMLEFT" then horizontal = child else vertical = child end
        elseif child:GetScript("OnMouseWheel") and child:GetScript("OnUpdate") then
            overlay = child
        end
    end
    local _, maxX = horizontal:GetMinMaxValues()
    local _, maxY = vertical:GetMinMaxValues()
    test.check("a wide enlarged sample can scroll horizontally", horizontal:IsShown() and maxX > 0, true)
    test.check("vertical scrolling uses the scaled height", maxY,
        math.max(0, math.ceil(panel:GetHeight() * 1.5 + 52 - host:GetHeight())))
    scaleSlider:GetScript("OnValueChanged")(scaleSlider, 50)
    test.check("the editor slider changes the shared setting and preview",
        { ns.tooltipScale(), panel:GetScale(), horizontal:IsShown() }, { .5, .5, false })

    local hit = panel.hits[1]
    local region = hit.region
    region.GetLeft = function() return 150 end
    region.GetRight = function() return 250 end
    region.GetTop = function() return 250 end
    region.GetBottom = function() return 150 end
    GetCursorPosition = function() return 100, 100 end
    overlay.IsMouseOver = function() return true end
    overlay:GetScript("OnUpdate")(overlay)
    local hint
    for _, font in ipairs({ overlay:GetRegions() }) do
        if font:GetObjectType() == "FontString" and font:GetText() then
            if font:GetText():find(": click to edit", 1, true) then hint = font:GetText() end
        end
    end
    test.check("hit detection follows the scaled region", hint, ns.L[ns.ELEMENT_BY_KEY[hit.key].label] .. ": click to edit")
end
