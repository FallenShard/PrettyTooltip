-- Frame artwork for the editor. Each treatment is built once; switching the
-- setting keeps the same controls, selection, and scroll positions.
local _, ns = ...
local WHITE = "Interface\\Buttons\\WHITE8X8"
local INPUT = "Interface\\Common\\Common-Input-Border"
local GOLD = { .93, .80, .52 }

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

    function skin:surface(frame, bg, edges, window)
        -- SettingsFrameTemplate itself belongs to the settings addon, which
        -- may not be loaded yet. Its shared background and border are already
        -- available, so use those without loading or modifying SettingsPanel.
        local art = CreateFrame("Frame", nil, frame,
            window and "FlatPanelBackgroundTemplate" or "InsetFrameTemplate")
        art:SetFrameLevel(frame:GetFrameLevel())
        if window then
            art:SetFrameLevel(0)
            art:SetPoint("TOPLEFT", 7, -18)
            art:SetPoint("BOTTOMRIGHT", -3, 3)
        else
            art:SetAllPoints()
        end
        local border
        if window then
            border = CreateFrame("Frame", nil, frame)
            border:SetAllPoints()
            border:SetFrameLevel(frame:GetFrameLevel())
            NineSliceUtil.ApplyLayoutByName(border, "ButtonFrameTemplateNoPortrait")
        end
        self:bind(function(native)
            flat(bg, edges, not native)
            art:SetShown(native)
            if border then border:SetShown(native) end
        end)
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

    function skin:field(frame, bg, edges, arrow)
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
        local icon
        if arrow then
            icon = frame:CreateTexture(nil, "ARTWORK")
            icon:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
            icon:SetSize(20, 20)
            icon:SetPoint("RIGHT", -2, 0)
        end
        self:bind(function(native)
            flat(bg, edges, not native)
            shown(parts, native)
            if icon then icon:SetShown(native) arrow:SetShown(not native) end
        end)
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
