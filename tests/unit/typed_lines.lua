-- Item lines the client types are read by their type, so a use or equip
-- effect, flavor text, an enchant, and a requirement need none of their
-- English wording.
return function(test)
    local LINE = { None = 0, ItemName = 1, ItemBinding = 2, ItemEnchantmentPermanent = 15, FlavorText = 37,
        UsageRequirement = 43, ItemSpellTriggerOnUse = 44, ItemSpellTriggerOnEquip = 45 }
    local texts = { "Pierre de foyer", "Lié", "Vous ramène à Hurlevent.", "Un souvenir de la taverne.",
        "Enchanté : Stamina +2 and Armor +16", "Niveau 70 requis", "Augmente les dégâts de Frappe-tempête de 10%." }
    local types = { LINE.ItemName, LINE.ItemBinding, LINE.ItemSpellTriggerOnUse, LINE.FlavorText,
        LINE.ItemEnchantmentPermanent, LINE.UsageRequirement, LINE.ItemSpellTriggerOnEquip }
    local capture = { enums = { TooltipDataType = { Item = 0 }, TooltipDataLineType = LINE },
        data = { type = 0, id = 6948, quality = 1, lines = {} }, lines = {} }
    for index, text in ipairs(texts) do
        capture.data.lines[index] = { type = types[index], lineIndex = index, leftText = text }
        capture.lines[index] = { left = { text = text } }
    end
    capture.data.lines[6].usable = false
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua", "Tooltips/Item.lua" }, capture)
    local model = ns.TooltipTypes[0].read(world.main, capture.data, ns.Game)
    local function lefts(rows)
        local out = {}
        for index, row in ipairs(rows) do out[index] = ns.util.plainText(row.left) end
        return out
    end
    test.check("a typed use effect, with its gear marker", { lefts(model.effects), model.effects[1].use },
        { { "Vous ramène à Hurlevent." }, true })
    test.check("a typed equip effect, among the stats", lefts(model.equipEffects),
        { "Augmente les dégâts de Frappe-tempête de 10%." })
    test.check("typed flavor text, without quotes", lefts(model.flavor), { "Un souvenir de la taverne." })
    test.check("a typed enchant, after its label", #model.enchants, 2)
    local requirement = model.footerRight[1]
    test.check("a typed requirement, met by its usable flag", { requirement.left, requirement.met },
        { "Niveau 70 requis", false })
    test.check("nothing left among other rows", #model.extras, 0)
end
