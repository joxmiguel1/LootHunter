-- =============================================================
-- Módulo: SpecResolver.lua
-- Detección y resolución de especialización del jugador.
-- Compatible con Retail (GetSpecialization), MoP+ y Classic (talentos).
-- =============================================================
local _, addonTable = ...

local LogDebug      = addonTable.LogDebug      or function() end
local FormatLogPrefix = addonTable.FormatLogPrefix or function(t) return "[" .. t .. "]" end

-- Nombre de spec actual (se cachea para evitar consultas repetidas)
local lastSpecName = nil

-- Tablas estáticas de specs por clase ID (indices WoW)
local CLASS_FALLBACK_SPECS = {
    [1]  = { "Arms", "Fury", "Protection" },              -- Guerrero
    [2]  = { "Holy", "Protection", "Retribution" },       -- Paladín
    [3]  = { "Beast Mastery", "Marksmanship", "Survival" },-- Cazador
    [4]  = { "Assassination", "Combat", "Subtlety" },     -- Pícaro
    [5]  = { "Discipline", "Holy", "Shadow" },            -- Sacerdote
    [6]  = { "Blood", "Frost", "Unholy" },                -- Caballero de la Muerte
    [7]  = { "Elemental", "Enhancement", "Restoration" }, -- Chamán
    [8]  = { "Arcane", "Fire", "Frost" },                 -- Mago
    [9]  = { "Affliction", "Demonology", "Destruction" }, -- Brujo
    [10] = { "Brewmaster", "Mistweaver", "Windwalker" },  -- Monje
    [11] = { "Balance", "Feral", "Guardian", "Restoration" }, -- Druida
}

-- Mapa de IDs de spec por clase con nombres en EN/ES para resolución bidireccional
local SPEC_ID_BY_CLASS = {
    [1]  = { {id=71,names={"arms","armas"}}, {id=72,names={"fury","furia"}}, {id=73,names={"protection","proteccion"}} },
    [2]  = { {id=65,names={"holy","sagrado"}}, {id=66,names={"protection","proteccion"}}, {id=70,names={"retribution","reprension"}} },
    [3]  = { {id=253,names={"beast mastery","bestias"}}, {id=254,names={"marksmanship","punteria"}}, {id=255,names={"survival","supervivencia"}} },
    [4]  = { {id=259,names={"assassination","asesinato"}}, {id=260,names={"combat","combate","outlaw"}}, {id=261,names={"subtlety","sutileza"}} },
    [5]  = { {id=256,names={"discipline","disciplina"}}, {id=257,names={"holy","sagrado"}}, {id=258,names={"shadow","sombra"}} },
    [6]  = { {id=250,names={"blood","sangre"}}, {id=251,names={"frost","escarcha"}}, {id=252,names={"unholy","profano"}} },
    [7]  = { {id=262,names={"elemental","elemental"}}, {id=263,names={"enhancement","mejora"}}, {id=264,names={"restoration","restauracion"}} },
    [8]  = { {id=62,names={"arcane","arcano"}}, {id=63,names={"fire","fuego"}}, {id=64,names={"frost","escarcha"}} },
    [9]  = { {id=265,names={"affliction","afliccion"}}, {id=266,names={"demonology","demonologia"}}, {id=267,names={"destruction","destruccion"}} },
    [10] = { {id=268,names={"brewmaster","maestro cervecero"}}, {id=270,names={"mistweaver","tejedor de niebla"}}, {id=269,names={"windwalker","viajero del viento"}} },
    [11] = { {id=102,names={"balance","equilibrio"}}, {id=103,names={"feral","feral"}}, {id=104,names={"guardian","guardian"}}, {id=105,names={"restoration","restauracion"}} },
}

-- Mapas derivados (construidos una sola vez con BuildSpecMaps)
local SPEC_ID_BY_CLASS_NAME  = {}
local SPEC_NAME_BY_CLASS_ID  = {}
local specMapsBuilt = false

-- Devuelve el idioma configurado en el addon (EN, ES o AUTO)
local function GetAddonLanguage()
    local db   = LootHunterDB or addonTable.db
    local lang = db and db.settings and db.settings.general and db.settings.general.language
    if type(lang) == "string" then lang = string.upper(lang) end
    if lang == "EN" or lang == "ES" then return lang end
    return "AUTO"
end

-- Capitaliza la primera letra de cada palabra (para nombres de spec)
local function TitleCaseSpecName(name)
    if not name or name == "" then return name end
    return (name:gsub("(%S)(%S*)", function(first, rest)
        return string.upper(first) .. string.lower(rest)
    end))
end

-- Devuelve el nombre estático de una spec en el idioma dado
local function GetStaticSpecName(specID, lang)
    local _, _, classID = UnitClass("player")
    local specs = classID and SPEC_ID_BY_CLASS[classID]
    if not specs then return nil end
    local index = (lang == "ES") and 2 or 1
    for _, spec in ipairs(specs) do
        if spec.id == specID then
            local name = spec.names[index] or spec.names[1]
            if name and name ~= "" then return TitleCaseSpecName(name) end
        end
    end
    return nil
end

-- Normaliza un nombre de spec para comparaciones (sin acentos, minúsculas, sin espacios extra)
local function NormalizeSpecKey(name)
    if type(name) ~= "string" then return "" end
    local key = string.lower(name)
    key = key:gsub("[áàäâã]", "a")
    key = key:gsub("[éèëê]",  "e")
    key = key:gsub("[íìïî]",  "i")
    key = key:gsub("[óòöôõ]", "o")
    key = key:gsub("[úùüû]",  "u")
    key = key:gsub("ñ",       "n")
    key = key:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return key
end

-- Construye los mapas bidireccionales desde la tabla estática
local function BuildStaticSpecMaps()
    for classID, specs in pairs(SPEC_ID_BY_CLASS) do
        SPEC_ID_BY_CLASS_NAME[classID]  = SPEC_ID_BY_CLASS_NAME[classID]  or {}
        SPEC_NAME_BY_CLASS_ID[classID]  = SPEC_NAME_BY_CLASS_ID[classID]  or {}
        for _, spec in ipairs(specs) do
            SPEC_NAME_BY_CLASS_ID[classID][spec.id] = SPEC_NAME_BY_CLASS_ID[classID][spec.id] or spec.names[1]
            for _, sname in ipairs(spec.names) do
                SPEC_ID_BY_CLASS_NAME[classID][NormalizeSpecKey(sname)] = spec.id
            end
        end
    end
end

-- Normaliza el nombre/puntos devueltos por GetTalentTabInfo (difiere entre versiones de WoW)
local function NormalizeTalentTabInfo(tab, group)
    if type(GetTalentTabInfo) ~= "function" then return nil, nil end
    local ok, v1, v2, v3, v4, v5 = pcall(GetTalentTabInfo, tab, nil, nil, group)
    if not ok then return nil, nil end
    local name, pointsSpent = nil, nil
    if type(v1) == "string" then
        name = v1 ; pointsSpent = v3
    elseif type(v2) == "string" then
        name = v2
        pointsSpent = type(v3) == "number" and v3 or type(v4) == "number" and v4 or v5
    else
        name = v1
        pointsSpent = type(v3) == "number" and v3 or type(v4) == "number" and v4 or v5
    end
    if type(name) == "number" then
        if GetSpecializationInfoByID then
            local _, specName = GetSpecializationInfoByID(name)
            name = (specName and specName ~= "") and specName or nil
        else
            name = nil
        end
    end
    return name, tonumber(pointsSpent) or 0
end
addonTable.NormalizeTalentTabInfo = NormalizeTalentTabInfo

-- Extiende los mapas con datos reales de la API de WoW (Retail/MoP)
local function ExtendSpecMapsWithAPI()
    local _, _, classID = UnitClass("player")
    if not classID then return end
    SPEC_ID_BY_CLASS_NAME[classID] = SPEC_ID_BY_CLASS_NAME[classID] or {}
    SPEC_NAME_BY_CLASS_ID[classID] = SPEC_NAME_BY_CLASS_ID[classID] or {}

    if GetNumSpecializationsForClassID and GetSpecializationInfoForClassID then
        local ok, num = pcall(GetNumSpecializationsForClassID, classID)
        if ok and num and num > 0 then
            for i = 1, num do
                local specID, name = GetSpecializationInfoForClassID(classID, i)
                if specID and name and name ~= "" then
                    SPEC_ID_BY_CLASS_NAME[classID][NormalizeSpecKey(name)] = specID
                    SPEC_NAME_BY_CLASS_ID[classID][specID] = name
                end
            end
        end
    end

    if GetNumSpecializations and GetSpecializationInfo then
        local ok, num = pcall(GetNumSpecializations)
        if ok and num and num > 0 then
            for i = 1, num do
                local specID, name = GetSpecializationInfo(i)
                if specID and name and name ~= "" then
                    SPEC_ID_BY_CLASS_NAME[classID][NormalizeSpecKey(name)] = specID
                    SPEC_NAME_BY_CLASS_ID[classID][specID] = name
                end
            end
        end
    end

    -- Classic: árbol de talentos
    if GetNumTalentTabs and GetTalentTabInfo then
        local ok, numTabs = pcall(GetNumTalentTabs)
        if ok and numTabs and numTabs > 0 then
            local group = (type(GetActiveTalentGroup) == "function" and GetActiveTalentGroup()) or 1
            for tab = 1, numTabs do
                local name = NormalizeTalentTabInfo(tab, group)
                if name and name ~= "" then
                    local fallback = SPEC_ID_BY_CLASS[classID] and SPEC_ID_BY_CLASS[classID][tab]
                    if fallback and fallback.id then
                        SPEC_ID_BY_CLASS_NAME[classID][NormalizeSpecKey(name)] = fallback.id
                        SPEC_NAME_BY_CLASS_ID[classID][fallback.id] = name
                    end
                end
            end
        end
    end
end

-- Construye todos los mapas de spec (solo lo hace una vez)
local function BuildSpecMaps()
    if specMapsBuilt then return end
    specMapsBuilt = true
    BuildStaticSpecMaps()
    ExtendSpecMapsWithAPI()
end

-- Devuelve el ID de spec a partir de su nombre
local function GetSpecIDFromName(specName)
    if not specName or specName == "" then return nil end
    BuildSpecMaps()
    local _, _, classID = UnitClass("player")
    local key = NormalizeSpecKey(specName)
    return classID and SPEC_ID_BY_CLASS_NAME[classID] and SPEC_ID_BY_CLASS_NAME[classID][key] or nil
end

-- Devuelve el nombre de spec a partir de su ID
local function GetSpecNameFromID(specID)
    if not specID then return nil end
    BuildSpecMaps()
    local lang = GetAddonLanguage()
    if lang ~= "AUTO" then
        local forced = GetStaticSpecName(specID, lang)
        if forced and forced ~= "" then return forced end
    end
    if GetSpecializationInfoByID then
        local _, name = GetSpecializationInfoByID(specID)
        if name and name ~= "" then return name end
    end
    local _, _, classID = UnitClass("player")
    local name = classID and SPEC_NAME_BY_CLASS_ID[classID] and SPEC_NAME_BY_CLASS_ID[classID][specID] or nil
    return TitleCaseSpecName(name)
end

-- Devuelve el nombre del árbol de talentos con más puntos invertidos (Classic)
local function GetTalentTabSpecName()
    if type(GetTalentTabInfo) ~= "function" then return nil end
    local group   = (type(GetActiveTalentGroup) == "function" and GetActiveTalentGroup()) or 1
    local maxTabs = 0
    if type(GetNumTalentTabs) == "function" then
        local ok, n = pcall(GetNumTalentTabs)
        if ok and n and n > 0 then maxTabs = n end
    end
    if maxTabs == 0 then maxTabs = 4 end
    local bestName, bestPoints = nil, -1
    for tab = 1, maxTabs do
        local name, pts = NormalizeTalentTabInfo(tab, group)
        if name and name ~= "" and pts > bestPoints then
            bestPoints = pts ; bestName = name
        end
    end
    return bestName
end

-- Devuelve el nombre del árbol principal (GetPrimaryTalentTree, MoP/Cata)
local function GetPrimaryTreeSpecName()
    if type(GetPrimaryTalentTree) ~= "function" then return nil end
    local treeIndex = GetPrimaryTalentTree()
    if not treeIndex or treeIndex == 0 then return nil end
    local _, _, classID = UnitClass("player")
    local classSpecs    = classID and CLASS_FALLBACK_SPECS[classID]
    return classSpecs and classSpecs[treeIndex] or nil
end

-- Devuelve el nombre de especialización actual usando múltiples APIs de fallback
local function GetCurrentSpecName()
    -- API Retail/MoP: GetSpecialization
    if GetSpecialization and GetSpecializationInfo then
        local specIndex = GetSpecialization(false, false, GetActiveSpecGroup and GetActiveSpecGroup() or nil) or GetSpecialization()
        if specIndex then
            local _, specName = GetSpecializationInfo(specIndex)
            if specName and specName ~= "" then lastSpecName = specName ; return specName end
        end
        if GetLootSpecialization and GetSpecializationInfoByID then
            local lootSpecID = GetLootSpecialization()
            if lootSpecID and lootSpecID > 0 then
                local _, specName = GetSpecializationInfoByID(lootSpecID)
                if specName and specName ~= "" then lastSpecName = specName ; return specName end
            end
        end
    end
    -- Inspect API como fallback
    if GetInspectSpecialization and GetSpecializationInfoByID then
        local ok, specID = pcall(GetInspectSpecialization, "player")
        if ok and specID and specID > 0 then
            local _, specName = GetSpecializationInfoByID(specID)
            if specName and specName ~= "" then lastSpecName = specName ; return specName end
        end
    end
    local primaryTree = GetPrimaryTreeSpecName()
    if primaryTree and primaryTree ~= "" then lastSpecName = primaryTree ; return primaryTree end
    local talentSpec  = GetTalentTabSpecName()
    if talentSpec and talentSpec ~= "" then lastSpecName = talentSpec ; return talentSpec end
    if lastSpecName and lastSpecName ~= "" then return lastSpecName end
    local _, className = UnitClass("player")
    return className
end

-- Devuelve el ID de especialización actual
local function GetCurrentSpecID()
    if GetSpecialization and GetSpecializationInfo then
        local specIndex = GetSpecialization(false, false, GetActiveSpecGroup and GetActiveSpecGroup() or nil) or GetSpecialization()
        if specIndex then
            local specID = GetSpecializationInfo(specIndex)
            if specID and specID > 0 then return specID end
        end
        if GetLootSpecialization then
            local lootSpecID = GetLootSpecialization()
            if lootSpecID and lootSpecID > 0 then return lootSpecID end
        end
    end
    if GetInspectSpecialization then
        local ok, specID = pcall(GetInspectSpecialization, "player")
        if ok and specID and specID > 0 then return specID end
    end
    local _, _, classID = UnitClass("player")
    local treeIndex = GetPrimaryTalentTree and GetPrimaryTalentTree() or nil
    if classID and treeIndex and SPEC_ID_BY_CLASS[classID] and SPEC_ID_BY_CLASS[classID][treeIndex] then
        return SPEC_ID_BY_CLASS[classID][treeIndex].id
    end
    return nil
end

-- Resuelve un nombre de spec válido priorizando el argumento dado
local function ResolveSpecName(preferred)
    if preferred and preferred ~= "" then lastSpecName = preferred ; return preferred end
    return GetCurrentSpecName()
end

-- Resuelve un ID de spec válido
local function ResolveSpecID(preferredName)
    local specID = GetCurrentSpecID()
    if specID then return specID end
    if preferredName and preferredName ~= "" then return GetSpecIDFromName(preferredName) end
    return GetSpecIDFromName(ResolveSpecName())
end

-- Añade nombres del árbol de talentos a la lista de specs disponibles
local function AddTalentTabNames(specs, seen)
    local group   = (type(GetActiveTalentGroup) == "function" and GetActiveTalentGroup()) or 1
    local maxTabs = 0
    if type(GetNumTalentTabs) == "function" then
        local ok, n = pcall(GetNumTalentTabs)
        if ok and n and n > 0 then maxTabs = n end
    end
    if maxTabs == 0 then maxTabs = 4 end
    for tab = 1, maxTabs do
        local name = NormalizeTalentTabInfo(tab, group)
        if name and name ~= "" and not seen[name] then
            table.insert(specs, name) ; seen[name] = true
        end
    end
end

-- Devuelve lista de specs disponibles (nombres) para el personaje
local function GetAvailableSpecs()
    local specs, seen = {}, {}
    if GetNumSpecializationsForClassID and GetSpecializationInfoForClassID then
        local _, _, classID = UnitClass("player")
        local ok, num = pcall(GetNumSpecializationsForClassID, classID)
        if ok and num and num > 0 then
            for i = 1, num do
                local _, name = GetSpecializationInfoForClassID(classID, i)
                if name and name ~= "" and not seen[name] then table.insert(specs, name) ; seen[name] = true end
            end
        end
    end
    if GetNumSpecializations and GetSpecializationInfo then
        local ok, num = pcall(GetNumSpecializations)
        if ok and num and num > 0 then
            for i = 1, num do
                local _, name = GetSpecializationInfo(i)
                if name and name ~= "" and not seen[name] then table.insert(specs, name) ; seen[name] = true end
            end
        end
    end
    if #specs == 0 then AddTalentTabNames(specs, seen) end
    local className = select(1, UnitClass("player"))
    local classNameLower = className and string.lower(className) or ""
    if lastSpecName and lastSpecName ~= "" and string.lower(lastSpecName) ~= classNameLower and not seen[lastSpecName] then
        table.insert(specs, lastSpecName) ; seen[lastSpecName] = true
    end
    local _, _, classID = UnitClass("player")
    if classID and CLASS_FALLBACK_SPECS[classID] then
        for _, name in ipairs(CLASS_FALLBACK_SPECS[classID]) do
            if not seen[name] then table.insert(specs, name) ; seen[name] = true end
        end
    end
    return specs
end

-- Devuelve lista de specs disponibles con sus IDs
local function GetAvailableSpecsWithIDs()
    BuildSpecMaps()
    local specs, seen = {}, {}
    local _, _, classID = UnitClass("player")
    local lang = GetAddonLanguage()
    if classID and SPEC_ID_BY_CLASS[classID] and lang ~= "AUTO" then
        for _, spec in ipairs(SPEC_ID_BY_CLASS[classID]) do
            local name = GetSpecNameFromID(spec.id) or spec.names[1]
            if spec.id and not seen[spec.id] then
                table.insert(specs, { id = spec.id, name = name }) ; seen[spec.id] = true
            end
        end
        return specs
    end
    if GetNumSpecializationsForClassID and GetSpecializationInfoForClassID and classID then
        local ok, num = pcall(GetNumSpecializationsForClassID, classID)
        if ok and num and num > 0 then
            for i = 1, num do
                local specID, name = GetSpecializationInfoForClassID(classID, i)
                if specID and name and name ~= "" and not seen[specID] then
                    table.insert(specs, { id = specID, name = name }) ; seen[specID] = true
                end
            end
        end
    elseif GetNumSpecializations and GetSpecializationInfo then
        local ok, num = pcall(GetNumSpecializations)
        if ok and num and num > 0 then
            for i = 1, num do
                local specID, name = GetSpecializationInfo(i)
                if specID and name and name ~= "" and not seen[specID] then
                    table.insert(specs, { id = specID, name = name }) ; seen[specID] = true
                end
            end
        end
    elseif classID and SPEC_ID_BY_CLASS[classID] then
        for _, spec in ipairs(SPEC_ID_BY_CLASS[classID]) do
            local name = GetSpecNameFromID(spec.id) or spec.names[1]
            if spec.id and not seen[spec.id] then
                table.insert(specs, { id = spec.id, name = name }) ; seen[spec.id] = true
            end
        end
    end
    return specs
end

-- Migra entradas del DB que solo tienen nombre de spec hacia specID numérico
local function MigrateSpecIDs()
    BuildSpecMaps()
    local CurrentCharDB = addonTable.CurrentCharDB
    if not CurrentCharDB then return false end
    local updated = false
    for id, data in pairs(CurrentCharDB) do
        if type(id) == "number" and type(data) == "table" then
            if not data.specID and data.spec and data.spec ~= "" then
                local specID = GetSpecIDFromName(data.spec)
                if specID then data.specID = specID ; updated = true end
            end
            if data.specID then
                local name = GetSpecNameFromID(data.specID)
                if name and name ~= "" and data.spec ~= name then
                    data.spec = name ; updated = true
                end
            end
        end
    end
    return updated
end

-- Manejador del evento de cambio de specialización
local function HandleSpecChange(event, unit)
    if unit and unit ~= "player" then return end
    lastSpecName = nil
    lastSpecName = ResolveSpecName()
    if LootHunter_RefreshUI then LootHunter_RefreshUI() end
end

-- Exponer funciones en addonTable para uso de LootHunter.lua y otros módulos
addonTable.GetAvailableSpecs         = GetAvailableSpecs
addonTable.GetAvailableSpecsWithIDs  = GetAvailableSpecsWithIDs
addonTable.GetSpecIDFromName         = GetSpecIDFromName
addonTable.GetSpecNameFromID         = GetSpecNameFromID
addonTable.ResolveSpecName           = ResolveSpecName
addonTable.ResolveSpecID             = ResolveSpecID
addonTable.MigrateSpecIDs            = MigrateSpecIDs
addonTable.HandleSpecChange          = HandleSpecChange
