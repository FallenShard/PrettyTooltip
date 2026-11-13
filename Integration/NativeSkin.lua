-- The game's own tooltips the addon does not redraw, as character stats, the
-- action bar's buttons, and option entries show, in the panel style chosen:
-- the panel's backdrop and border under their text, in place of the game's.
-- Only alpha and the addon's own frames change, so no game code runs as the
-- addon's.
local _, ns = ...
local ui = ns.ui
if not ui then return end
ns.NativeSkin = {}
local util = ns.util
local probe = ns.Profiler.probe
local STYLE = { color = ns.Palette.roles.neutral }
-- How thick a border the game pads its tooltips' text for.
local GAME_BORDER = 4

-- Each tooltip's backdrop, kept here rather than on the game's frame.
local skins = setmetatable({}, { __mode = "k" })

local function skinOf(tooltip)
    local skin = ui.createPanel(tooltip)
    -- Hidden with the tooltip while the addon's panel shows in its place.
    if skin.SetIgnoreParentAlpha then skin:SetIgnoreParentAlpha(false) end
    skin:SetClampedToScreen(false)
    return skin
end

local function skin(tooltip)
    if not util.canModify(tooltip) then return end
    local slice = tooltip.NineSlice
    if not slice then return end
    -- An embedded tooltip, as an item inside a quest's, has its backdrop hidden.
    local styled = ns.option("skinGameTooltips") and ui.backdropStyle() ~= "native" and slice:IsShown()
    local panel = skins[tooltip]
    -- Left to other addons once the game's backdrop is back.
    if not styled and not (panel and panel:IsShown()) then return end
    if not panel then
        panel = skinOf(tooltip)
        skins[tooltip] = panel
    end
    if styled then
        -- Under the tooltip's text, its border too, where the game's backdrop was.
        panel:SetFrameStrata(tooltip:GetFrameStrata())
        panel:SetFrameLevel(math.max(tooltip:GetFrameLevel() - 2, 0))
        ui.drawBackdrop(panel, STYLE)
        panel.header:Hide()
        -- A thicker border than the game's sits further out, clear of the text.
        local out = math.max(panel.inset - GAME_BORDER, 0)
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", tooltip, "TOPLEFT", -out, out)
        panel:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", out, -out)
    end
    panel:SetShown(styled)
    slice:SetAlpha(styled and 0 or 1)
end

function ns.NativeSkin.register()
    -- The game sets a tooltip's backdrop as it fills or hides it.
    if SharedTooltip_SetBackdropStyle then
        hooksecurefunc("SharedTooltip_SetBackdropStyle", probe("native skin", skin))
    end
    -- And on showing, after a change of style; the settings window's tooltip
    -- has its backdrop set once, before the addon loads.
    for _, tooltip in ipairs({ GameTooltip, SettingsTooltip }) do
        tooltip:HookScript("OnShow", probe("native skin show", skin))
    end
end
