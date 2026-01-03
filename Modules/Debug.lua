local addonName, addonTable = ...
local L = addonTable.L

local DebugLog = {}

local function IsDebugEnabled()
    return LootHunterDB
        and LootHunterDB.settings
        and LootHunterDB.settings.general
        and LootHunterDB.settings.general.debugLogging
end
addonTable.IsDebugEnabled = IsDebugEnabled

local function LogDebug(msg)
    if not IsDebugEnabled() then return end
    table.insert(DebugLog, msg)
    print(msg)
end
addonTable.DebugLog = DebugLog
addonTable.LogDebug = LogDebug

addonTable.LogCoinDebug = function(msg)
    if not IsDebugEnabled() then return end
    if addonTable.LogDebug then
        addonTable.LogDebug("|cff00ffff[Coin Debug]|r " .. msg)
    end
end

local function ExportDebugLog()
    if #DebugLog == 0 then
        print(L["LOG_EMPTY_CONSOLE"])
        return
    end
    if CreateCopyLogWindow then
        CreateCopyLogWindow()
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
