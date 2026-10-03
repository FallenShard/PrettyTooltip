-- Quests as a panel.
local _, ns = ...
local ui = ns.ui
local QUEST = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Quest
if not (ui and QUEST and ui.drawPills) then
    return
end

local isSecret, safeText = ui.isSecret, ui.safeText
local LINE = Enum.TooltipDataLineType or {}
local PAD = ui.PAD
local ICON_SIZE = 38
local TEXT_INDENT = ICON_SIZE + 10
local TINT_STRENGTH = .45
local CHECK_SIZE = 10
local OBJECTIVE_INDENT = CHECK_SIZE + 7
local BAR_HEIGHT = 3
local QUEST_GOLD = { 1, .82, 0 }
local PARCHMENT = { .86, .74, .45 }
local TITLE_COLOR = { .96, .92, .84 }
local ZONE_COLOR = { .82, .78, .71 }
local CAPTION_COLOR = { .60, .57, .52 }
local OBJECTIVE_COLOR = { .90, .85, .74 }
local DONE_COLOR = { .45, .80, .40 }
local FAILED_COLOR = { 1, .35, .30 }
local REPEAT_COLOR = { .45, .70, 1 }
local QUEST_ICON = "Interface\\Icons\\INV_Misc_Book_08"
local TAGS = { Elite = true, Dungeon = true, Raid = true, Group = true, PvP = true }
-- Questie writes the tag as a suffix on the level: "[27D] The Fury Runs Deep".
local SUFFIX_TAGS = {
    ["+"] = "Elite", ["++"] = "Legendary", D = "Dungeon", R = "Raid", H = "Heroic",
    G = "Group", S = "Scenario", W = "World event",
}
-- Questie's labeled rows, shown as label and value.
local LABELS = { ["Started by"] = true, ["Ended by"] = true, ["Found in"] = true, ["Completed on"] = true }
local PARTS = { "questTitle", "questInfo", "questBadges", "questText", "questCaption", "questObjectives",
    "extras" }

local function trim(text)
    return text:match("^%s*(.-)%s*$")
end

local function readable(value)
    if isSecret(value) then return nil end
    return value
end

local function check(fn, ...)
    if not fn then return end
    local ok, result = pcall(fn, ...)
    if ok and not isSecret(result) then return result end
end

local function difficultyColor(level)
    if type(level) ~= "number" or not GetQuestDifficultyColor then return end
    local color = check(GetQuestDifficultyColor, level)
    if type(color) == "table" and color.r then return { color.r, color.g, color.b } end
end

local function questKey(_, data)
    return readable(data.id)
end

local function completeModel(model, questID)
    if questID and C_QuestLog and not model.active then
        model.completed = model.completed or check(C_QuestLog.IsQuestFlaggedCompleted, questID) == true
        model.active = model.active or check(C_QuestLog.IsOnQuest, questID) == true
    end
    model.color = difficultyColor(model.level) or QUEST_GOLD
    model.icon = model.icon or QUEST_ICON
    return model
end

local function objectiveDone(row)
    if row.completed ~= nil then return row.completed end
    local have, need = (row.right ~= "" and row.right or row.left):match("(%d+)%s*/%s*(%d+)%s*$")
    return have ~= nil and tonumber(have) >= tonumber(need)
end

local function isRed(color)
    return type(color) == "table" and color[1] > .9 and color[2] < .4 and color[3] < .4
end

-- Questie colors its lines with codes on white text.
local function codeColor(text)
    local r, g, b = text:match("^%s*|c%x%x(%x%x)(%x%x)(%x%x)")
    if r then return { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255 } end
end

local function readTitle(model, text)
    local level, suffix, rest = text:match("^%[(%d+)([^%]]*)%]%s*(.+)$")
    if level then
        model.level = tonumber(level)
        if SUFFIX_TAGS[suffix] then model.tags[#model.tags + 1] = SUFFIX_TAGS[suffix] end
        text = rest
    end
    model.name = text:gsub("%s*%(%d+%)$", "")
end

-- A row from the data or from a font string, read the same way.
local function readRow(model, row, state)
    local text = trim(ui.uncolored(row.left))
    local right = trim(ui.uncolored(row.right or ""))
    if text == "" and right == "" then return end
    if not model.name then return readTitle(model, text) end
    if state.label then
        model.extras[#model.extras + 1] = { left = state.label, right = text }
        state.label = nil
        return
    end
    local label = text:match("^(.-):")
    local level = text:match("^Level (%d+)") or text:match("^Requires Level (%d+)")
    if level and not model.level then
        model.level = tonumber(level)
    elseif TAGS[text] then
        model.tags[#model.tags + 1] = text
    elseif text:match("^You are on this quest") then
        model.active = true
        model.ready = text:find("(Complete)", 1, true) ~= nil
        model.failed = text:find("(Failed)", 1, true) ~= nil
    elseif text:match("^You have completed this quest") then
        model.completed = true
    elseif text:match("^This quest is repeatable") then
        model.repeatable = true
    elseif text:match("^You have not done this quest") or text == "Objectives" or text:match("^Your progress") then
        return
    elseif text:match("^Instance: ") then
        model.zone = text:match("^Instance: (.+)")
    elseif row.objective or text:match("^%-") or text:match("%d+%s*/%s*%d+%s*$") then
        local name = text:gsub("^%-%s*", "")
        local goal, progress = name:match("^(.-):%s*(%d+%s*/%s*%d+)$")
        local objective = { left = goal or name, right = progress or right, completed = row.completed }
        objective.completed = objectiveDone(objective)
        model.objectives[#model.objectives + 1] = objective
    elseif label and LABELS[label] then
        local value = text:match("^.-:%s*(.+)$")
        if value then
            model.extras[#model.extras + 1] = { left = label, right = value }
        else
            -- "Completed on:" puts its date on the next line.
            state.label = label
        end
    elseif isRed(codeColor(row.left) or row.textColor) then
        model.extras[#model.extras + 1] = { left = text, right = right, color = FAILED_COLOR }
    elseif right == "" and #text >= 30 then
        model.description[#model.description + 1] = text
    else
        model.extras[#model.extras + 1] = { left = text, right = right, color = row.color, rightColor = row.rightColor }
    end
end

local function readQuest(tooltip, data)
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local model = { description = {}, objectives = {}, tags = {}, extras = {} }
    local lineIndices, state = {}, {}
    for _, line in ipairs(data.lines) do
        if isSecret(line) or not line or isSecret(line.type) or isSecret(line.lineIndex) then return end
        if line.lineIndex then
            local left, right = safeText(line.leftText), safeText(line.rightText)
            if not left or not right then return end
            lineIndices[line.lineIndex] = true
            local color = ui.colorOf(line.leftColor)
            local completed = line.completed
            if isSecret(completed) then completed = nil end
            readRow(model, {
                left = left,
                right = right,
                color = color,
                textColor = color,
                rightColor = ui.colorOf(line.rightColor),
                objective = LINE.QuestObjective and line.type == LINE.QuestObjective,
                completed = completed,
            }, state)
        end
    end
    local appended = ui.appendedRows(tooltip, lineIndices)
    if not appended then return end
    for _, row in ipairs(appended) do readRow(model, row, state) end
    if not model.name or model.name == "" then return end
    return completeModel(model, readable(data.id))
end

local function badges(model)
    local list = {}
    if model.level then list[#list + 1] = { "Level " .. model.level, model.color } end
    for _, tag in ipairs(model.tags) do list[#list + 1] = { tag, PARCHMENT } end
    if model.completed then
        list[#list + 1] = { "Completed", DONE_COLOR }
    elseif model.failed then
        list[#list + 1] = { "Failed", FAILED_COLOR }
    elseif model.ready then
        list[#list + 1] = { "Ready to turn in", DONE_COLOR }
    elseif model.active then
        list[#list + 1] = { "In progress", QUEST_GOLD }
    end
    if model.repeatable then list[#list + 1] = { "Repeatable", REPEAT_COLOR } end
    return list
end

-- The description reads as the quest giver's words.
local function quoted(model)
    local list = {}
    for index, text in ipairs(model.description) do
        if index == 1 then text = "\226\128\156" .. text end
        if index == #model.description then text = text .. "\226\128\157" end
        list[#list + 1] = text
    end
    return list
end

local function progressOf(row)
    local have, need = (row.right or ""):match("(%d+)%s*/%s*(%d+)")
    if have then return tonumber(have), tonumber(need) end
end

local function fitWidth(panel, model, styles, paragraphs)
    local indent = model.icon and TEXT_INDENT or 0
    local need = ui.measureStyled(panel, model.name, styles.questTitle) + indent
    local function consider(width) if width > need then need = width end end
    if model.zone then consider(ui.measureStyled(panel, model.zone, styles.questInfo) + indent) end
    local list = badges(model)
    if #list > 0 then consider(ui.pillsWidth(panel, list, styles.questBadges) + indent) end
    for _, text in ipairs(paragraphs) do
        consider(math.min(ui.measureStyled(panel, text, styles.questText), ui.PROSE_WIDTH))
    end
    for _, row in ipairs(model.objectives) do
        consider(ui.rowWidth(panel, row, styles.questObjectives) + OBJECTIVE_INDENT)
    end
    for _, row in ipairs(model.extras) do
        local width = ui.rowWidth(panel, row, styles.extras)
        if not row.right or row.right == "" then width = math.min(width, ui.PROSE_WIDTH) end
        consider(width)
    end
    return math.max(ui.MIN_WIDTH, math.min(ui.MAX_WIDTH, math.ceil(need + 2 * PAD)))
end

local function checkbox(panel, y, done, size)
    local top = y + math.max(0, math.floor((size - CHECK_SIZE) / 2)) + 1
    local border = ui.acquireTexture(panel, nil, 0)
    border:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -top)
    border:SetSize(CHECK_SIZE, CHECK_SIZE)
    local edge = done and DONE_COLOR or PARCHMENT
    border:SetVertexColor(edge[1] * .7, edge[2] * .7, edge[3] * .7, .9)
    local fill = ui.acquireTexture(panel, nil, 1)
    fill:SetPoint("TOPLEFT", border, "TOPLEFT", 1, -1)
    fill:SetSize(CHECK_SIZE - 2, CHECK_SIZE - 2)
    if done then
        fill:SetVertexColor(DONE_COLOR[1] * .45, DONE_COLOR[2] * .45, DONE_COLOR[3] * .45, 1)
        local mark = ui.acquireTexture(panel, "Interface\\Buttons\\UI-CheckBox-Check", 2)
        mark:SetPoint("CENTER", border, "CENTER", 1, 1)
        mark:SetSize(CHECK_SIZE + 6, CHECK_SIZE + 6)
        mark:SetVertexColor(1, 1, 1, 1)
    else
        fill:SetVertexColor(.08, .07, .06, 1)
    end
end

local function progressBar(panel, y, have, need, done)
    local width = panel.width - 2 * PAD - OBJECTIVE_INDENT
    local track = ui.acquireTexture(panel, nil, 0)
    track:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + OBJECTIVE_INDENT, -y)
    track:SetSize(width, BAR_HEIGHT)
    track:SetVertexColor(.16, .14, .13, 1)
    if have > 0 then
        local color = done and DONE_COLOR or QUEST_GOLD
        local fill = ui.acquireTexture(panel, nil, 1)
        fill:SetPoint("TOPLEFT", track, "TOPLEFT")
        fill:SetSize(math.max(1, width * math.min(1, have / need)), BAR_HEIGHT)
        fill:SetVertexColor(color[1] * .8, color[2] * .8, color[3] * .8, 1)
    end
    return y + BAR_HEIGHT + 6
end

local function renderQuest(panel, tooltip, model)
    panel:Show()
    ui.clearPool(panel)
    local styles = {}
    for _, key in ipairs(PARTS) do styles[key] = ui.styleOf(key) end
    if not ns.option("iconQuests") then model.icon = nil end
    local paragraphs = quoted(model)
    panel.width = fitWidth(panel, model, styles, paragraphs)
    panel:SetWidth(panel.width)
    local headerMin = ui.drawChrome(panel, tooltip, {
        kind = "quest",
        color = PARCHMENT,
        tint = PARCHMENT,
        strength = TINT_STRENGTH,
        icon = model.icon,
        iconSize = ICON_SIZE,
    })

    local inner = panel.width - 2 * PAD
    local indent = model.icon and TEXT_INDENT or 0
    local leftIndent = ui.headerInsets(indent)
    local y = ui.TITLE_TOP
    y = y + ui.styledAt(panel, model.name, PAD + leftIndent, y, inner - indent, styles.questTitle,
        TITLE_COLOR) + 3
    if model.zone then
        y = y + ui.styledAt(panel, model.zone, PAD + leftIndent, y, inner - indent, styles.questInfo,
            ZONE_COLOR) + 3
    end
    local list = badges(model)
    if #list > 0 then y = ui.drawPills(panel, list, PAD + leftIndent, y + 3, styles.questBadges) + 4 end
    y = math.max(y + 6, headerMin)
    panel.header:SetHeight(y - panel.inset)
    panel.footer:SetHeight(0)

    local sectioned = false
    if #paragraphs > 0 then
        y = ui.divider(panel, y, ui.GOLD_RULE)
        for _, text in ipairs(paragraphs) do
            y = ui.drawRow(panel, { left = text }, y, styles.questText, ui.FLAVOR_GOLD, 0, 5)
        end
        sectioned = true
    end
    if #model.objectives > 0 then
        y = ui.caption(panel, y + (sectioned and 4 or 0), "Objectives", styles.questCaption, CAPTION_COLOR)
        for _, row in ipairs(model.objectives) do
            checkbox(panel, y, row.completed, styles.questObjectives.size)
            local have, need = progressOf(row)
            local bar = need and need > 1
            y = ui.drawRow(panel, row, y, styles.questObjectives,
                row.completed and DONE_COLOR or OBJECTIVE_COLOR, OBJECTIVE_INDENT, bar and 3 or 5)
            if bar then y = progressBar(panel, y, have, need, row.completed) end
        end
        sectioned = true
    end
    if #model.extras > 0 then
        if sectioned then
            y = ui.rule(panel, y, { .50, .50, .54 }, 6)
        else
            y = y + 4
        end
        y = ui.drawGroup(panel, model.extras, y, styles.extras, ui.EXTRA_COLOR, 0, 2)
    end
    ui.finishPanel(panel, tooltip, y)
end

ui.questModel = function(fields)
    for _, list in ipairs({ "description", "objectives", "tags", "extras" }) do
        fields[list] = fields[list] or {}
    end
    return completeModel(fields)
end
ui.registerKind(QUEST, { read = readQuest, render = renderQuest, key = questKey, option = "questPanels" })

local function linkedQuest(link)
    if type(link) ~= "string" then return end
    local id = link:match("^questie:(%d+)") or link:match("^quest:(%d+)")
    return id and tonumber(id)
end

local function hasQuestData(tooltip)
    local ok, data = pcall(tooltip.GetTooltipData, tooltip)
    return ok and type(data) == "table" and not isSecret(data.type) and data.type == QUEST
end

-- Questie fills the tooltip with lines itself, for its own links and the game's.
local function drawQuestie(tooltip, id)
    if tooltip:IsShown() and tooltip:NumLines() > 0 and not hasQuestData(tooltip) then
        ui.renderLines(tooltip, QUEST, id)
    end
end

hooksecurefunc("SetItemRef", function(link)
    local id = linkedQuest(link)
    if id then drawQuestie(ItemRefTooltip, id) end
end)

-- Questie may hook the chat frames before or after this file, so its Show is
-- caught too.
local hovered
hooksecurefunc(GameTooltip, "Show", function(tooltip)
    if hovered and not hovered.drawing and tooltip:GetOwner() == hovered.frame then
        hovered.drawing = true
        drawQuestie(tooltip, hovered.id)
        hovered.drawing = false
    end
end)
for index = 1, NUM_CHAT_WINDOWS or 10 do
    local frame = _G["ChatFrame" .. index]
    if frame then
        frame:HookScript("OnHyperlinkEnter", function(self, link)
            local id = type(link) == "string" and link:match("^questie:(%d+)")
            hovered = id and { frame = self, id = tonumber(id) } or nil
            if hovered and GameTooltip:GetOwner() == self then drawQuestie(GameTooltip, hovered.id) end
        end)
        frame:HookScript("OnHyperlinkLeave", function() hovered = nil end)
    end
end
