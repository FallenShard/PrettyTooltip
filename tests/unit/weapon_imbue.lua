-- A weapon imbue's buff button shows the weapon's own tooltip; the panel shows
-- the imbue instead, as the spell that applied it, with its weapon slot,
-- charges, and time left. Any other weapon tooltip, an imbue the data does not
-- know, and the setting turned off are covered too, on Forever and on retail.
return function(test)
    local ITEM, SPELL, AURA, NAME = 0, 1, 7, 13
    local weapon = { type = ITEM, id = 19019, lines = {
        { type = 0, lineIndex = 1, leftText = "Thunderfury" },
        { type = 0, lineIndex = 2, leftText = "Windfury 1 (59 min)" },
    } }
    local fixture = {
        enums = { TooltipDataType = { Item = ITEM, Spell = SPELL, UnitAura = AURA },
            TooltipDataLineType = { None = 0, SpellName = NAME } },
        data = weapon,
        lines = { { left = { text = "Thunderfury" } }, { left = { text = "Windfury 1 (59 min)" } } },
    }
    local files = { "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua", "Data/Imbues.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua", "Tooltips/Spell.lua", "Tooltips/Aura.lua",
        "Tooltips/Imbue.lua", "Integration/Native.lua", "Integration/Hooks.lua" }

    -- The spells' own tooltips, as the hidden scanner would read them.
    local spells = {
        [8232] = { "Windfury Weapon", "Rank 1",
            "Imbue the Shaman's weapon with wind. Each hit has a 20% chance of dealing additional damage." },
        [8679] = { "Instant Poison", "", "Coats a weapon with poison that lasts for 30 minutes." },
        [334302] = { "Windfury Weapon", "", "Imbue your main-hand weapon with the element of Wind for 1 hour." },
    }
    local function start(enchants)
        local ns, world = test.load(files, fixture)
        PrettyTooltipDB = {}
        local scanner = CreateFrame("GameTooltip", nil, UIParent)
        scanner.prettyTooltipScanner = true
        ns.Game.spellTooltip = function(spellID)
            local spell = spells[spellID]
            if not spell then return end
            return scanner, { type = SPELL, id = spellID, lines = {
                { type = NAME, lineIndex = 1, leftText = spell[1], rightText = spell[2] },
                { type = 0, lineIndex = 2, leftText = spell[3] },
            } }
        end
        ns.Game.slotIcon = function(slot) return "weapon icon " .. slot end
        enchants(ns)
        ns.Hooks.install()
        return ns, world
    end

    -- An imbue's buff button, as the game's buff bar marks it, for a weapon slot.
    local function button(slot, auraType)
        local frame = CreateFrame("Button", nil, UIParent)
        frame.auraType = auraType or "TempEnchant"
        frame.GetID = function() return slot end
        return frame
    end
    local function hover(ns, world, owner)
        local tooltip = world.main
        tooltip.GetOwner = function() return owner end
        tooltip:Show()
        tooltip:SetAlpha(1)
        for _, callback in ipairs(world.postCalls[ITEM]) do callback(tooltip, weapon) end
        local panel = ns.ui.panels[tooltip]
        local texts = {}
        for _, font in ipairs(panel and panel.pool or {}) do
            if font._shown and font._text and font._text ~= "" then texts[#texts + 1] = font._text end
        end
        return panel, table.concat(texts, " | ")
    end
    -- Titles are drawn in capitals, as their style sets.
    local function has(text, part) return text:lower():find(part:lower(), 1, true) ~= nil end

    -- Forever: GetWeaponEnchantInfo, four values a weapon. Windfury 1 on the
    -- main hand, 59 minutes and 10 seconds left.
    local mainHand = { true, 3550000, 0, 283 }
    local ns, world = start(function()
        GetWeaponEnchantInfo = function()
            return mainHand[1], mainHand[2], mainHand[3], mainHand[4], false, nil, nil, nil
        end
    end)
    local panel, text = hover(ns, world, button(16))
    test.check("an imbue's button shows the imbue's panel", panel.dataType, "imbue")
    test.check("as its spell, with its slot and time left, not the weapon", {
        has(text, "Windfury Weapon"), has(text, "Imbue the Shaman's weapon"), has(text, "Main Hand"),
        has(text, "59 minutes remaining"), has(text, "Thunderfury") }, { true, true, true, true, false })
    local model = ns.TooltipTypes.imbue.read(world.main, weapon, ns.Game)
    test.check("its bar runs the hour Windfury lasts", { model.duration, model.expires }, { 3600, 1000 + 3550 })

    -- A poison's charges.
    mainHand = { true, 1700000, 60, 323 }
    panel, text = hover(ns, world, button(16))
    test.check("a poison shows its charges", { has(text, "Instant Poison"), has(text, "60 Charges"),
        has(text, "28 minutes remaining") }, { true, true, true })

    -- The last minute counts seconds, rounded up.
    mainHand = { true, 29400, 0, 283 }
    panel, text = hover(ns, world, button(16))
    test.check("the last minute in seconds", has(text, "30 seconds remaining"), true)

    -- An imbue the data does not know goes by the weapon's line for it, with
    -- the weapon's icon and no bar.
    mainHand = { true, 720000, 0, 999999 }
    panel, text = hover(ns, world, button(16))
    model = ns.TooltipTypes.imbue.read(world.main, weapon, ns.Game)
    test.check("an unknown imbue by the weapon's name for it",
        { panel.dataType, model.spell.name, model.spell.icon, model.duration, has(text, "12 minutes remaining") },
        { "imbue", "Windfury 1", "weapon icon 16", nil, true })

    -- The off hand's own imbue.
    mainHand = { false, nil, nil, nil }
    GetWeaponEnchantInfo = function() return false, nil, nil, nil, true, 3550000, 0, 283 end
    panel, text = hover(ns, world, button(17))
    test.check("the off hand's imbue", { panel.dataType, has(text, "Off Hand") }, { "imbue", true })
    panel = hover(ns, world, button(16))
    test.check("a slot without one shows its weapon", panel.dataType, ITEM)

    -- Any other weapon tooltip is the weapon's: a character sheet's slot.
    GetWeaponEnchantInfo = function() return mainHand[1], mainHand[2], mainHand[3], mainHand[4] end
    mainHand = { true, 3550000, 0, 283 }
    panel = hover(ns, world, button(16, "Buff"))
    test.check("another owner shows the weapon", panel.dataType, ITEM)
    panel = hover(ns, world, button(16))
    test.check("the imbue again", panel.dataType, "imbue")

    -- The setting turns it off: the weapon's tooltip, as the item settings show it.
    ns.setOption("imbuePanels", false)
    panel = hover(ns, world, button(16))
    test.check("turned off, the weapon shows", panel.dataType, ITEM)
    ns.setOption("imbuePanels", true)
    ns.setOption("layout", "blizzard")
    panel = hover(ns, world, button(16))
    test.check("the Blizzard layout shows the game's weapon tooltip", panel.dataType, ITEM)
    ns.setOption("layout", "pretty")
    test.check("the setting is on by default and in the options",
        { ns.option("imbuePanels") ~= nil, ns.TOOLTIP_TYPES[5].restyle }, { true, "imbuePanels" })
    GetWeaponEnchantInfo = nil

    -- Retail: C_PaperDollInfo, and retail's own enchant IDs.
    WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 1, 1
    ns, world = start(function()
        C_PaperDollInfo = { GetTemporaryEnchantmentInfo = function(slot)
            if slot == 16 then
                return { enchantID = 5401, remainingTimeMs = 1800000, chargesRemaining = 0, hasExpirationTime = true }
            end
        end }
    end)
    panel, text = hover(ns, world, button(16))
    model = ns.TooltipTypes.imbue.read(world.main, weapon, ns.Game)
    test.check("retail: the imbue by retail's enchant ID", { panel.dataType, has(text, "element of Wind"),
        has(text, "30 minutes remaining"), model.duration }, { "imbue", true, true, 3600 })
    C_PaperDollInfo, WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = nil, nil, nil
end
