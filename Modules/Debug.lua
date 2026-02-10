local _, addonTable = ...
local L = addonTable.L

local DebugLog = {}
local LOG_PREFIX_COLOR = "66ccff"
addonTable.LOG_PREFIX_COLOR = LOG_PREFIX_COLOR

local function FormatLogPrefix(tag)
    return "|cff" .. LOG_PREFIX_COLOR .. "[" .. tag .. "]|r"
end
addonTable.FormatLogPrefix = FormatLogPrefix

local function IsDebugEnabled()
    return LootHunterDB
        and LootHunterDB.settings
        and LootHunterDB.settings.general
        and LootHunterDB.settings.general.debugLogging
end
addonTable.IsDebugEnabled = IsDebugEnabled

local function GetDebugLogMax()
    if LootHunterDB
        and LootHunterDB.settings
        and LootHunterDB.settings.general
        and LootHunterDB.settings.general.debugLogMax
    then
        local max = tonumber(LootHunterDB.settings.general.debugLogMax)
        if max and max > 0 then
            return max
        end
    end
    return 1000
end

local function EnsureDebugLogStore()
    if LootHunterDB then
        if type(LootHunterDB.debugLog) ~= "table" then
            LootHunterDB.debugLog = {}
        end
        DebugLog = LootHunterDB.debugLog
    end
    addonTable.DebugLog = DebugLog
    return DebugLog
end

local function TrimDebugLog(maxEntries)
    local maxCount = tonumber(maxEntries) or GetDebugLogMax()
    if not DebugLog or type(DebugLog) ~= "table" or maxCount <= 0 then return end
    while #DebugLog > maxCount do
        table.remove(DebugLog, 1)
    end
end
addonTable.TrimDebugLog = TrimDebugLog

local function LogDebug(msg)
    if not IsDebugEnabled() then return end
    EnsureDebugLogStore()
    table.insert(DebugLog, msg)
    TrimDebugLog()
    print(msg)
end
EnsureDebugLogStore()
addonTable.LogDebug = LogDebug

addonTable.LogCoinDebug = function(msg)
    if not IsDebugEnabled() then return end
    if addonTable.LogDebug then
        addonTable.LogDebug(FormatLogPrefix("Coin Debug") .. " " .. msg)
    end
end

local function ExportDebugLog()
    if #DebugLog == 0 then
        print(L["LOG_EMPTY_CONSOLE"])
        return
    end
    if addonTable.CreateCopyLogWindow then
        addonTable.CreateCopyLogWindow()
    end
end

SLASH_LOOTHUNTER_EXPORT1 = "/loothunter_export"
SlashCmdList["LOOTHUNTER_EXPORT"] = function()
    ExportDebugLog()
end

SLASH_LOOTHUNTER_DEBUG1 = "/loothunter_debug"
SlashCmdList["LOOTHUNTER_DEBUG"] = function()
    if not LootHunterDB then LootHunterDB = {} end
    if not LootHunterDB.settings then LootHunterDB.settings = {} end
    if not LootHunterDB.settings.general then LootHunterDB.settings.general = {} end
    local current = LootHunterDB.settings.general.debugLogging
    LootHunterDB.settings.general.debugLogging = not current
    print(string.format("[Loot Hunter] Debug logging %s", LootHunterDB.settings.general.debugLogging and "enabled" or "disabled"))
    print("[Loot Hunter] Reload the UI (/reload) to update the log tab visibility.")
end

SLASH_LOOTHUNTER_SPEC1 = "/loothunter_spec"
SLASH_LOOTHUNTER_SPEC2 = "/lh_spec"
SlashCmdList["LOOTHUNTER_SPEC"] = function()
    local specName
    if GetSpecialization and GetSpecializationInfo then
        local idx = GetSpecialization()
        if idx then
            specName = select(2, GetSpecializationInfo(idx))
        end
    end
    specName = specName or "Unknown"
    print(string.format("[Loot Hunter] Current spec: %s", specName or "Unknown"))
end
