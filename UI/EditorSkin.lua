-- Frame artwork for the editor. Each treatment is built once; switching the
-- setting keeps the same controls, selection, and scroll positions.
local _, ns = ...
local WHITE = "Interface\\Buttons\\WHITE8X8"
local INPUT = "Interface\\Common\\Common-Input-Border"
local GOLD = { .93, .80, .52 }
local PALETTES = {
    flat = {
        window = { .040, .037, .033 }, edge = { .21, .19, .155 },
    },
}
-- ShadowOverlayTemplate's pieces, as SharedUIPanelTemplates.xml turns its one corner.
local INNER_TINT, SHADOW_SIZE = .35, 32
local SHADOW_CORNERS = {
    { point = "TOPLEFT", coords = { 0, 0, 0, 1, 1, 0, 1, 1 } },
    { point = "TOPRIGHT", coords = { 0, 1, 1, 1, 0, 0, 1, 0 } },
    { point = "BOTTOMLEFT", coords = { 1, 0, 0, 0, 1, 1, 0, 1 } },
    { point = "BOTTOMRIGHT", coords = { 1, 1, 1, 0, 0, 1, 0, 0 } },
}
local SHADOW_EDGES = {
    { file = "Top", across = true, { "TOPLEFT", "TOPLEFT", "TOPRIGHT" }, { "TOPRIGHT", "TOPRIGHT", "TOPLEFT" } },
    { file = "Bottom", across = true, { "BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT" }, { "BOTTOMRIGHT", "BOTTOMRIGHT", "BOTTOMLEFT" } },
    { file = "Left", { "TOPLEFT", "TOPLEFT", "BOTTOMLEFT" }, { "BOTTOMLEFT", "BOTTOMLEFT", "TOPLEFT" } },
    { file = "Right", { "TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT" }, { "BOTTOMRIGHT", "BOTTOMRIGHT", "TOPRIGHT" } },
}

local function surfaceColor(region, color)
    region:SetVertexColor(color[1], color[2], color[3], 1)
end

local function shown(regions, visible)
    for _, region in ipairs(regions) do region:SetShown(visible) end
end

local function flat(bg, edges, visible)
    if bg then bg:SetShown(visible) end
    shown(edges, visible)
end

-- Capture only the artwork inherited from a template, before adding our own
-- label and flat artwork. Children include a native slider's NineSlice.
local function templateParts(frame)
    local parts = { frame:GetRegions() }
    for _, child in ipairs({ frame:GetChildren() }) do parts[#parts + 1] = child end
    return parts
end

ns.EditorSkin = {}
function ns.EditorSkin.create()
    local skin = { bindings = {} }

    function skin:bind(paint)
        self.bindings[#self.bindings + 1] = paint
    end

    function skin:refresh()
        self.native = ns.editorStyle() == "native"
        for _, paint in ipairs(self.bindings) do paint(self.native) end
    end

    skin.templateParts = templateParts

    function skin:settingsLayout(frame, left, top, right, bottom, sidebarX, previewX)
        -- Native border pieces resize independently; the complete settings
        -- frame atlas contains a divider at a fixed position and cannot be
        -- stretched or cropped safely for this three-column window.
        local border = CreateFrame("Frame", nil, frame)
        border:SetFrameLevel(frame:GetFrameLevel())
        border:SetPoint("TOPLEFT", left, -top)
        border:SetPoint("BOTTOMRIGHT", -right, bottom)
        NineSliceUtil.ApplyLayoutByName(border, "InsetFrameTemplate")
        if border.Center then border.Center:Hide() end
        local pieces, rules = {}, {}
        for _, x in ipairs({ sidebarX, previewX }) do
            local divider = frame:CreateTexture(nil, "ARTWORK")
            divider:SetAtlas("!UI-Frame-InnerLeftTile")
            divider:SetVertTile(true)
            divider:SetPoint("TOPLEFT", x, -top - 3)
            divider:SetPoint("BOTTOMLEFT", x, bottom + 3)
            divider:SetWidth(3)
            pieces[#pieces + 1] = divider
            local rule = frame:CreateTexture(nil, "ARTWORK")
            rule:SetTexture(WHITE)
            rule:SetVertexColor(.21, .19, .155, 1)
            rule:SetPoint("TOPLEFT", x, -top)
            rule:SetPoint("BOTTOMLEFT", x, bottom)
            rule:SetWidth(1)
            rules[#rules + 1] = rule
        end
        -- The settings window darkens its inner area with Options_InnerFrame,
        -- which cannot be stretched either; a tint and the game's inner shadow
        -- on each column stand in for it, under every control and text.
        local shading = {}
        local function shade(x, relativePoint, toX)
            local tint = frame:CreateTexture(nil, "BACKGROUND", nil, 7)
            tint:SetColorTexture(0, 0, 0, INNER_TINT)
            tint:SetPoint("TOPLEFT", x, -top - 2)
            tint:SetPoint("BOTTOMRIGHT", frame, relativePoint, toX, bottom + 2)
            shading[#shading + 1] = tint
            local corners = {}
            for _, corner in ipairs(SHADOW_CORNERS) do
                local piece = frame:CreateTexture(nil, "BORDER")
                piece:SetTexture("Interface\\Common\\ShadowOverlay-Corner")
                piece:SetTexCoord(unpack(corner.coords))
                piece:SetSize(SHADOW_SIZE, SHADOW_SIZE)
                piece:SetPoint(corner.point, tint)
                corners[corner.point] = piece
                shading[#shading + 1] = piece
            end
            for _, edge in ipairs(SHADOW_EDGES) do
                local piece = frame:CreateTexture(nil, "BORDER")
                piece:SetTexture("Interface\\Common\\ShadowOverlay-" .. edge.file)
                if edge.across then piece:SetHeight(SHADOW_SIZE) else piece:SetWidth(SHADOW_SIZE) end
                piece:SetPoint(edge[1][1], corners[edge[1][2]], edge[1][3])
                piece:SetPoint(edge[2][1], corners[edge[2][2]], edge[2][3])
                shading[#shading + 1] = piece
            end
        end
        shade(left, "BOTTOMLEFT", sidebarX)
        shade(sidebarX + 3, "BOTTOMLEFT", previewX)
        shade(previewX + 3, "BOTTOMRIGHT", -right)
        self:bind(function(native)
            border:SetShown(native)
            shown(pieces, native)
            shown(rules, not native)
            shown(shading, native)
        end)
    end

    function skin:surface(frame, bg, edges, window)
        -- SettingsFrameTemplate uses this background with the game's own
        -- PANEL_BACKGROUND_COLOR. Inherit its artwork, tint, and opacity.
        local base = CreateFrame("Frame", nil, frame, "FlatPanelBackgroundTemplate")
        base:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
        if window then
            base:SetPoint("TOPLEFT", 7, -18)
            base:SetPoint("BOTTOMRIGHT", -3, 3)
        else
            base:SetAllPoints()
        end
        local border = CreateFrame("Frame", nil, frame)
        border:SetAllPoints()
        border:SetFrameLevel(frame:GetFrameLevel())
        NineSliceUtil.ApplyLayoutByName(border, window and "ButtonFrameTemplateNoPortrait" or "InsetFrameTemplate")
        if border.Center then border.Center:Hide() end
        self:bind(function(native)
            local palette = PALETTES.flat
            flat(bg, edges, not native)
            if bg then surfaceColor(bg, palette.window) end
            base:SetShown(native)
            for _, edge in ipairs(edges) do surfaceColor(edge, palette.edge) end
            border:SetShown(native)
        end)
        frame.editorSurface = { nativeBackground = base, flatBackground = bg }
    end

    -- Sections share the surrounding background in both appearances.
    function skin:group(bg, edges, header, accent)
        local expanded = false
        local function update(open)
            expanded = open
            bg:SetShown(not self.native and expanded)
            header:Hide()
            shown(edges, false)
            if edges[2] then edges[2]:SetShown(not self.native and expanded) edges[2]:SetAlpha(.35) end
            accent:Hide()
        end
        self:bind(function()
            local palette = PALETTES.flat
            surfaceColor(bg, palette.window)
            for _, edge in ipairs(edges) do surfaceColor(edge, palette.edge) end
            update(expanded)
        end)
        return update
    end

    function skin:button(button, bg, edges, parts)
        local function paint()
            if self.native then
                if button.selected then button:LockHighlight() else button:UnlockHighlight() end
                button.label:SetTextColor(button.selected and 1 or GOLD[1], GOLD[2], GOLD[3])
            else
                button:UnlockHighlight()
                local color = button.selected and { .36, .27, .13 }
                    or (button.hovered and { .16, .13, .12 } or { .10, .085, .085 })
                bg:SetVertexColor(color[1], color[2], color[3], 1)
                button.label:SetTextColor(1, 1, 1)
            end
        end
        self:bind(function(native)
            shown(parts, native)
            flat(bg, edges, not native)
            paint()
        end)
        return paint
    end

    function skin:tab(tab, bg, edges)
        local setSelected = tab.SetSelected
        local function paint()
            shown({ tab.Left, tab.Middle, tab.Right }, self.native)
            flat(bg, edges, not self.native)
            tab:SetHeight(self.native and 37 or 28)
            tab.label:ClearAllPoints()
            if self.native then
                tab:OnSelected(tab.selected)
            else
                local color = tab.selected and { .36, .27, .13 }
                    or (tab.over and { .16, .13, .12 } or { .10, .085, .085 })
                bg:SetVertexColor(color[1], color[2], color[3], 1)
                tab.label:SetFontObject("GameFontHighlightSmall")
                tab.label:SetPoint("BOTTOM", 0, 8)
            end
            tab.label:Show()
        end
        tab.SetSelected = function(button, selected)
            setSelected(button, selected)
            button.selected = selected
            paint()
        end
        tab:HookScript("OnEnter", paint)
        tab:HookScript("OnLeave", paint)
        self:bind(paint)
    end

    function skin:field(frame, bg, edges)
        local parts = {}
        for index, coords in ipairs({ { 0, .0625 }, { .0625, .9375 }, { .9375, 1 } }) do
            local part = frame:CreateTexture(nil, "BORDER")
            part:SetTexture(INPUT)
            part:SetTexCoord(coords[1], coords[2], 0, .625)
            if index == 2 then
                part:SetPoint("TOPLEFT", 8, 0)
                part:SetPoint("BOTTOMRIGHT", -8, 0)
            else
                part:SetPoint(index == 1 and "TOPLEFT" or "TOPRIGHT")
                part:SetPoint(index == 1 and "BOTTOMLEFT" or "BOTTOMRIGHT")
                part:SetWidth(8)
            end
            parts[index] = part
        end
        self:bind(function(native)
            flat(bg, edges, not native)
            shown(parts, native)
        end)
    end

    -- The same combo box used by Blizzard's settings: a beveled value field
    -- with real menu-driven previous/next buttons, not an edit-box border.
    function skin:dropdown(frame, bg, edges, arrow)
        local control = CreateFrame("Frame", nil, frame, "SettingsDropdownWithButtonsTemplate")
        control:SetAllPoints()
        control.Dropdown:SetWidth(math.max(40, frame:GetWidth() - 64))
        control.Label:Hide()
        control:Hide()
        frame.nativeControl = control
        self:bind(function(native)
            flat(bg, edges, not native)
            arrow:SetShown(not native)
            frame.label:SetShown(not native)
            frame:EnableMouse(not native)
            frame:SetHeight(native and 26 or 22)
            frame.extraHeight = native and 4 or 0
            control:SetShown(native)
        end)
        return control
    end

    function skin:slider(bar, track, parts)
        local fullWidth = bar:GetWidth()
        local back = CreateFrame("Button", nil, bar:GetParent())
        back:SetSize(11, 19)
        back:SetPoint("RIGHT", bar, "LEFT", -4, 0)
        local forward = CreateFrame("Button", nil, bar:GetParent())
        forward:SetSize(9, 18)
        forward:SetPoint("LEFT", bar, "RIGHT", 4, 0)
        bar.Back, bar.Forward = back, forward
        for _, entry in ipairs({ { back, "Left", -1 }, { forward, "Right", 1 } }) do
            local button, direction = entry[1], entry[3]
            local icon = button:CreateTexture(nil, "BACKGROUND")
            icon:SetAtlas("Minimal_SliderBar_Button_" .. entry[2], true)
            icon:SetAllPoints()
            button:SetScript("OnClick", function()
                local low, high = bar:GetMinMaxValues()
                bar:SetValue(math.max(low, math.min(high, bar:GetValue() + direction * bar:GetValueStep())))
            end)
        end
        local function update()
            local low, high = bar:GetMinMaxValues()
            back:SetEnabled(bar:GetValue() > low)
            forward:SetEnabled(bar:GetValue() < high)
            back:SetAlpha(back:IsEnabled() and 1 or .5)
            forward:SetAlpha(forward:IsEnabled() and 1 or .5)
        end
        bar:HookScript("OnValueChanged", update)
        self:bind(function(native)
            shown(parts, native)
            track:SetShown(not native)
            back:SetShown(native)
            forward:SetShown(native)
            bar:ClearAllPoints()
            bar:SetPoint("LEFT", native and 19 or 0, 0)
            bar:SetSize(fullWidth - (native and 38 or 0), native and 19 or 16)
            local thumb = bar:GetThumbTexture()
            if native then
                thumb:SetAtlas("Minimal_SliderBar_Button", true)
                thumb:SetVertexColor(1, 1, 1, 1)
            else
                thumb:SetTexture(WHITE)
                thumb:SetSize(8, 16)
                thumb:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
            end
            thumb:Show()
            update()
        end)
        return update
    end

    function skin:scrollbar(bar, track, width, step)
        local nativeBar = CreateFrame("EventFrame", nil, bar, "MinimalScrollBar")
        nativeBar:SetAllPoints()
        -- Expose the template's own controls, which handle dragging, paging,
        -- repeated arrow presses, and disabled states at either end.
        bar.nativeScrollBar = nativeBar
        local visible, total, syncing = 1, 1, false
        local function update()
            if syncing then return end
            syncing = true
            local low, high = bar:GetMinMaxValues()
            local range = high - low
            nativeBar:SetVisibleExtentPercentage(total > 0 and math.min(1, visible / total) or 1)
            nativeBar:SetPanExtentPercentage(range > 0 and math.min(1, step / range) or 0)
            nativeBar:SetScrollPercentage(range > 0 and (bar:GetValue() - low) / range or 0)
            bar:GetThumbTexture():SetShown(not self.native)
            syncing = false
        end
        nativeBar:RegisterCallback("OnScroll", function(_, percentage)
            if syncing then return end
            local low, high = bar:GetMinMaxValues()
            bar:SetValue(low + percentage * (high - low))
        end, bar)
        -- Mouse-wheel scrolling uses the same pixel step over either treatment.
        nativeBar:SetScript("OnMouseWheel", function(_, delta)
            local low, high = bar:GetMinMaxValues()
            bar:SetValue(math.max(low, math.min(high, bar:GetValue() - delta * step)))
        end)
        function bar.UpdateScrollMetrics(_, viewExtent, contentExtent)
            visible, total = viewExtent, contentExtent
            update()
        end
        bar:HookScript("OnValueChanged", update)
        self:bind(function(native)
            track:SetShown(not native)
            bar:SetWidth(native and 8 or width)
            bar:EnableMouse(not native)
            nativeBar:SetShown(native)
            update()
        end)
    end

    return skin
end
