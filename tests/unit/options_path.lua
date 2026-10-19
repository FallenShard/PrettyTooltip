-- The addon never opens or closes the game's settings window, which would run
-- its code under the addon's taint: /ptip options and the editor's More
-- options say where the page is, in combat as out of it, and the page's
-- editor button opens the editor over the window.
return function(test)
    local opened, hidden, printed, page = 0, 0, {}, nil
    Settings = {
        RegisterCanvasLayoutCategory = function(canvas)
            page = canvas
            return { GetID = function() return 7 end }
        end,
        RegisterAddOnCategory = function() end,
        OpenToCategory = function() opened = opened + 1 end,
    }
    HideUIPanel = function() hidden = hidden + 1 end
    GAMEMENU_OPTIONS, ADDONS = "Options", "AddOns"
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "UI/Options.lua" }, {})
    ns.Options.register()
    SettingsPanel = CreateFrame("Frame")
    SettingsPanel:Show()
    print = function(text) printed[#printed + 1] = text end

    local path = "PrettyTooltip: its options are in Options > AddOns > PrettyTooltip."
    InCombatLockdown = function() return true end
    ns.showOptionsPath()
    InCombatLockdown = function() return false end
    ns.showOptionsPath()
    test.check("the path is told, in combat and out", printed, { path, path })
    test.check("and the window is never opened", opened, 0)

    local editorOpened = 0
    ns.openEditor = function() editorOpened = editorOpened + 1 end
    local editorButton
    for _, child in ipairs(page._children) do
        if child._kind == "Button" then editorButton = child break end
    end
    editorButton:GetScript("OnClick")(editorButton)
    test.check("the page's button opens the editor over the window, which stays open",
        { editorOpened, hidden, SettingsPanel:IsShown() }, { 1, 0, true })
end
