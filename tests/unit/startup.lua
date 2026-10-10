-- Registration waits for the addon's own event and uses saved settings.
return function(test)
    local files = { "Core/Util.lua", "UI/Options.lua", "PrettyTooltip.lua" }
    local ns, world = test.load(files)
    local before = #world.objects
    test.check("slash command waits for startup", SlashCmdList.PRETTYTOOLTIP, nil)
    test.check("slash aliases wait for startup", SLASH_PRETTYTOOLTIP1, nil)
    test.check("settings are available before startup", ns.option("itemPanels"), true)

    local page, registered, opened
    local registrations = 0
    local category = { GetID = function() return 42 end }
    Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
            page = canvas
            test.check("category name", name, "PrettyTooltip")
            registrations = registrations + 1
            return category
        end,
        RegisterAddOnCategory = function(value) registered = value end,
        OpenToCategory = function(id) opened = id end,
    }
    world.fireEvent("ADDON_LOADED", "AnotherAddon")
    test.check("another addon's event does not register settings", registrations, 0)
    test.check("another addon's event does not create UI", #world.objects, before)
    test.check("another addon's event does not register commands", SlashCmdList.PRETTYTOOLTIP, nil)

    PrettyTooltipDB = { itemPanels = false, originalKey = "CTRL" }
    world.fireEvent("ADDON_LOADED", "PrettyTooltip")
    test.check("settings category registered", registered == category, true)
    test.check("settings page starts hidden", page:IsShown(), false)
    -- The first checkbox controls item panels; it must use the saved false.
    local firstCheckbox
    for _, child in ipairs(page._children) do
        if child._kind == "CheckButton" then firstCheckbox = child break end
    end
    test.check("controls use settings saved after file loading", firstCheckbox:GetChecked(), false)
    test.check("saved settings are retained", PrettyTooltipDB.originalKey, "CTRL")
    test.check("long slash alias", SLASH_PRETTYTOOLTIP1, "/prettytooltip")
    test.check("short slash alias", SLASH_PRETTYTOOLTIP2, "/ptip")

    local editorOpened = 0
    ns.openEditor = function() editorOpened = editorOpened + 1 end
    SlashCmdList.PRETTYTOOLTIP("")
    test.check("default command opens editor", editorOpened, 1)
    SlashCmdList.PRETTYTOOLTIP(" OPTIONS ")
    test.check("options command opens registered settings", opened, 42)

    local after = #world.objects
    local handler = SlashCmdList.PRETTYTOOLTIP
    world.fireEvent("ADDON_LOADED", "PrettyTooltip")
    ns.start()
    ns.Options.register()
    ns.Commands.register()
    test.check("repeated startup does not recreate UI", #world.objects, after)
    test.check("repeated startup does not register another category", registrations, 1)
    test.check("repeated startup preserves command handler", SlashCmdList.PRETTYTOOLTIP == handler, true)
    local listeners = 0
    for _, object in ipairs(world.objects) do
        if object:IsEventRegistered("ADDON_LOADED") then listeners = listeners + 1 end
    end
    test.check("startup listener removed", listeners, 0)

    Settings = nil
    local legacyPage, legacyOpened
    InterfaceOptions_AddCategory = function(canvas) legacyPage = canvas end
    InterfaceOptionsFrame_OpenToCategory = function(canvas) legacyOpened = canvas end
    ns, world = test.load(files)
    test.check("legacy category also waits for startup", legacyPage, nil)
    world.fireEvent("ADDON_LOADED", "PrettyTooltip")
    ns.openSettings()
    test.check("legacy settings opens registered page", legacyOpened == legacyPage and legacyPage ~= nil, true)
    InterfaceOptions_AddCategory, InterfaceOptionsFrame_OpenToCategory = nil, nil

    ns, world = test.load({ "Core/Util.lua", "UI/Options.lua" })
    listeners = 0
    for _, object in ipairs(world.objects) do
        if object:IsEventRegistered("ADDON_LOADED") then listeners = listeners + 1 end
    end
    test.check("options module alone installs no startup listener", listeners, 0)
    test.check("options module alone installs no command", SlashCmdList.PRETTYTOOLTIP, nil)
end
