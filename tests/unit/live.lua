-- Live parts follow the game while their panel shows: an aura's time bar
-- drains as its time runs out.
return function(test)
    local AURA = 7
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Aura.lua" }, {
        enums = { TooltipDataType = { Item = 0, UnitAura = AURA } },
    })
    local now = 1000
    GetTime = function() return now end
    local function renew(fields)
        fields.name, fields.harmful = "Renew", false
        return ns.ui.auraModel(fields)
    end
    local anchor = CreateFrame("Frame", nil, UIParent)
    local panel = ns.ui.renderPreview(anchor, renew({ duration = 10, expires = 1005 }), AURA)
    -- The bar's track, then its fill: the time left as a share of the track.
    local function shownRatio()
        local track
        for index = 1, panel.texturesUsed do
            local texture = panel.texturePool[index]
            if texture._shown ~= false and texture._height == 4 then
                if track then return texture._width / track._width end
                track = texture
            end
        end
    end
    local function tick()
        for _, object in ipairs(world.objects) do
            if object._scripts.OnUpdate then object._scripts.OnUpdate(object, .2) end
        end
    end
    test.check("drawn with the time left", shownRatio(), .5)
    now = 1003
    tick()
    test.check("a tick drains the bar", shownRatio(), .2)

    -- A redraw of the same panel drops the update the last drawing left: a
    -- fresh panel drawn for the aura, then at once for an aura with less time.
    anchor = CreateFrame("Frame", nil, UIParent)
    ns.ui.renderPreview(anchor, renew({ duration = 10, expires = 1004 }), AURA)
    panel = ns.ui.renderPreview(anchor, renew({ duration = 100, expires = 1053 }), AURA)
    now = 1023
    tick()
    test.check("a redraw clears the last update", shownRatio(), .3)
end
