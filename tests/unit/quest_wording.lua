-- A quest's lines are read by their wording: the game's own strings, and
-- Questie's phrases in the language Questie is set to, which it is asked for
-- and which need not be the client's.
return function(test)
    local QUEST = 23

    -- The quest's model from its lines, the first its title; questie, when
    -- given, is Questie's translations by English phrase.
    local function read(lines, questie)
        local capture = { enums = { TooltipDataType = { Item = 0, Quest = QUEST } },
            data = { type = QUEST, lines = {} }, lines = {} }
        for index, left in ipairs(lines) do
            capture.data.lines[index] = { type = 0, lineIndex = index, leftText = left }
            capture.lines[index] = { left = { text = left } }
        end
        local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
            "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
            "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Quest.lua" }, capture)
        if questie then
            local l10n = setmetatable({}, { __call = function(_, phrase) return questie[phrase] or phrase end })
            QuestieLoader = { _modules = { l10n = l10n } }
        end
        local model = ns.TooltipTypes[QUEST].read(world.main, capture.data, ns.Game)
        QuestieLoader = nil
        local objectives, extras = {}, {}
        for index, row in ipairs(model.objectives) do objectives[index] = { row.left, row.right, row.completed } end
        for index, row in ipairs(model.extras) do extras[index] = { row.left, row.right } end
        return {
            name = model.name, level = model.level, tags = model.tags, zone = model.zone,
            state = { model.active, model.ready, model.failed, model.completed, model.repeatable },
            objectives = objectives, extras = extras,
        }
    end

    test.check("enUS: a quest in progress, ready to turn in", read({
        "[27D] The Fury Runs Deep",
        "You are on this quest (Complete)",
        "Elite",
        "Instance: Dun Modr",
        "Your progress:",
        " - Head of Deepfury: 1/1",
        "Ended by: Motley Garmason",
        "Found in: Wetlands",
    }), {
        name = "The Fury Runs Deep", level = 27, tags = { "Dungeon", "Elite" }, zone = "Dun Modr",
        state = { true, true, false },
        objectives = { { "Head of Deepfury", "1/1", true } },
        extras = { { "Ended by", "Motley Garmason" }, { "Found in", "Wetlands" } },
    })

    test.check("enUS: a quest done, its date on the line after its label", read({
        "The Fury Runs Deep",
        "You have completed this quest",
        "Requires Level 20",
        "Completed on:",
        "2026-10-01",
    }), {
        name = "The Fury Runs Deep", level = 20, tags = {},
        state = { nil, nil, nil, true },
        objectives = {},
        extras = { { "Completed on", "2026-10-01" } },
    })

    test.check("enUS: a repeatable quest not taken, and the game's own headings", read({
        "Rise of the Silithid",
        "This quest is repeatable",
        "Objectives",
        "Requirements:",
        "Started by: Hierophant Theodora Mulvadania",
    }), {
        name = "Rise of the Silithid", tags = {},
        state = { nil, nil, nil, nil, true },
        objectives = {},
        extras = { { "Started by", "Hierophant Theodora Mulvadania" } },
    })

    -- Questie set to French on an English client, as it allows: its words,
    -- and " : " after a label.
    local french = { ["You are on this quest"] = "Vous effectuez cette qu\195\170te", Failed = "Echec",
        ["Started by"] = "D\195\169but", ["Your progress"] = "Progression", Instance = "Instance", [": "] = " : " }
    test.check("Questie in French: its phrases and its separator", read({
        "[42] La fureur des profondeurs",
        "Vous effectuez cette qu\195\170te (Echec)",
        "Instance : Dun Modr",
        "Progression :",
        "D\195\169but : Motley Garmason",
    }, french), {
        name = "La fureur des profondeurs", level = 42, tags = {}, zone = "Dun Modr",
        state = { true, false, true },
        objectives = {},
        extras = { { "D\195\169but", "Motley Garmason" } },
    })
end
