-- A unit's level goes on a plate under its portrait; with the plate off, or no
-- portrait, it stays in the info line.
-- Also verify Retail and Forever item-level preview extensions independently.
return function(test)
    local UNIT = 2
    local fixture = {
        enums = {
            TooltipDataType = {
                Item = 0,
                Unit = UNIT,
            },
        },
    }

    local baseFiles = {
        "Core/Util.lua",
        "Core/Palette.lua",
        "Core/Settings.lua",
        "Locale/Locale.lua",
        "Locale/English.lua",
        "Game/Game.lua",
        "Game/TooltipData.lua",
        "Panel/Layout.lua",
        "Panel/Render.lua",
        "Tooltips/Unit.lua",
    }

    -- Original unit-level display tests.
    local ns = test.load(baseFiles, fixture)

    local model = ns.ui.unitModel({
        name = "Thrall",
        isPlayer = true,
        level = 60,
        race = "Orc",
        className = "Shaman",
        classFile = "SHAMAN",
        iconPath = "Interface\\Icons\\Spell_Nature_BloodLust",
        quests = {},
    })

    local anchor = CreateFrame("Frame", nil, UIParent)

    local function draw()
        local panel = ns.ui.renderPreview(anchor, model, UNIT)
        local info

        for _, font in ipairs(panel.pool) do
            local text = ns.util.uncolored(font._text or "")
            if font._shown and text:find("Orc Shaman", 1, true) then
                info = text
            end
        end

        return {
            plate = panel.badge._shown and panel.badgeText._text or false,
            info = info,
        }
    end

    test.check("the level is on the plate", draw(), {
        plate = "60",
        info = "Orc Shaman",
    })

    ns.setOption("unitLevelBadge", false)
    test.check("with the plate off, the info line has it", draw(), {
        plate = false,
        info = "Level 60 Orc Shaman",
    })

    ns.setOption("unitLevelBadge", true)
    ns.setOption("iconUnits", false)

    test.check("without a portrait, the info line has it", draw(), {
        plate = false,
        info = "Level 60 Orc Shaman",
    })

    ns.setOption("iconUnits", true)
    model.level = -1

    test.check("a skull level shows as ??", draw().plate, "??")

    -- Identify the synthetic item-level row by its exact rendered shape:
    -- a non-empty localized label followed by a color-coded numeric value.
    -- This avoids false positives from unrelated text that happens to contain
    -- the digits "61" (for example, spell IDs or specialization descriptions).
    local function isItemLevelRow(row)
        if type(row) ~= "table" or type(row.left) ~= "string" then
            return false
        end

        local label, value = row.left:match(
            "^(.-)|cff%x%x%x%x%x%x([%d%.]+)|r$"
        )
        if not label or label == "" then
            return false
        end

        return tonumber(value) == 61
    end

    local function itemLevelRows(preview)
        local count = 0

        for _, row in ipairs(preview.extras or {}) do
            if isItemLevelRow(row) then
                count = count + 1
            end
        end

        return count
    end

    local function makePreview(clientNS)
        return clientNS.ui.unitModel({
            name = "Somniferie",
            unit = "player",
            isPlayer = true,
            level = 60,
            race = "Human",
            className = "Warrior",
            classFile = "WARRIOR",
            iconPath = "Interface\\Icons\\INV_Misc_Head_Human_02",
            faction = "Alliance",
            quests = {},
            extras = {},
        })
    end

    -- Test each client independently, using its actual extension.
    local function testItemLevelExtension(extensionFile, clientName)
        local files = {}

        for _, file in ipairs(baseFiles) do
            files[#files + 1] = file
        end

        files[#files + 1] = extensionFile

        local clientNS = test.load(files, fixture)

        clientNS.setOption("unitItemLevelEnabled", true)

        local preview = makePreview(clientNS)

        test.check(
            clientName .. ": item level appears in preview",
            itemLevelRows(preview),
            1
        )

        -- Re-running the extension must not duplicate preview rows.
        local extension = clientNS.TooltipTypes[UNIT].extension

        extension.afterRead(preview, {
            game = clientNS.Game,
            rootModel = preview,
            preview = true,
        })

        test.check(
            clientName .. ": repeated rendering does not duplicate item level",
            itemLevelRows(preview),
            1
        )

        -- Disabling the option must prevent a new preview row.
        clientNS.setOption("unitItemLevelEnabled", false)

        local disabledPreview = makePreview(clientNS)

        test.check(
            clientName .. ": disabling item level hides its preview row",
            itemLevelRows(disabledPreview),
            0
        )
    end

    testItemLevelExtension(
        "Retail/Tooltips/UnitExtension.lua",
        "Retail"
    )

    testItemLevelExtension(
        "Forever/Tooltips/UnitSpecialization.lua",
        "Forever"
    )
end
