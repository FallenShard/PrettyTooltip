-- Raid progression adapted from ElvUI_WindTools 4.23 (Progression.lua / Metadata.lua).
-- Blizzard achievement statistics; no Raider.IO dependency.
local _, ns = ...
local R = {}
ns.RaidProgress = R
local raids = {
    {id=3277, icon=8164250, fallback="The Tidebound Grotto", locale="Raid Short: Tidal Hollows", H={63615}, M={63616}, world=true},
    {id=3311, icon=8039391, fallback="The Venomous Abyss", locale="Raid Short: Venomous Abyss", H={63553,63568,63562,63535,63556,63565,63559,63539}, M={63536,63557,63569,63566,63560,63540,63554,63563}},
    {id=3262, icon=8280895, fallback="The Unbinding of Kith'ix", locale="Raid Short: Kishix Unbound", H={63841}, M={63842}},
}
local function safe(v) return not (issecretvalue and issecretvalue(v)) end
local function playerGuid()
    local ok, guid = pcall(UnitGUID, "player")
    return ok and safe(guid) and guid or nil
end
local cache = {}
local pending = {}
local waiting = false
local function stat(guid, id)
    local func = guid == playerGuid() and GetStatistic or GetComparisonStatistic
    if not func then return nil end
    local ok, value = pcall(func, id)
    if not ok or not safe(value) then return nil end
    return tonumber(value)
end
local function calculate(guid)
    local data = {}
    for i, raid in ipairs(raids) do
        local info = {}
        for _, key in ipairs({"H", "M"}) do
            local ids = raid[key]
            local killed, known = 0, 0
            for _, id in ipairs(ids) do
                local count = stat(guid, id)
                if count then
                    known = known + 1
                    if count > 0 then killed = killed + 1 end
                end
            end
            if known == #ids then info[key] = {killed, #ids, "history"}
            elseif known > 0 then info[key] = {killed, #ids, "partial"} end
        end
        data[i] = info
    end
    return data
end
local function weekly(data)
    if not GetNumSavedInstances or not GetSavedInstanceInfo then return end
    local ok, count = pcall(GetNumSavedInstances)
    if not ok or type(count) ~= "number" or not safe(count) then return end
    for i=1,count do
        local success, name, _, _, difficulty, locked, _, _, isRaid, _, _, total, progress = pcall(GetSavedInstanceInfo, i)
        if success and safe(name) and safe(difficulty) and safe(progress) and safe(total)
            and locked == true and isRaid == true and type(progress)=="number" and type(total)=="number" then
            for j, raid in ipairs(raids) do
                local matching = false
                if type(name)=="string" then
                    if j==1 then matching = name=="潮缚石窟" or name=="The Tidebound Grotto"
                    elseif j==2 then matching = name=="烈毒之渊" or name=="The Venomous Abyss"
                    else matching = name=="基希克斯破封" or name=="The Unbinding of Kith'ix" end
                end
                if matching then
                    local key = difficulty==15 and "H" or difficulty==16 and "M" or nil
                    if key and (not data[j][key] or data[j][key][3]=="partial") then
                        data[j][key] = {progress,total,"weekly"}
                    end
                end
            end
        end
    end
end
local function refresh(guid, selfUnit)
    local data = calculate(guid)
    if selfUnit then weekly(data) end
    cache[guid] = {data=data, at=GetTime()}
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("INSPECT_ACHIEVEMENT_READY")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, event, guid)
    if event=="PLAYER_ENTERING_WORLD" then cache={} return end
    if not guid or not safe(guid) or not pending[guid] then return end
    pending[guid] = nil
    waiting = false
    refresh(guid, false)
    if ClearAchievementComparisonUnit then pcall(ClearAchievementComparisonUnit) end
    -- Let the existing PrettyTooltip refresh path run on the next mouseover.
    if GameTooltip and GameTooltip:IsShown() and UnitGUID then
        local ok, current = pcall(UnitGUID, "mouseover")
        if ok and safe(current) and current==guid then
            if GameTooltip.SetUnit then pcall(GameTooltip.SetUnit, GameTooltip, "mouseover") end
        end
    end
end)
local lastAttempt={}
local function request(unit, guid)
    if waiting or not SetAchievementComparisonUnit then return end
    local now=GetTime()
    if lastAttempt[guid] and now-lastAttempt[guid]<15 then return end
    lastAttempt[guid]=now
    if AchievementFrame_LoadUI and not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_AchievementUI")) then
        pcall(AchievementFrame_LoadUI)
    elseif C_AddOns and C_AddOns.LoadAddOn and C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded("Blizzard_AchievementUI") then
        pcall(C_AddOns.LoadAddOn,"Blizzard_AchievementUI")
    end
    local ok, started = pcall(SetAchievementComparisonUnit, unit)
    if ok and started then pending[guid]=true waiting=true end
end
local function raidName(raid)
    local L=ns.L or {}
    local localized=L[raid.locale]
    if type(localized)=="string" and localized~="" and localized~=raid.locale then return localized end
    if EJ_GetInstanceInfo then
        local ok,name=pcall(EJ_GetInstanceInfo,raid.id)
        if ok and type(name)=="string" and safe(name) then return name end
    end
    return raid.fallback
end
local function display(entry,key,color)
    if not entry then return "|cff888888"..key.." --|r" end
    local suffix=""
    return "|cff"..color..key.." "..entry[1].."/"..entry[2]..suffix.."|r"
end
function R.rows(unit)
    if not unit or not UnitGUID then return end
    local ok,guid=pcall(UnitGUID,unit)
    if not ok or not guid or not safe(guid) then return end
    local selfUnit=guid==playerGuid()
    local record=cache[guid]
    if not record or GetTime()-record.at>120 then
        if selfUnit then refresh(guid,true);record=cache[guid]
        else request(unit,guid);record=cache[guid] end
    end
    -- Do not show fabricated H/M values while another player's comparison is loading.
    if not record then return end
    local L=ns.L or {}
    local heading=L["Raid Progress"]
    if not heading or heading=="Raid Progress" then heading=GetLocale()=="zhCN" and "团队副本" or "Raid Progress" end
    local rows={{left=heading,right=""}}
    for i,raid in ipairs(raids) do
        local info=record.data[i] or {}
        rows[#rows+1]={
            left="|T"..raid.icon..":14:14:0:0|t "..raidName(raid),
            right=display(info.H,"H","a335ee").."  "..display(info.M,"M","ff8000")
        }
    end
    return rows
end
