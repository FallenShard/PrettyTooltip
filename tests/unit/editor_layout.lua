-- Translated controls and sample buttons must stay within their columns in
-- both treatments. Small UI dimensions must keep the complete editor reachable.
return function(test)
    local locales = {
        { "enUS" }, { "deDE", "deDE" }, { "esES", "esES" }, { "esMX", "esMX" },
        { "frFR", "frFR" }, { "koKR", "koKR" }, { "ptBR", "Portuguese" },
        { "ptPT", "Portuguese" }, { "ruRU", "ruRU" }, { "zhCN", "zhCN" }, { "zhTW", "zhTW" },
    }
    for client, toc in pairs(test.tocs) do
        for _, language in ipairs(locales) do
            local files = {}
            for _, file in ipairs(toc) do
                files[#files + 1] = file
                if file == "Locale/English.lua" and language[2] then
                    files[#files + 1] = "Locale/" .. language[2] .. ".lua"
                end
            end
            local ns, world = test.load(files, { client = { locale = language[1] }, enums = test.enums })
            ns.openEditor()
            PrettyTooltipEditor:GetScript("OnShow")(PrettyTooltipEditor)
            local editor, host, column = PrettyTooltipEditor
            for _, object in ipairs(world.objects) do
                if object.prettyTooltipPreview then host = object.prettyTooltipPreview:GetParent():GetParent() end
                if object:GetObjectType() == "ScrollFrame" and object:GetParent() == editor then column = object end
            end
            for _, style in ipairs({ "native", "flat" }) do
                ns.setOption("editorStyle", style)
                ns.refreshEditorStyle()
                local pages = { "general", "tooltips", "other" }
                for _, page in ipairs(ns.editorSamples.order) do pages[#pages + 1] = page end
                local generalBounds
                for _, page in ipairs(pages) do
                    ns.editorPages.open(page)
                    -- Validate expanded content too, including inherited-value links.
                    for _, object in ipairs(world.objects) do
                        if object:GetObjectType() == "Button" and not object.label and object:IsVisible()
                            and object:GetScript("OnClick") then
                            for _, region in ipairs({ object:GetRegions() }) do
                                if region.GetText and region:GetText() == "+" then object:GetScript("OnClick")(object) break end
                            end
                        end
                    end
                    local prefix = client .. "/" .. language[1] .. "/" .. style .. "/" .. page
                    local _, _, _, hostX, hostY = host:GetPoint()
                    local bounds = { hostX, hostY, host:GetWidth(), host:GetHeight() }
                    generalBounds = generalBounds or bounds
                    test.check(prefix .. ": preview bounds match General", bounds, generalBounds)
                    local buttons, inside, separated, labelsFit, rowsFit = {}, true, true, true, true
                    for _, object in ipairs(world.objects) do
                        if object._template == "UIMenuButtonStretchTemplate" and object:IsVisible() then
                            local _, _, _, x, y = object:GetPoint()
                            inside = inside and x >= hostX and x + object:GetWidth() <= hostX + host:GetWidth()
                                and y - object:GetHeight() >= hostY
                            for _, previous in ipairs(buttons) do
                                if previous.y == y then separated = separated and x >= previous.right + 4 end
                            end
                            buttons[#buttons + 1] = { y = y, right = x + object:GetWidth() }
                        elseif object.caption and object:IsVisible() then
                            local holder = object:GetParent()
                            local _, _, _, _, y = object:GetPoint()
                            labelsFit = labelsFit and -y + object.caption:GetStringHeight() + 4 <= holder:GetHeight()
                        elseif object:GetObjectType() == "FontString" and object:IsVisible() then
                            local holder = object:GetParent()
                            if holder:GetParent() and holder:GetParent():GetParent() == column then
                                local _, _, _, _, y = object:GetPoint()
                                rowsFit = rowsFit and -(y or 0) + object:GetStringHeight() <= holder:GetHeight()
                            end
                        end
                    end
                    test.check(prefix .. ": sample buttons stay above and within the preview", inside, true)
                    test.check(prefix .. ": sample buttons do not overlap", separated, true)
                    test.check(prefix .. ": wrapped checkbox labels fit their sections", labelsFit, true)
                    test.check(prefix .. ": row labels and section summaries fit", rowsFit, true)
                    local _, _, _, _, columnY = column:GetPoint()
                    test.check(prefix .. ": the controls end above the footer",
                        -columnY + column:GetHeight() <= editor:GetHeight() - 20, true)
                end
                ns.editorPages.open("item")
                local function previewBounds()
                    local _, _, _, x, y = host:GetPoint()
                    return { x, y, host:GetWidth(), host:GetHeight() }
                end
                local bounds = previewBounds()
                ns.setOption("itemPanels", false)
                ns.refreshEditorStyle()
                local prefix = client .. "/" .. language[1] .. "/" .. style
                test.check(prefix .. ": disabling restyle keeps the preview in place", previewBounds(), bounds)
                ns.setOption("layout", "blizzard")
                ns.refreshEditorStyle()
                test.check(prefix .. ": Blizzard layout status keeps the preview in place", previewBounds(), bounds)
                ns.setOption("itemPanels", true)
                ns.setOption("layout", "pretty")
                ns.refreshEditorStyle()
            end
            UIParent:SetSize(960, 600)
            world.fireEvent("DISPLAY_SIZE_CHANGED")
            test.check(client .. "/" .. language[1] .. ": editor fits a small UI",
                editor:GetWidth() * editor:GetScale() <= 928 and editor:GetHeight() * editor:GetScale() <= 568, true)
            UIParent:SetSize(1920, 1080)
            world.fireEvent("UI_SCALE_CHANGED")
            test.check(client .. "/" .. language[1] .. ": a larger UI restores normal size", editor:GetScale(), 1)
        end
    end
end
