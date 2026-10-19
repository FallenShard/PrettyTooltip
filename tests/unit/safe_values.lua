-- Fail closed at the API boundary, including tables whose contents are
-- inaccessible even though the table reference itself is not secret.
return function(test)
    local ns, world = test.load({ "Core/Util.lua", "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua" })
    local util, game, secret, locked = ns.util, ns.Game, world.secret, world.secretTable
    test.check("secret text is rejected", util.safeText(secret), nil)
    test.check("secret numbers are rejected", util.number(secret), nil)
    test.check("an inaccessible table is rejected", util.readable(locked), nil)
    test.check("an inaccessible table is not an ordinary secret value", issecretvalue(locked), false)
    local calls = 0
    local function api() calls = calls + 1 return true end
    test.check("secret arguments are not sent to an API", util.call(api, secret), nil)
    test.check("inaccessible table arguments are not sent to an API", util.call(api, locked), nil)
    test.check("rejected arguments never called the API", calls, 0)
    test.check("API failures return nothing", util.call(function() error("unavailable") end), nil)
    test.check("secret API results are rejected", util.call(function() return secret end), nil)
    test.check("inaccessible API results are rejected", util.call(function() return locked end), nil)
    test.check("a secret secondary result rejects the call", util.call(function() return "name", secret end), nil)
    test.check("readable results retain nils", { util.call(function() return 1, nil, 3, 4 end) }, { 1, nil, 3, 4 })
    test.check("missing color components are rejected", util.rgb({ r = 1 }), nil)
    test.check("secret color components are rejected", util.rgb({ r = 1, g = secret, b = 0 }), nil)
    test.check("ordinary colors are retained", util.rgb({ r = 1, g = .5, b = 0 }), { 1, .5, 0 })

    C_QuestLog = { GetLogIndexForQuestID = function() return 1 end,
        GetInfo = function() return { level = secret } end }
    test.check("a secret nested quest level is not compared", game.questLevel(378), nil)
    C_QuestLog.GetInfo = function() return locked end
    test.check("an inaccessible quest result is not indexed", game.questLevel(378), nil)
    local atlas = { file = 123, width = 32, height = 32,
        leftTexCoord = 0, rightTexCoord = 1, topTexCoord = 0, bottomTexCoord = 1 }
    C_Texture = { GetAtlasInfo = function() return atlas end }
    test.check("ordinary atlas geometry is retained", game.atlasInfo("test").width, 32)
    atlas.rightTexCoord = secret
    test.check("secret atlas coordinates are rejected", game.atlasInfo("test"), nil)
    C_AddOns = { GetAddOnInfo = function() return secret end }
    test.check("secret addon metadata is not compared", game.addonInstalled("test"), false)
    test.check("a secret class key is not used to index colors", game.classColor(secret), nil)
    test.check("a secret difficulty input is not sent to the game", game.difficultyColor(secret), nil)
    local secretCalls = 0
    local function rejectSecret() secretCalls = secretCalls + 1 error("secret argument reached an API") end
    C_Item = { GetItemInfo = rejectSecret, GetItemInfoInstant = rejectSecret,
        RequestLoadItemDataByID = rejectSecret, IsEquippedItem = rejectSecret }
    C_UnitAuras = { GetAuraDataByIndex = rejectSecret }
    C_QuestLog.RequestLoadQuestByID = rejectSecret
    C_AddOns.GetAddOnInfo = rejectSecret
    game.itemInfo(secret)
    game.itemType(secret)
    game.loadItem(secret)
    game.isEquipped(secret)
    game.aura(secret, 1, "HELPFUL", false)
    game.questName(secret)
    game.addonInstalled(secret)
    test.check("direct-pcall API wrappers also reject secret inputs before calling", secretCalls, 0)

    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 2, -3)
    test.check("ordinary frames can be styled", util.canModify(frame), true)
    frame.IsForbidden = function() return true end
    frame.IsProtected = function() error("must not inspect a forbidden frame") end
    test.check("forbidden frames are rejected before other calls", util.canModify(frame), false)
    frame.IsForbidden = function() return false end
    frame.IsProtected = function() return true end
    test.check("protected frames are rejected even outside combat", util.canModify(frame), false)
    frame.IsProtected = function() return false end
    test.check("readable anchor snapshots retain all five components", util.framePoints(frame)[1][5], -3)
    frame.GetPoint = function() return "TOPLEFT", UIParent, "TOPLEFT", secret, 0 end
    test.check("secret anchor offsets cannot be cached for replay", util.framePoints(frame), nil)
    frame.IsForbidden = function() error("unavailable") end
    test.check("failed frame permission checks fail closed", util.canModify(frame), false)
    frame.IsForbidden = function() return nil end
    test.check("unknown frame permission results fail closed", util.canModify(frame), false)
    test.check("non-frame inputs are rejected", util.canModify("frame"), false)
    frame.IsForbidden = function() return false end
    frame.GetWidth = function() error("forbidden layout") end
    test.check("a layout restricted by its anchor fails closed", util.canModify(frame), false)
    frame.GetWidth = function() return secret end
    test.check("a size that is only hidden is not a restriction", util.canModify(frame), true)
end
