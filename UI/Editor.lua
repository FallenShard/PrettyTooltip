-- The /ptip style editor: a live sample panel and the controls for its parts.
local _, ns = ...
local ui = ns.ui
local L, fillText = ns.L, ns.util.fill
if not (ui and ui.renderPreview) then
    return
end

local WHITE = "Interface\\Buttons\\WHITE8X8"
-- The window keeps one height; the controls column scrolls within it.
local EDITOR_HEIGHT = 750
-- Below the controls column: a gap, then the buttons along the bottom.
local BUTTONS_SPACE = 20
-- Left to right: the page list, the page's settings, and the sample.
local SIDEBAR_X, SIDEBAR_TOP, SIDEBAR_WIDTH = 16, 64, 184
local NAV_HEIGHT = 24
local PAGE_X = SIDEBAR_X + SIDEBAR_WIDTH + 16
local PAGE_TOP = 78
local CONTROLS_X = PAGE_X
local CONTROLS_WIDTH = 494
local CONTROLS_TOP = 116
-- As in the game's settings: labels indented under their section, and the
-- controls in a column after them.
local ROW_INDENT = 16
local CONTROL_X = 200
local ROW_HEIGHT = 27
local LOOKUP_LABEL_WIDTH = 86
-- Clear of the controls column's scrollbar.
local PREVIEW_X = CONTROLS_X + CONTROLS_WIDTH + 28
-- Under the ID lookup and the examples, stacked above it.
local PREVIEW_TOP = 184
local PREVIEW_WIDTH = 460
local WIDTH = PREVIEW_X + PREVIEW_WIDTH + 18
-- Room around the panel for its rarity halo and the Equipped tag above it.
local PREVIEW_MARGIN = 26
local PREVIEW_TOP_MARGIN = PREVIEW_MARGIN / 2
local SCROLL_STEP = 40
-- Resets have their own gutter, so a changed label never runs into its icon.
local FIELD_WIDTH = CONTROLS_WIDTH - CONTROL_X - 24
local SIZE_MIN, SIZE_MAX = 8, 30
local MENU_ROWS, MENU_ROW_HEIGHT = 12, 20
local BACKGROUND = { .055, .045, .05 }
local FIELD = { .10, .085, .085 }
local FIELD_HOVER = { .16, .13, .12 }
local LINE = { .32, .26, .19 }
local GOLD = { .93, .80, .52 }
-- GameFontNormal's gold, the game's settings labels.
local NORMAL = { 1, .82, 0 }
local RESET_ICON = "Interface\\Buttons\\UI-RefreshButton"
local skin = ns.EditorSkin.create()
local BACKDROP_STYLES = {
    { text = "Default" },
    { value = "native", text = "Blizzard Border" },
    { value = "flat", text = "Flat" },
    { value = "dialogue", text = "DialogueUI" },
}
local PANEL_STYLE_NOTE = "The frame drawn around each panel.\n\n"
    .. "• Default: DialogueUI's art while DialogueUI is installed, Flat beside EllesmereUI, otherwise "
    .. "Blizzard Border.\n"
    .. "• Blizzard Border: The game's own tooltip border.\n"
    .. "• Flat: A dark, flat panel with a thin edge.\n"
    .. "• DialogueUI: DialogueUI's art, while it is installed."
local RESET_STYLES_NOTE = "Every font, text size, outline, capitalization, and color goes back to its default, "
    .. "and so do the panel opacities: on All Tooltips, every tooltip type, and every part. Other settings stay as they are."
local PANEL_TINT_NOTE = "On: The panel takes a color from what it shows:\n"
    .. "• Items: their quality, from uncommon up, or yellow for quest items\n"
    .. "• Spells and macros: the spell's school, or else the color of the resource it costs\n"
    .. "• Players and NPCs: the class color, gray once tapped, or red, yellow, or green by reaction\n"
    .. "• Buffs and debuffs: the dispel type's color, otherwise blue for buffs and red for debuffs\n"
    .. "• Objects: green for herbs, orange for ore, blue for fishing pools, yellow for locks and quest objects\n"
    .. "• Quests: a pale yellow-brown\n\n"
    .. "Off: Panels keep their plain, untinted color."
local OUTLINES = {
    { value = "NONE", text = "None" },
    { value = "OUTLINE", text = "Outline" },
    { value = "THICKOUTLINE", text = "Thick Outline" },
}

-- The samples, from UI/Samples.lua, for the types this client has.
local TOOLTIP_TYPES, TYPE_ORDER = {}, {}
for _, sampleType in ipairs(ns.editorSampleTypes and ns.editorSampleTypes() or {}) do
    TOOLTIP_TYPES[sampleType.key] = sampleType
    TYPE_ORDER[#TYPE_ORDER + 1] = sampleType.key
end
-- For tests/: every tooltip type's samples, in the editor's order.
ns.editorSamples = { tooltipTypes = TOOLTIP_TYPES, order = TYPE_ORDER }
local MAX_SAMPLES = 0
for _, tooltipType in pairs(TOOLTIP_TYPES) do MAX_SAMPLES = math.max(MAX_SAMPLES, #tooltipType.samples) end

-- Building blocks -----------------------------------------------------------

local function fill(parent, layer, color, alpha)
    local tex = parent:CreateTexture(nil, layer)
    tex:SetTexture(WHITE)
    tex:SetVertexColor(color[1], color[2], color[3], alpha or 1)
    return tex
end

local function background(frame, color, alpha)
    local tex = fill(frame, "BACKGROUND", color, alpha)
    tex:SetAllPoints()
    return tex
end

local function outline(frame, color, alpha)
    local edges = {}
    for index, points in ipairs({
        { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" },
    }) do
        local edge = fill(frame, "BORDER", color, alpha)
        edge:SetPoint(points[1])
        edge:SetPoint(points[2])
        if index <= 2 then edge:SetHeight(1) else edge:SetWidth(1) end
        edges[index] = edge
    end
    return edges
end

local function text(parent, template, value)
    local font = parent:CreateFontString(nil, "ARTWORK", template)
    font:SetJustifyH("LEFT")
    if value then font:SetText(L[value]) end
    return font
end

-- A string given a font file keeps it through SetFontObject.
local function plainFont(font)
    local path, size, flags = GameFontHighlightSmall:GetFont()
    ui.setFont(font, path, size, flags)
end

local function editorButton(parent, label, width, onClick, template)
    local button = CreateFrame("Button", nil, parent, template or "UIPanelButtonTemplate")
    local parts = skin.templateParts(button)
    button:SetSize(width, 22)
    button.bg = background(button, FIELD)
    local edges = outline(button, LINE)
    button.label = text(button, "GameFontHighlightSmall", label)
    button.label:SetPoint("CENTER")
    button:SetWidth(math.max(width, button.label:GetStringWidth() + 16))
    local paint = skin:button(button, button.bg, edges, parts)
    button:HookScript("OnEnter", function(self) self.hovered = true paint() end)
    button:HookScript("OnLeave", function(self) self.hovered = false paint() end)
    button:SetScript("OnClick", onClick)
    function button:SetSelected(selected)
        self.selected = selected
        paint()
    end
    return button
end

local function explain(widget, title, body)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L[title], 1, 1, 1)
        GameTooltip:AddLine(L[body], nil, nil, nil, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- A setting's label; a changed one stands out from the rest: gold among
-- white labels, white among the game's gold ones.
local function labelColor(caption, changed)
    local color
    if skin.native then color = changed and { 1, 1, 1 } or NORMAL
    else color = changed and GOLD or { 1, 1, 1 } end
    caption:SetTextColor(color[1], color[2], color[3])
end

-- The default is saved as no setting.
local function setFlag(key, checked)
    ns.setOption(key, nil)
    if ns.option(key) ~= checked then ns.setOption(key, checked) end
end

-- The window -----------------------------------------------------------------

local editor = CreateFrame("Frame", "PrettyTooltipEditor", UIParent)
editor:SetWidth(WIDTH)
editor:SetPoint("CENTER")
-- Below the color picker, which the editor opens.
editor:SetFrameStrata("HIGH")
editor:SetToplevel(true)
editor:SetClampedToScreen(true)
editor:EnableMouse(true)
editor:SetMovable(true)
editor:RegisterForDrag("LeftButton")
editor:SetScript("OnDragStart", editor.StartMoving)
editor:SetScript("OnDragStop", editor.StopMovingOrSizing)
editor:Hide()
tinsert(UISpecialFrames, "PrettyTooltipEditor")
skin:surface(editor, background(editor, BACKGROUND), outline(editor, LINE), true)
skin:settingsLayout(editor, SIDEBAR_X - 2, SIDEBAR_TOP - 8, 14, BUTTONS_SPACE - 6,
    PAGE_X - 12, PREVIEW_X - 10)

-- The native border is a child frame; its title bar covers regions drawn on
-- the editor itself. Keep the title above it in either appearance.
local titleContainer = CreateFrame("Frame", nil, editor)
titleContainer:SetPoint("TOPLEFT")
titleContainer:SetPoint("TOPRIGHT")
titleContainer:SetHeight(32)
titleContainer:SetFrameLevel(editor:GetFrameLevel() + 2)
local heading = text(titleContainer, "GameFontNormalLarge", "PrettyTooltip Style Editor")
heading:SetPoint("TOPLEFT", 16, -14)
local subheading = text(editor, "GameFontDisableSmall",
    "Click any part of the sample to restyle it. Tooltips use the new look the next time they open.")
subheading:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
local close = CreateFrame("Button", nil, editor, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)
skin:bind(function(native)
    -- Leave room inside the native frame for the scrollbar's arrow buttons.
    editor:SetWidth(WIDTH + (native and 16 or 0))
    heading:ClearAllPoints()
    heading:SetFontObject(native and "GameFontNormal" or "GameFontNormalLarge")
    if native then heading:SetPoint("TOP", 0, -5) else heading:SetPoint("TOPLEFT", 16, -14) end
    subheading:ClearAllPoints()
    if native then subheading:SetPoint("TOPLEFT", editor, "TOPLEFT", 16, -34)
    else subheading:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4) end
end)

-- The controls column scrolls, so the window keeps its size whatever the
-- tooltip type shown has to set.
local column = CreateFrame("ScrollFrame", nil, editor)
column:SetPoint("TOPLEFT", CONTROLS_X, -CONTROLS_TOP)
column:SetSize(CONTROLS_WIDTH, EDITOR_HEIGHT - CONTROLS_TOP - BUTTONS_SPACE)
column:SetClipsChildren(true)
local content = CreateFrame("Frame", nil, column)
content:SetSize(CONTROLS_WIDTH, 1)
column:SetScrollChild(content)
local columnBar = CreateFrame("Slider", nil, editor)
columnBar:SetOrientation("VERTICAL")
columnBar:SetPoint("TOPLEFT", column, "TOPRIGHT", 6, 0)
columnBar:SetPoint("BOTTOMLEFT", column, "BOTTOMRIGHT", 6, 0)
columnBar:SetWidth(6)
columnBar:SetValueStep(1)
local columnTrack = fill(columnBar, "BACKGROUND", LINE, .6)
columnTrack:SetAllPoints()
columnBar:SetThumbTexture(WHITE)
local columnThumb = columnBar:GetThumbTexture()
columnThumb:SetWidth(6)
columnThumb:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], .7)
columnBar:Hide()
columnBar:SetScript("OnValueChanged", function(_, offset) column:SetVerticalScroll(math.floor(offset + .5)) end)
skin:scrollbar(columnBar, columnTrack, 6, SCROLL_STEP)
column:EnableMouseWheel(true)
column:SetScript("OnMouseWheel", function(_, delta)
    if columnBar:IsShown() then columnBar:SetValue(columnBar:GetValue() - delta * SCROLL_STEP) end
end)

-- Shared pages keep the last preview type; opening a type selects its sample.
local state = { page = "tooltips", tooltipType = "item", sample = 1, selected = "title", saved = {}, navExpanded = true }
local controls = {}
local refresh, refreshLookup, closeMenu
local previewTop = PREVIEW_TOP
local previewTopMargin = PREVIEW_TOP_MARGIN

local function samples()
    return TOOLTIP_TYPES[state.tooltipType].samples
end

local function isTypePage(page)
    return TOOLTIP_TYPES[page] ~= nil
end

local function switchTooltipType(tooltipType)
    state.page = tooltipType
    if tooltipType == state.tooltipType then return end
    state.saved[state.tooltipType] = { sample = state.sample, selected = state.selected, lookup = state.lookup }
    local saved = state.saved[tooltipType] or {}
    state.tooltipType = tooltipType
    state.sample = saved.sample or 1
    state.selected = saved.selected or TOOLTIP_TYPES[tooltipType].first
    state.lookup = saved.lookup
end

local function openPage(page)
    closeMenu()
    if isTypePage(page) or page == "other" then state.navExpanded = true end
    if isTypePage(page) then switchTooltipType(page) else state.page = page end
    columnBar:SetValue(0)
    refresh()
end

-- The sample ----------------------------------------------------------------

-- The page list ---------------------------------------------------------------

-- Each editor type's restyle and follow cursor settings; remaining kinds have
-- the Other tooltips child page.
local KINDS = {}
for _, kind in ipairs(ns.TOOLTIP_TYPES) do
    if kind.editor then KINDS[kind.editor] = kind end
end
local RESTYLE_NOTE = "On: Draws the PrettyTooltip panel.\n\nOff: This kind keeps the game's own tooltip, with the "
    .. "details modifier's rows added to it."
local CURSOR_NOTE = "On: Shows this kind's tooltip at the cursor when the game would put it in its default corner; "
    .. "bags and other panels keep theirs.\n\nOff: Its position is left to the game and other addons."

local sidebar = CreateFrame("Frame", nil, editor)
sidebar:SetPoint("TOPLEFT", SIDEBAR_X, -SIDEBAR_TOP)
sidebar:SetPoint("BOTTOMLEFT", SIDEBAR_X, BUTTONS_SPACE)
sidebar:SetWidth(SIDEBAR_WIDTH)
local navButtons, navChildren = {}, {}
local function navButton(label, page, child)
    local button = CreateFrame("Button", nil, sidebar)
    button:SetSize(SIDEBAR_WIDTH - 2, NAV_HEIGHT)
    button.label = text(button, "GameFontHighlight", label)
    button.label:SetWordWrap(false)
    local categoryHeader
    if not child then
        categoryHeader = button:CreateTexture(nil, "BACKGROUND", nil, -1)
        categoryHeader:SetAtlas(page == "general" and "Options_CategoryHeader_1" or "Options_CategoryHeader_2", true)
        categoryHeader:SetPoint("TOPLEFT")
        categoryHeader:SetWidth(button:GetWidth())
    end
    button.chosen = fill(button, "BACKGROUND", GOLD, .14)
    button.chosen:SetAllPoints()
    button.active = button:CreateTexture(nil, "BACKGROUND")
    button.active:SetAtlas("Options_List_Active")
    button.active:SetAllPoints()
    button.bar = fill(button, "ARTWORK", GOLD)
    button.bar:SetPoint("TOPLEFT")
    button.bar:SetPoint("BOTTOMLEFT")
    button.bar:SetWidth(3)
    button.dot = fill(button, "ARTWORK", GOLD)
    button.dot:SetSize(5, 5)
    button.dot:SetPoint("RIGHT", -8, 0)
    local hover = fill(button, "HIGHLIGHT", GOLD, .08)
    hover:SetAllPoints()
    local nativeHover = button:CreateTexture(nil, "HIGHLIGHT")
    nativeHover:SetAtlas("Options_List_Hover")
    nativeHover:SetAllPoints()
    skin:bind(function(native)
        if categoryHeader then categoryHeader:SetShown(native) end
        -- Match SettingsCategoryListHeaderTemplate's row height; its artwork
        -- can include transparent padding beyond the visible header band.
        button:SetHeight(native and not child and 30 or NAV_HEIGHT)
        hover:SetShown(not native)
        nativeHover:SetShown(native)
        button.label:SetFontObject(native and (child and "GameFontNormal" or "GameFontHighlightMedium") or "GameFontHighlight")
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", child and 30 or 20, 0)
        button.label:SetPoint("RIGHT", -18, 0)
    end)
    button:SetScript("OnClick", function() openPage(page) end)
    navButtons[page] = button
    if child then navChildren[#navChildren + 1] = button end
    return button
end
navButton("General", "general")
local tooltipNav = navButton("Tooltips", "tooltips")
local tooltipChevron = editorButton(sidebar, "", 16, function()
    state.navExpanded = not state.navExpanded
    refresh()
end)
tooltipChevron:SetSize(16, 20)
tooltipChevron:SetFrameLevel(tooltipNav:GetFrameLevel() + 2)
for _, tooltipType in ipairs(TYPE_ORDER) do
    navButton(TOOLTIP_TYPES[tooltipType].label, tooltipType, true)
end
navButton("Other Tooltips", "other", true)
local function layoutNavigation()
    local tooltipTop = skin.native and 6 + navButtons.general:GetHeight() + 18 or 38
    local tooltipHeight = tooltipNav:GetHeight()
    navButtons.general:ClearAllPoints()
    navButtons.general:SetPoint("TOPLEFT", 1, -6)
    tooltipNav:ClearAllPoints()
    tooltipNav:SetPoint("TOPLEFT", 1, -tooltipTop)
    tooltipChevron:ClearAllPoints()
    tooltipChevron:SetPoint("LEFT", tooltipNav, "LEFT", 1, 0)
    tooltipChevron.label:SetText(state.navExpanded and "-" or "+")
    for index, button in ipairs(navChildren) do
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 1, -tooltipTop - tooltipHeight - (index - 1) * NAV_HEIGHT)
        button:SetShown(state.navExpanded)
    end
end
local function atlasHeight(name, fallback)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name)
    return info and info.height or fallback
end

-- The page's title, what it holds, and a divider over its settings.
local pageTitle = text(editor, "GameFontNormalLarge")
pageTitle:SetPoint("TOPLEFT", PAGE_X, -PAGE_TOP)
pageTitle:SetWidth(CONTROLS_WIDTH - 122)
local pageText = text(editor, "GameFontDisableSmall")
pageText:SetPoint("TOPLEFT", pageTitle, "BOTTOMLEFT", 0, -6)
pageText:SetWidth(CONTROLS_WIDTH)
local pageRule = fill(editor, "ARTWORK", LINE)
pageRule:SetPoint("TOPLEFT", PAGE_X, -(CONTROLS_TOP - 10))
pageRule:SetSize(CONTROLS_WIDTH, 1)
local pageDivider = editor:CreateTexture(nil, "ARTWORK")
pageDivider:SetAtlas("Options_HorizontalDivider")
pageDivider:SetPoint("TOP", editor, "TOPLEFT", PAGE_X + CONTROLS_WIDTH / 2, -(CONTROLS_TOP - 10))
pageDivider:SetSize(CONTROLS_WIDTH, atlasHeight("Options_HorizontalDivider", 4))
skin:bind(function(native)
    pageTitle:SetFontObject(native and "GameFontHighlightHuge" or "GameFontNormalLarge")
    pageRule:SetShown(not native)
    pageDivider:SetShown(native)
end)
local resetPage, pageChanged
local resetPageButton = editorButton(editor, "Reset Page", 110, function()
    resetPage(state.page)
    refresh()
end)
resetPageButton:SetPoint("TOPRIGHT", editor, "TOPLEFT", CONTROLS_X + CONTROLS_WIDTH, -PAGE_TOP + 2)

local host = CreateFrame("Frame", nil, editor)
host:SetPoint("TOPLEFT", PREVIEW_X, -PREVIEW_TOP)
host:SetWidth(PREVIEW_WIDTH)
host:SetClipsChildren(true)
-- Stands in for the game's tooltip; the panel pins itself to it.
local anchor = CreateFrame("Frame", nil, host)
anchor:SetSize(1, 1)
anchor:SetPoint("TOPLEFT", PREVIEW_MARGIN, -previewTopMargin)
local examplesLabel = text(editor, "GameFontNormalSmall", "Examples:")
examplesLabel:SetPoint("BOTTOMLEFT", host, "TOPLEFT", 0, 11)
local sampleTabs = {}
for index = 1, MAX_SAMPLES do
    local tab = editorButton(editor, "", 56, function()
        state.sample, state.lookup = index, nil
        refresh()
    end, "UIMenuButtonStretchTemplate")
    if index == 1 then tab:SetPoint("LEFT", examplesLabel, "RIGHT", 8, 0)
    else tab:SetPoint("LEFT", sampleTabs[index - 1], "RIGHT", 4, 0) end
    sampleTabs[index] = tab
end

local function sampleTabWidth(tab, sample)
    tab.label:SetText(L[sample.label])
    return math.min(PREVIEW_WIDTH, math.max(56, tab.label:GetStringWidth() + 16))
end

-- Reserve enough example rows for every type so changing pages cannot move
-- the preview, including when translated names wrap onto additional rows.
local function layoutSamples()
    local lastLine = 0
    for _, tooltipType in ipairs(TYPE_ORDER) do
        local x, line = examplesLabel:GetStringWidth() + 8, 0
        for index, sample in ipairs(TOOLTIP_TYPES[tooltipType].samples) do
            local width = sampleTabWidth(sampleTabs[index], sample)
            if x + width > PREVIEW_WIDTH then x, line = 0, line + 1 end
            x = x + width + 4
        end
        lastLine = math.max(lastLine, line)
    end
    local x, line = examplesLabel:GetStringWidth() + 8, 0
    for index, tab in ipairs(sampleTabs) do
        local sample = samples()[index]
        tab:SetShown(sample ~= nil)
        if sample then
            local width = sampleTabWidth(tab, sample)
            tab:SetWidth(width)
            tab:SetSelected(not state.lookup and index == state.sample)
            if x + width > PREVIEW_WIDTH then x, line = 0, line + 1 end
            tab:ClearAllPoints()
            tab:SetPoint("TOPLEFT", editor, "TOPLEFT", PREVIEW_X + x, -previewTop + 34 - line * 28)
            x = x + width + 4
        end
    end
    -- Halve the gap after the last examples row from 12 to 6 pixels.
    local top = previewTop + lastLine * 28 - 6
    examplesLabel:ClearAllPoints()
    examplesLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", PREVIEW_X, -previewTop + 28)
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", PREVIEW_X, -top)
    host:SetHeight(EDITOR_HEIGHT - top - BUTTONS_SPACE)
end

local overlay = CreateFrame("Frame", nil, host)
overlay:SetAllPoints()
overlay:EnableMouse(true)
local failure = text(overlay, "GameFontRedSmall")
failure:SetPoint("TOPLEFT", 12, -12)
failure:SetWidth(PREVIEW_WIDTH - 24)
local hint = text(overlay, "GameFontDisableSmall")
hint:SetPoint("BOTTOMLEFT", 10, 8)

local scrollBar = CreateFrame("Slider", nil, host)
scrollBar:SetOrientation("VERTICAL")
scrollBar:SetPoint("TOPRIGHT", -3, -3)
scrollBar:SetPoint("BOTTOMRIGHT", -3, 3)
scrollBar:SetWidth(8)
scrollBar:SetValueStep(1)
local scrollTrack = fill(scrollBar, "BACKGROUND", LINE, .6)
scrollTrack:SetAllPoints()
scrollBar:SetThumbTexture(WHITE)
local scrollThumbTexture = scrollBar:GetThumbTexture()
scrollThumbTexture:SetWidth(8)
scrollThumbTexture:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], .7)
scrollBar:Hide()
local scrolledFor
local horizontalBar = CreateFrame("Slider", nil, host)
horizontalBar:SetOrientation("HORIZONTAL")
horizontalBar:SetPoint("BOTTOMLEFT", 8, 4)
horizontalBar:SetPoint("BOTTOMRIGHT", -20, 4)
horizontalBar:SetHeight(8)
horizontalBar:SetValueStep(1)
local horizontalTrack = fill(horizontalBar, "BACKGROUND", LINE, .6)
horizontalTrack:SetAllPoints()
horizontalBar:SetThumbTexture(WHITE)
local horizontalThumb = horizontalBar:GetThumbTexture()
horizontalThumb:SetHeight(8)
horizontalThumb:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], .7)
horizontalBar:Hide()

local function scrollTo(offset)
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPLEFT", PREVIEW_MARGIN - horizontalBar:GetValue(), -previewTopMargin + offset)
end
scrollBar:SetScript("OnValueChanged", function(_, offset) scrollTo(math.floor(offset + .5)) end)
horizontalBar:SetScript("OnValueChanged", function() scrollTo(scrollBar:GetValue()) end)
skin:scrollbar(scrollBar, scrollTrack, 8, SCROLL_STEP)
skin:bind(function(native)
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPRIGHT", native and -12 or -3, native and -8 or -3)
    scrollBar:SetPoint("BOTTOMRIGHT", native and -12 or -3, native and 8 or 3)
end)
overlay:EnableMouseWheel(true)
overlay:SetScript("OnMouseWheel", function(_, delta)
    if IsShiftKeyDown() and horizontalBar:IsShown() then
        horizontalBar:SetValue(horizontalBar:GetValue() - delta * SCROLL_STEP)
    elseif scrollBar:IsShown() then
        scrollBar:SetValue(scrollBar:GetValue() - delta * SCROLL_STEP)
    end
end)
local highlights = {}
local hovered

local function preview()
    return anchor.prettyTooltipPreview
end

local function hasPart(key)
    local panel = preview()
    for _, hit in ipairs(panel and panel.hits or {}) do
        if hit.key == key then return true end
    end
    return false
end

local function partAtCursor()
    local panel = preview()
    if not (panel and panel:IsShown() and panel.hits) then return end
    local x, y = GetCursorPosition()
    for _, hit in ipairs(panel.hits) do
        local region = hit.region
        local scale = region:GetEffectiveScale()
        local cursorX, cursorY = x / scale, y / scale
        local left, right = region:GetLeft(), region:GetRight()
        local top, bottom = region:GetTop(), region:GetBottom()
        if left and region:IsShown() and cursorX >= left - 2 and cursorX <= right + 2
            and cursorY <= top + 1 and cursorY >= bottom - 1 then
            return hit.key
        end
    end
end

local function paintHighlights()
    for _, tex in ipairs(highlights) do tex:Hide() end
    local panel = preview()
    if not (panel and panel.hits) then return end
    local used = 0
    for _, hit in ipairs(panel.hits) do
        local selected = hit.key == state.selected
        if selected or hit.key == hovered then
            used = used + 1
            local tex = highlights[used]
            if not tex then
                tex = overlay:CreateTexture(nil, "OVERLAY")
                tex:SetTexture(WHITE)
                highlights[used] = tex
            end
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", hit.region, "TOPLEFT", -3, 2)
            tex:SetPoint("BOTTOMRIGHT", hit.region, "BOTTOMRIGHT", 3, -2)
            if selected then
                tex:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], .16)
            else
                tex:SetVertexColor(1, 1, 1, .07)
            end
            tex:Show()
        end
    end
end

local function showHint()
    local element = hovered and ns.ELEMENT_BY_KEY[hovered]
    hint:SetText(element and fillText(L["%s: click to edit"], L[element.label])
        or L["Click any part of the sample to edit it."])
end

overlay:SetScript("OnUpdate", function(self)
    local key = self:IsMouseOver() and partAtCursor() or nil
    if key == hovered then return end
    hovered = key
    paintHighlights()
    showHint()
end)

-- The editor's lookup by ID reads this hidden tooltip; it never gets a panel.
local scanner
local function previewByID(target, dataType, id)
    if not scanner then
        scanner = CreateFrame("GameTooltip", "PrettyTooltipScanner", UIParent, "GameTooltipTemplate")
        scanner.prettyTooltipScanner = true
    end
    scanner:SetOwner(UIParent, "ANCHOR_NONE")
    if dataType == Enum.TooltipDataType.Item then scanner:SetItemByID(id) else scanner:SetSpellByID(id) end
    local data = scanner:GetTooltipData()
    local tooltipType = ns.TooltipTypes[dataType]
    local ok, model = pcall(tooltipType.read, scanner, data, ns.Game)
    scanner:Hide()
    if not (ok and model) then return end
    return ui.renderPreview(target, model, dataType)
end

-- Uncached items are requested; GET_ITEM_INFO_RECEIVED redraws.
local function lookupProblem(tooltipType, id)
    if tooltipType.dataType ~= Enum.TooltipDataType.Item or not C_Item then return end
    if C_Item.DoesItemExistByID and C_Item.DoesItemExistByID(id) == false then
        return fillText(L["There is no item with ID %s."], id)
    end
    if C_Item.GetItemInfo and not C_Item.GetItemInfo(id) then
        if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
        return fillText(L["Loading item %s..."], id)
    end
end

local function drawSample()
    local tooltipType = TOOLTIP_TYPES[state.tooltipType]
    local problem = state.lookup and lookupProblem(tooltipType, state.lookup)
    if not problem then
        local ok, panel = pcall(function()
            if state.lookup then return previewByID(anchor, tooltipType.dataType, state.lookup) end
            return ui.renderPreview(anchor, tooltipType.samples[state.sample].build(), tooltipType.dataType)
        end)
        if not ok then
            problem = fillText(L["The sample failed to draw: %s"], tostring(panel))
        elseif not panel then
            problem = fillText(L["Nothing to show for %s ID %s."], L[tooltipType.noun], state.lookup)
        end
    end
    failure:SetText(problem or "")
    local shown = preview()
    if shown then
        shown:SetShown(problem == nil)
        overlay:SetFrameLevel(shown:GetFrameLevel() + 20)
        scrollBar:SetFrameLevel(overlay:GetFrameLevel() + 5)
        horizontalBar:SetFrameLevel(overlay:GetFrameLevel() + 5)
    end
    local showing = state.tooltipType .. ":" .. state.sample .. ":" .. tostring(state.lookup)
    local offset = showing == scrolledFor and scrollBar:GetValue() or 0
    local horizontalOffset = showing == scrolledFor and horizontalBar:GetValue() or 0
    scrolledFor = showing
    previewTopMargin = PREVIEW_TOP_MARGIN
    if shown and shown:IsShown() then
        local _, _, tagHeight = ui.clampInsets(shown)
        previewTopMargin = math.max(previewTopMargin, tagHeight * shown:GetEffectiveScale() / host:GetEffectiveScale())
    end
    local sampleWidth = (shown and shown:IsShown())
        and shown:GetWidth() * shown:GetEffectiveScale() / host:GetEffectiveScale() + 2 * PREVIEW_MARGIN or 0
    local horizontalRange = math.max(0, math.ceil(sampleWidth - host:GetWidth()))
    horizontalBar:SetMinMaxValues(0, horizontalRange)
    horizontalBar:SetShown(horizontalRange > 0)
    if horizontalRange > 0 then
        horizontalThumb:SetWidth(math.max(24, horizontalBar:GetWidth() * host:GetWidth() / sampleWidth))
    end
    horizontalBar:SetValue(math.min(horizontalOffset, horizontalRange))
    local sampleHeight = (shown and shown:IsShown())
        and shown:GetHeight() * shown:GetEffectiveScale() / host:GetEffectiveScale() + previewTopMargin + PREVIEW_MARGIN or 0
    local range = math.max(0, math.ceil(sampleHeight - host:GetHeight()))
    scrollBar:SetMinMaxValues(0, range)
    scrollBar:SetShown(range > 0)
    if range > 0 then
        scrollThumbTexture:SetHeight(math.max(24, scrollBar:GetHeight() * host:GetHeight() / sampleHeight))
    end
    offset = math.min(offset, range)
    scrollBar:SetValue(offset)
    scrollBar:UpdateScrollMetrics(host:GetHeight(), sampleHeight)
    scrollTo(offset)
end

-- A part clicked on another page opens its type's page.
local function selectPart(key)
    state.page = state.tooltipType
    state.selected = key
    state.focusPart = true
    state.navExpanded = true
    -- The part's settings head the column.
    columnBar:SetValue(0)
    if not hasPart(key) and not state.lookup then
        for index = 1, #samples() do
            if index ~= state.sample then
                state.sample = index
                drawSample()
                if hasPart(key) then break end
            end
        end
    end
    refresh()
end

overlay:SetScript("OnMouseDown", function()
    if hovered then selectPart(hovered) end
end)

-- Dropdowns ------------------------------------------------------------------

local catcher = CreateFrame("Button", nil, editor)
catcher:SetAllPoints(UIParent)
catcher:SetFrameStrata("FULLSCREEN_DIALOG")
catcher:EnableMouse(true)
catcher:RegisterForClicks("AnyUp")
catcher:Hide()
local menu = CreateFrame("Frame", nil, catcher)
menu:SetFrameStrata("FULLSCREEN_DIALOG")
menu:EnableMouse(true)
menu:EnableMouseWheel(true)
skin:surface(menu, background(menu, { .07, .06, .06 }), outline(menu, LINE))
local scrollThumb = fill(menu, "ARTWORK", GOLD, .5)
scrollThumb:SetWidth(2)
menu.rows = {}
local nativeDropdowns = {}

closeMenu = function()
    catcher:Hide()
    menu.owner = nil
    for _, dropdown in ipairs(nativeDropdowns) do dropdown:CloseMenu() end
end
catcher:SetScript("OnClick", closeMenu)

local function fillMenu()
    local items, offset = menu.items, menu.offset
    local current = menu.owner.current()
    for index = 1, MENU_ROWS do
        local row = menu.rows[index]
        local item = items[index + offset]
        if item then
            row.item = item
            if item.font then
                ui.setFont(row.label, item.font, 13)
            else
                plainFont(row.label)
            end
            row.label:SetText(L[item.text])
            if item.value == current then
                row.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            else
                row.label:SetTextColor(.90, .87, .80)
            end
            row:Show()
        else
            row:Hide()
        end
    end
    local shown = math.min(#items, MENU_ROWS)
    if #items > MENU_ROWS then
        local track = shown * MENU_ROW_HEIGHT - 4
        local length = math.max(12, track * MENU_ROWS / #items)
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -2,
            -2 - (track - length) * offset / (#items - MENU_ROWS))
        scrollThumb:SetHeight(length)
        scrollThumb:Show()
    else
        scrollThumb:Hide()
    end
    menu:SetHeight(shown * MENU_ROW_HEIGHT + 4)
end

for index = 1, MENU_ROWS do
    local row = CreateFrame("Button", nil, menu)
    row:SetHeight(MENU_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 2, -2 - (index - 1) * MENU_ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", -6, -2 - (index - 1) * MENU_ROW_HEIGHT)
    local glow = fill(row, "HIGHLIGHT", GOLD, .12)
    glow:SetAllPoints()
    row.label = text(row, "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", 8, 0)
    row.label:SetPoint("RIGHT", -4, 0)
    row.label:SetWordWrap(false)
    row:SetScript("OnClick", function(self)
        local owner = menu.owner
        closeMenu()
        owner.pick(self.item.value)
        refresh()
    end)
    menu.rows[index] = row
end

menu:SetScript("OnMouseWheel", function(_, delta)
    local last = math.max(0, #menu.items - MENU_ROWS)
    menu.offset = math.max(0, math.min(last, menu.offset - delta))
    fillMenu()
end)

local function openMenu(owner)
    local items = owner.items()
    menu.owner, menu.items, menu.offset = owner, items, 0
    for index, item in ipairs(items) do
        if item.value == owner.current() then
            menu.offset = math.max(0, math.min(index - 1, #items - MENU_ROWS))
            break
        end
    end
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    menu:SetWidth(owner:GetWidth())
    catcher:Show()
    menu:SetFrameLevel(catcher:GetFrameLevel() + 10)
    fillMenu()
end

-- items() lists { value, text, font }; current() is the chosen value, nil for
-- the default; pick(value) saves a choice.
local menuFonts = {}
local function menuFont(path)
    local font = menuFonts[path]
    if font then return font end
    font = CreateFont("PrettyTooltipMenuFont" .. (#menuFonts + 1))
    menuFonts[#menuFonts + 1] = font
    font:CopyFontObject(GameFontHighlight)
    if not font:SetFont(path, 13, "") then font:CopyFontObject(GameFontHighlight) end
    menuFonts[path] = font
    return font
end

local function dropdown(width, items, current, pick)
    local button = CreateFrame("Button", nil, content)
    button:SetSize(width, 22)
    button.bg = background(button, FIELD)
    local edges = outline(button, LINE)
    button.label = text(button, "GameFontHighlightSmall")
    button.label:SetPoint("LEFT", 8, 0)
    button.label:SetPoint("RIGHT", -20, 0)
    button.label:SetWordWrap(false)
    local arrow = text(button, "GameFontNormalSmall", "v")
    arrow:SetPoint("RIGHT", -8, 0)
    button.items, button.current, button.pick = items, current, pick
    local nativeControl = skin:dropdown(button, button.bg, edges, arrow)
    local native = nativeControl.Dropdown
    nativeDropdowns[#nativeDropdowns + 1] = native
    local nativeFont = { native.Text:GetFont() }
    native:SetupMenu(function(_, root)
        root:SetScrollMode(MENU_ROWS * MENU_ROW_HEIGHT)
        for _, item in ipairs(items()) do
            local choice = item
            local radio = root:CreateRadio(L[choice.text], function() return current() == choice.value end, function()
                pick(choice.value)
                refresh()
            end)
            if choice.font then
                -- Menu rows are Compositor regions: SetFont is forbidden, a font
                -- object is not, and the Compositor resets the font on reuse.
                radio:AddInitializer(function(entry)
                    local font = entry.fontString
                    font:SetFontObject(menuFont(choice.font))
                    if font.SetTextToFit then font:SetTextToFit(font:GetText()) end
                end)
            end
        end
    end)
    nativeControl:HookScript("OnShow", function() native:GenerateMenu() end)
    button:SetScript("OnEnter", function(self)
        self.bg:SetVertexColor(FIELD_HOVER[1], FIELD_HOVER[2], FIELD_HOVER[3], 1)
    end)
    button:SetScript("OnLeave", function(self)
        self.bg:SetVertexColor(FIELD[1], FIELD[2], FIELD[3], 1)
    end)
    button:SetScript("OnClick", function(self)
        if skin.native then return end
        if menu.owner == self then closeMenu() else openMenu(self) end
    end)
    button.refresh = function()
        local value, shown = current(), nil
        for _, item in ipairs(items()) do
            if item.value == value then shown = item break end
        end
        if shown and shown.font then
            ui.setFont(button.label, shown.font, 13)
        else
            plainFont(button.label)
        end
        button.label:SetText(shown and L[shown.text] or fillText(L["%s (not installed)"], tostring(value)))
        if skin.native and button:IsVisible() then native:GenerateMenu() end
        native.Text:SetText(button.label:GetText())
        if shown and shown.font then ui.setFont(native.Text, shown.font, 13)
        else ui.setFont(native.Text, unpack(nativeFont)) end
    end
    controls[#controls + 1] = button
    return button
end

local function fontItems(defaultText)
    local items = { { text = defaultText } }
    for _, name in ipairs(ns.fontNames()) do
        items[#items + 1] = { value = name, text = name, font = ns.fontPath(name) }
    end
    return items
end

-- Other controls -------------------------------------------------------------

local function slider(width, current, set, low, high, suffix, step)
    step = step or 1
    local holder = CreateFrame("Frame", nil, content)
    holder:SetSize(width, 22)
    local bar = CreateFrame("Slider", nil, holder, "MinimalSliderTemplate")
    local parts = skin.templateParts(bar)
    bar:SetOrientation("HORIZONTAL")
    bar:SetPoint("LEFT", 0, 0)
    bar:SetSize(width - 46, 16)
    bar:SetMinMaxValues(low or SIZE_MIN, high or SIZE_MAX)
    bar:SetValueStep(step)
    if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
    local track = fill(bar, "BACKGROUND", LINE)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)
    bar:SetThumbTexture(WHITE)
    local thumb = bar:GetThumbTexture()
    thumb:SetSize(8, 16)
    thumb:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
    local value = text(holder, "GameFontHighlight")
    value:SetPoint("RIGHT", 0, 0)
    value:SetJustifyH("RIGHT")
    bar:SetScript("OnValueChanged", function(self, number)
        if self.updating then return end
        number = math.floor(number / step + .5) * step
        if number ~= current() then
            set(number)
            refresh()
        end
    end)
    bar:EnableMouseWheel(true)
    bar:SetScript("OnMouseWheel", function(self, delta) self:SetValue(self:GetValue() + delta * step) end)
    local updateSteppers = skin:slider(bar, track, parts)
    skin:bind(function(native)
        value:SetFontObject(native and "GameFontNormal" or "GameFontHighlight")
    end)
    holder.refresh = function()
        bar.updating = true
        bar:SetValue(current())
        bar.updating = false
        updateSteppers()
        value:SetText(current() .. (suffix or ""))
    end
    controls[#controls + 1] = holder
    return holder
end

-- Both color picker interfaces; cancelling restores the saved color.
local function pickColor(start, apply, restore)
    local function changed()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        apply({ r, g, b })
        refresh()
    end
    local function cancelled()
        restore()
        refresh()
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = start[1], g = start[2], b = start[3], hasOpacity = false,
            swatchFunc = changed, cancelFunc = cancelled,
        })
    else
        ColorPickerFrame:Hide()
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.previousValues = { r = start[1], g = start[2], b = start[3] }
        ColorPickerFrame.func = changed
        ColorPickerFrame.cancelFunc = cancelled
        ColorPickerFrame:SetColorRGB(start[1], start[2], start[3])
        ShowUIPanel(ColorPickerFrame)
    end
end

local function selectedElement()
    return ns.ELEMENT_BY_KEY[state.selected]
end

local function colorControl()
    local holder = CreateFrame("Frame", nil, content)
    holder:SetSize(FIELD_WIDTH, 22)
    local swatch = CreateFrame("Button", nil, holder)
    swatch:SetSize(22, 22)
    swatch:SetPoint("LEFT")
    outline(swatch, LINE)
    local chip = fill(swatch, "ARTWORK", { 1, 1, 1 })
    chip:SetPoint("TOPLEFT", 3, -3)
    chip:SetPoint("BOTTOMRIGHT", -3, 3)
    local status = text(holder, "GameFontHighlightSmall")
    status:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
    local automatic = editorButton(holder, "Default", 80, function()
        local inherited = ns.elementValue(state.selected, "color", state.tooltipType, true)
        ns.setElementSetting(state.selected, "color", type(inherited) == "table" and "automatic" or nil)
        refresh()
    end)
    automatic:SetPoint("RIGHT")
    swatch:SetScript("OnClick", function()
        local key = state.selected
        local saved = ns.elementSetting(key, "color")
        local start = ns.style(key, state.tooltipType).color or ns.ELEMENT_BY_KEY[key].color
        pickColor(start,
            function(color) ns.setElementSetting(key, "color", color) end,
            function() ns.setElementSetting(key, "color", saved) end)
    end)
    holder.refresh = function()
        local effective = ns.style(state.selected, state.tooltipType).color
        local custom = type(effective) == "table"
        local color = custom and effective or selectedElement().color
        chip:SetVertexColor(color[1], color[2], color[3], custom and 1 or .35)
        status:SetText(custom and L["Custom"] or L["Default"])
        automatic:SetShown(custom)
    end
    controls[#controls + 1] = holder
    return holder
end

-- inverted shows a setting stored as its opposite, for a label that reads better on.
local function checkbox(label, key, description, isAvailable, warning, inverted)
    local button = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    button:SetSize(22, 22)
    if isAvailable then button:SetMotionScriptsWhileDisabled(true) end
    -- The label is the row's, at its indent; the whole row takes the click.
    local caption = text(button, "GameFontHighlightSmall", label)
    caption:SetPoint("TOPLEFT", button, "TOPLEFT", ROW_INDENT - CONTROL_X, -4)
    caption:SetWidth(CONTROL_X - ROW_INDENT - 8)
    caption:SetWordWrap(true)
    button.caption = caption
    button:SetHitRectInsets(ROW_INDENT - CONTROL_X, 0, 0, 0)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L[label], 1, 1, 1)
        GameTooltip:AddLine(L[description], nil, nil, nil, true)
        if warning then GameTooltip:AddLine(L[warning], 1, .82, 0, true) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- A key can depend on the tooltip type shown.
    local function keyOf() return type(key) == "function" and key() or key end
    button:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        if inverted then checked = not checked end
        setFlag(keyOf(), checked)
        refresh()
    end)
    button.refresh = function()
        local on = ns.option(keyOf()) and true or false
        if inverted then on = not on end
        button:SetChecked(on)
        local available = not isAvailable or isAvailable()
        button:SetEnabled(available)
        local native = skin.native
        if available then
            caption:SetFontObject(native and "GameFontNormal" or "GameFontHighlightSmall")
        else
            caption:SetFontObject(native and "GameFontDisable" or "GameFontDisableSmall")
        end
        if available then labelColor(caption, ns.optionChanged(keyOf())) end
    end
    controls[#controls + 1] = button
    return button
end

-- Looking up by ID -------------------------------------------------------------

local function applyLookup(entry)
    local tooltipType = state.tooltipType
    local id = entry:match("^%s*(%d+)%s*$")
    for _, candidate in ipairs(TYPE_ORDER) do
        local linked = entry:match(TOOLTIP_TYPES[candidate].noun .. ":(%d+)")
        if linked then id, tooltipType = linked, candidate break end
    end
    if tooltipType ~= state.tooltipType then switchTooltipType(tooltipType) end
    state.lookup = id and tonumber(id) or nil
    refresh()
end

local lookupLabel = text(editor, "GameFontHighlightSmall")
lookupLabel:SetPoint("BOTTOMLEFT", editor, "TOPLEFT", PREVIEW_X, -PREVIEW_TOP + 59)
local lookupBox = CreateFrame("EditBox", nil, editor)
lookupBox:SetSize(PREVIEW_WIDTH - LOOKUP_LABEL_WIDTH - 70, 22)
lookupBox:SetPoint("BOTTOMLEFT", editor, "TOPLEFT", PREVIEW_X + LOOKUP_LABEL_WIDTH, -PREVIEW_TOP + 54)
skin:field(lookupBox, background(lookupBox, FIELD), outline(lookupBox, LINE))
lookupBox:SetFontObject("GameFontHighlightSmall")
lookupBox:SetTextInsets(8, 8, 0, 0)
lookupBox:SetAutoFocus(false)
lookupBox:SetMaxLetters(255)
local lookupPlaceholder = text(lookupBox, "GameFontDisableSmall", "ID, or shift-click a link")
lookupPlaceholder:SetPoint("LEFT", 8, 0)
lookupBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    applyLookup(self:GetText())
end)
lookupBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    refresh()
end)
lookupBox:SetScript("OnEditFocusGained", function() lookupPlaceholder:Hide() end)
lookupBox:SetScript("OnEditFocusLost", function(self)
    lookupPlaceholder:SetShown(self:GetText() == "")
end)
local lookupClear = editorButton(editor, "Clear", 62, function()
    state.lookup = nil
    refresh()
end)
lookupClear:SetPoint("LEFT", lookupBox, "RIGHT", 8, 0)

if ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", function(link)
        if lookupBox:HasFocus() and type(link) == "string" then
            lookupBox:ClearFocus()
            applyLookup(link)
        end
    end)
end

refreshLookup = function()
    local hidden = TOOLTIP_TYPES[state.tooltipType].noLookup == true
    lookupLabel:SetShown(not hidden)
    lookupBox:SetShown(not hidden)
    lookupLabel:SetText(L[TOOLTIP_TYPES[state.tooltipType].label:sub(1, -2) .. " ID"])
    if not lookupBox:HasFocus() then
        lookupBox:SetText(state.lookup and tostring(state.lookup) or "")
        lookupPlaceholder:SetShown(state.lookup == nil)
    end
    lookupClear:SetShown(state.lookup ~= nil and not hidden)
end

-- The controls column ----------------------------------------------------------

-- Entries belong to a page and an expandable group. Visible entries close
-- up on each refresh, leaving room for wrapped labels and inheritance links.
local entries = {}
local groups, buildingGroup = {}, nil
-- "type" builds one set of controls reused for all type pages.
local building = "type"
-- Page ownership drives reset actions and changed-setting indicators.
local pageSettings = { general = {}, tooltips = {}, other = {} }

local function register(setting)
    local list = pageSettings[building]
    if list then list[#list + 1] = setting end
    if buildingGroup then buildingGroup.settings[#buildingGroup.settings + 1] = setting end
end

local function entry(height, shown)
    local page = building
    local group = buildingGroup
    local holder = CreateFrame("Frame", nil, content)
    holder:SetSize(CONTROLS_WIDTH, height)
    entries[#entries + 1] = { holder = holder, height = height, group = group, shown = function()
        local onPage = page == state.page or (page == "type" and isTypePage(state.page))
        local expanded = not group or group.open[state.page]
        if group and expanded == nil then expanded = group.defaultOpen end
        return onPage and (not group or expanded) and (not shown or shown())
    end }
    return holder, entries[#entries]
end

-- shown() for an entry of some tooltip types alone.
local function forTypes(...)
    local wanted = {}
    for _, tooltipType in ipairs({ ... }) do wanted[tooltipType] = true end
    return function() return wanted[state.tooltipType] == true end
end

-- title is text, or a function giving it, for one that names the type shown.
local function section(title, shown, first, defaultOpen)
    buildingGroup = nil
    local top = first and 0 or 8
    local holder, headerEntry = entry(top + 26, shown)
    local group = { title = title, page = building, open = {}, defaultOpen = defaultOpen ~= false, settings = {}, holder = holder }
    groups[#groups + 1] = group
    headerEntry.groupHeader, headerEntry.group = group, group
    -- All entries retain their own frames, with one surface behind the whole
    -- group so expanded controls read as part of their heading.
    local card = CreateFrame("Frame", nil, content)
    card:SetFrameLevel(content:GetFrameLevel())
    card:SetWidth(CONTROLS_WIDTH)
    group.card, group.topInset = card, top
    holder.sectionCard = card
    local cardFill = background(card, FIELD)
    local cardEdges = outline(card, LINE)
    local headerFill = fill(holder, "BACKGROUND", FIELD)
    headerFill:SetPoint("TOPLEFT", 1, -top - 1)
    headerFill:SetPoint("BOTTOMRIGHT", -1, 4)
    local accent = fill(holder, "ARTWORK", GOLD)
    accent:SetPoint("TOPLEFT", 1, -top - 1)
    accent:SetPoint("BOTTOMLEFT", 1, 4)
    accent:SetWidth(2)
    local paintGroup = skin:group(cardFill, cardEdges, headerFill, accent)
    local button = CreateFrame("Button", nil, holder)
    button:SetPoint("TOPLEFT", 0, -top)
    button:SetSize(CONTROLS_WIDTH, 24)
    local hover = fill(button, "HIGHLIGHT", GOLD, .08)
    hover:SetAllPoints()
    local nativeHover = button:CreateTexture(nil, "HIGHLIGHT")
    nativeHover:SetAtlas("Options_List_Hover")
    nativeHover:SetAllPoints()
    local divider = holder:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider")
    divider:SetPoint("BOTTOMLEFT", 4, 4)
    divider:SetPoint("BOTTOMRIGHT", -4, 4)
    divider:SetHeight(atlasHeight("Options_HorizontalDivider", 4))
    local chevron = text(button, "GameFontNormal")
    chevron:SetPoint("LEFT", 2, 0)
    local label = text(holder, "GameFontNormal")
    label:SetPoint("TOPLEFT", 18, -top - 3)
    label:SetWidth(CONTROLS_WIDTH - 170)
    local summary = text(holder, "GameFontDisableSmall")
    summary:SetPoint("TOPRIGHT", -6, -top - 4)
    summary:SetWidth(142)
    summary:SetJustifyH("RIGHT")
    button:SetScript("OnClick", function()
        local open = group.open[state.page]
        if open == nil then open = group.defaultOpen end
        group.open[state.page] = not open
        refresh()
    end)
    skin:bind(function(native)
        label:SetFontObject(native and "GameFontHighlightLarge" or "GameFontNormal")
        hover:SetShown(not native)
        nativeHover:SetShown(native)
        divider:SetShown(native)
    end)
    controls[#controls + 1] = {
        refresh = function()
            -- Hidden sections still refresh, and a title function can return nil.
            local name = title
            if type(title) == "function" then name = title() end
            label:SetText(name and L[name] or "")
            local open = group.open[state.page]
            if open == nil then open = group.defaultOpen end
            chevron:SetText(open and "-" or "+")
            local count = 0
            for _, setting in ipairs(group.settings) do
                local changed
                if setting.changed then changed = setting.changed() else changed = setting.saved() ~= nil end
                if changed then count = count + 1 end
            end
            summary:SetText(count == 1 and L["1 override"] or count > 0 and fillText(L["%s overrides"], count)
                or (group.page == "type" and L["All shared"] or ""))
            paintGroup(open)
        end,
    }
    -- The header stays visible when its body is collapsed.
    local item = entries[#entries]
    item.layout = function()
        local height = math.max(24, label:GetStringHeight() + 8, summary:GetStringHeight() + 8)
        button:SetHeight(height)
        return top + height + 4
    end
    buildingGroup = group
    return group
end

-- What a row's reset button clears: saved gives the stored value, nil while
-- the setting is at its default.
local function partSetting(field)
    return {
        saved = function() return ns.elementSetting(state.selected, field) end,
        reset = function() ns.setElementSetting(state.selected, field, nil) end,
        resetLabel = "Use tooltip text style",
    }
end

-- key can be a function, for a setting kept per tooltip type.
local function optionSetting(key)
    local function keyOf() return type(key) == "function" and key() or key end
    return {
        saved = function() return ns.savedOption(keyOf()) end,
        changed = function() return ns.optionChanged(keyOf()) end,
        reset = function() ns.setOption(keyOf(), nil) end,
    }
end

-- A label, the control beside it, and, once the setting is changed, the label
-- marked with a button to put it back.
-- A control taller than one line (colorSwatches over two) gives the extra
-- height in extraHeight. A note explains the setting when its label is hovered.
local function row(label, control, setting, shown, note)
    local holder, item = entry(ROW_HEIGHT + (control.extraHeight or 0), shown)
    local caption = text(holder, "GameFontHighlightSmall", label)
    caption:SetPoint("TOPLEFT", ROW_INDENT, -5)
    caption:SetWidth(CONTROL_X - ROW_INDENT - 8)
    caption:SetWordWrap(true)
    if note then
        local hover = CreateFrame("Frame", nil, holder)
        hover:SetAllPoints(caption)
        hover:EnableMouse(true)
        explain(hover, label, note)
    end
    item.layout = function()
        return math.max(ROW_HEIGHT + (control.extraHeight or 0), caption:GetStringHeight() + 10)
    end
    skin:bind(function(native)
        caption:SetFontObject(native and "GameFontNormal" or "GameFontHighlightSmall")
    end)
    control:SetParent(holder)
    control:ClearAllPoints()
    control:SetPoint("TOPLEFT", CONTROL_X, 0)
    if not setting then return end
    register(setting)
    local button = CreateFrame("Button", nil, holder)
    button:SetSize(16, 16)
    button:SetPoint("TOPRIGHT", holder, "TOPLEFT", CONTROLS_WIDTH, -3)
    button:SetNormalTexture(RESET_ICON)
    button:SetHighlightTexture(RESET_ICON, "ADD")
    button:SetScript("OnClick", function()
        setting.reset()
        refresh()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L[setting.resetLabel or "Restore addon default"], 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    controls[#controls + 1] = {
        refresh = function()
            local changed
            if setting.changed then changed = setting.changed() else changed = setting.saved() ~= nil end
            button:SetShown(changed)
            labelColor(caption, changed)
        end,
    }
end

-- Checkboxes a row each, each { label, key, description, shown, isAvailable,
-- warning }: those shown close up, so a type's own come out without gaps. A
-- warning is a gold line under the description.
local function toggles(list, shown)
    local holder, item = entry(0, shown)
    local boxes = {}
    for index, toggle in ipairs(list) do
        local box = checkbox(toggle[1], toggle[2], toggle[3], toggle[5], toggle[6], toggle.inverted)
        box:SetParent(holder)
        register(optionSetting(toggle[2]))
        boxes[index] = { box = box, shown = toggle[4] }
    end
    -- The height is what the boxes shown take, so it is worked out at layout.
    item.layout = function()
        local height = 0
        for _, entryBox in ipairs(boxes) do
            local visible = not entryBox.shown or entryBox.shown()
            entryBox.box:SetShown(visible)
            if visible then
                entryBox.box:ClearAllPoints()
                entryBox.box:SetPoint("TOPLEFT", CONTROL_X, -height)
                local rowHeight = math.max(ROW_HEIGHT, entryBox.box.caption:GetStringHeight() + 10)
                entryBox.box:SetHitRectInsets(ROW_INDENT - CONTROL_X, 0, 0, -(rowHeight - 22))
                height = height + rowHeight
            end
        end
        return height
    end
end

-- Color groups share picker, cancel, and reset behavior. Their swatches
-- take the control's place, clear of the reset button.
local hexColor = ns.util.fromHex

-- note, if given, says why the colors shown may not be the ones chosen. More
-- swatches than fit across, as retail's thirteen classes, share out over
-- lines of about equal length.
local SWATCH_SIZE, SWATCH_STEP = 22, 28
local function colorSwatches(list, prefix, colorOf, note, width)
    width = width or FIELD_WIDTH
    local holder = CreateFrame("Frame", nil, content)
    local fit = math.max(1, math.floor((width - SWATCH_SIZE) / SWATCH_STEP) + 1)
    local lines = math.max(1, math.ceil(#list / fit))
    local across = math.ceil(#list / lines)
    holder:SetSize(width, SWATCH_SIZE + (lines - 1) * SWATCH_STEP)
    holder.extraHeight = (lines - 1) * SWATCH_STEP
    local chips = {}
    for index, choice in ipairs(list) do
        local key = prefix .. choice.key
        local swatch = CreateFrame("Button", nil, holder)
        swatch:SetSize(SWATCH_SIZE, SWATCH_SIZE)
        local place, line = (index - 1) % across, math.floor((index - 1) / across)
        swatch:SetPoint("TOPLEFT", place * SWATCH_STEP, -line * SWATCH_STEP)
        outline(swatch, LINE)
        local chip = fill(swatch, "ARTWORK", { 1, 1, 1 })
        chip:SetPoint("TOPLEFT", 3, -3)
        chip:SetPoint("BOTTOMRIGHT", -3, 3)
        swatch:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        swatch:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                ns.setOption(key, nil)
                refresh()
                return
            end
            local saved = ns.savedOption(key)
            pickColor(colorOf(choice.key) or ns.Palette.roles.neutral,
                function(color) ns.setOption(key, color) end,
                function() ns.setOption(key, saved) end)
        end)
        swatch:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L[choice.label], 1, 1, 1)
            GameTooltip:AddLine(L["Click to choose its color; right-click for the default."], nil, nil, nil, true)
            local why = note and note()
            if why then GameTooltip:AddLine(why, 1, .82, 0, true) end
            GameTooltip:Show()
        end)
        swatch:SetScript("OnLeave", function() GameTooltip:Hide() end)
        chips[choice.key] = chip
    end
    holder.refresh = function()
        for key, chip in pairs(chips) do
            local color = colorOf(key) or ns.Palette.roles.neutral
            chip:SetVertexColor(color[1], color[2], color[3], 1)
        end
    end
    controls[#controls + 1] = holder
    return holder
end

local function colorGroupSetting(list, prefix)
    return {
        saved = function()
            for _, choice in ipairs(list) do
                if ns.savedOption(prefix .. choice.key) ~= nil then return true end
            end
        end,
        reset = function()
            for _, choice in ipairs(list) do ns.setOption(prefix .. choice.key, nil) end
        end,
    }
end

-- All tooltips: shared appearance and behavior ---------------------------------------

-- Shared and per-type pages use the same controls; the latter store only
-- overrides. Color-picker callbacks capture their target before opening.
local buildStyleControls
do
    local function settingFor(key, perType)
        local setting = {}
        setting.saved = function()
            if perType then return ns.tooltipSetting(state.tooltipType, key) end
            return ns.savedOption(key)
        end
        setting.changed = function()
            if perType then return setting.saved() ~= nil end
            return ns.optionChanged(key)
        end
        setting.bind = function()
            local tooltipType = perType and state.tooltipType or nil
            return function(value)
                if tooltipType then ns.setTooltipSetting(tooltipType, key, value) else ns.setOption(key, value) end
            end
        end
        setting.reset = function() setting.bind()(nil) end
        setting.value = function() return ns.option(key, perType and state.tooltipType or nil) end
        if perType then setting.resetLabel = "Use All Tooltips setting" end
        return setting
    end

    local function colorField(setting, perType)
        local holder = CreateFrame("Frame", nil, content)
        holder:SetSize(FIELD_WIDTH, 22)
        local swatch = CreateFrame("Button", nil, holder)
        swatch:SetSize(22, 22)
        swatch:SetPoint("LEFT")
        outline(swatch, LINE)
        local chip = fill(swatch, "ARTWORK", { 1, 1, 1 })
        chip:SetPoint("TOPLEFT", 3, -3)
        chip:SetPoint("BOTTOMRIGHT", -3, 3)
        local status = text(holder, "GameFontHighlightSmall")
        status:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
        local automatic = editorButton(holder, "Default", 80, function()
            setting.bind()(perType and "automatic" or nil)
            refresh()
        end)
        automatic:SetPoint("RIGHT")
        swatch:SetScript("OnClick", function()
            local saved, apply = setting.saved(), setting.bind()
            local color = setting.value()
            pickColor(type(color) == "table" and color or { 1, 1, 1 }, apply, function() apply(saved) end)
        end)
        holder.refresh = function()
            local color = setting.value()
            local custom = type(color) == "table"
            chip:SetVertexColor(custom and color[1] or 1, custom and color[2] or 1, custom and color[3] or 1, custom and 1 or .35)
            status:SetText(custom and L["Custom"] or L["Default"])
            automatic:SetShown(custom)
        end
        controls[#controls + 1] = holder
        return holder
    end

    buildStyleControls = function(perType)
        local function bind(key) return settingFor(key, perType) end
        local function choice(label, key, choices, shown, note)
            local setting = bind(key)
            local capitalization = key:find("Caps", 1, true) ~= nil
            -- Names are in capitals unless told otherwise, other text is not, so each list
            -- names what shows; choosing what already shows saves nothing. A type's Default
            -- is explicit, to outrank a shared All Caps: names as written, other text as
            -- each part has it (captions stay in capitals).
            local titles = key == "titleCaps"
            local function shownCaps(saved)
                if saved == nil then return titles end
                return saved == true
            end
            row(label, dropdown(FIELD_WIDTH, function()
                local list = {}
                local available = choices()
                if perType then
                    local value = ns.option(key)
                    local name = value == nil and "Default" or tostring(value)
                    local named
                    for _, item in ipairs(available) do if item.value == value then name, named = item.text, true break end end
                    if capitalization then name = shownCaps(ns.savedOption(key)) and "All Caps" or "Default"
                    elseif type(value) == "boolean" and not named then name = value and "On" or "Off" end
                    list[1] = { text = fillText(L["All Tooltips: %s"], L[name]),
                        font = key:find("Font", 1, true) and ns.fontPath(value) or nil }
                end
                for _, item in ipairs(available) do list[#list + 1] = item end
                return list
            end, function()
                if capitalization then
                    local saved = setting.saved()
                    if perType and saved == nil then return nil end
                    return shownCaps(saved) and "caps" or "default"
                end
                if perType then return setting.saved() end
                return setting.value()
            end, function(value)
                if capitalization and value ~= nil then
                    local caps = value == "caps"
                    if perType then
                        if caps then value = true elseif titles then value = false else value = "automatic" end
                    elseif caps == titles then
                        value = nil
                    else
                        value = caps
                    end
                end
                setting.bind()(value)
            end), setting, shown, note)
        end
        local function boolean(label, key, shown, note)
            choice(label, key, function()
                local list = { { value = true, text = "On" }, { value = false, text = "Off" } }
                if not perType and (key == "icon" or key == "followCursor") then
                    table.insert(list, 1, { text = "Default" })
                end
                return list
            end, shown, note)
        end
        local function number(label, key, low, high, factor, suffix, fallback)
            local setting = bind(key)
            row(label, slider(FIELD_WIDTH, function()
                local value = setting.value()
                if value == nil then value = type(fallback) == "function" and fallback() or fallback end
                return math.floor(value * (factor or 1) + .5)
            end, function(value) setting.bind()(value / (factor or 1)) end, low, high, suffix), setting)
        end

        section("Appearance", nil, true)
        choice("Panel Style", "backdropStyle", function()
            if not perType then return BACKDROP_STYLES end
            return { { value = "automatic", text = "Default" }, { value = "native", text = "Blizzard Border" },
                { value = "flat", text = "Flat" }, { value = "dialogue", text = "DialogueUI" } }
        end, nil, PANEL_STYLE_NOTE)
        boolean("Panel Tint", "qualityTint", nil, PANEL_TINT_NOTE)
        boolean("Separators", "separators")
        boolean("Show Icon", "icon")
        number("Backdrop Opacity", "backdropAlpha", 0, 100, 100, "%")
        number("Glow Strength", "glowAlpha", 0, 100, 100, "%")
        for _, edge in ipairs({ "Top", "Bottom" }) do
            number(edge == "Top" and "Header Opacity (Upper Edge)" or "Header Opacity (Lower Edge)", "header" .. edge .. "Alpha",
                0, 100, 100, "%", function() return ui.defaultHeaderAlpha(perType and state.tooltipType or nil) end)
        end
        if not perType then
            row("School Colors", colorSwatches(ns.Palette.SCHOOLS, "schoolColor", ns.Palette.school),
                colorGroupSetting(ns.Palette.SCHOOLS, "schoolColor"))
        end

        section("Layout", nil, false, false)
        number(perType and "Scale" or "Global Scale", "tooltipScale", 50, 150, 100, "%")
        number("Padding", "padding", 8, 32, nil, " px")
        number("Minimum Width", "minWidth", 120, 400, nil, " px")
        number("Row Spacing", "rowSpacing", 50, 150, 100, "%")
        number("Section Spacing", "sectionSpacing", 50, 150, 100, "%")
        choice("Icon Placement", "iconRight", function()
            return { { value = false, text = "Left" }, { value = true, text = "Right" } }
        end)

        section("Text", nil, false, false)
        number("Text Size", "fontScale", 80, 150, 100, "%")
        for _, role in ipairs({ { "title", "Title" }, { "body", "Body Text" } }) do
            local prefix = role[1]
            local holder, headingEntry = entry(28)
            local roleHeading = text(holder, "GameFontHighlight", role[2])
            roleHeading:SetPoint("TOPLEFT", ROW_INDENT, -8)
            roleHeading:SetWidth(CONTROLS_WIDTH - ROW_INDENT)
            headingEntry.layout = function() return roleHeading:GetStringHeight() + 16 end
            choice("Font", prefix == "title" and "titleFont" or "bodyFont", function()
                local list = fontItems("Default")
                if perType then list[1] = { value = "automatic", text = "Default" } end
                return list
            end)
            choice("Size", prefix .. "Size", function()
                local list = { { text = "Default" } }
                if perType then list[1].value = "automatic" end
                for size = SIZE_MIN, SIZE_MAX do list[#list + 1] = { value = size, text = tostring(size) } end
                return list
            end)
            choice("Outline", prefix .. "Outline", function() return OUTLINES end)
            local color = bind(prefix .. "Color")
            row("Color", colorField(color, perType), color)
            choice("Capitalization", prefix .. "Caps", function()
                return { { value = "default", text = "Default" }, { value = "caps", text = "All Caps" } }
            end)
        end
        local function positionAvailable()
            return not perType or (KINDS[state.tooltipType] and KINDS[state.tooltipType].cursor ~= nil)
        end
        section("Behavior")
        boolean("Restyle", "restyle")
        boolean("Follow Cursor", "followCursor", positionAvailable)
    end
end

building = "tooltips"
buildStyleControls(false)
toggles({
    { "Show IDs", "showIDs", "The item's, spell's, aura's, or NPC's ID at the bottom of its panel, under other addons' "
        .. "rows." },
    { "Enable Tooltip Fading", "fadeTooltips",
        "On: Panels for units and world objects fade out with the timings below; both at zero hides them at once."
            .. "\n\nOff: They hide as soon as the cursor leaves them." },
})
local function fadeTooltips() return ns.option("fadeTooltips") end
row("Fade Delay", slider(FIELD_WIDTH, function()
    local delay = ns.fadeTiming()
    return delay
end, function(seconds)
    ns.setOption("hideDelay", seconds)
end, 0, 5, L[" sec"], .1), optionSetting("hideDelay"), fadeTooltips)
row("Fade Duration", slider(FIELD_WIDTH, function()
    local _, duration = ns.fadeTiming()
    return duration
end, function(seconds)
    ns.setOption("fadeDuration", seconds)
end, 0, 5, L[" sec"], .1), optionSetting("fadeDuration"), fadeTooltips)
toggles({
    { "Follow Cursor in Combat", "cursorDisableInCombat",
        "On: Tooltips keep following the cursor in combat.\n\nOff: In combat, tooltips take their default "
            .. "position, and follow the cursor again afterward.", inverted = true },
})

-- The kinds without a page of their own: whether each is restyled and follows
-- the cursor, as on a type's page.
building = "other"
section("Other Tooltips", nil, true)
do
    local others = {}
    for _, kind in ipairs(ns.TOOLTIP_TYPES) do
        if not kind.editor then others[#others + 1] = kind end
    end
    local RESTYLE_X, CURSOR_X = CONTROL_X, CONTROL_X + 90
    local holder, item = entry(0)
    local headings, rows = {}, {}
    for index, name in ipairs({ "Restyle", "Follow Cursor" }) do
        local caption = text(holder, "GameFontNormalSmall", name)
        caption:SetPoint("TOP", holder, "TOPLEFT", (index == 1 and RESTYLE_X or CURSOR_X) + 11, 0)
        caption:SetWidth(90)
        headings[#headings + 1] = caption
    end
    -- The Blizzard layout restyles no kind, so a kind's own box has no say then.
    local function kindBox(key, x, y, title, note, followsLayout)
        local box = CreateFrame("CheckButton", nil, holder, "UICheckButtonTemplate")
        box:SetSize(22, 22)
        box:SetPoint("TOPLEFT", x, y + 3)
        if box.SetMotionScriptsWhileDisabled then box:SetMotionScriptsWhileDisabled(true) end
        explain(box, title, note)
        if not key then
            box:Disable()
            return box
        end
        box:SetScript("OnClick", function(self)
            setFlag(key, self:GetChecked() and true or false)
            refresh()
        end)
        box.refresh = function()
            box:SetChecked(ns.option(key))
            if followsLayout then box:SetEnabled(ns.option("layout") ~= "blizzard") end
        end
        controls[#controls + 1] = box
        register(optionSetting(key))
        return box
    end
    for _, kind in ipairs(others) do
        local label = text(holder, kind.restyle and "GameFontHighlightSmall" or "GameFontDisableSmall", kind.label)
        label:SetWidth(RESTYLE_X - ROW_INDENT - 8)
        label:SetWordWrap(true)
        local restyle = kindBox(kind.restyle, RESTYLE_X, 0, "Restyle " .. kind.label:lower(), kind.restyle and RESTYLE_NOTE
            or "Not restyled yet; this kind keeps the game's own tooltip.", true)
        local cursor = kind.cursor and kindBox(kind.cursor, CURSOR_X, 0, "Follow Cursor", CURSOR_NOTE)
        rows[#rows + 1] = { label = label, restyle = restyle, cursor = cursor }
    end
    item.layout = function()
        local height = 20
        for _, caption in ipairs(headings) do height = math.max(height, caption:GetStringHeight() + 6) end
        for _, line in ipairs(rows) do
            line.label:ClearAllPoints()
            line.label:SetPoint("TOPLEFT", ROW_INDENT, -height - 2)
            line.restyle:ClearAllPoints()
            line.restyle:SetPoint("TOPLEFT", RESTYLE_X, -height + 3)
            if line.cursor then
                line.cursor:ClearAllPoints()
                line.cursor:SetPoint("TOPLEFT", CURSOR_X, -height + 3)
            end
            height = height + math.max(24, line.label:GetStringHeight() + 8)
        end
        return height + 6
    end
end

-- The Layout and keys page ----------------------------------------------------------

-- A choice of values for one option, each { value, label, note }, as radio
-- buttons down the column. current() is the value chosen; picked() follows a choice.
local function radios(key, choices, current, picked)
    current = current or function() return ns.option(key) end
    local holder = entry(#choices * 24 + 8)
    for index, choice in ipairs(choices) do
        local value, label, note = choice[1], choice[2], choice[3]
        local button = CreateFrame("CheckButton", nil, holder, "UIRadioButtonTemplate")
        button:SetPoint("TOPLEFT", ROW_INDENT, -(index - 1) * 24)
        local caption = text(button, "GameFontHighlightSmall", label)
        caption:SetPoint("LEFT", button, "RIGHT", 6, 0)
        skin:bind(function(native)
            caption:SetFontObject(native and "GameFontHighlight" or "GameFontHighlightSmall")
            button:SetHitRectInsets(0, -(caption:GetStringWidth() + 8), 0, 0)
        end)
        button:SetScript("OnClick", function()
            ns.setOption(key, nil)
            if current() ~= value then ns.setOption(key, value) end
            if picked then picked() end
            refresh()
        end)
        explain(button, label, note)
        button.refresh = function() button:SetChecked(current() == value) end
        controls[#controls + 1] = button
    end
    register(optionSetting(key))
end

building = "general"
section("Layout Style", nil, true)
radios("layout", {
    { "pretty", "PrettyTooltip", "Draw the PrettyTooltip panel for each kind that is restyled." },
    { "blizzard", "Blizzard", "Keep the game's own tooltips. Item Equip effects are shortened, and the details "
        .. "modifier adds disenchant results, the spell power breakdown and rates, gathering contents, and IDs." },
})
section("Default Tooltip Modifier")
radios("originalKey", {
    { "CTRL", "Ctrl", "Hold Ctrl to see the game's own tooltip instead of the panel." },
    { "ALT", "Alt", "Hold Alt to see the game's own tooltip instead of the panel." },
    { "NONE", "Never", "Never show the game's own tooltip in place of the panel." },
})
section("Tooltip Details Modifier")
radios("detailsKey", {
    { "SHIFT", "Shift", "Hold Shift to see disenchant results, the spell power breakdown and rates, gathering "
        .. "contents, and IDs. Each can still be turned off in the style editor." },
    { "ALWAYS", "Always Show", "Always show disenchant results, the spell power breakdown and rates, gathering "
        .. "contents, and IDs, as each one's setting in the style editor allows." },
})
section("Style Editor Appearance")
radios("editorStyle", {
    { "native", "Blizzard", "Use the game's settings frame borders and controls." },
    { "flat", "Flat", "Dark, flat panels with thin edges and plain controls." },
}, ns.editorStyle, function()
    if ns.refreshEditorStyle then ns.refreshEditorStyle() end
end)
-- Fonts and colors reach every page, so their reset belongs to none of them.
section("Reset")
do
    local holder = entry(30)
    local resetAll = editorButton(holder, "Reset All Fonts and Colors", 190, function()
        ns.resetStyles()
        refresh()
    end)
    resetAll:SetPoint("TOPLEFT", ROW_INDENT, -2)
    resetAll:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Reset All Fonts and Colors"], 1, 1, 1)
        GameTooltip:AddLine(L[RESET_STYLES_NOTE], nil, nil, nil, true)
        GameTooltip:Show()
    end)
    resetAll:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- The same four styling groups are shared by the parent and every type page.
building = "type"
buildStyleControls(true)

-- What only the type shown has ---------------------------------------------------------

local DETAILS = { item = "Item Details", spell = "Spell Details", unit = "Unit Details", object = "Object Details",
    quest = "Quest Details" }
section(function() return DETAILS[state.tooltipType] end, function() return DETAILS[state.tooltipType] ~= nil end)
-- What each type's Reset page clears and its dot in the page list counts; a
-- detail two types share is left to neither.
local typeSettings = {}
for _, tooltipType in ipairs(TYPE_ORDER) do
    local list = {}
    for _, key in ipairs(ns.TOOLTIP_STYLE_KEYS) do
        list[#list + 1] = {
            saved = function() return ns.tooltipSetting(tooltipType, key) end,
            reset = function() ns.setTooltipSetting(tooltipType, key, nil) end,
        }
    end
    for _, key in ipairs({ "restyle", "followCursor" }) do
        list[#list + 1] = {
            saved = function() return ns.tooltipSetting(tooltipType, key) end,
            reset = function() ns.setTooltipSetting(tooltipType, key, nil) end,
        }
    end
    typeSettings[tooltipType] = list
end
-- A type this client has no samples for has no page.
local function ownSetting(tooltipType, setting)
    local list = typeSettings[tooltipType]
    if list then list[#list + 1] = setting end
    return setting
end

-- The spell power rows read spell descriptions, which not every language's reading covers yet.
local function coefficients() return ns.Locale.features.coefficients == true end
-- Each { label, key, description, types, needs, part, isAvailable, warning }:
-- needs names data only some clients load (Classic's tables, which retail does
-- not), part a style part a client adds (retail's gems); the toggle is offered
-- where it is.
local DETAIL_TOGGLES = {
    { "Quest Parchment", "questParchment", "DialogueUI's brown parchment for quest tooltips, Quest Items, "
        .. "and items that begin a quest, with darker ink for readability. Requires DialogueUI to be installed.",
        types = { "item", "quest" }, isAvailable = function() return ns.Game.addonInstalled("DialogueUI") end },
    { "Level Badge", "itemLevelBadge", "The item level on a plate under the icon, for equipment.", types = { "item" } },
    { "Level Badge", "unitLevelBadge",
        "On: The level on a plate under the portrait.\n\nOff: The level stays in the info line.", types = { "unit" } },
    { "Guild Realm", "unitRealm", "A guild from another realm has its realm beside its name, as the game "
        .. "writes Guild-Realm, styled apart from the guild.", types = { "unit" } },
    { "Stat Markers", "statMarkers", "The small diamond before each stat; enchants use a green one.", types = { "item" } },
    { "Abbreviated Equip Effects", "liteWording", "Where the game's own item tooltip shows, in the Blizzard layout or with "
        .. "items not restyled, its Equip effects are shortened, as +1% Critical Strike Chance, and the game's "
        .. "colors kept, but for spell power and chance on hit effects in their stat colors. Hold the default "
        .. "tooltip modifier for the full wording.", types = { "item" } },
    { "Weapon Damage First", "swapDamage", "A weapon's damage on the large line, with its speed and damage per "
        .. "second on the small one under it.", types = { "item" } },
    { "Disenchant", "disenchant", "Green, blue, and purple armor and weapons list what they disenchant into, "
        .. "with each result's chance and the Enchanting it needs; with Auctionator, the expected value.",
        types = { "item" }, needs = "disenchant" },
    { "Socket Hint", "socketHint", "On: The game's Shift Right Click to Socket line, under an item's sockets."
        .. "\n\nOff: The panel leaves it out.", types = { "item" }, part = "gems" },
    { "Sell Price", "sellPrice", "The vendor price in the footer; for a stack, the price of one and of the "
        .. "whole stack.", types = { "item" } },
    { "Spell Power (Experimental)", "spellPower", "Under the description, each amount's spell power coefficient "
        .. "and its split into base and spell power. No game API has coefficients: they come from Forever's client "
        .. "data, and ones marked ~ are estimates.", types = { "spell" }, needs = "coefficients",
        isAvailable = coefficients, warning = "Experimental: not all values are correct yet." },
    { "Rates", "spellRates", "Under the spell power breakdown (on retail, the description), the average a cast "
        .. "deals or heals per second and per mana. Per second, what lands at once counts over the cast time "
        .. "(instants as the global cooldown: 1.5 sec, or on retail after haste) and what comes over time over "
        .. "its duration. Crits do not count, nor on Forever do talents.", types = { "spell" }, isAvailable = coefficients },
    { "Health Bar", "unitHealthBar", "The game's own health bar at the bottom of player and NPC panels. The "
        .. "game fills it, so it stays live without the addon reading health, which WoW Forever keeps from "
        .. "addons.", types = { "unit" } },
    { "Gathering", "gatheringLoot", "What a herb or ore node holds: its yield over all the times it can be "
        .. "gathered, then the stone, gems, and other herbs it may give and the chance each time. On a dead "
        .. "creature that can be skinned, the Skinning it needs and the leather, hides, and scales it may give. "
        .. "From Classic's loot tables.", types = { "object", "unit" }, needs = "nodeLoot" },
}
local detailList = {}
for _, detail in ipairs(DETAIL_TOGGLES) do
    local onType = forTypes(unpack(detail.types))
    local shown = onType
    if detail.needs then
        shown = function() return ns.hasData(detail.needs) and onType() end
    elseif detail.part then
        shown = function() return ns.ELEMENT_BY_KEY[detail.part] ~= nil and onType() end
    end
    detailList[#detailList + 1] = { detail[1], detail[2], detail[3], shown, detail.isAvailable, detail.warning }
    if #detail.types == 1 then ownSetting(detail.types[1], optionSetting(detail[2])) end
end
toggles(detailList)

local itemsPage, unitsPage = forTypes("item"), forTypes("unit")

-- A switch and the colors it turns on share a row, the colors dimmed while it is
-- off. Without a toggle, the row is more colors under the same switch, lined up.
local function switchedSwatches(key, list, prefix, colorOf, toggle)
    local inline = CreateFrame("Frame", nil, content)
    if toggle then
        toggle:SetParent(inline)
        toggle:SetPoint("TOPLEFT")
        toggle.caption:Hide()
        toggle:SetHitRectInsets(0, 0, 0, 0)
    end
    local swatches = colorSwatches(list, prefix, colorOf, nil, FIELD_WIDTH - SWATCH_STEP)
    swatches:SetParent(inline)
    swatches:SetPoint("TOPLEFT", SWATCH_STEP, 0)
    inline:SetSize(FIELD_WIDTH, swatches:GetHeight())
    inline.extraHeight = swatches.extraHeight
    inline.refresh = function() swatches:SetAlpha(ns.option(key) and 1 or .4) end
    controls[#controls + 1] = inline
    return inline
end
local function switchSetting(key, colors)
    local flag = optionSetting(key)
    return {
        changed = function() return flag.changed() or colors.saved() == true end,
        saved = function() return flag.saved() ~= nil or colors.saved() end,
        reset = function() flag.reset() colors.reset() end,
    }
end

local function statColor(key) return hexColor((ns.Stats.categoryColors(key))) end
row("Stat Colors", switchedSwatches("statColors", ns.Stats.CATEGORIES, "statColor", statColor,
    checkbox("Stat Colors", "statColors", "On: Each kind of stat in its color, and the school colors.\n\nOff: Every "
        .. "stat is off-white.")),
    ownSetting("item", switchSetting("statColors", colorGroupSetting(ns.Stats.CATEGORIES, "statColor"))), itemsPage)
-- A client's own stat colors, as retail's secondary stats, each group on a row of its own.
for _, group in ipairs(ns.Stats.CATEGORY_GROUPS) do
    row(group.label, switchedSwatches("statColors", group.categories, "statColor", statColor),
        ownSetting("item", colorGroupSetting(group.categories, "statColor")), itemsPage)
end
row("Armor Colors", switchedSwatches("armorColors", ns.Palette.ARMOR, "armorColor", ns.Palette.armorColor,
    checkbox("Armor Colors", "armorColors", "On: Cloth, leather, mail, and plate under the item's name, each in its "
        .. "color. A type you cannot wear stays red.\n\nOff: They take the quality color.")),
    ownSetting("item", switchSetting("armorColors", colorGroupSetting(ns.Palette.ARMOR, "armorColor"))), itemsPage)
row("Class Colors", colorSwatches(ns.Palette.CLASSES, "classColor", ns.Palette.classColor, function()
    if ns.Palette.addonClassColors() then
        return L["Your class colors addon sets these; the colors chosen here apply without it."]
    end
end),
    ownSetting("unit", colorGroupSetting(ns.Palette.CLASSES, "classColor")), unitsPage)

-- The part selected ------------------------------------------------------------

section("Selected Part", nil, false, false)
local pickerHolder = entry(26)
local partPicker = dropdown(CONTROLS_WIDTH - ROW_INDENT - 24, function()
    local items = {}
    for _, element in ipairs(ns.ELEMENTS) do
        local tooltipType = element.tooltipType or "item"
        -- A part drawn from data only some clients load (Classic's disenchant and
        -- loot tables) names it, and is offered where it is loaded.
        if (tooltipType == state.tooltipType or tooltipType == "shared") and (not element.needs or ns.hasData(element.needs)) then
            items[#items + 1] = { value = element.key, text = element.label }
        end
    end
    return items
end, function() return state.selected end, function(key) selectPart(key) end)
partPicker:SetParent(pickerHolder)
partPicker:SetPoint("TOPLEFT", ROW_INDENT, 0)
local noteHolder, noteEntry = entry(28)
local partNote = text(noteHolder, "GameFontDisableSmall")
partNote:SetPoint("TOPLEFT", ROW_INDENT, 0)
partNote:SetWidth(CONTROLS_WIDTH - ROW_INDENT - 24)
partNote:SetJustifyV("TOP")
noteEntry.layout = function()
    return math.max(28, partNote:GetStringHeight() + 6)
end

row("Font", dropdown(FIELD_WIDTH, function()
    local name = ns.elementValue(state.selected, "font", state.tooltipType, true)
    if name == nil or name == "automatic" then name = L["Default"] end
    local items = fontItems(fillText(L["Tooltip Style: %s"], name))
    items[1].font = ui.styleOf(state.selected, state.tooltipType).font
    return items
end, function()
    return ns.elementSetting(state.selected, "font")
end, function(name)
    ns.setElementSetting(state.selected, "font", name)
end), partSetting("font"))

row("Size", slider(FIELD_WIDTH, function()
    return tonumber(ns.elementValue(state.selected, "size", state.tooltipType)) or selectedElement().size
end, function(size)
    ns.setElementSetting(state.selected, "size", size)
end), partSetting("size"))

row("Color", colorControl(), partSetting("color"))

row("Outline", dropdown(FIELD_WIDTH, function()
    local outlineValue = ns.elementValue(state.selected, "outline", state.tooltipType, true)
    local name = outlineValue
    for _, item in ipairs(OUTLINES) do if item.value == outlineValue then name = item.text end end
    local items = { { text = fillText(L["Tooltip Style: %s"], L[name or "None"]) } }
    for _, item in ipairs(OUTLINES) do items[#items + 1] = item end
    return items
end, function()
    return ns.elementSetting(state.selected, "outline")
end, function(value)
    ns.setElementSetting(state.selected, "outline", value)
end), partSetting("outline"))

-- The part's default is saved as no setting.
local allCaps = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
allCaps:SetSize(22, 22)
local allCapsLabel = text(allCaps, "GameFontHighlightSmall", "All Caps")
allCapsLabel:SetPoint("LEFT", allCaps, "RIGHT", 2, 1)
allCaps:SetHitRectInsets(0, -(allCapsLabel:GetStringWidth() + 6), 0, 0)
allCaps:SetScript("OnClick", function(self)
    local checked = self:GetChecked() and true or false
    if checked == ns.elementValue(state.selected, "caps", state.tooltipType, true) then
        ns.setElementSetting(state.selected, "caps", nil)
    else
        ns.setElementSetting(state.selected, "caps", checked)
    end
    refresh()
end)
allCaps.refresh = function()
    local caps = ns.elementValue(state.selected, "caps", state.tooltipType)
    allCaps:SetChecked(caps)
end
controls[#controls + 1] = allCaps
row("Capitalization", allCaps, partSetting("caps"))

local resetHolder = entry(28)
local resetPart = editorButton(resetHolder, "Reset This Part", 120, function()
    ns.resetElement(state.selected)
    refresh()
end)
resetPart:SetPoint("TOPLEFT", CONTROL_X, 0)


-- Reset page and the page list's dots -------------------------------------------------

local STYLE_FIELDS = { "font", "size", "color", "outline", "caps" }
local function ownElements(tooltipType)
    local list = {}
    for _, element in ipairs(ns.ELEMENTS) do
        if (element.tooltipType or "item") == tooltipType then list[#list + 1] = element.key end
    end
    return list
end

pageChanged = function(page)
    for _, setting in ipairs(pageSettings[page] or typeSettings[page] or {}) do
        if setting.changed then
            if setting.changed() then return true end
        elseif setting.saved() ~= nil then
            return true
        end
    end
    if not isTypePage(page) and page ~= "tooltips" then return false end
    for _, key in ipairs(ownElements(page == "tooltips" and "shared" or page)) do
        for _, field in ipairs(STYLE_FIELDS) do
            if ns.elementSetting(key, field) ~= nil then return true end
        end
    end
    return false
end

resetPage = function(page)
    for _, setting in ipairs(pageSettings[page] or typeSettings[page] or {}) do setting.reset() end
    if isTypePage(page) then
        for _, key in ipairs(ownElements(page)) do ns.resetElement(key) end
    elseif page == "tooltips" then
        for _, key in ipairs(ownElements("shared")) do ns.resetElement(key) end
    elseif page == "general" and ns.refreshEditorStyle then
        ns.refreshEditorStyle()
    end
end

-- Lays out the entries shown, top to bottom, and sizes the scroll to them.
local function layoutColumn()
    local y = 0
    for _, group in ipairs(groups) do group.card:Hide() group.bottom = nil end
    for _, item in ipairs(entries) do
        local visible = not item.shown or item.shown()
        local height = visible and (item.layout and item.layout() or item.height) or 0
        if height > 0 then
            item.holder:ClearAllPoints()
            item.holder:SetPoint("TOPLEFT", 0, -y)
            item.holder:SetHeight(height)
            item.holder:Show()
            -- A group's header owns the card; following entries extend it.
            if item.groupHeader then
                local group = item.groupHeader
                group.card:ClearAllPoints()
                group.card:SetPoint("TOPLEFT", 0, -y - group.topInset)
                group.cardTop = y + group.topInset
                group.card:Show()
            end
            y = y + height
            if item.group then item.group.bottom = y end
        else
            item.holder:Hide()
        end
    end
    for _, group in ipairs(groups) do
        if group.card:IsShown() then group.card:SetHeight(math.max(1, group.bottom - group.cardTop)) end
    end
    content:SetHeight(y + 8)
    local range = math.max(0, math.ceil(y + 8 - column:GetHeight()))
    columnBar:SetMinMaxValues(0, range)
    columnBar:SetShown(range > 0)
    if range > 0 then
        columnThumb:SetHeight(math.max(24, columnBar:GetHeight() * column:GetHeight() / (y + 8)))
    end
    columnBar:SetValue(math.min(columnBar:GetValue(), range))
    columnBar:UpdateScrollMetrics(column:GetHeight(), y + 8)
    column:SetVerticalScroll(math.min(columnBar:GetValue(), range))
    if state.focusGroup then
        local _, _, _, _, top = state.focusGroup.holder:GetPoint()
        local offset = math.min(range, math.max(0, -(top or 0)))
        columnBar:SetValue(offset)
        column:SetVerticalScroll(offset)
        state.focusGroup = nil
    end
end

editor:SetHeight(EDITOR_HEIGHT)
host:SetHeight(EDITOR_HEIGHT - PREVIEW_TOP - BUTTONS_SPACE)

-- Wiring ---------------------------------------------------------------------

local PAGE_TEXT = {
    tooltips = "Defaults for all tooltip types. Individual types can override these settings.",
    general = "Addon preferences, modifier keys, and editor appearance.",
    other = "Restyle and cursor settings for other tooltip types.",
}

local previewTitle = text(editor, "GameFontNormalLarge", "Preview")
previewTitle:SetPoint("TOPLEFT", PREVIEW_X, -PAGE_TOP)
skin:bind(function(native)
    previewTitle:SetFontObject(native and "GameFontHighlightHuge" or "GameFontNormalLarge")
end)
local previewStatus = text(editor, "GameFontDisableSmall")
previewStatus:SetPoint("TOPLEFT", previewTitle, "BOTTOMLEFT", 0, -6)
previewStatus:SetWidth(PREVIEW_WIDTH)
local previewTypePicker = dropdown(180, function()
    local choices = {}
    for _, tooltipType in ipairs(TYPE_ORDER) do
        choices[#choices + 1] = { value = tooltipType, text = TOOLTIP_TYPES[tooltipType].label }
    end
    return choices
end, function() return state.tooltipType end, function(tooltipType)
    local page = state.page
    switchTooltipType(tooltipType)
    state.page = page
end)
previewTypePicker:SetParent(editor)
previewTypePicker:SetPoint("TOPRIGHT", editor, "TOPLEFT", PREVIEW_X + PREVIEW_WIDTH, -PAGE_TOP + 3)

local function fitEditor()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if width > 32 and height > 32 then
        editor:SetScale(math.min(1, (width - 32) / editor:GetWidth(), (height - 32) / EDITOR_HEIGHT))
    end
end

local function refreshPages()
    local blizzard = ns.option("layout") == "blizzard"
    local native = skin.native
    for page, button in pairs(navButtons) do
        local chosen = page == state.page or (page == "tooltips" and not state.navExpanded and state.page ~= "general")
        -- The game's settings mark the page shown with their streak and white text.
        button.active:SetShown(native and chosen)
        button.chosen:SetShown(not native and chosen)
        button.bar:SetShown(not native and chosen)
        button.dot:SetShown(pageChanged(page))
        local kind = KINDS[page]
        local color
        if chosen then
            color = native and { 1, 1, 1 } or GOLD
        elseif native and (page == "general" or page == "tooltips") then
            color = { 1, 1, 1 }
        elseif kind and kind.restyle and (blizzard or not ns.option(kind.restyle)) then
            color = { .5, .48, .45 }
        else
            color = native and NORMAL or { .95, .92, .86 }
        end
        button.label:SetTextColor(color[1], color[2], color[3])
    end
    layoutNavigation()
    previewTypePicker:SetShown(state.page == "tooltips")
    -- Every page keeps room for the tallest description, type pages' empty one
    -- too, so the controls do not jump between pages.
    local textHeight = 0
    for _, description in pairs(PAGE_TEXT) do
        pageText:SetText(L[description])
        textHeight = math.max(textHeight, pageText:GetStringHeight())
    end
    if isTypePage(state.page) then
        pageTitle:SetText(L[TOOLTIP_TYPES[state.page].label])
        pageText:SetText("")
    else
        pageTitle:SetText(L[state.page == "general" and "General" or state.page == "other" and "Other Tooltips" or "All Tooltips"])
        pageText:SetText(L[PAGE_TEXT[state.page]])
    end
    resetPageButton:SetEnabled(pageChanged(state.page))
    pageTitle:SetWidth(CONTROLS_WIDTH - resetPageButton:GetWidth() - 12)
    local top = PAGE_TOP + pageTitle:GetStringHeight() + 6 + textHeight + 20
    pageRule:ClearAllPoints()
    pageRule:SetPoint("TOPLEFT", PAGE_X, -top + 10)
    pageDivider:ClearAllPoints()
    pageDivider:SetPoint("TOP", editor, "TOPLEFT", PAGE_X + CONTROLS_WIDTH / 2, -top + 10)
    column:ClearAllPoints()
    column:SetPoint("TOPLEFT", CONTROLS_X, -top)
    column:SetHeight(EDITOR_HEIGHT - top - BUTTONS_SPACE)

    -- Keep room for the picker and heading even on pages where
    -- the picker is hidden and the title has the full column width.
    previewTitle:SetWidth(PREVIEW_WIDTH - 192)
    local previewHeadingHeight = math.max(previewTypePicker:GetHeight(), previewTitle:GetStringHeight())
    previewTitle:SetWidth(state.page == "tooltips" and PREVIEW_WIDTH - 192 or PREVIEW_WIDTH)
    previewStatus:ClearAllPoints()
    previewStatus:SetPoint("TOPLEFT", editor, "TOPLEFT", PREVIEW_X, -PAGE_TOP - previewHeadingHeight - 6)
    -- Reserve both translated notices even while neither is displayed.
    previewStatus:SetText(L["Blizzard layout is active. This previews your saved style."])
    local statusHeight = previewStatus:GetStringHeight()
    previewStatus:SetText(L["Restyle is off for this type. This previews your saved style."])
    statusHeight = math.max(statusHeight, previewStatus:GetStringHeight())
    local kind = KINDS[state.tooltipType]
    if blizzard then
        previewStatus:SetText(L["Blizzard layout is active. This previews your saved style."])
    elseif kind and kind.restyle and not ns.option(kind.restyle) then
        previewStatus:SetText(L["Restyle is off for this type. This previews your saved style."])
    else
        previewStatus:SetText("")
    end
    previewTop = math.max(PREVIEW_TOP,
        PAGE_TOP + previewHeadingHeight + 6 + statusHeight + 90)
    lookupLabel:ClearAllPoints()
    lookupLabel:SetPoint("BOTTOMLEFT", editor, "TOPLEFT", PREVIEW_X, -previewTop + 59)
    lookupBox:ClearAllPoints()
    lookupBox:SetPoint("BOTTOMLEFT", editor, "TOPLEFT", PREVIEW_X + LOOKUP_LABEL_WIDTH, -previewTop + 54)
end

refresh = function()
    if state.focusPart then
        for _, group in ipairs(groups) do
            if group.title == "Selected Part" then
                group.open[state.page] = true
                state.focusGroup = group
            end
        end
        state.focusPart = nil
    end
    fitEditor()
    refreshPages()
    layoutSamples()
    drawSample()
    refreshLookup()
    partNote:SetText(L[selectedElement().note or ""])
    for _, control in ipairs(controls) do control.refresh() end
    layoutColumn()
    paintHighlights()
    showHint()
end

-- Also from the options page's Defaults, which can change what the editor shows.
function ns.refreshEditorStyle()
    closeMenu()
    skin:refresh()
    if editor:IsShown() then refresh() end
end

editor:SetScript("OnShow", function() ns.refreshEditorStyle() refresh() end)
editor:SetScript("OnHide", closeMenu)
editor:RegisterEvent("GET_ITEM_INFO_RECEIVED")
editor:RegisterEvent("QUEST_DATA_LOAD_RESULT")
editor:RegisterEvent("DISPLAY_SIZE_CHANGED")
editor:RegisterEvent("UI_SCALE_CHANGED")
editor:SetScript("OnEvent", function(_, event, id, success)
    if not editor:IsShown() then return end
    if event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then refresh() return end
    if ns.util.isSecret(id) or ns.util.isSecret(success) then return end
    if event == "GET_ITEM_INFO_RECEIVED" then
        if state.tooltipType == "item" and id == state.lookup then refresh() end
    elseif event == "QUEST_DATA_LOAD_RESULT" and success and state.tooltipType == "quest" then
        local sample = samples()[state.sample]
        if sample and sample.questID == id then refresh() end
    end
end)

-- For tests/: the pages, as the page list and Reset page reach them.
ns.editorPages = {
    open = openPage,
    current = function() return state.page end,
    changed = function(page) return pageChanged(page) end,
    reset = function(page)
        resetPage(page)
        refresh()
    end,
}

function ns.openEditor()
    editor:Show()
    editor:Raise()
end
