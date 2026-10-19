-- The details a panel shows, on the game's own tooltip wherever it shows
-- instead: in the Blizzard layout, and for a type not restyled. The original-
-- tooltip key leaves the game's tooltip as it was.
--
-- They are the addon's own font strings in room the tooltip leaves at its
-- bottom, as the game makes room for an embedded item: bottom padding, and a
-- minimum width. The game's lines are never added to, so the details key
-- shows and hides them at once, in combat too, without the game filling the
-- tooltip again.
local _, ns = ...
if not ns.TooltipTypes then return end
local util = ns.util
local isSecret = util.isSecret
local TooltipTypes = ns.TooltipTypes
local DETAIL_COLOR = ns.Palette.roles.detail
ns.Details = {}
local registered = false

-- The game's own inset from a tooltip's edges to its lines.
local INSET = 10
-- Above the details, as a blank line would leave.
local GAP = 8
local LINE_GAP = 2
local COLUMN_GAP = 16
-- Every detail whose setting is on; the key decides whether they show.
local ALL = { allDetails = true }

local states = setmetatable({}, { __mode = "k" })

local function number(value)
    if isSecret(value) or type(value) ~= "number" then return nil end
    return value
end

-- What the tooltip had before the details took room, as it is when the game
-- has just cleared it if it cannot be read.
local function keepBase(tooltip, state)
    if state.base then return end
    local right, bottom, left, top = util.call(tooltip.GetPadding, tooltip)
    state.base = { right = number(right) or 0, bottom = number(bottom) or 0, left = number(left) or 0,
        top = number(top) or 0, minWidth = number((util.call(tooltip.GetMinimumWidth, tooltip))) or 0 }
end

-- keepPadding: the game clears the padding itself, as on hide.
local function giveBack(tooltip, state, keepPadding)
    state.block:Hide()
    local base = state.base
    if not base then return end
    state.base = nil
    if not util.canModify(tooltip) then return end
    if not keepPadding then pcall(tooltip.SetPadding, tooltip, base.right, base.bottom, base.left, base.top) end
    pcall(tooltip.SetMinimumWidth, tooltip, base.minWidth)
end

local function fontAt(state, side, index)
    local list = state[side]
    local font = list[index]
    if not font then
        font = state.block:CreateFontString(nil, "ARTWORK", "GameTooltipText")
        if font.SetWordWrap then font:SetWordWrap(false) end
        font:SetJustifyH(side == "rights" and "RIGHT" or "LEFT")
        list[index] = font
    end
    return font
end

-- Draws the rows into the tooltip's block, hidden, and measures them.
local function draw(state, rows)
    local y, width = GAP, 0
    for index, row in ipairs(rows) do
        local left, right = fontAt(state, "lefts", index), fontAt(state, "rights", index)
        left:SetText(row.left)
        left:SetTextColor(unpack(row.color or DETAIL_COLOR))
        left:ClearAllPoints()
        left:SetPoint("TOPLEFT", state.block, "TOPLEFT", 0, -y)
        left:Show()
        local rowWidth = left:GetStringWidth()
        local height = left:GetStringHeight()
        if row.right and row.right ~= "" then
            right:SetText(row.right)
            right:SetTextColor(unpack(row.rightColor or row.color or DETAIL_COLOR))
            right:ClearAllPoints()
            right:SetPoint("TOPRIGHT", state.block, "TOPRIGHT", 0, -y)
            right:Show()
            rowWidth = rowWidth + COLUMN_GAP + right:GetStringWidth()
            height = math.max(height, right:GetStringHeight())
        else
            right:Hide()
        end
        width = math.max(width, rowWidth)
        y = y + height + (index < #rows and LINE_GAP or 0)
    end
    for _, side in ipairs({ "lefts", "rights" }) do
        for index = #rows + 1, #state[side] do state[side][index]:Hide() end
    end
    state.width, state.height = math.ceil(width), math.ceil(y)
    state.block:SetHeight(state.height)
end

local function shows(state)
    return state.rows ~= nil and not ns.originalKeyDown() and ns.detailsKeyDown()
        and not ns.restyles(TooltipTypes[state.dataType].option)
end

-- Takes room for the details while they show and gives it back otherwise.
-- relayout: the tooltip lays itself out again, which the game's fill does
-- itself right after the post-calls.
local function apply(tooltip, state, relayout)
    if not util.canModify(tooltip) then return end
    if not shows(state) then
        if state.base then
            giveBack(tooltip, state)
            if relayout then tooltip:Show() end
        end
        return
    end
    keepBase(tooltip, state)
    local base = state.base
    tooltip:SetPadding(base.right, base.bottom + state.height, base.left, base.top)
    tooltip:SetMinimumWidth(math.max(base.minWidth, state.width + 2 * INSET))
    state.block:Show()
    if relayout then tooltip:Show() end
end

local function stateOf(tooltip)
    local state = states[tooltip]
    if state then return state end
    local block = CreateFrame("Frame", nil, tooltip)
    block:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMLEFT", INSET, INSET)
    block:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -INSET, INSET)
    block:Hide()
    state = { block = block, lefts = {}, rights = {} }
    states[tooltip] = state
    -- The game clears its padding on hide, but not on a refill.
    tooltip:HookScript("OnHide", function(hidden)
        state.rows = nil
        giveBack(hidden, state, true)
    end)
    tooltip:HookScript("OnTooltipCleared", function(cleared)
        state.rows = nil
        giveBack(cleared, state, false)
    end)
    return state
end

local function anyOn(tooltipType)
    for _, key in ipairs(tooltipType.detailKeys) do
        if ns.option(key) then return true end
    end
    return false
end

local function onTooltipData(dataType, tooltip, data)
    if not util.canModify(tooltip) or tooltip.prettyTooltipScanner then return end
    local tooltipType = TooltipTypes[dataType]
    if ns.restyles(tooltipType.option) or not anyOn(tooltipType) then return end
    if isSecret(data) or type(data) ~= "table" then return end
    local ok, model = pcall(tooltipType.read, tooltip, data, ns.Game)
    if not ok or not model then return end
    local built, rows = pcall(tooltipType.details, model, ALL)
    if not built or not rows or #rows == 0 then return end
    local state = stateOf(tooltip)
    if not pcall(draw, state, rows) then return end
    state.rows, state.dataType = rows, dataType
    pcall(apply, tooltip, state, false)
end

-- Called once by the entry file.
function ns.Details.register()
    if registered then return end
    if not ns.Processor.available() then return end
    registered = true
    for dataType, tooltipType in pairs(TooltipTypes) do
        if tooltipType.details then
            ns.Processor.onData("details", dataType, function(tooltip, data)
                onTooltipData(dataType, tooltip, data)
            end)
        end
    end

    ns.Processor.onKey("details", function(key)
        if not (ns.isDetailsKey(key) or ns.isOriginalKey(key)) then return end
        for tooltip, state in pairs(states) do
            if state.rows and util.canModify(tooltip) and util.call(tooltip.IsShown, tooltip) then
                pcall(apply, tooltip, state, true)
            end
        end
    end)
end
