-- =============================================================
-- 1. VARIABLES Y TABLAS DE ORDEN
-- =============================================================
local addonName, addonTable = ...
local L = addonTable.L
local CreateGradient = addonTable.CreateGradient or function(text) return text end
local ColorPrimary = addonTable.ColorPrimary
local frame = CreateFrame("Frame")
addonTable.isRefreshing = false
local BuildStaticDB
local ResolveAllUnknownSources
local LogCoinDebug
local GetCurrentSpecName
local MOPTierSelected = false
local ShowDropAlert
local function RequestItemData(itemID)
    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    elseif C_Item and C_Item.RequestServerCache then
        C_Item.RequestServerCache(itemID)
    end
    -- Forzar GetItemInfo para disparar la carga del cliente
    GetItemInfo(itemID)
end
local ITEM_CLASS_WEAPON = _G.LE_ITEM_CLASS_WEAPON or 2
local ITEM_CLASS_ARMOR = _G.LE_ITEM_CLASS_ARMOR or 4
local ITEM_CLASS_MISC = _G.LE_ITEM_CLASS_MISCELLANEOUS or 15
local ITEM_SUBCLASS_MOUNT = _G.LE_ITEM_MISCELLANEOUS_MOUNT or (_G.Enum and _G.Enum.ItemMiscellaneousSubclass and _G.Enum.ItemMiscellaneousSubclass.Mount) or 5
-- Variables para la base de datos del personaje actual
local CurrentCharDB = nil 
local refresh_timer = nil
-- Iconos de Raid
local ICON_STAR = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:24|t"
local ICON_DIAMOND = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:24|t"
local ICON_TRIANGLE = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:24|t"
addonTable.ICON_DIAMOND = ICON_DIAMOND
addonTable.ICON_STAR = ICON_STAR
local lastSpecName = nil
local CLASS_FALLBACK_SPECS = {
    [1] = { "Arms", "Fury", "Protection" }, -- GUERRERO
    [2] = { "Holy", "Protection", "Retribution" }, -- PALADIN
    [3] = { "Beast Mastery", "Marksmanship", "Survival" }, -- CAZADOR
    [4] = { "Assassination", "Combat", "Subtlety" }, -- PICARO
    [5] = { "Discipline", "Holy", "Shadow" }, -- SACERDOTE
    [6] = { "Blood", "Frost", "Unholy" }, -- CABALLERO DE LA MUERTE
    [7] = { "Elemental", "Enhancement", "Restoration" }, -- CHAMAN
    [8] = { "Arcane", "Fire", "Frost" }, -- MAGO
    [9] = { "Affliction", "Demonology", "Destruction" }, -- BRUJO
    [10] = { "Brewmaster", "Mistweaver", "Windwalker" }, -- MONJE
    [11] = { "Balance", "Feral", "Guardian", "Restoration" }, -- DRUIDA
}
local SPEC_ID_BY_CLASS = {
    [1] = {
        { id = 71, names = { "arms", "armas" } },
        { id = 72, names = { "fury", "furia" } },
        { id = 73, names = { "protection", "proteccion" } },
    },
    [2] = {
        { id = 65, names = { "holy", "sagrado" } },
        { id = 66, names = { "protection", "proteccion" } },
        { id = 70, names = { "retribution", "reprension" } },
    },
    [3] = {
        { id = 253, names = { "beast mastery", "bestias" } },
        { id = 254, names = { "marksmanship", "punteria" } },
        { id = 255, names = { "survival", "supervivencia" } },
    },
    [4] = {
        { id = 259, names = { "assassination", "asesinato" } },
        { id = 260, names = { "combat", "combate", "outlaw" } },
        { id = 261, names = { "subtlety", "sutileza" } },
    },
    [5] = {
        { id = 256, names = { "discipline", "disciplina" } },
        { id = 257, names = { "holy", "sagrado" } },
        { id = 258, names = { "shadow", "sombra" } },
    },
    [6] = {
        { id = 250, names = { "blood", "sangre" } },
        { id = 251, names = { "frost", "escarcha" } },
        { id = 252, names = { "unholy", "profano" } },
    },
    [7] = {
        { id = 262, names = { "elemental", "elemental" } },
        { id = 263, names = { "enhancement", "mejora" } },
        { id = 264, names = { "restoration", "restauracion" } },
    },
    [8] = {
        { id = 62, names = { "arcane", "arcano" } },
        { id = 63, names = { "fire", "fuego" } },
        { id = 64, names = { "frost", "escarcha" } },
    },
    [9] = {
        { id = 265, names = { "affliction", "afliccion" } },
        { id = 266, names = { "demonology", "demonologia" } },
        { id = 267, names = { "destruction", "destruccion" } },
    },
    [10] = {
        { id = 268, names = { "brewmaster", "maestro cervecero" } },
        { id = 270, names = { "mistweaver", "tejedor de niebla" } },
        { id = 269, names = { "windwalker", "viajero del viento" } },
    },
    [11] = {
        { id = 102, names = { "balance", "equilibrio" } },
        { id = 103, names = { "feral", "feral" } },
        { id = 104, names = { "guardian", "guardian" } },
        { id = 105, names = { "restoration", "restauracion" } },
    },
}
local SPEC_ID_BY_CLASS_NAME = {}
local SPEC_NAME_BY_CLASS_ID = {}
local specMapsBuilt = false

local function GetAddonLanguage()
    local db = LootHunterDB or addonTable.db
    local lang = db and db.settings and db.settings.general and db.settings.general.language
    if type(lang) == "string" then
        lang = string.upper(lang)
    end
    if lang == "EN" or lang == "ES" then
        return lang
    end
    return "AUTO"
end

local function TitleCaseSpecName(name)
    if not name or name == "" then return name end
    return (name:gsub("(%S)(%S*)", function(first, rest)
        return string.upper(first) .. string.lower(rest)
    end))
end

local function GetStaticSpecName(specID, lang)
    local _, _, classID = UnitClass("player")
    local specs = classID and SPEC_ID_BY_CLASS[classID]
    if not specs then return nil end
    local index = (lang == "ES") and 2 or 1
    for _, spec in ipairs(specs) do
        if spec.id == specID then
            local name = spec.names[index] or spec.names[1]
            if name and name ~= "" then
                return TitleCaseSpecName(name)
            end
        end
    end
    return nil
end

local function NormalizeSpecKey(name)
    if type(name) ~= "string" then return "" end
    local key = string.lower(name)
    key = key:gsub("[áàäâã]", "a")
    key = key:gsub("[éèëê]", "e")
    key = key:gsub("[íìïî]", "i")
    key = key:gsub("[óòöôõ]", "o")
    key = key:gsub("[úùüû]", "u")
    key = key:gsub("ñ", "n")
    key = key:gsub("%s+", " ")
    key = key:gsub("^%s+", ""):gsub("%s+$", "")
    return key
end

local function BuildStaticSpecMaps()
    for classID, specs in pairs(SPEC_ID_BY_CLASS) do
        SPEC_ID_BY_CLASS_NAME[classID] = SPEC_ID_BY_CLASS_NAME[classID] or {}
        SPEC_NAME_BY_CLASS_ID[classID] = SPEC_NAME_BY_CLASS_ID[classID] or {}
        for _, spec in ipairs(specs) do
            SPEC_NAME_BY_CLASS_ID[classID][spec.id] = SPEC_NAME_BY_CLASS_ID[classID][spec.id] or spec.names[1]
            for _, name in ipairs(spec.names) do
                SPEC_ID_BY_CLASS_NAME[classID][NormalizeSpecKey(name)] = spec.id
            end
        end
    end
end

local function ExtendSpecMapsWithAPI()
    local _, _, classID = UnitClass("player")
    if not classID then return end
    SPEC_ID_BY_CLASS_NAME[classID] = SPEC_ID_BY_CLASS_NAME[classID] or {}
    SPEC_NAME_BY_CLASS_ID[classID] = SPEC_NAME_BY_CLASS_ID[classID] or {}
    if GetNumSpecializationsForClassID and GetSpecializationInfoForClassID then
        local okNum, num = pcall(GetNumSpecializationsForClassID, classID)
        if okNum and num and num > 0 then
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
        local okNum, num = pcall(GetNumSpecializations)
        if okNum and num and num > 0 then
            for i = 1, num do
                local specID, name = GetSpecializationInfo(i)
                if specID and name and name ~= "" then
                    SPEC_ID_BY_CLASS_NAME[classID][NormalizeSpecKey(name)] = specID
                    SPEC_NAME_BY_CLASS_ID[classID][specID] = name
                end
            end
        end
    end
    if GetNumTalentTabs and GetTalentTabInfo then
        local okNum, numTabs = pcall(GetNumTalentTabs)
        if okNum and numTabs and numTabs > 0 then
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

local function BuildSpecMaps()
    if specMapsBuilt then return end
    specMapsBuilt = true
    BuildStaticSpecMaps()
    ExtendSpecMapsWithAPI()
end

local function GetSpecIDFromName(specName)
    if not specName or specName == "" then return nil end
    BuildSpecMaps()
    local _, _, classID = UnitClass("player")
    local key = NormalizeSpecKey(specName)
    return classID and SPEC_ID_BY_CLASS_NAME[classID] and SPEC_ID_BY_CLASS_NAME[classID][key] or nil
end

local function GetSpecNameFromID(specID)
    if not specID then return nil end
    BuildSpecMaps()
    local lang = GetAddonLanguage()
    if lang ~= "AUTO" then
        local forced = GetStaticSpecName(specID, lang)
        if forced and forced ~= "" then
            return forced
        end
    end
    if GetSpecializationInfoByID then
        local _, name = GetSpecializationInfoByID(specID)
        if name and name ~= "" then
            return name
        end
    end
    local _, _, classID = UnitClass("player")
    local name = classID and SPEC_NAME_BY_CLASS_ID[classID] and SPEC_NAME_BY_CLASS_ID[classID][specID] or nil
    return TitleCaseSpecName(name)
end
-- Control de alertas de drop para evitar spam
local LastDropAlert = {}
local PendingCoinReminders = {}
local LastCoinReminderBoss = nil
local TriggerLootReadyTimers
local COIN_REMINDER_DELAY = 4
local COIN_REMINDER_MIN_WAIT = 30
local COIN_REMINDER_MAX_WAIT = 150
local COIN_REMINDER_FALLBACK = 40
local PREWARN_SOUND_ID = (SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081
local COIN_LOST_SOUND_ID = (SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081
local OTHER_WON_SOUND = "Sound\\Creature\\ArthasPrisoner\\UR_ArthasPrisoner_YSVisThree01.ogg"
local ROLL_TRACK_WINDOW = 35
local lastAnnouncedRollItemID = nil
local lastAnnouncedRollTime = nil
local lastPlayerRollItemID = nil
local lastPlayerRollTime = nil
local ALERT_DEFAULT_DURATION = 6.8
local ALERT_PRIORITY_PRIMARY = 1
local ALERT_PRIORITY_SECONDARY = 2
local ALERT_PRIORITY_PREWARN = 3
local function EnqueueAlert(duration, priority, fn)
    if addonTable and addonTable.EnqueueAlert then
        addonTable.EnqueueAlert(duration or ALERT_DEFAULT_DURATION, fn, priority or ALERT_PRIORITY_SECONDARY)
        return
    end
    if fn then fn() end
end
local function LogAlertDebug(msg)
    if addonTable and addonTable.LogDebug then
        addonTable.LogDebug("|cff00ff00[Alert]|r " .. msg)
    end
end
local function GetCoinReminderWait()
    local value = COIN_REMINDER_MAX_WAIT
    if LootHunterDB and LootHunterDB.settings and LootHunterDB.settings.coinReminder then
        local saved = tonumber(LootHunterDB.settings.coinReminder.reminderDelay)
        if saved then
            value = saved
        end
        value = math.max(COIN_REMINDER_MIN_WAIT, math.min(COIN_REMINDER_MAX_WAIT, value))
        LootHunterDB.settings.coinReminder.reminderDelay = value
    end
    return value
end
-- TABLA DE CATEGORÍAS
local SLOT_INFO = {}
local function RebuildSlotInfo()
    SLOT_INFO = {
        ["RAID_TOKEN"] = { order = 0, name = L["RAID_TOKEN"] },
        ["INVTYPE_HEAD"] = { order = 1, name = L["HEAD"] },
        ["INVTYPE_NECK"] = { order = 2, name = L["NECK"] },
        ["INVTYPE_SHOULDER"] = { order = 3, name = L["SHOULDER"] },
        ["INVTYPE_CLOAK"] = { order = 4, name = L["CLOAK"] },
        ["INVTYPE_CHEST"] = { order = 5, name = L["CHEST"] },
        ["INVTYPE_ROBE"] = { order = 5, name = L["CHEST"] },
        ["INVTYPE_WRIST"] = { order = 6, name = L["WRIST"] },
        ["INVTYPE_HAND"] = { order = 7, name = L["HAND"] },
        ["INVTYPE_WAIST"] = { order = 8, name = L["WAIST"] },
        ["INVTYPE_LEGS"] = { order = 9, name = L["LEGS"] },
        ["INVTYPE_FEET"] = { order = 10, name = L["FEET"] },
        ["INVTYPE_FINGER"] = { order = 11, name = L["FINGER"] },
        ["INVTYPE_TRINKET"] = { order = 12, name = L["TRINKET"] },
        ["INVTYPE_WEAPON"] = { order = 13, name = L["WEAPON_1H"] },
        ["INVTYPE_WEAPONMAINHAND"] = { order = 13, name = L["WEAPON_MAIN"] },
        ["INVTYPE_WEAPONOFFHAND"] = { order = 14, name = L["WEAPON_OFF"] },
        ["INVTYPE_SHIELD"] = { order = 14, name = L["SHIELD"] },
        ["INVTYPE_HOLDABLE"] = { order = 14, name = L["HOLDABLE"] },
        ["INVTYPE_2HWEAPON"] = { order = 15, name = L["WEAPON_2H"] },
        ["INVTYPE_RANGED"] = { order = 16, name = L["RANGED"] },
        ["INVTYPE_RANGEDRIGHT"] = { order = 16, name = L["RANGED"] },
        ["INVTYPE_THROWN"] = { order = 16, name = L["RANGED"] },
        ["INVTYPE_WAND"] = { order = 16, name = L["RANGED"] },
        ["INVTYPE_RELIC"] = { order = 16, name = L["RELIC"] },
        ["MOUNT"] = { order = 17, name = L["MOUNT"] },
    }
    addonTable.SLOT_INFO = SLOT_INFO
end
addonTable.RebuildSlotInfo = RebuildSlotInfo
RebuildSlotInfo()
-- =============================================================
-- 2. LÓGICA DE EVENTOS
-- =============================================================
local function InitializeSettings()
    local defaults = {
        coinReminder = {
            enabled = true,
            preWarning = true,
            channel = "SELF",
            visualAlert = true,
            soundEnabled = true,
            soundFile = 12867, -- ID de sonido por defecto del codigo original
            reminderDelay = COIN_REMINDER_MAX_WAIT,
        },
        lootAlerts = {
            itemWon = true,
            itemSeen = true,
            otherWonSound = true,
            bossNoItems = false,
        },
        general = {
            windowsLocked = true,
            debugLogging = false,
            language = "AUTO",
            helpSeen = false,
            uiScale = 1.0,
        }
    }
    if not LootHunterDB.settings then
        LootHunterDB.settings = defaults
        return
    end
    -- Merge profundo de defaults para usuarios existentes sin sobrescribir sus preferencias
    for category, settings in pairs(defaults) do
        if not LootHunterDB.settings[category] then
            LootHunterDB.settings[category] = settings
        else
            for key, value in pairs(settings) do
                if LootHunterDB.settings[category][key] == nil then
                    LootHunterDB.settings[category][key] = value
                end
            end
        end
    end
end

local ValidateAddonAssets
local MigrateSpecIDs
local function HandleAddonLoaded(event, arg1)
    if arg1 == "Blizzard_EncounterJournal" then
        EJUnavailable = false
        EJUnavailableLogged = false
        if ResolveAllUnknownSources then
            ResolveAllUnknownSources()
        else
            -- Si el resolver aún no está definido (por orden de carga), reintenta en el siguiente tick
            C_Timer.After(0, function()
                if ResolveAllUnknownSources then
                    ResolveAllUnknownSources()
                end
            end)
        end
        return
    end
    if arg1 ~= addonName then return end
    addonTable.version = GetAddOnMetadata(addonName, "Version") or "1.0"

    if LootHunterDB == nil then LootHunterDB = {} end

    InitializeSettings()
    addonTable.db = LootHunterDB -- Compartir DB con otros archivos
    if addonTable.ApplyLocale then
        addonTable.ApplyLocale()
    end
    if addonTable.RebuildSlotInfo then
        addonTable.RebuildSlotInfo()
    end
    ValidateAddonAssets()

    if not LootHunterDB.windowSettings then
        local screenWidth = (GetScreenWidth and GetScreenWidth()) or (UIParent and UIParent:GetWidth()) or 0
        local defaultX = -math.floor((screenWidth or 0) * 0.10)
        LootHunterDB.windowSettings = { point = "RIGHT", relativePoint = "RIGHT", x = defaultX, y = 0, width = 510, height = 463 }
    end
    if not LootHunterDB.buttonPos then
        LootHunterDB.buttonPos = { point = "CENTER", x = -200, y = 0 }
    end

    if not LootHunterDB.Characters then LootHunterDB.Characters = {} end
    local charKey = UnitName("player") .. " - " .. GetRealmName()
    if not LootHunterDB.Characters[charKey] then LootHunterDB.Characters[charKey] = {} end
    CurrentCharDB = LootHunterDB.Characters[charKey]
    addonTable.CurrentCharDB = CurrentCharDB -- Compartir con UI.lua
    MigrateSpecIDs()

    local count = 0
    for k, v in pairs(CurrentCharDB) do 
        if type(k) == "number" then 
            count = count + 1
            if type(v) == "table" and v.status == 1 then v.status = 0 end
        end
    end
    
    print(string.format(L["LOADED_MSG"], charKey, count))
    if addonTable.CreateMinimapIcon then
        addonTable.CreateMinimapIcon()
    end
    -- CreateFloatingButton() -- Reemplazado por el icono del minimapa
    BuildStaticDB()

    hooksecurefunc("HandleModifiedItemClick", function(itemLink)
        if not IsShiftKeyDown() or addonTable.SuppressAddItem then return end
        if not (addonTable.MainFrame and addonTable.MainFrame:IsShown()) then return end
        if not itemLink or ChatEdit_GetActiveWindow() then return end
        local safeLink = itemLink
    C_Timer.After(0, function()
        if addonTable.SuppressAddItem then return end
        if addonTable.MainFrame and addonTable.MainFrame:IsShown() then
            AddItemToList(safeLink)
        end
    end)
end)

end

ValidateAddonAssets = function()
    if type(L) ~= "table" then return end
    local missing = {}
    local fontPath = "Interface\\AddOns\\LootHunter\\Fonts\\Prototype.ttf"
    if CreateFont then
        local testFont = CreateFont("LootHunterFontCheck")
        local ok = testFont and testFont.SetFont and testFont:SetFont(fontPath, 12, "")
        local currentFont = testFont and testFont.GetFont and testFont:GetFont()
        if not ok and (not currentFont or currentFont == "") then
            table.insert(missing, "Fonts\\Prototype.ttf")
        end
    end
    local texturePaths = {
        "Textures\\icon_equipped.tga",
        "Textures\\icon_help.tga",
        "Textures\\backbutton.tga",
    }
    if frame and frame.CreateTexture then
        local tex = frame:CreateTexture(nil, "ARTWORK")
        for _, relPath in ipairs(texturePaths) do
            local ok = tex:SetTexture("Interface\\AddOns\\LootHunter\\" .. relPath)
            if not ok then
                table.insert(missing, relPath)
            end
        end
        tex:SetTexture(nil)
    end
    if #missing > 0 then
        local list = table.concat(missing, ", ")
        local msg = string.format(L["ASSET_MISSING_MSG"] or "[Loot Hunter] Missing assets: %s", list)
        print(msg)
        print(L["ASSET_MISSING_HINT"] or "[Loot Hunter] Verify the addon folder name is LootHunter.")
    end
end
local function HandleInfoUpdate(event, arg1)
    if refresh_timer then return end
    refresh_timer = C_Timer.After(0.2, function()
        if LootHunter_RefreshUI then
            LootHunter_RefreshUI()
        end
        refresh_timer = nil
    end)
end
-- Devuelve el nombre de la especializacion actual del jugador (si existe)
local function NormalizeTalentTabInfo(tab, group)
    if type(GetTalentTabInfo) ~= "function" then return nil, nil end
    local ok, v1, v2, v3, v4, v5 = pcall(GetTalentTabInfo, tab, nil, nil, group)
    if not ok then return nil, nil end
    local name = nil
    local pointsSpent = nil
    if type(v1) == "string" then
        name = v1
        pointsSpent = v3
    elseif type(v2) == "string" then
        name = v2
        if type(v3) == "number" then
            pointsSpent = v3
        elseif type(v4) == "number" then
            pointsSpent = v4
        elseif type(v5) == "number" then
            pointsSpent = v5
        end
    else
        name = v1
        if type(v3) == "number" then
            pointsSpent = v3
        elseif type(v4) == "number" then
            pointsSpent = v4
        elseif type(v5) == "number" then
            pointsSpent = v5
        end
    end
    if type(name) == "number" then
        if GetSpecializationInfoByID then
            local _, specName = GetSpecializationInfoByID(name)
            if specName and specName ~= "" then
                name = specName
            else
                name = nil
            end
        else
            name = nil
        end
    end
    return name, tonumber(pointsSpent) or 0
end

local function GetTalentTabSpecName()
    if type(GetTalentTabInfo) ~= "function" then return nil end

    local group = (type(GetActiveTalentGroup) == "function" and GetActiveTalentGroup()) or 1
    local maxTabs = 0
    if type(GetNumTalentTabs) == "function" then
        local okNum, numTabs = pcall(GetNumTalentTabs)
        if okNum and numTabs and numTabs > 0 then
            maxTabs = numTabs
        end
    end
    if maxTabs == 0 then
        maxTabs = 4
    end

    local bestName, bestPoints = nil, -1
    for tab = 1, maxTabs do
        local name, pts = NormalizeTalentTabInfo(tab, group)
        if name and name ~= "" and pts > bestPoints then
            bestPoints = pts
            bestName = name
        end
    end
    return bestName
end

local function GetPrimaryTreeSpecName()
    if type(GetPrimaryTalentTree) ~= "function" then return nil end
    local treeIndex = GetPrimaryTalentTree()
    if not treeIndex or treeIndex == 0 then return nil end
    local _, _, classID = UnitClass("player")
    local classSpecs = classID and CLASS_FALLBACK_SPECS[classID]
    return classSpecs and classSpecs[treeIndex] or nil
end

local function GetCurrentSpecName()
    -- API estilo Retail
    if GetSpecialization and GetSpecializationInfo then
        local specIndex = GetSpecialization(false, false, GetActiveSpecGroup and GetActiveSpecGroup() or nil) or GetSpecialization()
        if specIndex then
            local _, specName = GetSpecializationInfo(specIndex)
            if specName and specName ~= "" then
                lastSpecName = specName
                return specName
            end
        end
        -- Respaldo de loot spec (MoP+)
        if GetLootSpecialization and GetSpecializationInfoByID then
            local lootSpecID = GetLootSpecialization()
            if lootSpecID and lootSpecID > 0 then
                local _, specName = GetSpecializationInfoByID(lootSpecID)
                if specName and specName ~= "" then
                    lastSpecName = specName
                    return specName
                end
            end
        end
    end
    -- Respaldo via inspect (MoP+)
    if GetInspectSpecialization and GetSpecializationInfoByID then
        local ok, specID = pcall(GetInspectSpecialization, "player")
        if ok and specID and specID > 0 then
            local _, specName = GetSpecializationInfoByID(specID)
            if specName and specName ~= "" then
                lastSpecName = specName
                return specName
            end
        end
    end
    -- Classic/MoP: indice de arbol principal (mas confiable)
    local primaryTreeSpec = GetPrimaryTreeSpecName()
    if primaryTreeSpec and primaryTreeSpec ~= "" then
        lastSpecName = primaryTreeSpec
        return primaryTreeSpec
    end

    local talentSpec = GetTalentTabSpecName()
    if talentSpec and talentSpec ~= "" then
        lastSpecName = talentSpec
        return talentSpec
    end

    -- Respaldo final: ultimo nombre conocido o nombre de clase
    if lastSpecName and lastSpecName ~= "" then
        return lastSpecName
    end
    local _, className = UnitClass("player")
    return className
end
-- Resuelve una especializacion valida usando la actual, la ultima conocida o el fallback de clase
local function ResolveSpecName(preferred)
    if preferred and preferred ~= "" then
        lastSpecName = preferred
        return preferred
    end
    return GetCurrentSpecName()
end

local function GetCurrentSpecID()
    if GetSpecialization and GetSpecializationInfo then
        local specIndex = GetSpecialization(false, false, GetActiveSpecGroup and GetActiveSpecGroup() or nil) or GetSpecialization()
        if specIndex then
            local specID = GetSpecializationInfo(specIndex)
            if specID and specID > 0 then
                return specID
            end
        end
        if GetLootSpecialization then
            local lootSpecID = GetLootSpecialization()
            if lootSpecID and lootSpecID > 0 then
                return lootSpecID
            end
        end
    end
    if GetInspectSpecialization then
        local ok, specID = pcall(GetInspectSpecialization, "player")
        if ok and specID and specID > 0 then
            return specID
        end
    end
    local _, _, classID = UnitClass("player")
    local treeIndex = GetPrimaryTalentTree and GetPrimaryTalentTree() or nil
    if classID and treeIndex and SPEC_ID_BY_CLASS[classID] and SPEC_ID_BY_CLASS[classID][treeIndex] then
        return SPEC_ID_BY_CLASS[classID][treeIndex].id
    end
    return nil
end

local function ResolveSpecID(preferredName)
    local specID = GetCurrentSpecID()
    if specID then return specID end
    if preferredName and preferredName ~= "" then
        return GetSpecIDFromName(preferredName)
    end
    local resolvedName = ResolveSpecName()
    return GetSpecIDFromName(resolvedName)
end

local function AddTalentTabNames(specs, seen)
    local group = (type(GetActiveTalentGroup) == "function" and GetActiveTalentGroup()) or 1
    local maxTabs = 0
    if type(GetNumTalentTabs) == "function" then
        local okNum, numTabs = pcall(GetNumTalentTabs)
        if okNum and numTabs and numTabs > 0 then
            maxTabs = numTabs
        end
    end
    if maxTabs == 0 then
        maxTabs = 4
    end

    for tab = 1, maxTabs do
        local name = NormalizeTalentTabInfo(tab, group)
        if name and name ~= "" and not seen[name] then
            table.insert(specs, name)
            seen[name] = true
        end
    end
end

-- Devuelve la lista de especializaciones disponibles para el jugador actual (nombres)
local function GetAvailableSpecs()
    local specs = {}
    local seen = {}
    -- API por clase (Retail/MoP+)
    if GetNumSpecializationsForClassID and GetSpecializationInfoForClassID then
        local _, _, classID = UnitClass("player")
        local okNum, num = pcall(GetNumSpecializationsForClassID, classID)
        if okNum and num and num > 0 then
            for i = 1, num do
                local _, name = GetSpecializationInfoForClassID(classID, i)
                if name and name ~= "" and not seen[name] then
                    table.insert(specs, name)
                    seen[name] = true
                end
            end
        end
    end
    -- API Retail/MoP
    if GetNumSpecializations and GetSpecializationInfo then
        local ok, num = pcall(GetNumSpecializations)
        if ok and num and num > 0 then
            for i = 1, num do
                local _, name = GetSpecializationInfo(i)
                if name and name ~= "" and not seen[name] then
                    table.insert(specs, name)
                    seen[name] = true
                end
            end
        end
    end
    -- API de talentos (estilo Classic)
    if #specs == 0 then
        AddTalentTabNames(specs, seen)
    end
    local className = select(1, UnitClass("player"))
    local classNameLower = className and string.lower(className) or ""
    if lastSpecName and lastSpecName ~= "" and string.lower(lastSpecName) ~= classNameLower and not seen[lastSpecName] then
        table.insert(specs, lastSpecName)
        seen[lastSpecName] = true
    end
    local _, _, classID = UnitClass("player")
    if classID and CLASS_FALLBACK_SPECS[classID] then
        for _, name in ipairs(CLASS_FALLBACK_SPECS[classID]) do
            if not seen[name] then
                table.insert(specs, name)
                seen[name] = true
            end
        end
    end
    return specs
end
addonTable.GetAvailableSpecs = GetAvailableSpecs
local function GetAvailableSpecsWithIDs()
    BuildSpecMaps()
    local specs = {}
    local seen = {}
    local _, _, classID = UnitClass("player")
    local lang = GetAddonLanguage()
    if classID and SPEC_ID_BY_CLASS[classID] and lang ~= "AUTO" then
        for _, spec in ipairs(SPEC_ID_BY_CLASS[classID]) do
            local name = GetSpecNameFromID(spec.id) or spec.names[1]
            if spec.id and not seen[spec.id] then
                table.insert(specs, { id = spec.id, name = name })
                seen[spec.id] = true
            end
        end
        return specs
    end
    if GetNumSpecializationsForClassID and GetSpecializationInfoForClassID and classID then
        local okNum, num = pcall(GetNumSpecializationsForClassID, classID)
        if okNum and num and num > 0 then
            for i = 1, num do
                local specID, name = GetSpecializationInfoForClassID(classID, i)
                if specID and name and name ~= "" and not seen[specID] then
                    table.insert(specs, { id = specID, name = name })
                    seen[specID] = true
                end
            end
        end
    elseif GetNumSpecializations and GetSpecializationInfo then
        local okNum, num = pcall(GetNumSpecializations)
        if okNum and num and num > 0 then
            for i = 1, num do
                local specID, name = GetSpecializationInfo(i)
                if specID and name and name ~= "" and not seen[specID] then
                    table.insert(specs, { id = specID, name = name })
                    seen[specID] = true
                end
            end
        end
    elseif classID and SPEC_ID_BY_CLASS[classID] then
        for _, spec in ipairs(SPEC_ID_BY_CLASS[classID]) do
            local name = GetSpecNameFromID(spec.id) or spec.names[1]
            if spec.id and not seen[spec.id] then
                table.insert(specs, { id = spec.id, name = name })
                seen[spec.id] = true
            end
        end
    end
    return specs
end
addonTable.GetAvailableSpecsWithIDs = GetAvailableSpecsWithIDs
addonTable.GetSpecIDFromName = GetSpecIDFromName
addonTable.GetSpecNameFromID = GetSpecNameFromID

MigrateSpecIDs = function()
    BuildSpecMaps()
    if not CurrentCharDB then return false end
    local updated = false
    for id, data in pairs(CurrentCharDB) do
        if type(id) == "number" and type(data) == "table" then
            if not data.specID and data.spec and data.spec ~= "" then
                local specID = GetSpecIDFromName(data.spec)
                if specID then
                    data.specID = specID
                    updated = true
                end
            end
            if data.specID then
                local name = GetSpecNameFromID(data.specID)
                if name and name ~= "" and data.spec ~= name then
                    data.spec = name
                    updated = true
                end
            end
        end
    end
    return updated
end
local function HandleSpecChange(event, unit)
    if unit and unit ~= "player" then return end
    lastSpecName = nil
    lastSpecName = ResolveSpecName()
    LootHunter_RefreshUI()
end
local function HandleLootEvent(event)
    if PendingCoinReminders and next(PendingCoinReminders) then
        LogCoinDebug(string.format("Event %s received. Checking pending coin timers.", event))
    end
    -- Al abrir el botín, si vemos items de la lista, disparar alerta DROP inmediata
    if CurrentCharDB and GetNumLootItems then
        local num = GetNumLootItems()
        for slot = 1, num do
            local link = GetLootSlotLink(slot)
            local itemID = link and tonumber(link:match("item:(%d+):"))
            if itemID and CurrentCharDB[itemID] and CurrentCharDB[itemID].status == 0 then
                ShowDropAlert(itemID, CurrentCharDB[itemID])
                LootHunter_RefreshUI()
            end
        end
    end
    TriggerLootReadyTimers()
end
-- === LÓGICA DE MONEDA (COIN REMINDER) ===
local function TrimString(str)
    if not str then return nil end
    return (str:gsub("^%s+", ""):gsub("%s+$", ""))
end
local function ItemMatchesBossSource(itemData, bossName)
    if not itemData or not bossName then return false end
    local source = itemData.boss
    if not source or source == "" or source == L["UNKNOWN_SOURCE"] then return false end
    local srcLower = string.lower(source)
    local bossLower = string.lower(bossName)
    if srcLower:find(bossLower, 1, true) then return true end
    for token in srcLower:gmatch("[^/]+") do
        token = TrimString(token)
        if token and token ~= "" then
            if token:find(bossLower, 1, true) or bossLower:find(token, 1, true) then
                return true
            end
            for dash in token:gmatch("[^%-]+") do
                dash = TrimString(dash)
                if dash and dash ~= "" then
                    if dash:find(bossLower, 1, true) or bossLower:find(dash, 1, true) then
                        return true
                    end
                end
            end
        end
    end
    return false
end
local function ProcessCoinReminder(key)
    local entry = PendingCoinReminders[key]
    if not entry or not CurrentCharDB then return end
    if entry.dropSeen then
        LogCoinDebug(string.format("Coin reminder for %s skipped because drop was seen.", entry.boss or "Unknown"))
        return
    end
    PendingCoinReminders[key] = nil
    local stillMissing = {}
    for _, id in ipairs(entry.items) do
        local data = CurrentCharDB[id]
        if data and data.status == 0 then
            table.insert(stillMissing, data)
        end
    end
    if #stillMissing == 0 then 
        LogCoinDebug(string.format("Coin reminder for %s canceled: no items pending.", entry.boss or "Unknown"))
        return 
    end
    if LootHunterDB.settings.coinReminder.visualAlert then
        local rawText = string.format(L["COIN_REMINDER_RAID_MSG"], entry.boss)
        local visualText = (addonTable.CreateGradient and addonTable.CreateGradient(rawText, 1, 0.85, 0.35, 1, 0.75, 0)) or rawText
        local msg = ICON_DIAMOND .. visualText .. ICON_DIAMOND
        local chatFmt = L["COIN_REMINDER_RAID_CHAT"] or L["COIN_REMINDER_RAID_MSG"]
        local chatMsg = string.format(chatFmt, entry.boss)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(chatMsg)
        else
            print(chatMsg)
        end
        EnqueueAlert(ALERT_DEFAULT_DURATION, ALERT_PRIORITY_SECONDARY, function()
            if addonTable.ShowAlert then
                addonTable.ShowAlert(msg, 1, 0.85, 0)
            end
            if addonTable.FlashScreen then
                addonTable.FlashScreen("YELLOW")
            end
        end)
        LogAlertDebug("Coin reminder alert shown for " .. (entry.boss or "Unknown"))
    end
    -- Alertas visuales y sonoras
    if LootHunterDB.settings.coinReminder.soundEnabled then
        PlaySound(LootHunterDB.settings.coinReminder.soundFile or 12867) -- Sonido de alerta
    end
    print(string.format(L["COIN_REMINDER_CHAT_MSG"], entry.boss))
    if addonTable.LogDebug then
        local names = {}
        for _, data in ipairs(stillMissing) do
            table.insert(names, data.name or tostring(data.id))
        end
        addonTable.LogDebug("|cffffff00[Loot Hunter] Coin reminder triggered: " .. entry.boss .. " -> " .. table.concat(names, ", ") .. "|r")
    end
end
local function StartCoinReminderTimer(key, reason, delay)
    local entry = PendingCoinReminders[key]
    if not entry or entry.timerStarted then return end
    if entry.dropSeen or entry.blockCoin then
        LogCoinDebug(string.format("Coin timer blocked for %s (reason: %s).", entry.boss or "Unknown", reason or "unknown"))
        return
    end
    if entry.deferStartUntil and GetTime() < entry.deferStartUntil then
        LogCoinDebug("Coin timer deferred until boss pre-warning completes.")
        return
    end
    entry.timerStarted = true
    delay = delay or COIN_REMINDER_DELAY
    LogCoinDebug(string.format("Coin timer started for %s (reason: %s, delay: %.1fs)", entry.boss or "Unknown", reason or "unspecified", delay))
    C_Timer.After(delay, function()
        LogCoinDebug(string.format("Coin timer finished for %s. Processing reminder.", entry.boss or "Unknown"))
        ProcessCoinReminder(key)
    end)
end
local function StartTwoStageCoinReminder(key)
    local entry = PendingCoinReminders[key]
    if not entry or entry.timerStarted then return end
    if entry.dropSeen then
        LogCoinDebug(string.format("Two-stage reminder for %s blocked because drop was seen.", entry.boss or "Unknown"))
        return
    end
    local waitWindow = GetCoinReminderWait()
    if entry.deathTime and (GetTime() - entry.deathTime) < waitWindow then
        LogCoinDebug(string.format("Two-stage reminder for %s delayed until %.0fs after boss death.", entry.boss or "Unknown", waitWindow))
        return
    end
    if entry.deferStartUntil and GetTime() < entry.deferStartUntil then
        LogCoinDebug("Two-stage coin reminder deferred until boss pre-warning completes.")
        return
    end
    entry.timerStarted = true
    entry.isTwoStage = true -- Marca para permitir interrupción si cae loot
    LogCoinDebug(string.format("Starting 2-stage timer for %s (wait %.0fs then 10s pre-warn + 35s final)", entry.boss or "Unknown", waitWindow))
    if entry.skipPrewarn then
        C_Timer.After(35, function()
            if PendingCoinReminders[key] then
                LogCoinDebug(string.format("2-stage timer finished for %s (skip pre-warn). Processing reminder.", entry.boss or "Unknown"))
                ProcessCoinReminder(key)
            end
        end)
        return
    end
    -- Fase 1: 10 segundos para aviso de texto
    C_Timer.After(10, function()
        local e = PendingCoinReminders[key]
        if e then
            if LootHunterDB.settings.coinReminder.preWarning then
                local msg = string.format(L["COIN_PRE_WARNING"] or "|cff00ff00[Loot Hunter]|r %s might have your loot. Get your coin ready!", e.boss)
                if addonTable.ShowPreWarningFrame then
                    EnqueueAlert(6, ALERT_PRIORITY_PREWARN, function()
                        addonTable.ShowPreWarningFrame(msg, 6)
                        if PREWARN_SOUND_ID then PlaySound(PREWARN_SOUND_ID, "Master") end
                    end)
                else
                    print(msg)
                    if PREWARN_SOUND_ID then PlaySound(PREWARN_SOUND_ID, "Master") end
                end
            end
            -- Fase 2: 35 segundos más para alerta completa
            C_Timer.After(35, function()
                if PendingCoinReminders[key] then
                    LogCoinDebug(string.format("2-stage timer finished for %s. Processing reminder.", e.boss or "Unknown"))
                    ProcessCoinReminder(key)
                end
            end)
        end
    end)
end
local function ActivatePendingForBonusRoll(reason)
    for key, entry in pairs(PendingCoinReminders) do
        if entry and not entry.timerStarted then
            local waitWindow = GetCoinReminderWait()
            if entry.dropSeen then
                LogCoinDebug(string.format("Bonus roll activation ignored for %s because drop was seen.", entry.boss or "Unknown"))
            elseif entry.deathTime and (GetTime() - entry.deathTime) >= waitWindow then
                LogCoinDebug(string.format("Bonus roll activation triggering reminder for %s.", entry.boss or "Unknown"))
                StartCoinReminderTimer(key, "bonus_roll_activate", 0)
            else
                LogCoinDebug(string.format("Bonus roll activation deferred for %s (waiting %.0fs no-drop window).", entry.boss or "Unknown", waitWindow))
            end
        end
    end
end
-- Buscar la entrada de recordatorio de moneda que contenga un itemID
local function FindReminderKeyForItem(itemID)
    if not itemID then return nil end
    for key, entry in pairs(PendingCoinReminders) do
        if entry and entry.items then
            for _, pendingID in ipairs(entry.items) do
                if pendingID == itemID then
                    return key
                end
            end
        end
    end
    return nil
end
local function RemoveItemFromReminder(itemID)
    local key = FindReminderKeyForItem(itemID)
    if not key then return end
    local entry = PendingCoinReminders[key]
    if not entry or not entry.items then return end
    local remaining = {}
    for _, pendingID in ipairs(entry.items) do
        if pendingID ~= itemID then
            table.insert(remaining, pendingID)
        end
    end
    entry.items = remaining
    if #remaining == 0 then
        PendingCoinReminders[key] = nil
    end
end
local function MarkDropSeen(itemID, reason)
    local key = FindReminderKeyForItem(itemID)
    if not key then return end
    local entry = PendingCoinReminders[key]
    if not entry then return end
    entry.dropSeen = true
    entry.blockCoin = true
    entry.dropSeenAt = GetTime()
    LogCoinDebug(string.format("Drop seen for item %d (reason: %s) - blocking coin reminder.", itemID, reason or "unknown"))
end
local function ShowDropAlert(itemID, itemData)
    if not itemID and itemData and itemData.id then
        itemID = itemData.id
    end
    if not itemID then return end
    itemData = itemData or (CurrentCharDB and CurrentCharDB[itemID])
    if not itemData then return end
    -- Actualiza estado en la DB
    if CurrentCharDB and CurrentCharDB[itemID] then
        CurrentCharDB[itemID].status = 1
        CurrentCharDB[itemID].lastState = "drop"
    end
    lastAnnouncedRollItemID = itemID
    lastAnnouncedRollTime = GetTime()
    MarkDropSeen(itemID, "drop_alert")
    -- Auto-reset del estado DROP tras 45s si sigue pendiente
    C_Timer.After(45, function()
        if CurrentCharDB and CurrentCharDB[itemID] and CurrentCharDB[itemID].status == 1 then
            CurrentCharDB[itemID].status = 0
            LootHunter_RefreshUI()
        end
    end)
    local now = GetTime()
    if LastDropAlert[itemID] and (now - LastDropAlert[itemID] < 2) then
        return
    end
    LastDropAlert[itemID] = now
    local dropTitle = CreateGradient(L["DROP_ALERT_TITLE"], 1, 0.7, 0.2, 1, 0.45, 0)
    local dropHeader = string.format("%s %s %s", ICON_DIAMOND, dropTitle, ICON_DIAMOND)
    local dropItemLine = string.format("%s!", itemData.link or itemData.name or tostring(itemID))
    local _, instanceType = IsInInstance()
    local showPrompt = (instanceType == "raid")
    local dropPrompt = showPrompt and CreateGradient(L["DROP_ALERT_PROMPT"], 1, 0.85, 0.35, 1, 0.75, 0) or nil
    local alertText = dropHeader .. "\n" .. dropItemLine .. (dropPrompt and ("\n" .. dropPrompt) or "")
    EnqueueAlert(ALERT_DEFAULT_DURATION, ALERT_PRIORITY_PRIMARY, function()
        if addonTable.FlashScreen then addonTable.FlashScreen("ORANGE") end
        if addonTable.ShowAlert then
            addonTable.ShowAlert(alertText, 1, 0.55, 0.05)
        end
        PlaySound(12867)
    end)
    if L["DROP_CHAT_MSG"] then
        print(string.format(L["DROP_CHAT_MSG"], itemData.link or itemData.name or tostring(itemID)))
    end
    local displayName = itemData.link or itemData.name or tostring(itemID)
    LogAlertDebug(string.format("DROP alert shown for item %s (%s)", tostring(itemID), displayName))
end
-- Buffs de moneda MoP: Seal of Power (LFR), Seal of Fate (Normal)
local bonusSpellIDs = {126938, 128362}
local function HasBonusRollBuff()
    for i=1, 40 do
        -- UnitBuff devuelve varios valores, solo necesitamos spellID (10mo valor)
        local _, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", i)
        if not spellID then break end -- No hay mas buffs
        for _, id in ipairs(bonusSpellIDs) do
            if spellID == id then
                return true
            end
        end
    end
    return false
end
local function HandleBonusRollActivate(event, ...)
    LogCoinDebug("|cff00ffff[Coin Debug]|r BONUS_ROLL_ACTIVATE received")
    LogCoinDebug(string.format("Bonus roll window visible: %s", tostring(IsBonusRollWindowVisible())))
    -- Iniciar secuencia de 2 fases (10s aviso -> 35s alerta)
    ActivatePendingForBonusRoll("bonus_roll_activate")
end
local function HandleUnitAura(event, unit)
    if unit ~= "player" then return end
    if HasBonusRollBuff() then
        LogCoinDebug("|cff00ffff[Coin Debug]|r Bonus Roll buff detected")
        ActivatePendingForBonusRoll("bonus_roll_buff")
    end
end
local function IsBonusRollWindowVisible()
    local frame = _G.BonusRollFrame
    return frame and frame:IsShown()
end
local function ScheduleCoinReminder(encounterID, bossName, forceRaid, forcePreWarn)
    if not CurrentCharDB or not bossName or bossName == "" or not (LootHunterDB and LootHunterDB.settings and LootHunterDB.settings.coinReminder.enabled) then return end
    local _, instanceType = IsInInstance()
    LastCoinReminderBoss = bossName
    local instanceName = (GetInstanceInfo and select(1, GetInstanceInfo())) or nil
    local reminderDelay = GetCoinReminderWait()
    LogCoinDebug(string.format("User-configured coin wait set to %.0fs for %s", reminderDelay, bossName))
    local pendingItems = {}
    for id, data in pairs(CurrentCharDB) do
        if type(id) == "number" and type(data) == "table" and data.status == 0 then
            if ItemMatchesBossSource(data, bossName) then
                table.insert(pendingItems, id)
            end
        end
    end
    if #pendingItems == 0 then 
        if instanceName and instanceName ~= "" then
            local instanceLower = string.lower(instanceName)
            local hasInstanceItems = false
            for id, data in pairs(CurrentCharDB) do
                if type(id) == "number" and type(data) == "table" and data.boss and data.boss ~= "" and data.boss ~= L["UNKNOWN_SOURCE"] then
                    local srcLower = string.lower(data.boss)
                    if srcLower:find(instanceLower, 1, true) then
                        hasInstanceItems = true
                        break
                    end
                    local instPart = srcLower:match("^(.-)%s*%-%s*.+$")
                    if instPart and instPart:find(instanceLower, 1, true) then
                        hasInstanceItems = true
                        break
                    end
                end
            end
            if hasInstanceItems and LootHunterDB and LootHunterDB.settings
                and LootHunterDB.settings.lootAlerts
                and LootHunterDB.settings.lootAlerts.bossNoItems then
                local coloredBoss = string.format("|cffff0000%s|r", bossName)
                print(string.format(L["COIN_NO_ITEMS_BOSS"], coloredBoss))
                LogCoinDebug(string.format("Boss %s has no items in list (instance: %s).", bossName, instanceName))
            end
        else
            LogCoinDebug(string.format("Skipping boss-no-items message for %s: instance name missing.", bossName))
        end
        LogCoinDebug(string.format("No pending items matched %s. No reminder scheduled.", bossName))
        return 
    end
    if not forceRaid and instanceType ~= "raid" then
        LogCoinDebug(string.format("Skipping coin reminder for %s because instance type is %s.", bossName, tostring(instanceType)))
        return
    end
    local itemList = {}
    for _, pendingID in ipairs(pendingItems) do
        local data = CurrentCharDB[pendingID]
        table.insert(itemList, data and (data.name or tostring(pendingID)) or tostring(pendingID))
    end
    LogCoinDebug(string.format("Coin logic starting for %s with %d pending items (%s)", bossName, #pendingItems, table.concat(itemList, ", ")))
    local key = string.lower(bossName) .. ":" .. tostring(encounterID or 0)
    PendingCoinReminders[key] = {
        boss = bossName,
        encounterID = encounterID,
        items = pendingItems,
        timerStarted = false,
        dropSeen = false,
        blockCoin = false,
        deathTime = GetTime(),
    }
    if LootHunterDB.settings.coinReminder.preWarning then
        C_Timer.After(3, function()
            local entry = PendingCoinReminders[key]
            if not entry then return end
            local windowVisible = IsBonusRollWindowVisible()
            if windowVisible or forcePreWarn then
                LogCoinDebug(string.format("Pre-warning window visible for %s: %s", entry.boss or "Unknown", tostring(windowVisible)))
                local msg = string.format(L["COIN_PRE_WARNING"] or "|cff00ff00[Loot Hunter]|r %s might have your loot. Get your coin ready!", entry.boss)
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    DEFAULT_CHAT_FRAME:AddMessage(msg)
                else
                    print(msg)
                end
                if addonTable.ShowPreWarningFrame then
                    EnqueueAlert(6, ALERT_PRIORITY_PREWARN, function()
                        addonTable.ShowPreWarningFrame(msg, 6)
                        if PREWARN_SOUND_ID then PlaySound(PREWARN_SOUND_ID, "Master") end
                    end)
                else
                    if PREWARN_SOUND_ID then PlaySound(PREWARN_SOUND_ID, "Master") end
                end
                LogAlertDebug("Pre-warning shown for " .. (entry.boss or "Unknown"))
            end
        end)
    end
    local itemNames = {}
    for _, pendingID in ipairs(pendingItems) do
        local data = CurrentCharDB[pendingID]
        table.insert(itemNames, data and (data.name or tostring(pendingID)) or tostring(pendingID))
    end
    LogCoinDebug(string.format("Scheduled coin reminder for %s with %d pending items: %s", bossName, #pendingItems, table.concat(itemNames, ", ")))
    LogCoinDebug(string.format("Scheduling no-drop timer for %s with wait %.0fs (user value).", bossName, reminderDelay))
    C_Timer.After(reminderDelay, function()
        local entry = PendingCoinReminders[key]
        if not entry then return end
        if entry.dropSeen then
            LogCoinDebug(string.format("No-drop timer skipped for %s because drop was seen.", entry.boss or "Unknown"))
            return
        end
        if not IsBonusRollWindowVisible() then
            LogCoinDebug(string.format("No-drop timer for %s fired but Bonus Roll window is not visible, skipping reminder.", entry.boss or "Unknown"))
            return
        end
        LogCoinDebug(string.format("No-drop timer (%.0fs) expired for %s. Triggering reminder.", reminderDelay, entry.boss or "Unknown"))
        StartCoinReminderTimer(key, "no_drop", 0)
    end)
end
TriggerLootReadyTimers = function()
    for key, entry in pairs(PendingCoinReminders) do
        if entry then
            if not entry.timerStarted then
                LogCoinDebug(string.format("Loot event ready/opened for %s (drop seen=%s).", entry.boss or "Unknown", tostring(entry.dropSeen)))
            elseif entry.isTwoStage then
                -- Si abres el loot durante la espera larga, procesar inmediatamente
                LogCoinDebug("Loot opened during 2-stage wait. Processing immediately.")
                ProcessCoinReminder(key)
            end
        end
    end
end
local function TriggerLootActivityTimerForItemID(itemID)
    if not itemID then return end
    itemID = tonumber(itemID)
    if not itemID then return end
    for key, entry in pairs(PendingCoinReminders) do
        local match = false
        for _, pendingID in ipairs(entry.items) do
            if pendingID == itemID then match = true; break end
        end
        if match then
            LogCoinDebug(string.format("Loot activity detected for tracked itemID %d.", itemID))
            MarkDropSeen(itemID, "loot_activity")
        end
    end
end
-- Ayuda visual para boton manual
local function ShowCoinReminderVisual(bossName)
    local title = CreateGradient(L["COIN_REMINDER_ALERT_TITLE"], 1, 0.85, 0.35, 1, 0.75, 0)
    local prompt = CreateGradient(L["COIN_REMINDER_ALERT_PROMPT"], 1, 0.85, 0.35, 1, 0.75, 0)
    local text = string.format("%s %s %s\n%s", ICON_TRIANGLE, title, ICON_TRIANGLE, prompt)
    EnqueueAlert(ALERT_DEFAULT_DURATION, ALERT_PRIORITY_SECONDARY, function()
        if addonTable.ShowAlert then
            addonTable.ShowAlert(text, 1, 0.9, 0.15)
        end
        if addonTable.FlashScreen then
            addonTable.FlashScreen("YELLOW")
        end
        local soundID = (SOUNDKIT and SOUNDKIT.UI_BONUS_ROLL_START) or 12867
        PlaySound(soundID)
    end)
    LogAlertDebug("Coin reminder manual alert shown for " .. (bossName or "Unknown"))
end
addonTable.ShowCoinReminderVisual = ShowCoinReminderVisual
-- Manejadores de Boss Kill (ahora que ScheduleCoinReminder está definido)
local function HandleBossKill(event, encounterID, bossName)
    if not bossName or bossName == "" then return end
    LogCoinDebug(string.format("BOSS_KILL detected: %s (encounterID=%s)", bossName or "?", tostring(encounterID)))
    ScheduleCoinReminder(encounterID, bossName)
end
local function HandleEncounterEnd(event, encounterID, bossName, _, endStatus)
    if endStatus == 1 then -- 1 significa éxito
        if not bossName or bossName == "" then return end
        LogCoinDebug(string.format("ENCOUNTER_END success detected: %s (encounterID=%s)", bossName or "?", tostring(encounterID)))
        ScheduleCoinReminder(encounterID, bossName)
    end
end
-- Patrones de loot multi-idioma basados en GlobalStrings
local function BuildSelfLootPatterns()
    local patterns = {}
    local formats = {
        LOOT_ITEM_PUSHED_SELF,
        LOOT_ITEM_SELF,
        LOOT_ITEM_SELF_MULTIPLE,
    }
    for _, fmt in ipairs(formats) do
        if type(fmt) == "string" and fmt ~= "" then
            local pattern = "^" .. fmt:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)") .. "$"
            table.insert(patterns, pattern)
        end
    end
    return patterns
end

local function BuildOtherLootPatterns()
    local patterns = {}
    local formats = {
        LOOT_ITEM_PUSHED,
        LOOT_ITEM,
        LOOT_ITEM_MULTIPLE,
    }
    for _, fmt in ipairs(formats) do
        if type(fmt) == "string" and fmt ~= "" then
            local pattern = "^" .. fmt:gsub("%%s", "(.-)", 1):gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)") .. "$"
            table.insert(patterns, pattern)
        end
    end
    return patterns
end

local selfLootPatterns = BuildSelfLootPatterns()
local otherLootPatterns = BuildOtherLootPatterns()
local rollResultPattern = "^" .. (RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)"):gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)") .. "$"
local function IsPlayerRollMessage(msg)
    if type(msg) ~= "string" then return false end
    local name = msg:match(rollResultPattern)
    if not name then return false end
    local playerName = UnitName("player")
    if name == playerName then return true end
    local you = _G.YOU or "You"
    if name == you then return true end
    local youCaps = _G.YOU_CAPS
    if youCaps and name == youCaps then return true end
    return false
end
local function ShouldTriggerOtherWon(itemID)
    if not lastPlayerRollItemID or lastPlayerRollItemID ~= itemID then return false end
    if not lastPlayerRollTime then return false end
    if not lastAnnouncedRollItemID or lastAnnouncedRollItemID ~= itemID then return false end
    if not lastAnnouncedRollTime then return false end
    if lastPlayerRollTime < lastAnnouncedRollTime then return false end
    return (GetTime() - lastPlayerRollTime) <= ROLL_TRACK_WINDOW
end

local function HandleChatSystem(event, msg, ...)
    if not IsPlayerRollMessage(msg) then return end
    lastPlayerRollTime = GetTime()
    if lastAnnouncedRollItemID and lastAnnouncedRollTime
        and (lastPlayerRollTime - lastAnnouncedRollTime) <= ROLL_TRACK_WINDOW then
        lastPlayerRollItemID = lastAnnouncedRollItemID
    else
        lastPlayerRollItemID = nil
    end
end
local function HandleChatLoot(event, msg, ...)
    if not CurrentCharDB or type(msg) ~= "string" then return end
    local itemLink, playerName
    local isMine = false
    -- Comprueba si el jugador mismo despojó el objeto
    for _, pattern in ipairs(selfLootPatterns) do
        local capturedItemLink = msg:match(pattern)
        if capturedItemLink then
            itemLink = capturedItemLink
            isMine = true
            break
        end
    end
    if not itemLink then
        -- Comprueba si alguien más despojó el objeto
        for _, pattern in ipairs(otherLootPatterns) do
            local capturedPlayer, capturedItemLink2 = msg:match(pattern)
            if capturedPlayer and capturedItemLink2 then
                playerName = capturedPlayer
                itemLink = capturedItemLink2
                isMine = (playerName == UnitName("player"))
                break
            end
        end
    end
    if not itemLink then return end
    local id = tonumber(string.match(itemLink, "item:(%d+):"))
    if not id then return end
    TriggerLootActivityTimerForItemID(id)
    if CurrentCharDB[id] then
        local itemData = CurrentCharDB[id]
        if isMine then
            if itemData.status ~= 2 then
                itemData.status = 2
                itemData.lastState = "won"
                LootHunter_RefreshUI()
                RemoveItemFromReminder(id)
                if LootHunterDB.settings.lootAlerts.itemWon then
                    local winTitle = CreateGradient(L["WIN_ALERT_TITLE"], 0.35, 1, 0.35, 0.65, 1, 0.65)
                    local winDesc = CreateGradient(L["WIN_ALERT_DESC"], 0.35, 1, 0.35, 0.65, 1, 0.65)
                    local winBanner = string.format("%s %s %s", ICON_STAR, winTitle, ICON_STAR)
                    local itemLine = itemData.link or itemData.name or "?"
                    EnqueueAlert(ALERT_DEFAULT_DURATION, ALERT_PRIORITY_PRIMARY, function()
                        if addonTable.FlashScreen then addonTable.FlashScreen("WIN") end
                        if addonTable.ShowAlert then
                            addonTable.ShowAlert(string.format("%s\n%s\n%s", winBanner, winDesc, itemLine), 0, 1, 0)
                        end
                        PlaySound(12891)
                    end)
                    print(string.format(L["CONGRATS_CHAT_MSG"], itemData.link))
                    LogAlertDebug("WIN alert shown for item " .. tostring(id))
                end
            end
        else
            if itemData.status == 0 and ShouldTriggerOtherWon(id) then
                itemData.status = 1 
                LootHunter_RefreshUI()
                if LootHunterDB.settings.lootAlerts.itemSeen then
                    -- Solo mensaje local cuando otro jugador lo obtiene; sin alerta visual/sonora.
                    local looter = playerName or L["UNKNOWN_SOURCE"]
                    local coloredLooter = string.format("|cffff0000%s|r", looter)
                    local otherMsg = string.format(L["DROP_OTHER_CHAT_MSG"], itemData.link or itemData.name or "?", coloredLooter)
                    print(otherMsg)
                    if addonTable.ShowPreWarningFrame then
                        EnqueueAlert(6, ALERT_PRIORITY_PRIMARY, function()
                            addonTable.ShowPreWarningFrame(otherMsg, 6, false, true)
                            if addonTable.PlayOtherWonSound then addonTable.PlayOtherWonSound() end
                            if addonTable.FlashScreen then addonTable.FlashScreen("RED") end
                        end)
                    else
                        if addonTable.PlayOtherWonSound then addonTable.PlayOtherWonSound() end
                        if addonTable.FlashScreen then addonTable.FlashScreen("RED") end
                    end
                    LogAlertDebug("OTHER_WON alert shown for item " .. tostring(id))
                    if LootHunterDB and LootHunterDB.settings and LootHunterDB.settings.coinReminder
                        and LootHunterDB.settings.coinReminder.enabled
                        and IsBonusRollWindowVisible() then
                        C_Timer.After(3, function()
                            if not IsBonusRollWindowVisible() then return end
                            local lostMsg = L["COIN_LOST_REMINDER"]
                            print(lostMsg)
                            if addonTable.ShowPreWarningFrame then
                                EnqueueAlert(6, ALERT_PRIORITY_PREWARN, function()
                                    addonTable.ShowPreWarningFrame(lostMsg, 6)
                                    if COIN_LOST_SOUND_ID then
                                        PlaySound(COIN_LOST_SOUND_ID, "Master")
                                    end
                                    LogAlertDebug("COIN_LOST_REMINDER alert shown for item " .. tostring(id))
                                    C_Timer.After(6, function()
                                        if IsBonusRollWindowVisible() then
                                            local followMsg = L["COIN_LOST_REMINDER_FOLLOWUP"]
                                            print(followMsg)
                                            EnqueueAlert(6, ALERT_PRIORITY_PREWARN, function()
                                                addonTable.ShowPreWarningFrame(followMsg, 6)
                                                if COIN_LOST_SOUND_ID then
                                                    PlaySound(COIN_LOST_SOUND_ID, "Master")
                                                end
                                                LogAlertDebug("COIN_LOST_REMINDER_FOLLOWUP alert shown for item " .. tostring(id))
                                            end)
                                        end
                                    end)
                                end)
                            else
                                if COIN_LOST_SOUND_ID then
                                    PlaySound(COIN_LOST_SOUND_ID, "Master")
                                end
                            end
                        end)
                        LogCoinDebug("Bonus roll available after another player won your item.")
                    end
                    lastPlayerRollItemID = nil
                    RemoveItemFromReminder(id)
                    -- El recordatorio de moneda usa la alerta de pérdida si el bonus roll sigue activo
                end
                -- Auto reset tras 45s si sigue en estado drop
                C_Timer.After(45, function()
                    if CurrentCharDB and CurrentCharDB[id] and CurrentCharDB[id].status == 1 then
                        CurrentCharDB[id].status = 0
                        LootHunter_RefreshUI()
                    end
                end)
                C_Timer.After(120, function()
                    if CurrentCharDB[id] and CurrentCharDB[id].status == 1 then
                        CurrentCharDB[id].status = 0
                        LootHunter_RefreshUI()
                    end
                end)
            end
        end
    end
end
local function PlayOtherWonSound(force)
    if not force and not (LootHunterDB and LootHunterDB.settings and LootHunterDB.settings.lootAlerts.otherWonSound) then return end
    local originalVolume = nil
    local volumeCVar = "Sound_SFXVolume"
    if GetCVar and SetCVar then
        originalVolume = tonumber(GetCVar(volumeCVar) or 1)
        if originalVolume then
            local target = math.max(0, math.min(originalVolume * 0.5, 1))
            if target ~= originalVolume then
                SetCVar(volumeCVar, target)
                C_Timer.After(1, function()
                    SetCVar(volumeCVar, originalVolume)
                end)
            end
        end
    end
    local channel = "SFX"
    local ok = PlaySoundFile(OTHER_WON_SOUND, channel)
    if not ok then
        PlaySoundFile(OTHER_WON_SOUND, "Master")
    end
end
addonTable.PlayOtherWonSound = PlayOtherWonSound
-- Ayuda para verificar si el remitente es lider de raid o master looter en alertas de chat
local function NormalizeName(name)
    if not name or name == "" then return nil end
    return Ambiguate(name, "short")
end
local function IsLeaderName(name)
    local target = NormalizeName(name)
    if not target then return false end
    if UnitIsGroupLeader("player") and target == NormalizeName(UnitName("player")) then
        return true
    end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if NormalizeName(UnitName(unit)) == target and UnitIsGroupLeader(unit) then
                return true
            end
        end
    else
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            if NormalizeName(UnitName(unit)) == target and UnitIsGroupLeader(unit) then
                return true
            end
        end
    end
    return false
end
local function IsMasterLooterName(name)
    local target = NormalizeName(name)
    if not target then return false end
    if not GetLootMethod then return false end
    local method, mlParty, mlRaid = GetLootMethod()
    if method ~= "master" then return false end
    local unit
    if mlRaid and mlRaid > 0 then
        unit = "raid" .. mlRaid
    elseif mlParty then
        if mlParty == 0 then
            unit = "player"
        else
            unit = "party" .. mlParty
        end
    end
    if unit then
        return NormalizeName(UnitName(unit)) == target
    end
    return false
end
local function IsAssistantName(name)
    local target = NormalizeName(name)
    if not target or not IsInGroup() then return false end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if NormalizeName(UnitName(unit)) == target and UnitIsGroupAssistant(unit) then
                return true
            end
        end
    end
    return false
end
local function IsAuthorizedAnnounce(sender)
    return IsLeaderName(sender) or IsAssistantName(sender) or IsMasterLooterName(sender)
end
-- Detecta cuando alguien linkea items en chat (raid/party) para disparar alerta DROP y recordatorio
local function HandleChatLinkAnnounce(event, msg, sender, ...)
    if not CurrentCharDB or type(msg) ~= "string" then return end
    if not IsAuthorizedAnnounce(sender) then return end
    for link in msg:gmatch("|Hitem:[-%d:]+|h.-|h") do
        local itemID = tonumber(link:match("item:(%d+):"))
        if itemID and CurrentCharDB[itemID] and CurrentCharDB[itemID].status == 0 then
            ShowDropAlert(itemID, CurrentCharDB[itemID])
            LootHunter_RefreshUI()
        end
        if itemID then
            lastAnnouncedRollItemID = itemID
            lastAnnouncedRollTime = GetTime()
        end
    end
end
-- Detecta inicio de tirada Need/Greed (Group Loot en mazmorras)
local function HandleStartLootRoll(event, rollID, rollTime)
    if not rollID or not GetLootRollItemLink then return end
    local link = GetLootRollItemLink(rollID)
    if not link or not CurrentCharDB then return end
    local id = tonumber(string.match(link, "item:(%d+):"))
    if not id or not CurrentCharDB[id] or CurrentCharDB[id].status ~= 0 then return end
    local itemData = CurrentCharDB[id]
    local itemName = (itemData and itemData.name) or link or ("item:" .. tostring(id))
    LogAlertDebug(string.format("START_LOOT_ROLL detected for pending item %d (%s)", id, itemName))
    ShowDropAlert(id, itemData)
    LootHunter_RefreshUI()
end

-- Resalta en verde discreto los objetos del vendedor que ya estA!n en la lista
local trackedVendorColor = { 0.55, 1.0, 0.65 }
local merchantHooked = false
local merchantTooltipHooked = false

local function AddTrackedInfoToMerchantTooltip(button)
    if not button or not CurrentCharDB or not GetMerchantItemLink then return end
    local perPage = _G.MERCHANT_ITEMS_PER_PAGE or 10
    local page = MerchantFrame and (MerchantFrame.page or 1) or 1
    local idx = ((page - 1) * perPage) + (button:GetID() or 0)
    local link = GetMerchantItemLink(idx)
    local itemID = link and tonumber(link:match("item:(%d+):"))
    if not (itemID and CurrentCharDB[itemID] and GameTooltip) then return end
    -- Cabecera en color primario + lAnea informativa en verde
    -- Usar el verde habitual de las notificaciones
    local header = "|cff00ff00[Loot Hunter]|r"
    GameTooltip:AddLine(header)
    GameTooltip:AddLine(L["VENDOR_TRACKED_TOOLTIP"], trackedVendorColor[1], trackedVendorColor[2], trackedVendorColor[3])
    GameTooltip:Show()
end

local function HighlightTrackedMerchantItems()
    if not MerchantFrame or not MerchantFrame:IsShown() or not GetMerchantNumItems then return end
    if not CurrentCharDB then return end
    local perPage = _G.MERCHANT_ITEMS_PER_PAGE or 10
    local page = MerchantFrame.page or 1
    local offset = (page - 1) * perPage
    for i = 1, perPage do
        local nameText = _G["MerchantItem" .. i .. "Name"]
        if nameText then
            -- Guarda el color original una sola vez para restaurarlo en items no rastreados
            if not nameText._lh_origColor then
                local r0, g0, b0 = nameText:GetTextColor()
                nameText._lh_origColor = { r0 or 1, g0 or 1, b0 or 1 }
            end
            local idx = offset + i
            local link = GetMerchantItemLink and GetMerchantItemLink(idx)
            local itemID = link and tonumber(link:match("item:(%d+):"))
            if itemID and CurrentCharDB and CurrentCharDB[itemID] then
                nameText:SetTextColor(trackedVendorColor[1], trackedVendorColor[2], trackedVendorColor[3])
            else
                local orig = nameText._lh_origColor
                nameText:SetTextColor(orig[1], orig[2], orig[3])
            end
        end
    end
end
local function HookMerchantHighlight()
    if merchantHooked or not MerchantFrame_UpdateMerchantInfo then return end
    merchantHooked = true
    local originalMerchantUpdate = MerchantFrame_UpdateMerchantInfo
    MerchantFrame_UpdateMerchantInfo = function(...)
        local res = originalMerchantUpdate(...)
        HighlightTrackedMerchantItems()
        return res
    end
    if not merchantTooltipHooked and hooksecurefunc and GameTooltip and GameTooltip.HookScript then
        merchantTooltipHooked = true
        GameTooltip:HookScript("OnTooltipSetItem", function(tip)
            local owner = tip:GetOwner()
            if owner and owner:GetName() and owner:GetName():match("^MerchantItem") then
                AddTrackedInfoToMerchantTooltip(owner)
            end
        end)
    end
end
local function HandleMerchantEvent()
    HookMerchantHighlight()
    HighlightTrackedMerchantItems()
end
local eventHandlers = {
    ADDON_LOADED = HandleAddonLoaded,
    GET_ITEM_INFO_RECEIVED = HandleInfoUpdate,
    PLAYER_EQUIPMENT_CHANGED = HandleInfoUpdate,
    LOOT_READY = HandleLootEvent,
    LOOT_OPENED = HandleLootEvent,
    BONUS_ROLL_ACTIVATE = HandleBonusRollActivate,
    UNIT_AURA = HandleUnitAura,
    BOSS_KILL = HandleBossKill,
    ENCOUNTER_END = HandleEncounterEnd,
    CHAT_MSG_LOOT = HandleChatLoot,
    CHAT_MSG_SYSTEM = HandleChatSystem,
    CHAT_MSG_RAID = HandleChatLinkAnnounce,
    CHAT_MSG_RAID_LEADER = HandleChatLinkAnnounce,
    CHAT_MSG_RAID_WARNING = HandleChatLinkAnnounce,
    CHAT_MSG_PARTY = HandleChatLinkAnnounce,
    CHAT_MSG_PARTY_LEADER = HandleChatLinkAnnounce,
    START_LOOT_ROLL = HandleStartLootRoll,
    PLAYER_SPECIALIZATION_CHANGED = HandleSpecChange,
    ACTIVE_TALENT_GROUP_CHANGED = HandleSpecChange,
    PLAYER_TALENT_UPDATE = HandleSpecChange,
    MERCHANT_SHOW = HandleMerchantEvent,
    MERCHANT_UPDATE = HandleMerchantEvent,
}
frame:SetScript("OnEvent", function(self, event, arg1, ...)
    if eventHandlers[event] then
        eventHandlers[event](event, arg1, ...)
    end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("BOSS_KILL")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("LOOT_READY")
frame:RegisterEvent("LOOT_OPENED")
frame:RegisterEvent("BONUS_ROLL_ACTIVATE")
frame:RegisterUnitEvent("UNIT_AURA", "player")
frame:RegisterEvent("CHAT_MSG_RAID")
frame:RegisterEvent("CHAT_MSG_RAID_LEADER")
frame:RegisterEvent("CHAT_MSG_RAID_WARNING")
frame:RegisterEvent("CHAT_MSG_PARTY")
frame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
frame:RegisterEvent("START_LOOT_ROLL")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_UPDATE")
 -- === SISTEMA DE LOGGING ===
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
 LogCoinDebug = function(msg)
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
    local specName = ResolveSpecName()
    print(string.format("[Loot Hunter] Current spec: %s", specName or "Unknown"))
end
-- === CACHE DE LOOT (EJ) ===
local LootSourceCache = {}
local StaticDBBuilt = false
local function BuildSourceFromJournal()
    if not EncounterJournal or not EncounterJournal:IsShown() then return nil end
    local instanceName, encounterName
    if EncounterJournal.instanceID then
        instanceName = EJ_GetInstanceInfo(EncounterJournal.instanceID)
    end
    if EncounterJournal.encounterID then
        encounterName = EJ_GetEncounterInfo(EncounterJournal.encounterID)
    end
    if instanceName and encounterName then
        return instanceName .. " - " .. encounterName
    elseif encounterName then
        return encounterName
    elseif instanceName then
        return instanceName .. " " .. L["ZONE_DROP"]
    end
    return nil
end
local function MaybeRefreshJournalBoss(id)
    if not CurrentCharDB or not EncounterJournal or not EncounterJournal:IsShown() then return end
    local entry = CurrentCharDB[id]
    if not entry then return end
    local currentSource = entry.boss or ""
    if currentSource ~= "" and currentSource ~= L["UNKNOWN_SOURCE"] and not string.find(currentSource, L["ZONE_DROP"], 1, true) then
        return
    end
    local attempts = 0
    local function try()
        if not CurrentCharDB or not EncounterJournal or not EncounterJournal:IsShown() then return end
        local source = BuildSourceFromJournal()
        if source and source ~= "" and source ~= L["UNKNOWN_SOURCE"] and not string.find(source, L["ZONE_DROP"], 1, true) then
            entry.boss = source
            LootHunter_RefreshUI()
            return
        end
        attempts = attempts + 1
        if attempts < 4 then
            C_Timer.After(0.35, try)
        end
    end
    try()
end
-- Detecta flag heroico desde link/contexto; usado en alta y UI.
local function IsHeroicItem(itemLink, source, ejDifficulty)
    if not itemLink or itemLink == "" then return false end
    local plainLink = itemLink:match("|H(item:.-)|h") or itemLink
    local parts = { strsplit(":", plainLink) }
    local difficultyCandidates = {
        tonumber(parts[12]),
        tonumber(parts[13]),
        tonumber(parts[15]),
        tonumber(parts[16]),
    }
    local heroicDifficulty = false
    for _, diffID in ipairs(difficultyCandidates) do
        if diffID and (diffID == 5 or diffID == 6 or diffID == 16 or diffID == 148 or diffID == 149 or (diffID >= 175 and diffID <= 177)) then
            heroicDifficulty = true
            break
        end
    end
    local suffixID = tonumber(parts[8])
    local isHeroicFromSource = source and (string.find(string.lower(source), "%(h%)") or string.find(string.lower(source), "heroic"))
    local ejIsHeroic = ejDifficulty and (ejDifficulty == 5 or ejDifficulty == 6 or ejDifficulty == 16)
    -- Heroico si la dificultad es heroica, el link tiene sufijo heroico, la fuente lo indica o el EJ es heroico (desde EJ).
    local isHeroic = heroicDifficulty or (suffixID and suffixID > 0) or isHeroicFromSource or ejIsHeroic
    return isHeroic and true or false
end
addonTable.IsHeroicItem = IsHeroicItem
local EJUnavailable = false
local EJUnavailableLogged = false
-- Resolver fuente directamente desde el Encounter Journal (sin DB estatica)
local function EnsureEJLoaded()
    if EJUnavailable then return false end
    if EJ_GetNumInstances or EJ_GetLootInfoByItemID or (C_EncounterJournal and (C_EncounterJournal.GetLootInfoByItemID or C_EncounterJournal.GetLootInfo)) then
        return true
    end
    -- Intentar cargar via UIParentLoadAddOn (carga perezosa del EJ)
    if UIParentLoadAddOn then
        local loaded = UIParentLoadAddOn('Blizzard_EncounterJournal')
        if loaded and (EJ_GetNumInstances or EJ_GetLootInfoByItemID or (C_EncounterJournal and (C_EncounterJournal.GetLootInfoByItemID or C_EncounterJournal.GetLootInfo))) then
            return true
        end
    end
    -- Respaldo a LoadAddOn
    if not IsAddOnLoaded('Blizzard_EncounterJournal') then
        local loaded = LoadAddOn('Blizzard_EncounterJournal')
        if loaded and (EJ_GetNumInstances or EJ_GetLootInfoByItemID or (C_EncounterJournal and (C_EncounterJournal.GetLootInfoByItemID or C_EncounterJournal.GetLootInfo))) then
            return true
        end
    end
    EJUnavailable = true
    if LogDebug and not EJUnavailableLogged then
        LogDebug("|cffff0000[EJ]|r Encounter Journal no disponible; omitiendo resolución hasta /reload")
        EJUnavailableLogged = true
    end
    return false
end
local function ResolveSourceFromEJ(itemID)
    if not itemID or type(itemID) ~= 'number' then return nil end
    if not EnsureEJLoaded() then
        return nil, "EJ_UNAVAILABLE"
    end
    -- Seleccionar tier de Pandaria si es posible (mejora resultados en MoP)
    if EJ_SelectTier and EJ_GetNumTiers then
        if not MOPTierSelected then
            local numTiers = EJ_GetNumTiers() or 0
            local selected = false
            for i = 1, numTiers do
                local name = EJ_GetTierInfo and EJ_GetTierInfo(i) or ""
                if name and string.find(string.lower(name), "pandaria") then
                    EJ_SelectTier(i)
                    selected = true
                    break
                end
            end
            if not selected then
                -- fallback hardcodeado a la expansión MoP (índice habitual 5)
                EJ_SelectTier(5)
            end
            MOPTierSelected = true
        end
    end
    -- Intento directo: EJ_GetLootInfoByItemID (o equivalente en C_EncounterJournal)
    local lootFunc = EJ_GetLootInfoByItemID or (C_EncounterJournal and (C_EncounterJournal.GetLootInfoByItemID or C_EncounterJournal.GetLootInfo))
    local encounterFunc = EJ_GetEncounterInfo or (C_EncounterJournal and (C_EncounterJournal.GetEncounterInfo or C_EncounterJournal.GetEncounterInfoByIndex))
    local instanceInfoFunc = EJ_GetInstanceInfo or (C_EncounterJournal and C_EncounterJournal.GetInstanceInfo)
    if lootFunc and encounterFunc then
        local name, _, _, _, _, encounterID, instanceID = lootFunc(itemID)
        if encounterID then
            local bossName, _, _, instFromBoss = encounterFunc(encounterID)
            local instID = instFromBoss or instanceID
            local instanceName = instanceInfoFunc and (instID and instanceInfoFunc(instID) or (instanceID and instanceInfoFunc(instanceID))) or nil
            if instanceName and bossName then
                if LogDebug then LogDebug("|cff00ff00[EJ]|r Resuelta fuente (directo) para item " .. itemID .. ": " .. instanceName .. " - " .. bossName) end
                return instanceName .. " - " .. bossName
            end
            if bossName or instanceName then
                if LogDebug then LogDebug("|cff00ff00[EJ]|r Resuelta fuente (directo) para item " .. itemID .. ": " .. (bossName or instanceName)) end
                return bossName or instanceName
            end
        end
    end
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
                        if instName and bossName then
                            if LogDebug then LogDebug("|cff00ff00[EJ]|r Resuelta fuente para item " .. itemID .. ": " .. instName .. " - " .. bossName) end
                            return instName .. ' - ' .. bossName
                        end
                        if LogDebug then LogDebug("|cff00ff00[EJ]|r Resuelta fuente para item " .. itemID .. ": " .. (bossName or instName or "??")) end
                        return bossName or instName
                    end
                    lootIndex = lootIndex + 1
                end
                bossIndex = bossIndex + 1
            end
        end
    end
    return nil
end
local function TryResolveSourceAsync(itemID)
    if not itemID then return end
    if EJUnavailable then return end
    RequestItemData(itemID)
    C_Timer.After(0, function()
        if not CurrentCharDB then return end
        if EJUnavailable then return end
        local entry = CurrentCharDB[itemID]
        if not entry or (entry.boss and entry.boss ~= '' and entry.boss ~= L['UNKNOWN_SOURCE']) then return end
        if LogDebug then LogDebug("|cffffd700[EJ]|r Intentando resolver fuente via EJ para item " .. tostring(itemID)) end
        local src, errFlag = ResolveSourceFromEJ(itemID)
        if errFlag == "EJ_UNAVAILABLE" then
            EJUnavailable = true
            return
        end
        if src and src ~= '' then
            entry.boss = src
            LootHunter_RefreshUI()
            if addonTable.RefreshLogPanel then addonTable.RefreshLogPanel() end
        else
            if LogDebug then LogDebug("|cffff0000[EJ]|r No se encontró fuente para item " .. tostring(itemID) .. " en EJ") end
        end
    end)
end
local function ResolveAllUnknownSources()
    if not CurrentCharDB then return end
    local pending = {}
    for id, data in pairs(CurrentCharDB) do
        if type(id) == "number" and type(data) == "table" then
            local boss = data.boss
            if not boss or boss == "" or boss == L["UNKNOWN_SOURCE"] then
                pending[#pending+1] = id
            end
        end
    end
    if #pending == 0 then return end
    -- Precargar datos de item para mejorar respuestas de EJ
    for _, itemID in ipairs(pending) do
        RequestItemData(itemID)
    end
    -- Dar tiempo al cliente a traer datos antes de resolver
    local delay = 0.6
    C_Timer.After(delay, function()
        if EJUnavailable then return end
        for index, itemID in ipairs(pending) do
            C_Timer.After(0.05 * (index-1), function()
                TryResolveSourceAsync(itemID)
            end)
        end
    end)
end
local function _BuildStaticDB()
    -- Deshabilitado: ya no usamos bases de datos estáticas
    StaticDBBuilt = true
end
BuildStaticDB = _BuildStaticDB
-- Función para obtener información del item desde la cache
local function GetItemSourceFromCache(itemID)
    if LootSourceCache[itemID] then
        return LootSourceCache[itemID]
    end
    return nil
end
addonTable.GetItemSourceFromCache = GetItemSourceFromCache
function AddItemToList(itemLink, bisType, spec, sourceOverride, slotOverride)
    if not itemLink then return end
    local id = string.match(itemLink, "item:(%d+)")
    if not id then return end
    id = tonumber(id)
    if not CurrentCharDB then return end 
    local name, itemLinkResolved, quality = GetItemInfo(id)
    local equipLoc = select(9, GetItemInfo(id))
    local icon = select(10, GetItemInfo(id))
    local instantEquipLoc, instantClassID, instantSubClassID = nil, nil, nil
    if GetItemInfoInstant then
        local _, _, _, instLoc, _, classID, subClassID = GetItemInfoInstant(itemLink)
        instantEquipLoc = instLoc
        instantClassID = classID
        instantSubClassID = subClassID
    end
    if (not equipLoc or equipLoc == "") and instantEquipLoc and instantEquipLoc ~= "" then
        equipLoc = instantEquipLoc
    end
    local isMountItem = (instantClassID == ITEM_CLASS_MISC and instantSubClassID == ITEM_SUBCLASS_MOUNT)
    if isMountItem then
        equipLoc = "MOUNT"
    end
    -- No dependemos de la DB estática para determinar la fuente
    local journalSource = BuildSourceFromJournal and BuildSourceFromJournal() or nil
    -- Solo permitir equipo (slot conocido o instant data) o tokens conocidos
    local hasValidSlot = (equipLoc and SLOT_INFO[equipLoc] ~= nil)
    local slotOverrideValid = (slotOverride and SLOT_INFO[slotOverride] ~= nil)
    local isEquippable = IsEquippableItem(itemLink)
    if not isEquippable and instantClassID then
        if instantClassID == ITEM_CLASS_ARMOR or instantClassID == ITEM_CLASS_WEAPON then
            isEquippable = true
        end
    end
    if not slotOverrideValid and not hasValidSlot then
        if isMountItem then
            equipLoc = "MOUNT"
            hasValidSlot = true
        else
            -- Permitir tokens u objetos sin ranura conocida, incluso si no son equipables.
            if not isEquippable then
                equipLoc = "RAID_TOKEN"
                hasValidSlot = true
            elseif not equipLoc or equipLoc == "" then
                -- Equipo sin datos cargados aun: lo clasificamos temporalmente como token
                equipLoc = "RAID_TOKEN"
                hasValidSlot = true
            else
                return
            end
        end
    end
    if slotOverrideValid then
        equipLoc = slotOverride
        hasValidSlot = true
    end
    if not equipLoc or equipLoc == "" or not SLOT_INFO[equipLoc] then
        equipLoc = "RAID_TOKEN"
    end
    -- Preferir solo la fuente del Journal (o override); no usar la DB para la fuente en Shift+Click
    local source = sourceOverride or journalSource
    -- Si se agrega desde un vendedor, usar el nombre del vendedor como fuente.
    if (not source or source == "" or source == L["UNKNOWN_SOURCE"]) and MerchantFrame and MerchantFrame:IsShown() then
        local vendorName = UnitName("npc") or UnitName("target") or L["UNKNOWN_SOURCE"]
        if vendorName and vendorName ~= "" then
            source = vendorName .. " (Vendor)"
        else
            source = "Vendor"
        end
    end
    local ejDifficulty = nil
    if EncounterJournal and EncounterJournal:IsShown() and EJ_GetDifficulty then
        ejDifficulty = EJ_GetDifficulty()
    end
    -- Respaldo si no encontramos nada
    if not source then
        source = L["UNKNOWN_SOURCE"]
    end
    -- Determinar si es heroico usando link, dificultad y fuente
    local plainLink = itemLink:match("|H(item:.-)|h") or itemLink
    local isHeroic = IsHeroicItem(plainLink, source, ejDifficulty)
    itemLink = plainLink
    local resolvedSpec = ResolveSpecName(spec)
    local resolvedSpecID = ResolveSpecID(spec)
    if not CurrentCharDB[id] then
        CurrentCharDB[id] = {
            name = name or L["LOADING"],
            link = itemLink,
            slot = equipLoc, 
            icon = icon,
            boss = source,
            bisType = bisType,
            spec = resolvedSpec,
            specID = resolvedSpecID,
            isHeroic = isHeroic,
            status = 0 
        }
        local displayName = name or L["LOADING"]
        if quality and GetItemQualityColor and name then
            local color = select(4, GetItemQualityColor(quality))
            if color then
                displayName = string.format("|c%s%s|r", color, name)
            end
        end
        print(string.format(L["ADDED_MSG"], id, displayName))
        LootHunter_RefreshUI()
        if MerchantFrame and MerchantFrame:IsShown() then
            HighlightTrackedMerchantItems()
        end
        MaybeRefreshJournalBoss(id)
    else
        if bisType then CurrentCharDB[id].bisType = bisType end
        if resolvedSpecID and not CurrentCharDB[id].specID then
            CurrentCharDB[id].specID = resolvedSpecID
        end
        if resolvedSpec and (not CurrentCharDB[id].spec or CurrentCharDB[id].spec == "") then
            CurrentCharDB[id].spec = resolvedSpec
        elseif spec then
            CurrentCharDB[id].spec = spec
        end
        if sourceOverride then CurrentCharDB[id].boss = sourceOverride end
        if (not CurrentCharDB[id].boss or CurrentCharDB[id].boss == L["UNKNOWN_SOURCE"]) and source then
            CurrentCharDB[id].boss = source
        end
        CurrentCharDB[id].isHeroic = isHeroic
        -- Si no tienen source establecido aún, intentar obtenerlo
        if not CurrentCharDB[id].boss or CurrentCharDB[id].boss == L["UNKNOWN_SOURCE"] then
            CurrentCharDB[id].boss = source
        end
        LootHunter_RefreshUI()
        if MerchantFrame and MerchantFrame:IsShown() then
            HighlightTrackedMerchantItems()
        end
    end
    if CurrentCharDB[id] and (not CurrentCharDB[id].boss or CurrentCharDB[id].boss == L["UNKNOWN_SOURCE"]) then
        TryResolveSourceAsync(id)
    end
end

local function ParseItemArg(arg)
    if not arg or arg == "" then return nil, nil end
    local link = arg:match("|Hitem:.-|h.-|h") or arg
    local id = tonumber(link:match("item:(%d+)")) or tonumber(link)
    return id, link
end

local function EnsureItemEntry(itemID, itemLink)
    if not itemID then return nil end
    if CurrentCharDB and CurrentCharDB[itemID] then
        return CurrentCharDB[itemID]
    end
    local name, resolvedLink, quality = GetItemInfo(itemID)
    local displayLink = resolvedLink or itemLink
    local displayName = name or L["LOADING"]
    if quality and GetItemQualityColor and name then
        local color = select(4, GetItemQualityColor(quality))
        if color then
            displayName = string.format("|c%s%s|r", color, name)
        end
    end
    CurrentCharDB[itemID] = {
        name = displayName,
        link = displayLink or displayName,
        slot = "RAID_TOKEN",
        icon = select(10, GetItemInfo(itemID)),
        boss = L["UNKNOWN_SOURCE"],
        bisType = nil,
        spec = ResolveSpecName(),
        specID = ResolveSpecID(),
        isHeroic = false,
        status = 0,
    }
    return CurrentCharDB[itemID]
end
SLASH_LOOTHUNTER1 = "/loothunter"
SLASH_LOOTHUNTER2 = "/lh"
SlashCmdList["LOOTHUNTER"] = function(msg)
    LootHunter_CreateGUI()
end

SLASH_LOOTHUNTER_BOSS1 = "/lh_boss"
SlashCmdList["LOOTHUNTER_BOSS"] = function(msg)
    local bossName = msg and msg:match("^%s*(.-)%s*$") or ""
    if bossName == "" then
        print("[Loot Hunter] Usage: /lh_boss <boss name>")
        return
    end
    ScheduleCoinReminder(nil, bossName, true, true)
    C_Timer.After(5, function()
        if CurrentCharDB then
            for id, data in pairs(CurrentCharDB) do
                if type(id) == "number" and type(data) == "table" and data.status == 0 then
                    if ItemMatchesBossSource(data, bossName) then
                        ShowDropAlert(id, data)
                        LootHunter_RefreshUI()
                    end
                end
            end
        end
    end)
end

SLASH_LOOTHUNTER_DROP1 = "/lh_drop"
SlashCmdList["LOOTHUNTER_DROP"] = function(msg)
    if not CurrentCharDB then return end
    local itemID, itemLink = ParseItemArg(msg or "")
    if not itemID then
        print("[Loot Hunter] Usage: /lh_drop <itemID or itemLink>")
        return
    end
    local entry = EnsureItemEntry(itemID, itemLink)
    ShowDropAlert(itemID, entry)
    LootHunter_RefreshUI()
end

SLASH_LOOTHUNTER_WON1 = "/lh_won"
SlashCmdList["LOOTHUNTER_WON"] = function(msg)
    if not CurrentCharDB then return end
    local itemID, itemLink = ParseItemArg(msg or "")
    if not itemID then
        print("[Loot Hunter] Usage: /lh_won <itemID or itemLink>")
        return
    end
    local entry = EnsureItemEntry(itemID, itemLink)
    if entry and entry.status ~= 2 then
        entry.status = 2
        entry.lastState = "won"
        LootHunter_RefreshUI()
        if LootHunterDB.settings.lootAlerts.itemWon then
            local winTitle = CreateGradient(L["WIN_ALERT_TITLE"], 0.35, 1, 0.35, 0.65, 1, 0.65)
            local winDesc = CreateGradient(L["WIN_ALERT_DESC"], 0.35, 1, 0.35, 0.65, 1, 0.65)
            local winBanner = string.format("%s %s %s", ICON_STAR, winTitle, ICON_STAR)
            local itemLine = entry.link or entry.name or "?"
            EnqueueAlert(ALERT_DEFAULT_DURATION, ALERT_PRIORITY_PRIMARY, function()
                if addonTable.FlashScreen then addonTable.FlashScreen("WIN") end
                if addonTable.ShowAlert then
                    addonTable.ShowAlert(string.format("%s\n%s\n%s", winBanner, winDesc, itemLine), 0, 1, 0)
                end
                PlaySound(12891)
            end)
            print(string.format(L["CONGRATS_CHAT_MSG"], itemLine))
        end
    end
end

