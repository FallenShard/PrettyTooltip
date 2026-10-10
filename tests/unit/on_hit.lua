-- Proc highlighting, including the native rewrite and panel style overrides.
return function(test)
    local original = "Chance on hit: Deals 39 to 59 Holyfire damage. Deals 3 times as much damage to Fire Elementals."
    local capture = {
        enums = { TooltipDataType = { Item = 0, Spell = 1 }, TooltipDataLineType = { None = 0, ItemName = 1 } },
        data = { type = 0, quality = 3, lines = {
            { type = 1, lineIndex = 1, leftText = "Test Weapon" },
            { type = 0, lineIndex = 2, leftText = original },
        } },
        lines = { { left = { text = "Test Weapon" } }, { left = { text = original } } },
    }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Game/Game.lua",
        "Data/Stats.lua", "Panel/Layout.lua", "Tooltips/Spell.lua", "Integration/ItemLite.lua" }, capture)
    ns.ItemLite.register()
    ns.ui.registerItemHooks()
    local function styleOnHit(text) return ns.Stats.styleOnHit(text, ns.option("statColors")) end
    local function color(code, text) return "|cff" .. code .. text .. "|r" end

    for school, code in pairs({
        Arcane = "F190E2", Fire = "FF9960", Frost = "82D8FA", Holy = "FBCF74",
        Nature = "A6DB7E", Shadow = "BF84EB", Holyfire = "FDB46A",
    }) do
        local text = "Deals 40 " .. school .. " damage."
        local styled = styleOnHit(text)
        test.check(school .. " proc palette", styled, "Deals " .. color(code, "40") .. " " .. school .. " damage.")
        -- Render a real spell description to ensure the two paths agree.
        local spell = { name = "Test spell", rank = "", cells = {}, details = {}, requirements = {},
            description = { text }, extras = {} }
        local panel = ns.ui.renderPreview(CreateFrame("Frame", nil, UIParent), spell, 1)
        local description
        for _, font in ipairs(panel.pool) do
            if font:IsShown() and ns.util.uncolored(font:GetText() or "") == text then description = font:GetText() end
        end
        test.check(school .. " proc matches spell rendering", styled, description)
    end
    test.check("unqualified damage uses spell fallback", styleOnHit("Deals 40 to 60 damage."),
        "Deals " .. color("FFF6E4", "40") .. " to " .. color("FFF6E4", "60") .. " damage.")
    test.check("physical damage uses spell fallback", styleOnHit("Deals 40 Physical damage."),
        "Deals " .. color("FFF6E4", "40") .. " Physical damage.")
    test.check("non-damage proc uses neutral numbers", styleOnHit("Stuns the target for 3 sec."),
        "Stuns the target for " .. color("FFF6E4", "3") .. " sec.")
    test.check("unknown school stays readable", styleOnHit("Deals 40 Chaos damage."),
        "Deals " .. color("FFF6E4", "40") .. " Chaos damage.")
    test.check("capitalized school labels", styleOnHit("Deals 40 FIRE DAMAGE."),
        "Deals " .. color("FF9960", "40") .. " FIRE DAMAGE.")
    test.check("generic damage wording does not mask the school", styleOnHit("Causes additional damage: 40 Fire damage."),
        "Causes additional damage: " .. color("FF9960", "40") .. " Fire damage.")
    test.check("creature names cannot imply a school", styleOnHit("Deals 40 damage to Fire Elementals."),
        "Deals " .. color("FFF6E4", "40") .. " damage to Fire Elementals.")
    test.check("non-damage school mentions cannot imply a school", styleOnHit("Rapid Fire grants 20% attack speed."),
        "Rapid Fire grants " .. color("FFF6E4", "20%") .. " attack speed.")
    test.check("spell names can supply a school", ns.Palette.detectSchool({ "Heals 40 health." }, "Holy Light"), "Holy")
    test.check("description takes precedence over spell name", ns.Palette.detectSchool({ "Deals 40 Fire damage." }, "Holy Light"), "Fire")
    local escaped = "Deals 40 Fire damage. |TInterface\\Icons\\Spell_Fire_01:16:16|t"
    test.check("icon escapes are preserved", styleOnHit(escaped),
        "Deals " .. color("FF9960", "40") .. " Fire damage"
            .. ". |TInterface\\Icons\\Spell_Fire_01:16:16|t")
    local styled = styleOnHit(original)
    test.check("highlighting is repeatable", styleOnHit(styled), styled)
    ns.setOption("statColors", false)
    test.check("stat colors off preserves wording", styleOnHit(original), original)
    local plainData = { type = 0, lines = { { type = 0, lineIndex = 2, leftText = original } } }
    world.preCalls[0][1](world.main, plainData)
    test.check("native proc stays unchanged with stat colors off", plainData.lines[1].leftText, original)
    test.check("disabled colors do not create a proc rewrite", plainData.lines[1].prettyTooltipOriginal, nil)
    ns.setOption("statColors", true)

    local data = capture.data
    world.preCalls[0][1](world.main, data)
    test.check("native rewrite keeps original text", data.lines[2].prettyTooltipOriginal, original)
    test.check("native rewrite adds proc colors without stat marker", data.lines[2].prettyTooltipLite, styled)
    test.check("native display keeps chance-on-hit wording", data.lines[2].prettyTooltipDisplay, styled)
    data.lines[2].lineIndex = 2
    ns.setOption("itemLite", true)
    world.postCalls[0][1](world.main, data)
    test.check("lite tooltip shows proc colors", world.main:GetLeftLine(2):GetText(), styled)
    IsAltKeyDown = function() return true end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 1)
    test.check("ALT restores original proc", world.main:GetLeftLine(2):GetText(), original)
    IsAltKeyDown = function() return false end
    world.fireEvent("MODIFIER_STATE_CHANGED", "LALT", 0)
    test.check("releasing ALT restores colors", world.main:GetLeftLine(2):GetText(), styled)
    world.preCalls[0][1](world.main, data)
    test.check("cached proc is not rewritten twice", data.lines[2].prettyTooltipDisplay, styled)

    ns.setOption("itemLite", false)
    local model = ns.TooltipTypes[0].read(world.main, data, ns.Game)
    local effect = original:gsub("^Chance on hit:%s*", "")
    test.check("rewritten proc stays an on-hit effect", model.equipEffects[1], { left = effect, right = "", onHit = true })
    test.check("rewritten proc does not become a stat", #model.secondary, 0)
    local anchor = CreateFrame("Frame", nil, UIParent)
    local function renderedEffect()
        local panel = ns.ui.renderPreview(anchor, model, 0)
        for _, font in ipairs(panel.pool) do
            if font:IsShown() and ns.util.uncolored(font:GetText() or ""):find(effect, 1, true) then return font end
        end
        error("on-hit effect was not drawn")
    end
    test.check("panel highlights proc", renderedEffect():GetText(), styleOnHit(effect))
    ns.setOption("statMarkers", false)
    test.check("markers off restores prefix and keeps colors", renderedEffect():GetText(), "Chance on hit: " .. styleOnHit(effect))
    ns.setOption("statColors", false)
    test.check("panel respects stat colors off", renderedEffect():GetText(), "Chance on hit: " .. effect)
    ns.setOption("statColors", true)
    ns.setElementSetting("equipEffects", "color", { .2, .3, .4 })
    local font = renderedEffect()
    test.check("custom effect color removes inline colors", font:GetText(), "Chance on hit: " .. effect)
    test.check("custom effect color applies to proc", { font._color[1], font._color[2], font._color[3] }, { .2, .3, .4 })
end
