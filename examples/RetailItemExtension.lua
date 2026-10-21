-- Illustrative stubs only: deliberately absent from PrettyTooltip.toc.
-- A future client TOC would load its real implementation after Tooltips/Item.lua
-- and before UI/Samples.lua, UI/Editor.lua, and PrettyTooltip.lua.
local _, ns = ...
local ITEM = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
local descriptor = ns.TooltipTypes and ns.TooltipTypes[ITEM]
if not descriptor then return end

descriptor.extension = {
    initModel = function(model)
        -- Private to this client, including on embedded items and samples.
        model.retail = {}
    end,

    readLine = function(_model, _line, _context)
        -- Retail parsing belongs here, for example:
        -- if this is an upgrade line then
        --     model.retail.upgrade = context.text
        --     return true -- skip the core's content classification
        -- end
        -- Raw line metadata can be secret; validate every field you inspect.
        return false -- no override: continue through the shared reader
    end,

    afterReadLine = function(_model, _line, _context)
        -- Decorate an agreed shared row field after the core classified it,
        -- or record Retail-only information under model.retail.
    end,

    afterRead = function(_model, _context)
        -- Derive Retail fields from the completed item. Embedded items finish
        -- before the root item; context.rootModel still identifies the root.
    end,

    extendView = function(view, model, context)
        local retail = model.retail
        if not (retail and retail.upgrade) then return end
        -- Example contribution using an existing shared style. A real Retail
        -- implementation would register its own upgrade style separately.
        local entry = { id = "retail.upgrade", text = retail.upgrade,
            style = context.styles.subtitle, color = { .90, .80, .55 }, gap = 4 }
        for index, header in ipairs(view.header) do
            if header.id == "slot" then
                table.insert(view.header, index + 1, entry)
                return
            end
        end
        -- Some items have no slot; the title is always the first header entry.
        table.insert(view.header, 2, entry)
    end,
}
