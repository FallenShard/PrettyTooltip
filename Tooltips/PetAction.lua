-- Pet bar buttons as the spell panel: an ability is the spell the game nests
-- in its tooltip, a command or stance its name and description. The pet bar
-- adds autocast and the active command as badges.
local _, ns = ...
local ui = ns.ui
local TYPES = Enum and Enum.TooltipDataType
local PET, SPELL = TYPES and TYPES.PetAction, TYPES and TYPES.Spell
if not (ui and PET and SPELL and ui.renderView) then
    return
end

local tooltipData = ns.TooltipData
local isSecret, safeText = ns.util.isSecret, ns.util.safeText
local ON_COLOR = { .45, .85, .45 }
local OFF_COLOR = ns.Palette.roles.caption

local function nameOf(data)
    for _, line in ipairs(data.lines) do
        if isSecret(line) or type(line) ~= "table" or isSecret(line.lineIndex) then return end
        if line.lineIndex == 1 then return safeText(line.leftText) end
    end
end

-- Toggling autocast or switching stance leaves the lines alone.
local function petKey(_, data)
    if isSecret(data.lines) or type(data.lines) ~= "table" then return end
    local name = nameOf(data)
    if not name then return end
    local slot = ns.Game.petAction(name) or {}
    return name .. "\031" .. tostring(slot.autocast) .. "\031" .. tostring(slot.active)
end

local function readPet(tooltip, data, game)
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local spellType = ns.TooltipTypes[SPELL]
    local nested = tooltipData.nested(data)
    if nested and nested.type ~= SPELL then return end
    local model = spellType and spellType.read(tooltip, nested or data, game)
    if not model then return end
    local slot = game.petAction(model.name)
    if slot then
        model.icon = model.icon or slot.icon
        model.tags = {}
        if slot.autocast ~= nil then
            model.tags[1] = slot.autocast and { "Autocast", ON_COLOR } or { "Autocast off", OFF_COLOR }
        end
        if slot.active then model.tags[#model.tags + 1] = { "Active", ON_COLOR } end
    end
    return model
end

local function renderPet(panel, tooltip, model)
    ns.TooltipTypes[SPELL].render(panel, tooltip, model)
end

ui.defineTooltipType(PET, { read = readPet, render = renderPet, key = petKey, option = "petPanels" })
