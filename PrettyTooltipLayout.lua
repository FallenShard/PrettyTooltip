-- Optional display layer. The game's tooltip stays intact underneath and is
-- shown whenever ALT is held or a line cannot safely be read.
if GetLocale() ~= "enUS" or not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then
    return
end

local isSecret = issecretvalue or function() return false end
local ITEM = Enum.TooltipDataType.Item
local LINE = Enum.TooltipDataLineType
local ART = "Interface\\AddOns\\PrettyTooltip\\art\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local BODY_FONT = "Fonts\\FRIZQT__.TTF"
local TITLE_FONT = "Fonts\\MORPHEUS.TTF"
local WIDTH = 408
local PAD = 19
local QUALITY = {
    [0] = { .62, .62, .62 },
    [1] = { .77, .77, .77 },
    [2] = { .30, .82, .30 },
    [3] = { .32, .59, .98 },
    [4] = { .72, .40, .94 },
    [5] = { 1.00, .57, .22 },
}
local QUALITY_NAME = {
    [2] = "Uncommon",
    [3] = "Rare",
    [4] = "Epic",
    [5] = "Legendary",
}
local ARMOR_SLOTS = {
    Head = true, Shoulder = true, Chest = true, Wrist = true,
    Hands = true, Waist = true, Legs = true, Feet = true,
}
local panels = setmetatable({}, { __mode = "k" })

local function safeText(value)
    if isSecret(value) then return nil end
    if value == nil then return "" end
    if type(value) ~= "string" then return nil end
    return value
end

local function getItemInfo(tooltip, data)
    if tooltip.GetItem then
        local ok, _, link = pcall(tooltip.GetItem, tooltip)
        if ok and not isSecret(link) and link then return link end
    end
    if not isSecret(data.hyperlink) and data.hyperlink then return data.hyperlink end
    if not isSecret(data.id) then return data.id end
end

local function getQuality(itemInfo, data)
    if itemInfo and C_Item and C_Item.GetItemInfo then
        local ok, _, _, quality = pcall(C_Item.GetItemInfo, itemInfo)
        if ok and not isSecret(quality) and type(quality) == "number" then
            return quality
        end
    end
    if not isSecret(data.quality) and type(data.quality) == "number" then
        return data.quality
    end
    return 1
end

local function getIcon(itemInfo)
    if not (itemInfo and C_Item and C_Item.GetItemIconByID) then return end
    local ok, icon = pcall(C_Item.GetItemIconByID, itemInfo)
    if ok and not isSecret(icon) then return icon end
end

local function getLevel(itemInfo)
    if not (itemInfo and C_Item and C_Item.GetDetailedItemLevelInfo) then return end
    local ok, level = pcall(C_Item.GetDetailedItemLevelInfo, itemInfo)
    if ok and not isSecret(level) and type(level) == "number" and level > 0 then
        return level
    end
end

local function add(list, left, right)
    list[#list + 1] = { left = left, right = right }
end

local function readModel(tooltip, data)
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local itemInfo = getItemInfo(tooltip, data)
    local model = {
        quality = getQuality(itemInfo, data),
        icon = getIcon(itemInfo),
        level = getLevel(itemInfo),
        header = {},
        armor = {},
        primary = {},
        magic = {},
        effects = {},
        setItems = {},
        setBonuses = {},
        extras = {},
        footerLeft = {},
        footerRight = {},
        lineIndices = {},
    }
    local inSet, setTotal = false, 0

    for _, line in ipairs(data.lines) do
        if isSecret(line) or not line or isSecret(line.type) or isSecret(line.lineIndex) then
            return
        end
        if line.lineIndex then
        local left, right = safeText(line.leftText), safeText(line.rightText)
        if not left or not right then return end
        local lineType = line.type
        if line.lineIndex then model.lineIndices[line.lineIndex] = true end
        local trimmed = left:match("^%s*(.-)%s*$")
        if isSecret(line.prettyTooltipDisplay) or isSecret(line.prettyTooltipOriginal) then return end
        local displayed = line.prettyTooltipDisplay or left

        if lineType == LINE.ItemName then
            model.name = left
        elseif lineType == LINE.ItemLevel then
            local level = left:match("(%d+)")
            if level then model.level = tonumber(level) end
        elseif lineType == LINE.EquipSlot then
            if ARMOR_SLOTS[left] and right ~= "" and QUALITY_NAME[model.quality] then
                model.slot = QUALITY_NAME[model.quality] .. " " .. right .. " " .. left
            else
                model.slot = right ~= "" and (left .. " \194\183 " .. right) or left
            end
        elseif lineType == LINE.ItemBinding or trimmed:match("^Binds ")
            or trimmed == "Soulbound" or trimmed:match("^Unique") then
            add(model.header, left, right)
        elseif trimmed ~= "" then
            local setName, count, total = trimmed:match("^(.-) %((%d+)/(%d+)%)$")
            if setName and not model.setName then
                model.setName, model.setCount = setName, count .. "/" .. total
                inSet, setTotal = true, tonumber(total)
            elseif lineType == LINE.SellPrice then
                add(model.footerRight, left, right)
            elseif trimmed:match("^Requires ") then
                add(model.footerRight, left, right)
            elseif trimmed:match("^Classes:") or trimmed:match("^You haven't collected")
                or trimmed:match("^Appearance ") then
                add(model.footerLeft, left, right)
            elseif inSet and trimmed:match("^%(%d+%) Set:") then
                add(model.setBonuses, left, right)
            elseif inSet and #model.setItems < setTotal
                and right == "" and trimmed:match("^[%a'%- ]+$") then
                add(model.setItems, trimmed, right)
            elseif right:match("^Speed [%d%.]+$") and trimmed:match("^%d+%s*%-%s*%d+ Damage$") then
                model.weaponDamage, model.weaponSpeed = left, right
            elseif trimmed:match("^%([%d%.]+ damage per second%)$") then
                model.weaponDps = trimmed:match("^%(([%d%.]+) damage per second%)$")
            elseif trimmed:match("^%d+ Armor$") then
                add(model.armor, left, right)
            elseif line.prettyTooltipOriginal or trimmed:match("^%+[%d%.]+") then
                local group = displayed:find("Spell", 1, true)
                    or displayed:find("Mana", 1, true)
                    or displayed:find("Healing", 1, true)
                add(group and model.magic or model.primary, displayed, right)
            elseif trimmed:match("^Equip:") or trimmed:match("^Use:") then
                add(model.effects, left, right)
            else
                add(model.extras, left, right)
            end
        end
        end
    end

    if not model.name or model.name == "" then return end
    -- Rows appended directly by other addons are absent from data.lines.
    for index = 1, tooltip:NumLines() do
        if not model.lineIndices[index] then
            local leftFont = tooltip:GetLeftLine(index)
            local name = tooltip:GetName()
            local rightFont = tooltip.GetRightLine and tooltip:GetRightLine(index)
                or (name and _G[name .. "TextRight" .. index])
            local left = leftFont and safeText(leftFont:GetText()) or ""
            local right = rightFont and safeText(rightFont:GetText()) or ""
            if not left or not right then return end
            if left ~= "" or right ~= "" then add(model.extras, left, right) end
        end
    end
    return model
end

local function makeTexture(parent, layer, path)
    local tex = parent:CreateTexture(nil, layer)
    tex:SetTexture(path or WHITE)
    return tex
end

local function getPanel(tooltip)
    local panel = panels[tooltip]
    if panel then return panel end
    panel = CreateFrame("Frame", nil, UIParent)
    panel:SetFrameStrata("TOOLTIP")
    panel:SetWidth(WIDTH)
    panel:SetClampedToScreen(true)
    panel:Hide()
    panel.pool, panel.used = {}, 0
    panel.texturePool, panel.texturesUsed = {}, 0
    panel.background = makeTexture(panel, "BACKGROUND")
    panel.background:SetAllPoints()
    panel.background:SetVertexColor(.035, .025, .034, .985)
    panel.header = makeTexture(panel, "BORDER")
    panel.header:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -1)
    panel.header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -1)
    panel.footer = makeTexture(panel, "BORDER")
    panel.footer:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 1, 1)
    panel.footer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -1, 1)
    panel.footer:SetVertexColor(.10, .075, .08, .95)
    panel.icon = makeTexture(panel, "OVERLAY")
    panel.icon:SetSize(43, 43)
    panel.icon:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -19, -21)
    panel.iconBorder = makeTexture(panel, "OVERLAY")
    panel.iconBorder:SetSize(45, 45)
    panel.iconBorder:SetPoint("CENTER", panel.icon, "CENTER")
    panel.iconBorder:SetVertexColor(.55, .45, .37, .9)
    panel.iconBorder:SetDrawLayer("OVERLAY", 1)
    panel.icon:SetDrawLayer("OVERLAY", 2)
    panel.edges = {}
    for i = 1, 4 do panel.edges[i] = makeTexture(panel, "OVERLAY") end
    panel.edges[1]:SetPoint("TOPLEFT", panel, "TOPLEFT")
    panel.edges[1]:SetPoint("TOPRIGHT", panel, "TOPRIGHT")
    panel.edges[1]:SetHeight(2)
    panel.edges[2]:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT")
    panel.edges[2]:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT")
    panel.edges[2]:SetHeight(1)
    panel.edges[3]:SetPoint("TOPLEFT", panel, "TOPLEFT")
    panel.edges[3]:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT")
    panel.edges[3]:SetWidth(1)
    panel.edges[4]:SetPoint("TOPRIGHT", panel, "TOPRIGHT")
    panel.edges[4]:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT")
    panel.edges[4]:SetWidth(1)
    panel.corners = {}
    for i = 1, 4 do
        local corner = makeTexture(panel, "OVERLAY", ART .. "quality-corner")
        corner:SetSize(38, 38)
        panel.corners[i] = corner
    end
    panel.corners[1]:SetPoint("TOPLEFT", panel, "TOPLEFT", 3, -3)
    panel.corners[2]:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
    panel.corners[2]:SetTexCoord(1, 0, 0, 1)
    panel.corners[3]:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 3, 3)
    panel.corners[3]:SetTexCoord(0, 1, 1, 0)
    panel.corners[4]:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -3, 3)
    panel.corners[4]:SetTexCoord(1, 0, 1, 0)
    panels[tooltip] = panel
    return panel
end

local function clearPool(panel)
    for _, font in ipairs(panel.pool) do font:Hide() end
    for _, tex in ipairs(panel.texturePool) do tex:Hide() end
    panel.used, panel.texturesUsed = 0, 0
end

local function textAt(panel, content, x, y, width, size, color, fontPath, align)
    panel.used = panel.used + 1
    local font = panel.pool[panel.used]
    if not font then
        font = panel:CreateFontString(nil, "OVERLAY")
        panel.pool[panel.used] = font
    end
    font:ClearAllPoints()
    font:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -y)
    font:SetWidth(width)
    font:SetFont(fontPath or BODY_FONT, size)
    font:SetJustifyH(align or "LEFT")
    font:SetJustifyV("TOP")
    font:SetTextColor(color[1], color[2], color[3])
    font:SetText(content)
    font:Show()
    return math.max(size + 2, font:GetStringHeight() or 0)
end

local function drawRow(panel, row, y, size, color, indent)
    local left = row.left
    local right = row.right
    indent = indent or 0
    local w = WIDTH - 2 * PAD - indent
    if right and right ~= "" then
        local leftHeight = textAt(panel, left, PAD + indent, y, w * .72, size, color)
        local rightHeight = textAt(panel, right, WIDTH - PAD - w * .27, y,
            w * .27, size, color, nil, "RIGHT")
        return y + math.max(leftHeight, rightHeight) + 3
    end
    return y + textAt(panel, left, PAD + indent, y, w, size, color) + 3
end

local function divider(panel, y, color)
    panel.texturesUsed = panel.texturesUsed + 1
    local left = panel.texturePool[panel.texturesUsed]
    if not left then
        left = makeTexture(panel, "OVERLAY")
        panel.texturePool[panel.texturesUsed] = left
    end
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y - 5)
    left:SetSize((WIDTH - 2 * PAD - 18) / 2, 1)
    left:SetVertexColor(color[1] * .52, color[2] * .52, color[3] * .52, .8)
    left:Show()
    panel.texturesUsed = panel.texturesUsed + 1
    local right = panel.texturePool[panel.texturesUsed]
    if not right then
        right = makeTexture(panel, "OVERLAY")
        panel.texturePool[panel.texturesUsed] = right
    end
    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -y - 5)
    right:SetSize((WIDTH - 2 * PAD - 18) / 2, 1)
    right:SetVertexColor(color[1] * .52, color[2] * .52, color[3] * .52, .8)
    right:Show()
    panel.texturesUsed = panel.texturesUsed + 1
    local center = panel.texturePool[panel.texturesUsed]
    if not center then
        center = makeTexture(panel, "OVERLAY", ART .. "stat-marker")
        panel.texturePool[panel.texturesUsed] = center
    end
    center:ClearAllPoints()
    center:SetPoint("TOP", panel, "TOP", 0, -y)
    center:SetSize(10, 10)
    center:SetVertexColor(.9, .76, .48, .9)
    center:Show()
    return y + 18
end

local function drawGroup(panel, list, y, size, color, indent)
    for _, row in ipairs(list) do y = drawRow(panel, row, y, size, color, indent) end
    return y
end

local function render(panel, tooltip, model)
    panel:Show()
    clearPool(panel)
    local quality = QUALITY[model.quality] or QUALITY[1]
    panel:SetFrameLevel(tooltip:GetFrameLevel() + 5)
    panel.header:SetGradient("VERTICAL",
        CreateColor(quality[1] * .12, quality[2] * .12, quality[3] * .12, .96),
        CreateColor(quality[1] * .38, quality[2] * .38, quality[3] * .38, .96))
    for index, edge in ipairs(panel.edges) do
        local strength = index == 1 and .8 or .36
        edge:SetVertexColor(quality[1] * strength, quality[2] * strength,
            quality[3] * strength, .95)
    end
    for _, corner in ipairs(panel.corners) do
        corner:SetVertexColor(
            quality[1] * .65 + .75 * .35,
            quality[2] * .65 + .59 * .35,
            quality[3] * .65 + .31 * .35,
            model.quality < 2 and .52 or .76)
        corner:Show()
    end
    panel.iconBorder:SetVertexColor(quality[1], quality[2], quality[3], .85)
    if model.icon then
        panel.icon:SetTexture(model.icon)
        panel.icon:Show()
        panel.iconBorder:Show()
    else
        panel.icon:Hide()
        panel.iconBorder:Hide()
    end

    local y = 19
    local title = model.name:find("|", 1, true) and model.name or model.name:upper()
    y = y + textAt(panel, title, PAD, y, WIDTH - 2 * PAD - 63,
        19, quality, TITLE_FONT) + 4
    if model.slot and model.slot ~= "" then
        y = y + textAt(panel, model.slot, PAD, y, WIDTH - 2 * PAD - 60,
            13, quality) + 4
    end
    if model.level then
        y = y + textAt(panel, model.level .. " Item Level", PAD, y,
            WIDTH - 2 * PAD, 12, { .88, .81, .68 }) + 3
    end
    y = drawGroup(panel, model.header, y, 12, { .78, .72, .63 })
    y = y + 6
    panel.header:SetHeight(y)
    y = divider(panel, y, { .78, .59, .32 })
    if model.weaponDps then
        y = y + textAt(panel, model.weaponDps .. " Damage per Second", PAD, y,
            WIDTH - 2 * PAD, 18, { .93, .87, .75 }) + 5
    end
    if model.weaponDamage then
        local secondary = model.weaponDamage
        if model.weaponSpeed then secondary = secondary .. "  \194\183  " .. model.weaponSpeed end
        y = y + textAt(panel, secondary, PAD + 7, y, WIDTH - 2 * PAD - 7,
            12, { .71, .72, .73 }) + 7
    end
    y = drawGroup(panel, model.armor, y, 16, { .93, .87, .75 })
    if #model.armor > 0 then y = y + 5 end
    y = drawGroup(panel, model.primary, y, 13, { .90, .85, .74 })
    if #model.magic > 0 and #model.primary > 0 then
        y = divider(panel, y + 3, { .56, .54, .74 })
    end
    y = drawGroup(panel, model.magic, y, 13, { .73, .77, 1 })
    if #model.effects > 0 then y = y + 5 end
    y = drawGroup(panel, model.effects, y, 13, { .48, .88, .48 })

    if model.setName then
        y = divider(panel, y + 11, { .78, .59, .32 })
        local setTitle = model.setName:upper()
        textAt(panel, setTitle, PAD, y, WIDTH - 2 * PAD - 45, 15,
            { 1, .76, .18 }, TITLE_FONT)
        textAt(panel, model.setCount or "", WIDTH - PAD - 42, y, 42, 12,
            { 1, .76, .18 }, nil, "RIGHT")
        y = y + 24
        for _, row in ipairs(model.setItems) do
            y = drawRow(panel, { left = "|cff756C60-  |r" .. row.left, right = row.right },
                y, 12, { .61, .58, .54 }, 5)
        end
        if #model.setBonuses > 0 then y = y + 7 end
        y = drawGroup(panel, model.setBonuses, y, 12, { .68, .65, .57 }, 3)
    end

    if #model.extras > 0 then
        y = divider(panel, y + 9, { .53, .53, .57 })
        y = y + textAt(panel, "ADDITIONAL DETAILS", PAD, y,
            WIDTH - 2 * PAD, 11, { .68, .70, .75 }) + 5
        y = drawGroup(panel, model.extras, y, 11, { .76, .75, .75 })
    end

    if #model.footerLeft > 0 or #model.footerRight > 0 then
        y = y + 9
        local footerStart = y
        local rows = math.max(#model.footerLeft, #model.footerRight)
        for index = 1, rows do
            local left = model.footerLeft[index]
            local right = model.footerRight[index]
            local h1, h2 = 0, 0
            if left then
                h1 = textAt(panel, left.left, PAD, y, (WIDTH - 2 * PAD) * .53,
                    11, { .82, .78, .71 })
            end
            if right then
                local content = right.left
                if right.right ~= "" then content = content .. " " .. right.right end
                h2 = textAt(panel, content, PAD + (WIDTH - 2 * PAD) * .55, y,
                    (WIDTH - 2 * PAD) * .45, 11,
                    content:match("^Requires") and { 1, .34, .28 } or { .88, .78, .60 },
                    nil, "RIGHT")
            end
            y = y + math.max(h1, h2, 13) + 4
        end
        panel.footer:SetHeight(y - footerStart + 23)
    else
        panel.footer:SetHeight(0)
    end
    panel:SetHeight(y + 17)
    panel:ClearAllPoints()
    local right = tooltip:GetRight() or 0
    local top = tooltip:GetTop() or 0
    local alignRight = right > UIParent:GetWidth() * .62
    local alignBottom = top < panel:GetHeight()
    local point = (alignBottom and "BOTTOM" or "TOP")
        .. (alignRight and "RIGHT" or "LEFT")
    panel:SetPoint(point, tooltip, point)
    panel:Show()
end

local function restoreNative(tooltip)
    local panel = panels[tooltip]
    if not panel then return end
    panel.restorePending = false
    panel:Hide()
    if panel.nativeAlpha then
        tooltip:SetAlpha(panel.nativeAlpha)
        panel.nativeAlpha = nil
    end
end

local function update(tooltip, data)
    local panel = getPanel(tooltip)
    if IsAltKeyDown() then restoreNative(tooltip); return end
    local ok, model = pcall(readModel, tooltip, data)
    if not ok or not model then restoreNative(tooltip); return end
    if not panel.nativeAlpha then panel.nativeAlpha = tooltip:GetAlpha() end
    local rendered = pcall(render, panel, tooltip, model)
    if not rendered then restoreNative(tooltip); return end
    panel.data = data
    panel.itemKey = getItemInfo(tooltip, data)
    panel.lineCount = tooltip:NumLines()
    tooltip:SetAlpha(0)
end

-- Some tooltip owners clear or briefly hide the tooltip while refreshing the
-- same item. Keep the previous panel for that frame, and only tear it down if
-- no new item post-call replaces it.
local function scheduleRestore(tooltip)
    local panel = panels[tooltip]
    if not panel then return end
    panel.restorePending = true
    panel.refreshToken = (panel.refreshToken or 0) + 1
    local token = panel.refreshToken
    C_Timer.After(0, function()
        if panel.refreshToken == token and panel.restorePending then
            restoreNative(tooltip)
        end
    end)
end

TooltipDataProcessor.AddTooltipPostCall(ITEM, function(tooltip, data)
    local panel = getPanel(tooltip)
    local previousKey = panel.itemKey
    local itemKey = getItemInfo(tooltip, data)
    panel.data = data
    panel.refreshToken = (panel.refreshToken or 0) + 1
    local token = panel.refreshToken
    panel.restorePending = false
    if not panel.hooked then
        tooltip:HookScript("OnHide", scheduleRestore)
        tooltip:HookScript("OnTooltipCleared", scheduleRestore)
        panel.hooked = true
        panel:SetScript("OnUpdate", function(self, elapsed)
            if self.nativeAlpha and tooltip:GetAlpha() ~= 0 then
                tooltip:SetAlpha(0)
            end
            self.elapsed = (self.elapsed or 0) + elapsed
            if self.elapsed < .25 then return end
            self.elapsed = 0
            if tooltip:IsShown() and self.data and tooltip:NumLines() ~= self.lineCount then
                C_Timer.After(0, function()
                    if tooltip:IsShown() and tooltip:IsTooltipType(ITEM)
                        and self.data and tooltip:NumLines() ~= self.lineCount then
                        update(tooltip, self.data)
                    end
                end)
            end
        end)
    end
    if IsAltKeyDown() then
        restoreNative(tooltip)
        return
    end
    -- The first render shows the new item promptly. On refresh, retain the
    -- complete old panel until other addons have appended their rows.
    if not panel:IsShown() or (itemKey and itemKey ~= previousKey) then
        update(tooltip, data)
    else
        if not panel.nativeAlpha then panel.nativeAlpha = tooltip:GetAlpha() end
        tooltip:SetAlpha(0)
    end
    C_Timer.After(0, function()
        if panel.refreshToken == token and tooltip:IsShown()
            and tooltip:IsTooltipType(ITEM) then
            update(tooltip, data)
        end
    end)
end)

local modifier = CreateFrame("Frame")
modifier:RegisterEvent("MODIFIER_STATE_CHANGED")
modifier:SetScript("OnEvent", function(_, _, key)
    if key ~= "LALT" and key ~= "RALT" then return end
    for tooltip, panel in pairs(panels) do
        if tooltip:IsShown() and tooltip:IsTooltipType(ITEM) then
            if IsAltKeyDown() then
                restoreNative(tooltip)
            elseif panel.data then
                update(tooltip, panel.data)
            end
        end
    end
end)
