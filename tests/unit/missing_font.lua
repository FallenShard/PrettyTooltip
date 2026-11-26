-- On Forever, SetFont errors on a missing file instead of returning false. A
-- font another addon renamed or removed draws in the standard font instead.
return function(test)
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Locale/Locale.lua",
        "Locale/English.lua", "Game/Game.lua", "Panel/Layout.lua" },
        { enums = { TooltipDataType = { Item = 0 }, TooltipDataLineType = { None = 0 } } })
    local MISSING = "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway Bold.ttf"
    local font = CreateFrame("Frame", nil, UIParent):CreateFontString()
    local setFont = font.SetFont
    function font:SetFont(path, ...)
        if path == MISSING then error("Invalid font asset (" .. path .. "): file not found") end
        return setFont(self, path, ...)
    end
    local ok = pcall(ns.ui.setFont, font, MISSING, 13, "")
    test.check("a missing font file draws in the standard font", { ok, (font:GetFont()) }, { true, STANDARD_TEXT_FONT })
end
