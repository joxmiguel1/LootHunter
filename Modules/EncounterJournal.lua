-- =============================================================
-- Módulo: EncounterJournal.lua
-- Resuelve la fuente de drop (instancia - boss) de un item
-- consultando el Encounter Journal de WoW (EJ).
-- =============================================================
local _, addonTable = ...

local LogDebug        = addonTable.LogDebug        or function() end
local FormatLogPrefix = addonTable.FormatLogPrefix or function(t) return "[" .. t .. "]" end
local L               = addonTable.L

-- Flag para evitar intentos repetidos cuando el EJ no está disponible
local EJUnavailable      = false
local EJUnavailableLogged = false
-- Indica si ya se seleccionó el tier de Pandaria para mejorar los resultados en MoP
local MOPTierSelected = false

-- Permite que HandleAddonLoaded resetee el flag cuando Blizzard_EncounterJournal carga
local function ResetEJFlags()
    EJUnavailable       = false
    EJUnavailableLogged = false
end
addonTable.ResetEJFlags = ResetEJFlags

-- Cache local de fuentes resueltas por itemID
local LootSourceCache = {}

-- Verifica si las APIs del EJ están disponibles; intenta cargar el módulo si no
local function EnsureEJLoaded()
    if EJUnavailable then return false end
    if EJ_GetNumInstances or EJ_GetLootInfoByItemID or
       (C_EncounterJournal and (C_EncounterJournal.GetLootInfoByItemID or C_EncounterJournal.GetLootInfo)) then
        return true
    end
    if UIParentLoadAddOn then
        local loaded = UIParentLoadAddOn("Blizzard_EncounterJournal")
        if loaded and (EJ_GetNumInstances or EJ_GetLootInfoByItemID or
           (C_EncounterJournal and (C_EncounterJournal.GetLootInfoByItemID or C_EncounterJournal.GetLootInfo))) then
            return true
        end
    end
    if not IsAddOnLoaded("Blizzard_EncounterJournal") then
        local loaded = LoadAddOn("Blizzard_EncounterJournal")
        if loaded and (EJ_GetNumInstances or EJ_GetLootInfoByItemID or
           (C_EncounterJournal and (C_EncounterJournal.GetLootInfoByItemID or C_EncounterJournal.GetLootInfo))) then
            return true
        end
    end
    EJUnavailable = true
    if LogDebug and not EJUnavailableLogged then
        EJUnavailableLogged = true
        LogDebug(FormatLogPrefix("EJ") .. " Encounter Journal no disponible; omitiendo hasta /reload")
    end
    return false
end

-- Construye la fuente desde el contexto actual del EJ abierto
local function BuildSourceFromJournal()
    if not EncounterJournal or not EncounterJournal:IsShown() then return nil end
    local instanceName, encounterName
    if EncounterJournal.instanceID then
        instanceName = EJ_GetInstanceInfo(EncounterJournal.instanceID)
    end
    if EncounterJournal.encounterID then
        encounterName = EJ_GetEncounterInfo(EncounterJournal.encounterID)
    end
    if instanceName and encounterName then return instanceName .. " - " .. encounterName
    elseif encounterName then return encounterName
    elseif instanceName then return instanceName .. " " .. (L["ZONE_DROP"] or "Zone Drop")
    end
    return nil
end
addonTable.BuildSourceFromJournal = BuildSourceFromJournal

-- Detecta si un item es de dificultad heroica a partir de su link, fuente y dificultad EJ
local function IsHeroicItem(itemLink, source, ejDifficulty)
    if not itemLink or itemLink == "" then return false end
    local plainLink = itemLink:match("|H(item:.-)|h") or itemLink
    local parts     = { strsplit(":", plainLink) }
    local candidates = {
        tonumber(parts[12]), tonumber(parts[13]),
        tonumber(parts[15]), tonumber(parts[16]),
    }
    local heroicDifficulty = false
    for _, diffID in ipairs(candidates) do
        if diffID and (diffID == 5 or diffID == 6 or diffID == 16 or diffID == 148 or diffID == 149
                       or (diffID >= 175 and diffID <= 177)) then
            heroicDifficulty = true ; break
        end
    end
    local suffixID         = tonumber(parts[8])
    local isHeroicFromSrc  = source and (string.find(string.lower(source), "%(h%)") or string.find(string.lower(source), "heroic"))
    local ejIsHeroic       = ejDifficulty and (ejDifficulty == 5 or ejDifficulty == 6 or ejDifficulty == 16)
    return (heroicDifficulty or (suffixID and suffixID > 0) or isHeroicFromSrc or ejIsHeroic) and true or false
end
addonTable.IsHeroicItem = IsHeroicItem

-- Resuelve la fuente de un item consultando el EJ directamente
local function ResolveSourceFromEJ(itemID)
    if not itemID or type(itemID) ~= "number" then return nil end
    if not EnsureEJLoaded() then return nil, "EJ_UNAVAILABLE" end

    -- Seleccionar tier de Pandaria para mejorar resultados en MoP
    if EJ_SelectTier and EJ_GetNumTiers and not MOPTierSelected then
        local numTiers = EJ_GetNumTiers() or 0
        local selected = false
        for i = 1, numTiers do
            local name = EJ_GetTierInfo and EJ_GetTierInfo(i) or ""
            if name and string.find(string.lower(name), "pandaria") then
                EJ_SelectTier(i) ; selected = true ; break
            end
        end
        if not selected then EJ_SelectTier(5) end
        MOPTierSelected = true
    end

    local lootFunc      = EJ_GetLootInfoByItemID or (C_EncounterJournal and (C_EncounterJournal.GetLootInfoByItemID or C_EncounterJournal.GetLootInfo))
    local encounterFunc = EJ_GetEncounterInfo   or (C_EncounterJournal and (C_EncounterJournal.GetEncounterInfo or C_EncounterJournal.GetEncounterInfoByIndex))
    local instanceFunc  = EJ_GetInstanceInfo    or (C_EncounterJournal and C_EncounterJournal.GetInstanceInfo)

    -- Intento directo por EJ_GetLootInfoByItemID
    if lootFunc and encounterFunc then
        local _, _, _, _, _, encounterID, instanceID = lootFunc(itemID)
        if encounterID then
            local bossName, _, _, instFromBoss = encounterFunc(encounterID)
            local instID = instFromBoss or instanceID
            local instanceName = instanceFunc and (instID and instanceFunc(instID) or (instanceID and instanceFunc(instanceID))) or nil
            if instanceName and bossName then
                LogDebug(FormatLogPrefix("EJ") .. " Resuelta fuente (directo) para item " .. itemID .. ": " .. instanceName .. " - " .. bossName)
                return instanceName .. " - " .. bossName
            end
            if bossName or instanceName then
                LogDebug(FormatLogPrefix("EJ") .. " Resuelta fuente (directo) para item " .. itemID .. ": " .. (bossName or instanceName))
                return bossName or instanceName
            end
        end
    end

    -- Fallback: iterar todas las instancias y bosses
    local numInstances = (EJ_GetNumInstances and EJ_GetNumInstances()) or 0
    for i = 1, numInstances do
        local instID = EJ_GetInstanceByIndex(i, false)
        if instID then
            EJ_SelectInstance(instID)
            local instName = EJ_GetInstanceInfo(instID)
            local bossIndex = 1
            while true do
                local bossName, _, bossID = EJ_GetEncounterInfoByIndex(bossIndex, instID)
                if not bossName then break end
                EJ_SelectEncounter(bossID)
                local lootIndex = 1
                while true do
                    local info = EJ_GetLootInfoByIndex(lootIndex)
                    if not info then break end
                    if info.itemID == itemID then
                        local src = (instName and bossName) and (instName .. " - " .. bossName) or (bossName or instName)
                        LogDebug(FormatLogPrefix("EJ") .. " Resuelta fuente para item " .. itemID .. ": " .. (src or "??"))
                        return src
                    end
                    lootIndex = lootIndex + 1
                end
                bossIndex = bossIndex + 1
            end
        end
    end
    return nil
end

-- Intenta actualizar la fuente de un item del EJ en el próximo tick
local function TryResolveSourceAsync(itemID)
    if not itemID or EJUnavailable then return end
    -- RequestLoadItemDataByID para asegurar que el cliente tenga los datos
    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
    GetItemInfo(itemID)
    C_Timer.After(0, function()
        local CurrentCharDB = addonTable.CurrentCharDB
        if not CurrentCharDB or EJUnavailable then return end
        local entry = CurrentCharDB[itemID]
        if not entry or (entry.boss and entry.boss ~= "" and entry.boss ~= L["UNKNOWN_SOURCE"]) then return end
        LogDebug(FormatLogPrefix("EJ") .. " Intentando resolver fuente via EJ para item " .. tostring(itemID))
        local src, errFlag = ResolveSourceFromEJ(itemID)
        if errFlag == "EJ_UNAVAILABLE" then EJUnavailable = true ; return end
        if src and src ~= "" then
            entry.boss = src
            if LootHunter_RefreshUI then LootHunter_RefreshUI() end
            if addonTable.RefreshLogPanel then addonTable.RefreshLogPanel() end
        else
            LogDebug(FormatLogPrefix("EJ") .. " No se encontró fuente para item " .. tostring(itemID) .. " en EJ")
        end
    end)
end
addonTable.TryResolveSourceAsync = TryResolveSourceAsync

-- Resuelve todas las fuentes desconocidas en el DB actual de forma asíncrona
local function ResolveAllUnknownSources()
    local CurrentCharDB = addonTable.CurrentCharDB
    if not CurrentCharDB then return end
    local pending = {}
    for id, data in pairs(CurrentCharDB) do
        if type(id) == "number" and type(data) == "table" then
            local boss = data.boss
            if not boss or boss == "" or boss == L["UNKNOWN_SOURCE"] then
                pending[#pending + 1] = id
            end
        end
    end
    if #pending == 0 then return end
    -- Precargar datos de item para mejorar las respuestas del EJ
    for _, itemID in ipairs(pending) do
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
        GetItemInfo(itemID)
    end
    C_Timer.After(0.6, function()
        if EJUnavailable then return end
        for index, itemID in ipairs(pending) do
            C_Timer.After(0.05 * (index - 1), function()
                TryResolveSourceAsync(itemID)
            end)
        end
    end)
end
addonTable.ResolveAllUnknownSources = ResolveAllUnknownSources

-- Refresca la fuente del boss para un item ya registrado si el EJ está abierto
local function MaybeRefreshJournalBoss(id)
    local CurrentCharDB = addonTable.CurrentCharDB
    if not CurrentCharDB or not EncounterJournal or not EncounterJournal:IsShown() then return end
    local entry = CurrentCharDB[id]
    if not entry then return end
    local currentSource = entry.boss or ""
    if currentSource ~= "" and currentSource ~= L["UNKNOWN_SOURCE"] and not string.find(currentSource, L["ZONE_DROP"] or "Zone Drop", 1, true) then
        return
    end
    local attempts = 0
    local function try()
        if not CurrentCharDB or not EncounterJournal or not EncounterJournal:IsShown() then return end
        local source = BuildSourceFromJournal()
        if source and source ~= "" and source ~= L["UNKNOWN_SOURCE"] then
            entry.boss = source
            if LootHunter_RefreshUI then LootHunter_RefreshUI() end
            return
        end
        attempts = attempts + 1
        if attempts < 4 then C_Timer.After(0.35, try) end
    end
    try()
end
addonTable.MaybeRefreshJournalBoss = MaybeRefreshJournalBoss

-- BuildStaticDB está deshabilitado  
local function _BuildStaticDB() end
addonTable.BuildStaticDB = _BuildStaticDB

-- Devuelve la fuente cacheada de un item (si existe)
function addonTable.GetItemSourceFromCache(itemID)
    return LootSourceCache[itemID] or nil
end
