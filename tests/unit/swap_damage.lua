-- Swap Damage Stats moves a weapon's damage to the large line, colored as the
-- DPS is there, and its DPS and speed to the small one under it, their
-- numbers a little brighter than its grey words.
return function(test)
    local FILES = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua",
        "Panel/Render.lua", "Tooltips/Item.lua" }

    -- A weapon's model, and its lines as drawn from the top: text and size.
    local function weapon(lines, locale, word)
        local capture = { client = locale and { locale = locale },
            enums = { TooltipDataType = { Item = 0 }, TooltipDataLineType = { None = 0, ItemName = 1 } },
            data = { type = 0, id = 2000, quality = 2, lines = {} }, lines = {},
        }
        for index, line in ipairs(lines) do
            local left, right = line, nil
            if type(line) == "table" then left, right = line[1], line[2] end
            capture.data.lines[index] = { type = index == 1 and 1 or 0, lineIndex = index, leftText = left,
                rightText = right }
            capture.lines[index] = { left = { text = left }, right = right and { text = right } }
        end
        local files = FILES
        if locale then
            files = { unpack(FILES) }
            table.insert(files, 6, "Locale/" .. locale .. ".lua")
        end
        local ns, world = test.load(files, capture)
        local model = ns.TooltipTypes[0].read(world.main, capture.data, ns.Game)
        local anchor = CreateFrame("Frame", nil, UIParent)
        local function drawn(colored)
            local panel = ns.ui.renderPreview(anchor, model, 0)
            local out = {}
            for _, font in ipairs(panel.pool) do
                local text = font:IsShown() and font:GetText() or ""
                if ns.util.uncolored(text):find(word or "Damage", 1, true) then
                    out[#out + 1] = colored and text or { ns.util.uncolored(text), (select(2, font:GetFont())) }
                end
            end
            return out
        end
        return ns, model, drawn
    end

    local DOT = "  \194\183  "
    local ns, model, drawn = weapon({ "Test Sword", { "41 - 77 Damage", "Speed 2.60" }, "(22.7 damage per second)",
        "+3 Strength" })
    test.check("off: DPS leads, damage and speed under it", drawn(),
        { { "22.7 Damage per Second", 18 }, { "41 - 77 Damage" .. DOT .. "Speed 2.60", 12 } })
    ns.setOption("swapDamage", true)
    test.check("on: damage leads, DPS and speed under it", drawn(),
        { { "41 - 77 Damage", 18 }, { "22.7 Damage per Second" .. DOT .. "Speed 2.60", 12 } })
    test.check("on: the numbers bright and words dim on both lines", drawn(true),
        { "|cffF2E8D541 - 77|r |cffA89F8EDamage|r", "|cffD9DADB22.7|r Damage per Second" .. DOT .. "Speed |cffD9DADB2.60|r" })

    -- A weapon without a DPS line keeps its damage where it was.
    model.weaponDps = nil
    test.check("on, without DPS: damage stays on the small line", drawn(),
        { { "41 - 77 Damage" .. DOT .. "Speed 2.60", 12 } })

    local wandNs, _, wand = weapon({ "Test Wand", { "64 - 120 Shadow Damage", "Speed 1.50" },
        "(61.3 damage per second)" })
    wandNs.setOption("swapDamage", true)
    test.check("on: a school's damage keeps its stat colors", wand(true),
        { "|cffC174FF64 - 120|r |cffC9A2EEShadow Damage|r", "|cffD9DADB61.3|r Damage per Second" .. DOT .. "Speed |cffD9DADB1.50|r" })
    wandNs.setOption("statColors", false)
    test.check("on, stat colors off: a school's damage reads as the sword's", wand(true),
        { "|cffF2E8D564 - 120|r |cffA89F8EShadow Damage|r", "|cffD9DADB61.3|r Damage per Second" .. DOT .. "Speed |cffD9DADB1.50|r" })

    -- Russian names the damage before its amount.
    local ruNs, _, ru = weapon({ "Боевая перчатка Веригана", { "Урон: 153-256", "Скорость 3,80" },
        "(53,8 ед. урона в секунду)" }, "ruRU", "Урон")
    ruNs.setOption("swapDamage", true)
    test.check("ruRU, on: words before the amount are dim too", ru(true)[1],
        "|cffA89F8EУрон:|r |cffF2E8D5153-256|r")
end
