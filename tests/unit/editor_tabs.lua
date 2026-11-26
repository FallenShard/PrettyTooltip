-- Every page in the editor's page list draws, including the types whose
-- details section has no title, on every client's .toc.
return function(test)
    local clients = {}
    for client in pairs(test.tocs) do clients[#clients + 1] = client end
    table.sort(clients)
    for _, client in ipairs(clients) do
        local ns, world = test.load(test.tocs[client], { enums = test.enums })
        ns.openEditor()
        local labels = { [ns.L["General"]] = true, [ns.L["Tooltips"]] = true, [ns.L["Other Tooltips"]] = true }
        for _, tooltipType in ipairs(ns.editorSamples.order) do
            labels[ns.L[ns.editorSamples.tooltipTypes[tooltipType].label]] = true
        end
        local clicked = 0
        for _, object in ipairs(world.objects) do
            local label = object.label and object.label.GetText and object.label:GetText()
            local onClick = object.GetScript and object:GetScript("OnClick")
            if label and labels[label] and onClick and object:GetObjectType() == "Button"
                and object:GetParent() ~= PrettyTooltipEditor then
                local ok, problem = pcall(onClick, object)
                if not ok then test.check(client .. ": the " .. label .. " page draws", problem, nil) end
                clicked = clicked + 1
            end
        end
        test.check(client .. ": every page was tried", clicked, #ns.editorSamples.order + 3)
    end
end
