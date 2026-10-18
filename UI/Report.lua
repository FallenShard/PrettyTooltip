-- The diagnostic commands' output, in a window of selectable text a player can
-- copy into a bug report. It opens with everything selected, under a line
-- naming the addon's version and the client.
local addonName, ns = ...

local WIDTH, HEIGHT = 640, 440
local window

local function header()
    local metadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local version = metadata and metadata(addonName, "Version")
    local client, build, _, interface = GetBuildInfo()
    return ("PrettyTooltip %s, client %s (%s), interface %s, %s"):format(tostring(version or "?"),
        tostring(client), tostring(build), tostring(interface), tostring(GetLocale()))
end

-- The game's frame artwork where the client has it; a flat backdrop where not.
local function decorate(frame)
    local ok = pcall(function()
        local art = CreateFrame("Frame", nil, frame, "FlatPanelBackgroundTemplate")
        art:SetFrameLevel(0)
        art:SetPoint("TOPLEFT", 7, -18)
        art:SetPoint("BOTTOMRIGHT", -3, 3)
        local border = CreateFrame("Frame", nil, frame)
        border:SetAllPoints()
        border:SetFrameLevel(frame:GetFrameLevel())
        NineSliceUtil.ApplyLayoutByName(border, "ButtonFrameTemplateNoPortrait")
    end)
    if ok then return end
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(.05, .04, .04, .96)
end

local function create()
    local frame = CreateFrame("Frame", "PrettyTooltipReport", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    tinsert(UISpecialFrames, "PrettyTooltipReport")
    decorate(frame)

    -- Above the border, whose title bar covers what is drawn on the frame.
    local top = CreateFrame("Frame", nil, frame)
    top:SetAllPoints()
    top:SetFrameLevel(frame:GetFrameLevel() + 2)
    frame.title = top:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -5)
    local hint = top:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 16, -32)
    hint:SetText("Press Ctrl+C to copy the selected text, and paste it into your bug report.")
    local close = CreateFrame("Button", nil, top, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", 16, -52)
    scroll:SetPoint("BOTTOMRIGHT", -16, 44)
    scroll:SetClipsChildren(true)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject("GameFontHighlightSmall")
    edit:SetWidth(WIDTH - 32)
    scroll:SetScrollChild(edit)
    -- Read only: typing puts the report back, selected.
    edit:SetScript("OnTextChanged", function(self, typed)
        if typed then
            self:SetText(frame.text or "")
            self:HighlightText()
        end
    end)
    edit:SetScript("OnEscapePressed", function() frame:Hide() end)
    -- Keeps the cursor in view as the arrow keys move it.
    edit:SetScript("OnCursorChanged", function(_, _, y, _, height)
        local offset, visible = scroll:GetVerticalScroll(), scroll:GetHeight()
        y = -y
        if y < offset then
            scroll:SetVerticalScroll(y)
        elseif y + height > offset + visible then
            scroll:SetVerticalScroll(y + height - visible)
        end
    end)
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.min(range, math.max(0, self:GetVerticalScroll() - delta * 40)))
    end)

    local selectAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    selectAll:SetSize(110, 22)
    selectAll:SetPoint("BOTTOMLEFT", 16, 14)
    selectAll:SetText("Select all")
    selectAll:SetScript("OnClick", function()
        edit:SetFocus()
        edit:HighlightText()
    end)
    local done = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    done:SetSize(110, 22)
    done:SetPoint("BOTTOMRIGHT", -16, 14)
    done:SetText("Close")
    done:SetScript("OnClick", function() frame:Hide() end)
    frame:SetScript("OnHide", function() edit:ClearFocus() end)

    frame.scroll, frame.edit = scroll, edit
    return frame
end

-- Shows lines under a title. Text is shown as typed: escape codes, such as
-- colors, are not drawn. Printed to chat where the window cannot be made.
function ns.showReport(title, lines)
    local text = header() .. "\n" .. table.concat(lines, "\n")
    if not window then
        local ok, made = pcall(create)
        if not ok then
            for line in (text .. "\n"):gmatch("(.-)\n") do print((line:gsub("|", "||"))) end
            return
        end
        window = made
    end
    window.text = text:gsub("|", "||")
    window.title:SetText("PrettyTooltip " .. title)
    window.edit:SetText(window.text)
    window:Show()
    window.scroll:SetVerticalScroll(0)
    window.edit:SetFocus()
    window.edit:SetCursorPosition(0)
    window.edit:HighlightText()
end
