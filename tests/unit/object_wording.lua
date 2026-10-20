-- World objects and auras are read by their wording: the game's own strings,
-- and skill and dispel names as the client words them (ns.Locale), so a
-- language file that gives those names reads its client's tooltips.
return function(test)
    local OBJECT, AURA = 33, 7

    -- A model from lines, the first the name: each a left text, or { left, right }.
    -- skills and dispels, when given, stand in for a language file's names.
    local function read(kind, file, lines, names)
        local capture = { enums = { TooltipDataType = { Item = 0, Object = OBJECT, UnitAura = AURA } },
            data = { type = kind, lines = {} }, lines = {} }
        for index, line in ipairs(lines) do
            local left, right, color = line, nil, nil
            if type(line) == "table" then left, right, color = line[1], line[2], line.color end
            capture.data.lines[index] = { type = 0, lineIndex = index, leftText = left, rightText = right,
                leftColor = color and { r = color[1], g = color[2], b = color[3] } }
            capture.lines[index] = { left = { text = left }, right = right and { text = right } }
        end
        -- A language file loads after English.lua, before everything that reads it.
        local function language(_, ns)
            for table, entries in pairs(names or {}) do
                for key, name in pairs(entries) do ns.Locale[table][key] = name end
            end
        end
        local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
            "Locale/English.lua", language, "Game/Game.lua", "Game/TooltipData.lua", "Data/Nodes.lua",
            "Panel/Layout.lua", "Panel/Render.lua", file }, capture)
        return ns.TooltipTypes[kind].read(world.main, capture.data, ns.Game)
    end

    local function object(lines, names)
        local model = read(OBJECT, "Tooltips/Object.lua", lines, names)
        local details = {}
        for index, row in ipairs(model.details) do details[index] = row.left end
        return { skill = model.skill, row = model.skillRow and model.skillRow.name, details = details }
    end

    test.check("enUS: a herb's skill line", object({ "Peacebloom", "Herbalism" }),
        { skill = "Herbalism", row = "Herbalism", details = {} })
    test.check("enUS: a vein's requirement", object({ "Copper Vein", "Requires Mining" }),
        { skill = "Mining", row = "Mining", details = { "Requires Mining" } })
    test.check("enUS: a locked chest", object({ "Battered Chest", "Locked", "Requires Lockpicking (25)" }),
        { skill = "Lockpicking", details = { "Locked", "Requires Lockpicking (25)" } })
    -- "Locked" keeps the game's color, which tells how hard the lock is to pick.
    local chest = read(OBJECT, "Tooltips/Object.lua", { "Battered Chest", { "Locked", "", color = { 1, .5, .25 } } })
    test.check("enUS: a lock's difficulty color", chest.details[1].color, { 1, .5, .25 })
    test.check("a skill line in the client's words", object({ "Peacebloom", "Kr\195\164uterkunde" },
        { skills = { Herbalism = "Kr\195\164uterkunde" } }),
        { skill = "Herbalism", row = "Kr\195\164uterkunde", details = {} })

    local function aura(lines, names)
        local model = read(AURA, "Tooltips/Aura.lua", lines, names)
        return { dispel = model.dispel, remaining = model.remaining, text = model.text }
    end

    test.check("enUS: a dispel type and the time left", aura({ { "Deadly Poison", "Poison" },
        "Deals 12 Nature damage every 3 sec.", "9 seconds remaining" }),
        { dispel = "Poison", remaining = "9 seconds remaining", text = "Deals 12 Nature damage every 3 sec." })
    test.check("enUS: a minute left", aura({ "Power Word: Fortitude", "Increases Stamina by 32.", "1 minute remaining" }),
        { remaining = "1 minute remaining", text = "Increases Stamina by 32." })
    test.check("a dispel type in the client's words", aura({ { "Deadly Poison", "Gift" } },
        { dispels = { Poison = "Gift" } }), { dispel = "Poison" })
end
