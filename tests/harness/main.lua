-- The harness's two entry points. fixture() runs one captured tooltip through
-- the addon as the game would: loads its files in the .toc's order, lets the
-- item rewrite change the data, reads it with its kind's reader, and renders
-- the model, returning the output text and the harness's notes. unit() runs
-- a file of checks against parts of the addon loaded on their own.
local main = {}

local function notesCollector()
    local notes, seen = {}, {}
    local function report(kind, message)
        local line = kind .. ": " .. message
        if not seen[line] then
            seen[line] = true
            notes[#notes + 1] = line
        end
    end
    return notes, report
end

-- Loads the named addon files into a fresh world and returns the namespace.
local function loadAddon(files, sources)
    local ns = {}
    for _, file in ipairs(files) do
        local chunk, problem = loadstring(sources[file], "@" .. file)
        if not chunk then error(problem, 0) end
        local ok, failure = xpcall(function() chunk("PrettyTooltip", ns) end, debug.traceback)
        if not ok then error("loading " .. file .. ": " .. failure, 0) end
    end
    return ns
end

local function number(value)
    if type(value) ~= "number" then return tostring(value) end
    if value == math.floor(value) then return string.format("%d", value) end
    return string.format("%.4g", value)
end

local function quote(text)
    return (string.format("%q", text):gsub("\\\n", "\\n"))
end

-- What a render drew: each shown font string and texture under the panel, in
-- the order they were made, with where they sit. Places relative to the
-- panel's top left read "at x,y", y counting down.
local function drawn(panel)
    local function name(object)
        if object == panel then return "panel" end
        if object == nil then return "parent" end
        return object._name or object._kind
    end
    local function place(object)
        local point = object._points[1]
        if not point then return "unplaced" end
        local anchor, relativeTo, relativePoint, x, y = point[1], point[2], point[3], point[4], point[5]
        if relativeTo == panel and anchor == "TOPLEFT" and relativePoint == "TOPLEFT" then
            return "at " .. number(x) .. "," .. number(-y)
        end
        return anchor .. " " .. name(relativeTo) .. " " .. relativePoint .. " " .. number(x) .. "," .. number(y)
    end
    local out = { "panel " .. number(panel._width) .. " x " .. number(panel._height) }
    local function walk(object)
        for _, child in ipairs(object._children) do
            -- The panel measures text in a string of its own, never drawn.
            if child._shown and child ~= panel.measure then
                local color = child._color
                local rgb = number(color[1]) .. "," .. number(color[2]) .. "," .. number(color[3])
                if child._kind == "FontString" and child._text and child._text ~= "" then
                    out[#out + 1] = "text " .. place(child) .. " w=" .. number(child._width)
                        .. " size=" .. number(child._font.size) .. " rgb=" .. rgb .. " " .. quote(child._text)
                elseif child._kind == "Texture" and child._texture ~= nil then
                    local texture = tostring(child._texture):gsub("^.*\\", "")
                    out[#out + 1] = "texture " .. place(child) .. " " .. number(child._width) .. "x"
                        .. number(child._height) .. " rgb=" .. rgb .. "," .. number(color[4]) .. " " .. texture
                end
                walk(child)
            end
        end
    end
    walk(panel)
    return table.concat(out, "\n")
end

-- The counts of one phase, largest first, as "name count" lines.
local function profileText(label, counts)
    local names = {}
    local total = 0
    for name, count in pairs(counts) do
        names[#names + 1] = name
        if not name:find(",") then total = total + count end
    end
    table.sort(names, function(a, b)
        if counts[a] ~= counts[b] then return counts[a] > counts[b] end
        return a < b
    end)
    local out = { string.format("%s: %d frame calls", label, total) }
    for _, name in ipairs(names) do out[#out + 1] = string.format("  %-28s %d", name, counts[name]) end
    return table.concat(out, "\n")
end

-- options.profile: also return what reading and rendering each cost.
function main.fixture(fixture, enums, files, sources, serialize, makeWorld, options)
    options = options or {}
    local profiles = {}
    local notes, report = notesCollector()
    local world = makeWorld(fixture, enums, report)
    local ns = loadAddon(files, sources)
    -- The saved variables arrive, as at login.
    for _, object in ipairs(world.objects) do
        if object._events and object._events.ADDON_LOADED and object._scripts.OnEvent then
            object._scripts.OnEvent(object, "ADDON_LOADED", "PrettyTooltip")
        end
    end

    local sections = {}
    local function run(label, tooltip, capture)
        local data = capture.data
        if not data then
            sections[#sections + 1] = "== " .. label .. "\n(filled by an addon with lines alone; not replayed yet)"
            return
        end
        -- The game gives each line its place on the tooltip as it draws them;
        -- lines the rewrite replaced get theirs back.
        local places = {}
        for index, line in ipairs(data.lines or {}) do places[index] = line.lineIndex end
        for _, preCall in ipairs(world.preCalls[data.type] or {}) do preCall(tooltip, data) end
        for index, line in ipairs(data.lines or {}) do
            if line.lineIndex == nil then line.lineIndex = places[index] end
        end
        local kind = ns.ui and ns.ui.kinds and ns.ui.kinds[data.type]
        if not kind then
            sections[#sections + 1] = "== " .. label .. "\n(no panel for this kind of tooltip)"
            return
        end
        if options.profile then world.counts = {} end
        local ok, model = xpcall(function() return kind.read(tooltip, data) end, debug.traceback)
        if not ok then error(label .. ": reading failed: " .. model, 0) end
        if options.profile then
            profiles[#profiles + 1] = profileText(label .. " read", world.counts)
            world.counts = nil
        end
        local text = { "== " .. label .. " model" }
        if not model then
            text[#text + 1] = "(none: the game's own tooltip shows instead)"
        else
            text[#text + 1] = serialize.dump(model)
            local anchor = CreateFrame("Frame", nil, UIParent)
            -- The panel is made on the first render; the profile times a later
            -- one, as the game draws again and again into the same panel.
            if options.profile then ns.ui.renderPreview(anchor, model, data.type) world.counts = {} end
            local rendered, panel = xpcall(function()
                return ns.ui.renderPreview(anchor, model, data.type)
            end, debug.traceback)
            if not rendered then error(label .. ": rendering failed: " .. panel, 0) end
            if options.profile then
                profiles[#profiles + 1] = profileText(label .. " render", world.counts)
                world.counts = nil
            end
            text[#text + 1] = "== " .. label .. " render"
            text[#text + 1] = drawn(panel)
        end
        sections[#sections + 1] = table.concat(text, "\n")
    end

    run("tooltip", world.main, fixture)
    for index, comparison in ipairs(world.comparisons) do
        run("comparison " .. index, comparison, fixture.comparisons[index])
    end
    return table.concat(sections, "\n\n") .. "\n", notes, table.concat(profiles, "\n")
end

-- Records each line of the addon's files that runs, into hits[source][line].
function main.track(hits)
    debug.sethook(function(_, line)
        local source = debug.getinfo(2, "S").source
        if source:sub(1, 1) == "@" then
            local lines = hits[source]
            if not lines then
                lines = {}
                hits[source] = lines
            end
            lines[line] = true
        end
    end, "l")
end

-- check(name, got, expected): got and expected are compared as dumped text.
function main.unit(testSource, testName, sources, serialize, makeWorld)
    local results = {}
    local notes, report = notesCollector()
    local test = {}
    -- Loads the named addon files with a world answering from fixture's calls.
    function test.load(files, fixture)
        makeWorld(fixture or {}, {}, report)
        return loadAddon(files, sources)
    end
    function test.check(name, got, expected)
        local gotText = type(got) == "table" and serialize.dump(got) or tostring(got)
        local expectedText = type(expected) == "table" and serialize.dump(expected) or tostring(expected)
        results[#results + 1] = { name = name, ok = gotText == expectedText, got = gotText, expected = expectedText }
    end
    local chunk, problem = loadstring(testSource, "@" .. testName)
    if not chunk then error(problem, 0) end
    local ok, failure = xpcall(function() chunk()(test) end, debug.traceback)
    if not ok then error(failure, 0) end
    return results, notes
end

return main
