-- Quests as a panel.
local _, ns = ...
local ui = ns.ui
local QUEST = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Quest
if not (ui and QUEST and ui.renderView) then
    return
end

local util = ns.util
local tooltipData = ns.TooltipData
local colors = ns.Palette.roles
local isSecret, safeText, trim, readable = util.isSecret, util.safeText, util.trim, util.readable
local unformat, startsWith = util.unformat, util.startsWith
local LINE = Enum.TooltipDataLineType or {}
local pad = ui.pad
local ICON_SIZE = 38
local TINT_STRENGTH = .45
local CHECK_SIZE = 10
local OBJECTIVE_INDENT = CHECK_SIZE + 7
local QUEST_GOLD = colors.quest
local PARCHMENT = colors.flavor
local DONE_COLOR = colors.done
local FAILED_COLOR = { 1, .35, .30 }
local EXTRAS_RULE = { .50, .50, .54 }
local REPEAT_COLOR = { .45, .70, 1 }
local QUEST_ICON = "Interface\\Icons\\INV_Misc_Book_08"
local TAGS = ns.Locale.questTags
-- Questie writes the tag as a suffix on the level: "[27D] The Fury Runs Deep".
local SUFFIX_TAGS = {
    ["+"] = "Elite", ["++"] = "Legendary", D = "Dungeon", R = "Raid", H = "Heroic",
    G = "Group", S = "Scenario", W = "World event",
}
-- Questie's labeled rows, shown as label and value.
local LABELS = { "Started by", "Ended by", "Found in", "Completed on" }
local PARTS = { "questTitle", "questInfo", "questBadges", "questText", "questCaption", "questObjectives",
    "extras" }

local function questKey(_, data)
    return readable(data.id)
end

local function completeModel(model, questID, game)
    -- The quest log's tooltip names no level.
    if questID and not model.level then model.level = game.questLevel(questID) end
    if questID and not model.active then
        -- nil without a quest log to ask.
        local completed = game.questCompleted(questID)
        if completed ~= nil then
            model.completed = model.completed or completed
            model.active = model.active or game.onQuest(questID)
        end
    end
    -- A quest turned in has done all it asked, whatever its lines count.
    if model.completed then
        for _, objective in ipairs(model.objectives) do objective.completed = true end
    end
    model.color = game.difficultyColor(model.level) or QUEST_GOLD
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

-- Questie's words, in the language it is set to: its phrases, the separator
-- it puts after a label (" : " in French), and its labels.
local function questieWords(game)
    local words = {}
    for _, phrase in ipairs({ "You are on this quest", "Complete", "Failed", "You have completed this quest",
        "This quest is repeatable", "You have not done this quest", "Your progress", "Objectives", "Instance",
        ": " }) do
        words[phrase] = game.questieText(phrase)
    end
    words.labels = {}
    for index, label in ipairs(LABELS) do words.labels[index] = game.questieText(label) end
    return words
end

-- The text after a label, trimmed: "" for the label alone; nil without it.
local function afterLabel(text, label)
    if startsWith(text, label) then return trim(text:sub(#trim(label) + 1)) end
end

-- A row from the data or from a font string, read the same way.
local function readRow(model, row, state)
    local text = trim(util.uncolored(row.left))
    local right = trim(util.uncolored(row.right or ""))
    if text == "" and right == "" then return end
    if not model.name then return readTitle(model, text) end
    if state.label then
        model.extras[#model.extras + 1] = { left = state.label, right = text }
        state.label = nil
        return
    end
    local words = state.words
    local colon = words[": "]
    local label, value
    for _, name in ipairs(words.labels) do
        value = afterLabel(text, name .. colon)
        if value then label = name break end
    end
    local onQuest = afterLabel(text, words["You are on this quest"]) or afterLabel(text, QUEST_TOOLTIP_ACTIVE)
    local level = unformat(text, UNIT_LEVEL_TEMPLATE) or unformat(text, ITEM_MIN_LEVEL)
    if tonumber(level) and not model.level then
        model.level = tonumber(level)
    elseif TAGS[text] then
        model.tags[#model.tags + 1] = text
    elseif onQuest then
        model.active = true
        model.ready = onQuest:find("(" .. words.Complete .. ")", 1, true) ~= nil
        model.failed = onQuest:find("(" .. words.Failed .. ")", 1, true) ~= nil
    elseif startsWith(text, words["You have completed this quest"]) then
        model.completed = true
    elseif startsWith(text, words["This quest is repeatable"]) then
        model.repeatable = true
    -- The headings over the objectives; the panel has its own caption.
    elseif startsWith(text, words["You have not done this quest"]) or text == words.Objectives
        or text == OBJECTIVES_LABEL or text == QUEST_TOOLTIP_REQUIREMENTS or startsWith(text, words["Your progress"]) then
        return
    elseif afterLabel(text, words.Instance .. colon) then
        model.zone = afterLabel(text, words.Instance .. colon)
    elseif row.objective or text:match("^%-") or text:match("%d+%s*/%s*%d+%s*$") then
        local name = text:gsub("^%-%s*", "")
        local goal, progress = name:match("^(.-):%s*(%d+%s*/%s*%d+)$")
        -- The quest log puts the count first: "0/1 Head of Deepfury".
        if not goal then progress, goal = name:match("^(%d+%s*/%s*%d+)%s+(.+)$") end
        -- A quest not in the log names how many: "15 x Dark Iron Dwarf".
        if not goal then progress, goal = name:match("^(%d+) x (.+)$") end
        local objective = { left = goal or name, right = progress or right, completed = row.completed }
        objective.completed = objectiveDone(objective)
        model.objectives[#model.objectives + 1] = objective
    elseif label then
        if value ~= "" then
            model.extras[#model.extras + 1] = { left = label, right = value }
        else
            -- "Completed on:" puts its date on the next line.
            state.label = label
        end
    elseif isRed(codeColor(row.left) or row.textColor) then
        model.extras[#model.extras + 1] = { left = text, right = right, color = FAILED_COLOR }
    -- The description comes before the objectives; long lines after them are
    -- other addons'.
    elseif right == "" and #text >= 30 and #model.objectives == 0 and #model.extras == 0 then
        model.description[#model.description + 1] = text
    else
        -- A color code on the line outranks the font's color, dimmed as other addons' rows are.
        local code = codeColor(row.left)
        local color = code and { code[1] * .85, code[2] * .85, code[3] * .85 } or row.color
        model.extras[#model.extras + 1] = { left = text, right = right, color = color, rightColor = row.rightColor }
    end
end

local function readQuest(tooltip, data, game)
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local model = { description = {}, objectives = {}, tags = {}, extras = {} }
    local lineIndices, state = {}, { words = questieWords(game) }
    for _, line in ipairs(data.lines) do
        if isSecret(line) or not line or isSecret(line.type) or isSecret(line.lineIndex) then return end
        if line.lineIndex then
            local left, right = safeText(line.leftText), safeText(line.rightText)
            if not left or not right then return end
            lineIndices[line.lineIndex] = true
            local color = tooltipData.colorOf(line.leftColor)
            local completed = line.completed
            if isSecret(completed) then completed = nil end
            readRow(model, {
                left = left,
                right = right,
                color = color,
                textColor = color,
                rightColor = tooltipData.colorOf(line.rightColor),
                objective = LINE.QuestObjective and line.type == LINE.QuestObjective,
                completed = completed,
            }, state)
        end
    end
    local appended = tooltipData.appendedRows(tooltip, lineIndices)
    if not appended then return end
    for _, row in ipairs(appended) do readRow(model, row, state) end
    if not model.name or model.name == "" then return end
    return completeModel(model, readable(data.id), game)
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

local function checkbox(panel, y, done, size)
    local top = y + math.max(0, math.floor((size - CHECK_SIZE) / 2)) + 1
    local px = ui.pixel(panel)
    local border = ui.acquireTexture(panel, nil, 0)
    border:SetPoint("TOPLEFT", panel, "TOPLEFT", pad(), -ui.snap(panel, top))
    border:SetSize(CHECK_SIZE, CHECK_SIZE)
    local edge = done and DONE_COLOR or PARCHMENT
    if panel.parchment then edge = { .35, .21, .10 } end
    border:SetVertexColor(edge[1] * .7, edge[2] * .7, edge[3] * .7, .9)
    local fill = ui.acquireTexture(panel, nil, 1)
    fill:SetPoint("TOPLEFT", border, "TOPLEFT", px, -px)
    fill:SetSize(CHECK_SIZE - 2 * px, CHECK_SIZE - 2 * px)
    if done then
        fill:SetVertexColor(DONE_COLOR[1] * .45, DONE_COLOR[2] * .45, DONE_COLOR[3] * .45, 1)
        local mark = ui.acquireTexture(panel, "Interface\\Buttons\\UI-CheckBox-Check", 2)
        mark:SetPoint("CENTER", border, "CENTER", 1, 1)
        mark:SetSize(CHECK_SIZE + 6, CHECK_SIZE + 6)
        if panel.parchment then mark:SetVertexColor(.11, .085, .055, 1)
        else mark:SetVertexColor(1, 1, 1, 1) end
    else
        fill:SetVertexColor(.08, .07, .06, panel.parchment and 0 or 1)
    end
end

-- The objectives under their caption, each with a checkbox.
local function objectivesSection(model, styles, after)
    local style = styles.questObjectives
    return {
        kind = "custom",
        measure = function(panel)
            local need = 0
            for _, row in ipairs(model.objectives) do
                need = math.max(need, ui.rowWidth(panel, row, style) + OBJECTIVE_INDENT)
            end
            return need
        end,
        draw = function(panel, y)
            y = ui.caption(panel, y + (after and 4 or 0), "Objectives", styles.questCaption, colors.caption)
            for _, row in ipairs(model.objectives) do
                checkbox(panel, y, row.completed, style.size)
                y = ui.drawRow(panel, row, y, style, row.completed and DONE_COLOR or colors.objective,
                    OBJECTIVE_INDENT, 5)
            end
            return y
        end,
    }
end

-- What the panel shows, for Panel/Render.lua to draw.
local function questView(model)
    local styles = {}
    for _, key in ipairs(PARTS) do styles[key] = ui.styleOf(key) end
    local header = { { text = model.name, style = styles.questTitle, color = colors.title, gap = 3 } }
    if model.zone then header[#header + 1] = { text = model.zone, style = styles.questInfo, color = colors.detail, gap = 3 } end
    header[#header + 1] = { badges = badges(model), style = styles.questBadges, before = 3, gap = 4 }

    local sections = {}
    local paragraphs = quoted(model)
    if #paragraphs > 0 then
        sections[#sections + 1] = { separator = { divider = ui.GOLD_RULE }, kind = "prose", sentences = paragraphs,
            style = styles.questText, color = ui.FLAVOR_GOLD, gap = 5 }
    end
    if #model.objectives > 0 then
        sections[#sections + 1] = objectivesSection(model, styles, #sections > 0)
    end
    if #model.extras > 0 then
        sections[#sections + 1] = { separator = #sections > 0 and { rule = EXTRAS_RULE } or { space = 4 },
            kind = "rows", rows = model.extras, style = styles.extras, color = ui.EXTRA_COLOR, gap = 2, wrap = true }
    end
    return {
        tooltipType = "quest",
        color = PARCHMENT,
        tint = PARCHMENT,
        strength = TINT_STRENGTH,
        icon = ns.option("iconQuests") and model.icon or nil,
        iconSize = ICON_SIZE,
        header = header,
        sections = sections,
    }
end

local function renderQuest(panel, tooltip, model)
    ui.renderView(panel, tooltip, questView(model))
end

ui.questModel = function(fields)
    for _, list in ipairs({ "description", "objectives", "tags", "extras" }) do
        fields[list] = fields[list] or {}
    end
    return completeModel(fields, nil, ns.Game)
end
ui.defineTooltipType(QUEST, { read = readQuest, render = renderQuest, key = questKey, option = "questPanels" })

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
        if ns.Hooks then ns.Hooks.renderLines(tooltip, QUEST, id) end
    end
end

hooksecurefunc("SetItemRef", function(link)
    local id = linkedQuest(link)
    if id then drawQuestie(ItemRefTooltip, id) end
end)

-- The world map's quest log fills the tooltip with lines too, from its title
-- buttons; their quest is the button's.
local function questLogButton(owner)
    local contents = QuestScrollFrame and QuestScrollFrame.Contents
    return contents and owner and owner.GetParent and owner:GetParent() == contents
end

-- Questie may hook the chat frames before or after this file, so its Show is
-- caught too. Other addons add their lines to the quest log's and show it again.
local hovered
local drawing = false
hooksecurefunc(GameTooltip, "Show", function(tooltip)
    if drawing then return end
    local owner = tooltip:GetOwner()
    local id
    if hovered and owner == hovered.frame then
        id = hovered.id
    elseif questLogButton(owner) then
        id = readable(owner.questID)
    else
        return
    end
    drawing = true
    drawQuestie(tooltip, id)
    drawing = false
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
