-- =============================================================
-- LootHunter.lua — Núcleo del addon (archivo principal)
-- Contiene: inicialización, sistema de alertas, AddItemToList,
-- manejadores de eventos principales y slash commands.
-- Los sistemas específicos están en Modules/*.lua
-- =============================================================
local addonName, addonTable = ...
local L             = addonTable.L
local CreateGradient = addonTable.CreateGradient or function(text) return text end

-- Frame de eventos principal del addon
local frame = CreateFrame("Frame")
addonTable.isRefreshing = false

-- Variables de debug cargadas desde Debug.lua (precedencia)
local LogDebug      = addonTable.LogDebug      or function() end
local FormatLogPrefix = addonTable.FormatLogPrefix or function(t) return "[" .. t .. "]" end
local LogCoinDebug  = addonTable.LogCoinDebug   or function() end

-- Referencia local al StatsStore definido en Modules/StatsStore.lua
-- Se asigna después de ADDON_LOADED cuando los módulos ya cargaron
local StatsStore = nil

-- Clave del personaje actual (Nombre - Realm)
local charKey = nil
-- Base de datos del personaje actual (referencia a LootHunterDB.Characters[charKey])
local CurrentCharDB = nil
local refresh_timer  = nil

-- Constantes de clase de items (fallback para versiones que no tengan LE_ITEM_CLASS_*)
local ITEM_CLASS_WEAPON   = _G.LE_ITEM_CLASS_WEAPON         or 2
local ITEM_CLASS_ARMOR    = _G.LE_ITEM_CLASS_ARMOR           or 4
local ITEM_CLASS_MISC     = _G.LE_ITEM_CLASS_MISCELLANEOUS   or 15
local ITEM_SUBCLASS_MOUNT = _G.LE_ITEM_MISCELLANEOUS_MOUNT
    or (_G.Enum and _G.Enum.ItemMiscellaneousSubclass and _G.Enum.ItemMiscellaneousSubclass.Mount)
    or 5

-- Iconos de marcadores de raid (también definidos en Utils.lua; esto es para compatibilidad
-- con partes del código que los usan como locales antes de que Utils cargue en old-path)
local ICON_STAR     = addonTable.ICON_STAR     or "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:24|t"
local ICON_DIAMOND  = addonTable.ICON_DIAMOND  or "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:24|t"

-- =============================================================
-- SLOT_INFO: tabla de categorías de equipo con nombre localizado
-- =============================================================
local SLOT_INFO = {}

-- Tabla para rastrear el último alert de DROP por itemID (anti-duplicados)
local LastDropAlert = {}
local function RebuildSlotInfo()
    SLOT_INFO = {
        ["RAID_TOKEN"]            = { order = 0,  name = L["RAID_TOKEN"]   },
        ["INVTYPE_HEAD"]          = { order = 1,  name = L["HEAD"]         },
        ["INVTYPE_NECK"]          = { order = 2,  name = L["NECK"]         },
        ["INVTYPE_SHOULDER"]      = { order = 3,  name = L["SHOULDER"]     },
        ["INVTYPE_CLOAK"]         = { order = 4,  name = L["CLOAK"]        },
        ["INVTYPE_CHEST"]         = { order = 5,  name = L["CHEST"]        },
        ["INVTYPE_ROBE"]          = { order = 5,  name = L["CHEST"]        },
        ["INVTYPE_WRIST"]         = { order = 6,  name = L["WRIST"]        },
        ["INVTYPE_HAND"]          = { order = 7,  name = L["HAND"]         },
        ["INVTYPE_WAIST"]         = { order = 8,  name = L["WAIST"]        },
        ["INVTYPE_LEGS"]          = { order = 9,  name = L["LEGS"]         },
        ["INVTYPE_FEET"]          = { order = 10, name = L["FEET"]         },
        ["INVTYPE_FINGER"]        = { order = 11, name = L["FINGER"]       },
        ["INVTYPE_TRINKET"]       = { order = 12, name = L["TRINKET"]      },
        ["INVTYPE_WEAPON"]        = { order = 13, name = L["WEAPON_1H"]    },
        ["INVTYPE_WEAPONMAINHAND"]= { order = 13, name = L["WEAPON_MAIN"]  },
        ["INVTYPE_WEAPONOFFHAND"] = { order = 14, name = L["WEAPON_OFF"]   },
        ["INVTYPE_SHIELD"]        = { order = 14, name = L["SHIELD"]       },
        ["INVTYPE_HOLDABLE"]      = { order = 14, name = L["HOLDABLE"]     },
        ["INVTYPE_2HWEAPON"]      = { order = 15, name = L["WEAPON_2H"]    },
        ["INVTYPE_RANGED"]        = { order = 16, name = L["RANGED"]       },
        ["INVTYPE_RANGEDRIGHT"]   = { order = 16, name = L["RANGED"]       },
        ["INVTYPE_THROWN"]        = { order = 16, name = L["RANGED"]       },
        ["INVTYPE_WAND"]          = { order = 16, name = L["RANGED"]       },
        ["INVTYPE_RELIC"]         = { order = 16, name = L["RELIC"]        },
        ["MOUNT"]                 = { order = 17, name = L["MOUNT"]        },
    }
    addonTable.SLOT_INFO = SLOT_INFO
end
addonTable.RebuildSlotInfo = RebuildSlotInfo
RebuildSlotInfo()  -- Primer build  con el idioma cargado en Localization.lua

-- =============================================================
-- SISTEMA DE ALERTAS (cola con prioridad)
-- =============================================================
-- Prioridades: 1 = primaria (ganado/perdido), 2 = secundaria, 3 = pre-aviso
local ALERT_DEFAULT_DURATION  = 6.8
local ALERT_PRIORITY_PRIMARY  = 1
local ALERT_PRIORITY_SECONDARY = 2
local ALERT_PRIORITY_PREWARN  = 3

-- Reenvía al sistema de cola de alertas definido en UI.lua
local function EnqueueAlert(duration, priority, fn)
    if addonTable.EnqueueAlert then
        addonTable.EnqueueAlert(duration or ALERT_DEFAULT_DURATION, fn, priority or ALERT_PRIORITY_SECONDARY)
        return
    end
    if fn then fn() end
end
-- Exponer para que los módulos puedan encolar alertas
addonTable._coreEnqueueAlert = EnqueueAlert

-- Registra un mensaje en el log de alerta
local function LogAlertDebug(msg)
    if addonTable.LogDebug then
        addonTable.LogDebug(FormatLogPrefix("Alert") .. " " .. msg)
    end
end

-- Muestra la alerta de DROP cuando un item deseado aparece en el loot
local function ShowDropAlert(itemID, itemData)
    if not itemID or not itemData then return end
    local now = GetTime and GetTime() or 0
    -- Suprimir alertas duplicadas en menos de 2 segundos
    if LastDropAlert[itemID] and (now - LastDropAlert[itemID]) < 2 then return end
    LastDropAlert[itemID] = now

    local allowScope = addonTable.IsScopeAllowed
        and addonTable.IsScopeAllowed(LootHunterDB and LootHunterDB.settings and LootHunterDB.settings.lootAlerts and LootHunterDB.settings.lootAlerts.lostAlertScope)
        or true
    if not allowScope then return end

    local itemName = itemData.link or itemData.name or "?"
    local isPriority = (LootHunterDB and LootHunterDB.settings and LootHunterDB.settings.lootAlerts and LootHunterDB.settings.lootAlerts.itemSeen)
    local headerIcon = isPriority and ICON_STAR or ICON_DIAMOND
    local titleRaw   = L["DROP_ALERT_TITLE"] or "Your loot dropped!"
    local title      = CreateGradient(titleRaw, 1, 0.9, 0.15, 1, 0.65, 0)
    local banner     = string.format("%s %s %s", headerIcon, title, headerIcon)
    local alertText  = string.format("%s\n%s", banner, itemName)

    EnqueueAlert(ALERT_DEFAULT_DURATION, ALERT_PRIORITY_PRIMARY, function()
        if addonTable.ShowAlert   then addonTable.ShowAlert(alertText, 1, 0.9, 0.15) end
        if addonTable.FlashScreen then addonTable.FlashScreen("YELLOW") end
        local soundID = (SOUNDKIT and SOUNDKIT.UI_BONUS_ROLL_START) or 12867
        if not PlaySound(soundID, "Master") then PlaySound(soundID) end
    end)
    LogAlertDebug("DROP alert shown for item " .. tostring(itemID))
end
addonTable.ShowDropAlert = ShowDropAlert

-- =============================================================
-- CONFIGURACIÓN POR DEFECTO (settings)
-- =============================================================
local function InitializeSettings()
    local defaults = {
        coinReminder = {
            enabled      = true,
            preWarning   = true,
            channel      = "SELF",
            visualAlert  = true,
            soundEnabled = true,
            soundFile    = 12867,
            reminderDelay = 60,
        },
        lootAlerts = {
            itemWon          = true,
            itemSeen         = true,
            otherWonSound    = true,
            lostAlertEnabled = true,
            lostAlertScope   = "RAID",
            bossNoItems      = false,
        },
        misc = {
            heroicQueueConfirm = true,
            muteRaidChannels   = false,
            autoRemoveFromList = false,
        },
        general = {
            windowsLocked = true,
            debugLogging  = false,
            debugLogMax   = 1000,
            language      = "AUTO",
            helpSeen      = false,
            uiScale       = 1.0,
        },
        stats = {
            maxSessions = 25,
        },
    }
    if not LootHunterDB.settings then
        LootHunterDB.settings = defaults
        return
    end
    -- Merge profundo de defaults preservando las preferencias del usuario
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
    -- Normalizar el alcance de alerta de loot perdido
    if LootHunterDB.settings and LootHunterDB.settings.lootAlerts then
        local scope = LootHunterDB.settings.lootAlerts.lostAlertScope
        local valid = { ALL = true, RAID = true, DUNGEON = true }
        if not valid[scope] then LootHunterDB.settings.lootAlerts.lostAlertScope = "RAID" end
    end
    -- Sincronizar MAX_SESSION_LOGS desde la configuración del usuario
    if LootHunterDB.settings.stats and LootHunterDB.settings.stats.maxSessions then
        local maxS = math.max(25, math.min(50, tonumber(LootHunterDB.settings.stats.maxSessions) or 25))
        if addonTable.StatsStore then addonTable.StatsStore.MAX_SESSION_LOGS = maxS end
    end
end

-- =============================================================
-- VALIDAR RECURSOS DEL ADDON
-- =============================================================
local function ValidateAddonAssets()
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
            if not tex:SetTexture("Interface\\AddOns\\LootHunter\\" .. relPath) then
                table.insert(missing, relPath)
            end
        end
        tex:SetTexture(nil)
    end
    if #missing > 0 then
        local list = table.concat(missing, ", ")
        print(string.format(L["ASSET_MISSING_MSG"] or "[Loot Hunter] Missing assets: %s", list))
        print(L["ASSET_MISSING_HINT"] or "[Loot Hunter] Verify the addon folder name is LootHunter.")
    end
end

-- =============================================================
-- MANEJADORES DE EVENTOS PRINCIPALES
-- =============================================================

-- Actualiza la UI de forma diferida para evitar refrescos excesivos
local function HandleInfoUpdate(event, arg1)
    if refresh_timer then return end
    refresh_timer = C_Timer.After(0.2, function()
        if LootHunter_RefreshUI then LootHunter_RefreshUI() end
        refresh_timer = nil
    end)
end

-- Manejador del evento ADDON_LOADED: inicializa el addon o responde a sub-addons
local function HandleAddonLoaded(event, arg1)
    -- Responder a la carga tardía del Encounter Journal
    if arg1 == "Blizzard_EncounterJournal" then
        if addonTable.ResetEJFlags then addonTable.ResetEJFlags() end
        C_Timer.After(0, function()
            if addonTable.ResolveAllUnknownSources then addonTable.ResolveAllUnknownSources() end
        end)
        return
    end
    -- Responder a la carga de la UI del buscador de mazmorras
    if arg1 == "Blizzard_LFDUI" then
        if addonTable.SetupHeroicQueueConfirm then addonTable.SetupHeroicQueueConfirm() end
        return
    end
    if arg1 ~= addonName then return end

    addonTable.version = GetAddOnMetadata(addonName, "Version") or "v1.0"
    if LootHunterDB == nil then LootHunterDB = {} end

    InitializeSettings()
    addonTable.db = LootHunterDB

    if addonTable.ApplyLocale    then addonTable.ApplyLocale() end
    if addonTable.RebuildSlotInfo then addonTable.RebuildSlotInfo() end
    ValidateAddonAssets()

    -- Posición de ventana por defecto si no existe configuración previa
    if not LootHunterDB.windowSettings then
        local screenWidth = (GetScreenWidth and GetScreenWidth()) or (UIParent and UIParent:GetWidth()) or 0
        local defaultX    = -math.floor(screenWidth * 0.10)
        LootHunterDB.windowSettings = {
            point         = "RIGHT",
            relativePoint = "RIGHT",
            x             = defaultX,
            y             = 0,
            width         = addonTable.DEFAULT_WINDOW_WIDTH  or 530,
            height        = addonTable.DEFAULT_WINDOW_HEIGHT or 456,
        }
    end
    if not LootHunterDB.buttonPos then
        LootHunterDB.buttonPos = { point = "CENTER", x = -200, y = 0 }
    end

    -- Inicializar DB de personaje
    if not LootHunterDB.Characters then LootHunterDB.Characters = {} end
    charKey = UnitName("player") .. " - " .. GetRealmName()
    addonTable.charKey = charKey
    if not LootHunterDB.Characters[charKey] then LootHunterDB.Characters[charKey] = {} end
    CurrentCharDB = LootHunterDB.Characters[charKey]
    addonTable.CurrentCharDB = CurrentCharDB

    -- Obtener referencia al StatsStore (definido en Modules/StatsStore.lua)
    StatsStore = addonTable.StatsStore
    if StatsStore then
        StatsStore:EnsureHistoryDB()
        StatsStore:EnsureSessionDB()
    end
    if addonTable.MigrateSpecIDs then addonTable.MigrateSpecIDs() end

    -- Restaurar items en estado "visto" de vuelta a "pendiente" al cargar
    local count = 0
    for k, v in pairs(CurrentCharDB) do
        if type(k) == "number" then
            count = count + 1
            if type(v) == "table" and v.status == 1 then v.status = 0 end
        end
    end

    print(string.format(L["LOADED_MSG"], charKey, count))

    if addonTable.CreateMinimapIcon     then addonTable.CreateMinimapIcon() end
    if addonTable.BuildStaticDB         then addonTable.BuildStaticDB() end
    if addonTable.SetupHeroicQueueConfirm then addonTable.SetupHeroicQueueConfirm() end
    if addonTable.UpdateRaidChatFilter  then addonTable.UpdateRaidChatFilter() end
    if addonTable.ResolveAllUnknownSources then
        C_Timer.After(2, addonTable.ResolveAllUnknownSources)
    end

    -- Hook en Shift+Click de items para agregarlos a la lista
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

-- Manejador del evento LOOT_OPENED / LOOT_READY
local function HandleLootEvent(event)
    if addonTable.TriggerLootReadyTimers then
        if LogCoinDebug then LogCoinDebug(string.format("Evento %s recibido. Revisando temporizadores de moneda.", event)) end
        addonTable.TriggerLootReadyTimers()
    end
    -- Recorrer slots del loot actual y mostrar alertas de drop
    if CurrentCharDB and GetNumLootItems then
        local num = GetNumLootItems()
        for slot = 1, num do
            local link   = GetLootSlotLink(slot)
            local itemID = link and tonumber(link:match("item:(%d+):"))
            if itemID and CurrentCharDB[itemID] and CurrentCharDB[itemID].status == 0 then
                CurrentCharDB[itemID].status = 1
                if addonTable.MarkRecentDrop then addonTable.MarkRecentDrop(itemID) end
                ShowDropAlert(itemID, CurrentCharDB[itemID])
                if LootHunter_RefreshUI then LootHunter_RefreshUI() end
                -- Auto-reset si nadie lo recoge y CHAT_MSG_LOOT nunca llega
                local capturedID = itemID
                C_Timer.After(120, function()
                    if CurrentCharDB and CurrentCharDB[capturedID] and CurrentCharDB[capturedID].status == 1 then
                        CurrentCharDB[capturedID].status = 0
                        if LootHunter_RefreshUI then LootHunter_RefreshUI() end
                    end
                end)
            end
        end
    end
end

-- Manejador de BOSS_KILL: dispara el recordatorio de moneda
local function HandleBossKill(event, encounterID, bossName, ...)
    if not bossName or bossName == "" then return end
    if addonTable.ScheduleCoinReminder then
        addonTable.ScheduleCoinReminder(encounterID, bossName)
    end
end

-- Manejador de ENCOUNTER_END: fallback si BOSS_KILL no disparó
local function HandleEncounterEnd(event, encounterID, bossName, _, success, ...)
    if tonumber(success) ~= 1 then return end
    if not bossName or bossName == "" then return end
    if addonTable.ScheduleCoinReminder then
        addonTable.ScheduleCoinReminder(encounterID, bossName)
    end
end

-- =============================================================
-- AGREGAR ITEM A LA LISTA
-- =============================================================

-- Solicita los datos del item al servidor si no están disponibles aún
local function RequestItemData(itemID)
    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    elseif C_Item and C_Item.RequestServerCache then
        C_Item.RequestServerCache(itemID)
    end
    GetItemInfo(itemID)
end

-- Añade un item a la lista de rastreo del personaje actual
function AddItemToList(itemLink, bisType, spec, sourceOverride, slotOverride)
    if not itemLink then return end
    local id = string.match(itemLink, "item:(%d+)")
    if not id then return end
    id = tonumber(id)
    if not CurrentCharDB then return end

    local name, _, quality = GetItemInfo(id)
    local equipLoc         = select(9, GetItemInfo(id))
    local icon             = select(10, GetItemInfo(id))
    local instantEquipLoc, instantClassID, instantSubClassID = nil, nil, nil
    if GetItemInfoInstant then
        local _, _, _, instLoc, _, classID, subClassID = GetItemInfoInstant(itemLink)
        instantEquipLoc   = instLoc
        instantClassID    = classID
        instantSubClassID = subClassID
    end
    if (not equipLoc or equipLoc == "") and instantEquipLoc and instantEquipLoc ~= "" then
        equipLoc = instantEquipLoc
    end

    local isMountItem = (instantClassID == ITEM_CLASS_MISC and instantSubClassID == ITEM_SUBCLASS_MOUNT)
    if isMountItem then equipLoc = "MOUNT" end

    local journalSource = addonTable.BuildSourceFromJournal and addonTable.BuildSourceFromJournal() or nil
    local hasValidSlot  = (equipLoc and SLOT_INFO[equipLoc] ~= nil)
    local slotOvValid   = (slotOverride and SLOT_INFO[slotOverride] ~= nil)
    local isEquippable  = IsEquippableItem(itemLink)
    if not isEquippable and instantClassID then
        if instantClassID == ITEM_CLASS_ARMOR or instantClassID == ITEM_CLASS_WEAPON then
            isEquippable = true
        end
    end

    if not slotOvValid and not hasValidSlot then
        if isMountItem then
            equipLoc = "MOUNT" ; hasValidSlot = true
        elseif not isEquippable then
            equipLoc = "RAID_TOKEN" ; hasValidSlot = true
        elseif not equipLoc or equipLoc == "" then
            equipLoc = "RAID_TOKEN" ; hasValidSlot = true
        else
            return
        end
    end
    if slotOvValid then equipLoc = slotOverride ; hasValidSlot = true end
    if not equipLoc or equipLoc == "" or not SLOT_INFO[equipLoc] then equipLoc = "RAID_TOKEN" end

    -- Determinar fuente del item
    local source = sourceOverride or journalSource
    if (not source or source == "" or source == L["UNKNOWN_SOURCE"]) and MerchantFrame and MerchantFrame:IsShown() then
        local vendorName = UnitName("npc") or UnitName("target") or L["UNKNOWN_SOURCE"]
        source = (vendorName and vendorName ~= "") and (vendorName .. " (Vendor)") or "Vendor"
    end

    -- Detectar dificultad heroica
    local ejDifficulty = nil
    if EncounterJournal and EncounterJournal:IsShown() and EJ_GetDifficulty then
        ejDifficulty = EJ_GetDifficulty()
    end
    source = source or L["UNKNOWN_SOURCE"]

    local plainLink = itemLink:match("|H(item:.-)|h") or itemLink
    local isHeroic  = addonTable.IsHeroicItem and addonTable.IsHeroicItem(plainLink, source, ejDifficulty) or false
    itemLink        = plainLink

    local resolvedSpec   = addonTable.ResolveSpecName and addonTable.ResolveSpecName(spec)   or spec
    local resolvedSpecID = addonTable.ResolveSpecID   and addonTable.ResolveSpecID(spec)     or nil

    if not CurrentCharDB[id] then
        -- Item nuevo: crear entrada completa
        CurrentCharDB[id] = {
            name     = name or L["LOADING"],
            link     = itemLink,
            slot     = equipLoc,
            icon     = icon,
            boss     = source,
            bisType  = bisType,
            spec     = resolvedSpec,
            specID   = resolvedSpecID,
            isHeroic = isHeroic,
            status   = 0,
        }
        local displayName = name or L["LOADING"]
        if quality and GetItemQualityColor and name then
            local color = select(4, GetItemQualityColor(quality))
            if color then displayName = string.format("|c%s%s|r", color, name) end
        end
        print(string.format(L["ADDED_MSG"], id, displayName))
        if LootHunter_RefreshUI then LootHunter_RefreshUI() end
        if MerchantFrame and MerchantFrame:IsShown() and addonTable.HighlightTrackedMerchantItems then
            addonTable.HighlightTrackedMerchantItems()
        end
        if addonTable.MaybeRefreshJournalBoss and not sourceOverride then addonTable.MaybeRefreshJournalBoss(id) end
    else
        -- Item existente: actualizar campos faltantes
        local entry = CurrentCharDB[id]
        if bisType then entry.bisType = bisType end
        if resolvedSpecID and not entry.specID then entry.specID = resolvedSpecID end
        if resolvedSpec and (not entry.spec or entry.spec == "") then
            entry.spec = resolvedSpec
        elseif spec then
            entry.spec = spec
        end
        if sourceOverride then entry.boss = sourceOverride end
        if (not entry.boss or entry.boss == L["UNKNOWN_SOURCE"]) and source then entry.boss = source end
        entry.isHeroic = isHeroic
        if LootHunter_RefreshUI then LootHunter_RefreshUI() end
        if MerchantFrame and MerchantFrame:IsShown() and addonTable.HighlightTrackedMerchantItems then
            addonTable.HighlightTrackedMerchantItems()
        end
    end

    -- Si la fuente sigue siendo desconocida, intentar resolverla vía EJ
    if CurrentCharDB[id] and (not CurrentCharDB[id].boss or CurrentCharDB[id].boss == L["UNKNOWN_SOURCE"]) then
        if addonTable.TryResolveSourceAsync then addonTable.TryResolveSourceAsync(id) end
    end
end

-- Parsea un argumento de slash command: puede ser itemLink o itemID numérico
function addonTable.ParseItemArg(arg)
    if not arg or arg == "" then return nil, nil end
    local link = arg:match("|Hitem:.-|h.-|h") or arg
    local id   = tonumber(link:match("item:(%d+)")) or tonumber(link)
    return id, link
end

-- Asegura que exista una entrada para un item en la DB del personaje
function addonTable.EnsureItemEntry(itemID, itemLink)
    if not itemID then return nil end
    if CurrentCharDB and CurrentCharDB[itemID] then return CurrentCharDB[itemID] end
    local name, resolvedLink, quality = GetItemInfo(itemID)
    local displayName = name or L["LOADING"]
    if quality and GetItemQualityColor and name then
        local color = select(4, GetItemQualityColor(quality))
        if color then displayName = string.format("|c%s%s|r", color, name) end
    end
    CurrentCharDB[itemID] = {
        name     = displayName,
        link     = resolvedLink or itemLink or displayName,
        slot     = "RAID_TOKEN",
        icon     = select(10, GetItemInfo(itemID)),
        boss     = L["UNKNOWN_SOURCE"],
        bisType  = nil,
        spec     = addonTable.ResolveSpecName and addonTable.ResolveSpecName() or nil,
        specID   = addonTable.ResolveSpecID   and addonTable.ResolveSpecID()   or nil,
        isHeroic = false,
        status   = 0,
    }
    return CurrentCharDB[itemID]
end

-- =============================================================
-- REGISTRO DE EVENTOS
-- =============================================================

-- Tabla que mapea eventos WoW a su manejador.
-- Los módulos exponen sus manejadores vía addonTable antes de que
-- LootHunter.lua termine de cargar gracias al orden del TOC.
local eventHandlers = {
    ADDON_LOADED                = HandleAddonLoaded,
    GET_ITEM_INFO_RECEIVED      = HandleInfoUpdate,
    PLAYER_EQUIPMENT_CHANGED    = HandleInfoUpdate,
    LOOT_READY                  = HandleLootEvent,
    LOOT_OPENED                 = HandleLootEvent,
    BONUS_ROLL_ACTIVATE         = function(...) if addonTable.HandleBonusRollActivate then addonTable.HandleBonusRollActivate(...) end end,
    BONUS_ROLL_RESULT           = function(...) if addonTable.HandleBonusRollResult   then addonTable.HandleBonusRollResult(...)   end end,
    UNIT_AURA                   = function(...) if addonTable.HandleUnitAura          then addonTable.HandleUnitAura(...)          end end,
    BOSS_KILL                   = HandleBossKill,
    ENCOUNTER_END               = HandleEncounterEnd,
    CHAT_MSG_LOOT               = function(...) if addonTable.HandleChatLoot          then addonTable.HandleChatLoot(...)          end end,
    CHAT_MSG_SYSTEM             = function(...) if addonTable.HandleChatSystem         then addonTable.HandleChatSystem(...)        end end,
    CHAT_MSG_RAID               = function(...) if addonTable.HandleChatLinkAnnounce  then addonTable.HandleChatLinkAnnounce(...)  end end,
    CHAT_MSG_RAID_LEADER        = function(...) if addonTable.HandleChatLinkAnnounce  then addonTable.HandleChatLinkAnnounce(...)  end end,
    CHAT_MSG_RAID_WARNING       = function(...) if addonTable.HandleChatLinkAnnounce  then addonTable.HandleChatLinkAnnounce(...)  end end,
    CHAT_MSG_PARTY              = function(...) if addonTable.HandleChatLinkAnnounce  then addonTable.HandleChatLinkAnnounce(...)  end end,
    CHAT_MSG_PARTY_LEADER       = function(...) if addonTable.HandleChatLinkAnnounce  then addonTable.HandleChatLinkAnnounce(...)  end end,
    START_LOOT_ROLL             = function(...) if addonTable.HandleStartLootRoll      then addonTable.HandleStartLootRoll(...)     end end,
    COMBAT_LOG_EVENT_UNFILTERED = function(...) if addonTable.HandleCombatLogEvent    then addonTable.HandleCombatLogEvent(...)    end end,
    UNIT_HEALTH                 = function(...) if addonTable.HandleUnitLifeState      then addonTable.HandleUnitLifeState(...)     end end,
    UNIT_FLAGS                  = function(...) if addonTable.HandleUnitLifeState      then addonTable.HandleUnitLifeState(...)     end end,
    TRADE_SHOW                  = function(...) if addonTable.HandleTradeShow          then addonTable.HandleTradeShow(...)         end end,
    TRADE_CLOSED                = function(...) if addonTable.HandleTradeClosed        then addonTable.HandleTradeClosed(...)       end end,
    PLAYER_SPECIALIZATION_CHANGED = function(...) if addonTable.HandleSpecChange       then addonTable.HandleSpecChange(...)        end end,
    ACTIVE_TALENT_GROUP_CHANGED = function(...) if addonTable.HandleSpecChange         then addonTable.HandleSpecChange(...)        end end,
    PLAYER_TALENT_UPDATE        = function(...) if addonTable.HandleSpecChange         then addonTable.HandleSpecChange(...)        end end,
    GROUP_ROSTER_UPDATE         = function(...) if addonTable.HandleInstanceChange     then addonTable.HandleInstanceChange(...)    end end,
    MERCHANT_SHOW               = function(...) if addonTable.HandleMerchantEvent      then addonTable.HandleMerchantEvent(...)     end end,
    MERCHANT_UPDATE             = function(...) if addonTable.HandleMerchantEvent      then addonTable.HandleMerchantEvent(...)     end end,
    PLAYER_ENTERING_WORLD       = function(...) if addonTable.HandleInstanceChange     then addonTable.HandleInstanceChange(...)    end end,
    ZONE_CHANGED_NEW_AREA       = function(...) if addonTable.HandleInstanceChange     then addonTable.HandleInstanceChange(...)    end end,
    LFG_QUEUE_STATUS_UPDATE     = function(...) if addonTable.HandleLFGQueueUpdate     then addonTable.HandleLFGQueueUpdate(...)    end end,
    LFG_UPDATE                  = function(...) if addonTable.HandleLFGQueueUpdate     then addonTable.HandleLFGQueueUpdate(...)    end end,
    LFG_PROPOSAL_SHOW           = function(...) if addonTable.HandleLFGQueueUpdate     then addonTable.HandleLFGQueueUpdate(...)    end end,
}

frame:SetScript("OnEvent", function(self, event, arg1, ...)
    if eventHandlers[event] then
        eventHandlers[event](event, arg1, ...)
    end
end)

-- Registrar todos los eventos
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
frame:RegisterEvent("BONUS_ROLL_RESULT")
frame:RegisterUnitEvent("UNIT_AURA", "player")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("UNIT_FLAGS")
frame:RegisterEvent("CHAT_MSG_RAID")
frame:RegisterEvent("CHAT_MSG_RAID_LEADER")
frame:RegisterEvent("CHAT_MSG_RAID_WARNING")
frame:RegisterEvent("CHAT_MSG_PARTY")
frame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
frame:RegisterEvent("START_LOOT_ROLL")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("TRADE_SHOW")
frame:RegisterEvent("TRADE_CLOSED")
frame:RegisterEvent("LFG_QUEUE_STATUS_UPDATE")
frame:RegisterEvent("LFG_UPDATE")
frame:RegisterEvent("LFG_PROPOSAL_SHOW")

-- =============================================================
-- SLASH COMMANDS
-- =============================================================

-- Abre la ventana principal de LootHunter, o procesa subcomandos.
-- Uso: /lh add <itemID o itemLink>
SLASH_LOOTHUNTER1 = "/loothunter"
SLASH_LOOTHUNTER2 = "/lh"
SlashCmdList["LOOTHUNTER"] = function(msg)
    local sub, rest = (msg or ""):match("^%s*(%S+)%s*(.-)%s*$")
    if sub and sub:lower() == "add" then
        if not CurrentCharDB then
            print(L["CMD_NOT_INITIALIZED"])
            return
        end
        if not rest or rest == "" then
            print(L["CMD_ADD_USAGE"])
            return
        end
        local itemID, itemLink = addonTable.ParseItemArg(rest)
        if not itemID then
            print(L["CMD_ADD_USAGE"])
            return
        end
        -- Validar que el item existe antes de continuar
        local resolvedID = C_Item.GetItemInfoInstant(itemID)
        if not resolvedID then
            print(L["CMD_ADD_USAGE"])
            return
        end
        -- Cargar datos completos de forma asíncrona y agregar al terminar
        local itemObj = Item:CreateFromItemID(resolvedID)
        itemObj:ContinueOnItemLoad(function()
            local asyncLink = itemObj:GetItemLink()
            -- Usar el link completo si está disponible; si no, construir el string mínimo.
            -- sourceOverride = UNKNOWN_SOURCE para ignorar el journal si está abierto.
            AddItemToList(asyncLink or string.format("item:%d", resolvedID), nil, nil, L["UNKNOWN_SOURCE"])
            if addonTable.CurrentCharDB and addonTable.CurrentCharDB[resolvedID] then
                addonTable.CurrentCharDB[resolvedID].manualAdd = true
            end
        end)
    else
        LootHunter_CreateGUI()
    end
end

-- Simula el kill de un boss (para pruebas sin entrar a instancia)
SLASH_LOOTHUNTER_BOSS1 = "/lh_boss"
SlashCmdList["LOOTHUNTER_BOSS"] = function(msg)
    local bossName = msg and msg:match("^%s*(.-)%s*$") or ""
    if bossName == "" then
        print("[Loot Hunter] Uso: /lh_boss <nombre del boss>")
        return
    end
    if addonTable.ScheduleCoinReminder then addonTable.ScheduleCoinReminder(nil, bossName, true, true) end
    C_Timer.After(5, function()
        if CurrentCharDB then
            for id, data in pairs(CurrentCharDB) do
                if type(id) == "number" and type(data) == "table" and data.status == 0 then
                    local matchFunc = addonTable.ItemMatchesBossSource
                    -- Fallback: buscar en boss source directamente
                    local matches = matchFunc and matchFunc(data, bossName)
                        or (data.boss and data.boss:lower():find(bossName:lower(), 1, true))
                    if matches then
                        ShowDropAlert(id, data)
                        if LootHunter_RefreshUI then LootHunter_RefreshUI() end
                    end
                end
            end
        end
    end)
end

-- Simula la aparición de un item en el loot (para pruebas)
SLASH_LOOTHUNTER_DROP1 = "/lh_drop"
SlashCmdList["LOOTHUNTER_DROP"] = function(msg)
    if not CurrentCharDB then return end
    local itemID, itemLink = addonTable.ParseItemArg(msg or "")
    if not itemID then
        print("[Loot Hunter] Uso: /lh_drop <itemID o itemLink>")
        return
    end
    local entry = addonTable.EnsureItemEntry(itemID, itemLink)
    ShowDropAlert(itemID, entry)
    if LootHunter_RefreshUI then LootHunter_RefreshUI() end
end

-- Marca un item como obtenido manualmente
SLASH_LOOTHUNTER_WON1 = "/lh_won"
SlashCmdList["LOOTHUNTER_WON"] = function(msg)
    if not CurrentCharDB then return end
    local itemID, itemLink = addonTable.ParseItemArg(msg or "")
    if not itemID then
        print("[Loot Hunter] Uso: /lh_won <itemID o itemLink>")
        return
    end
    local entry = addonTable.EnsureItemEntry(itemID, itemLink)
    if entry and entry.status ~= 2 then
        entry.status    = 2
        entry.lastState = "won"
        if addonTable.StatsStore then
            addonTable.StatsStore:RecordHistoryEvent("won", { itemID = itemID, link = entry.link or entry.name, boss = entry.boss, player = UnitName("player") })
            addonTable.StatsStore:AddSessionLootEntry(itemID, entry.link or entry.name, UnitName("player"), select(2, UnitClass("player")), nil, false, entry.boss, entry.bonus)
        end
        if LootHunter_RefreshUI then LootHunter_RefreshUI() end
        if LootHunterDB.settings.lootAlerts.itemWon then
            local winTitle  = CreateGradient(L["WIN_ALERT_TITLE"], 0.35, 1, 0.35, 0.65, 1, 0.65)
            local winDesc   = CreateGradient(L["WIN_ALERT_DESC"],  0.35, 1, 0.35, 0.65, 1, 0.65)
            local winBanner = string.format("%s %s %s", ICON_STAR, winTitle, ICON_STAR)
            local itemLine  = entry.link or entry.name or "?"
            EnqueueAlert(ALERT_DEFAULT_DURATION, ALERT_PRIORITY_PRIMARY, function()
                if addonTable.FlashScreen then addonTable.FlashScreen("WIN") end
                if addonTable.ShowAlert   then addonTable.ShowAlert(string.format("%s\n%s\n%s", winBanner, winDesc, itemLine), 0, 1, 0) end
                if not PlaySound(12891, "Master") then PlaySound(12891) end
            end)
            print(string.format(L["CONGRATS_CHAT_MSG"], itemLine))
        end
        
        -- Eliminar automáticamente de la lista si la opción está activada
        if LootHunterDB.settings.misc and LootHunterDB.settings.misc.autoRemoveFromList then
            CurrentCharDB[itemID] = nil
            if LootHunter_RefreshUI then LootHunter_RefreshUI() end
        end
    end
end

-- Muestra el Wall of Shame (anuncio de loot en un canal)
SLASH_LOOTHUNTER_WALL1 = "/lh_wall"
SlashCmdList["LOOTHUNTER_WALL"] = function(msg)
    if not addonTable or not addonTable.AnnounceWallOfShame then
        print("[Loot Hunter] Wall of shame no está disponible.")
        return
    end
    if not StaticPopupDialogs then
        addonTable.AnnounceWallOfShame("LOCAL")
        return
    end

    local function BuildWallPromptText()
        local _key = addonTable.SelectedSessionKey
        if not _key and addonTable.GetCurrentSessionKey then _key = addonTable.GetCurrentSessionKey() end
        if not _key and addonTable.GetLatestSessionKey  then _key = addonTable.GetLatestSessionKey()  end
        local sessionLabel = nil
        if _key and addonTable.GetSessionByKey then
            local _session = addonTable.GetSessionByKey(_key)
            if _session then
                local _raidName = _session.raidName or "Raid"
                local _idx      = _session.sessionIndex or 1
                local _dateStr  = (_session.startedAt and type(date) == "function") and date("%m/%d/%Y", _session.startedAt) or ""
                sessionLabel = _session.label or string.format("%s #%d - %s", _raidName, _idx, _dateStr ~= "" and _dateStr or "N/A")
            end
        end
        local promptText = L["STATS_WALL_CHANNEL_PROMPT"] or "Where do you want to announce the Wall of Shame?"
        if sessionLabel then
            promptText = promptText .. "\n\n" .. string.format(L["STATS_WALL_SESSION_LABEL"] or "Session: %s", sessionLabel)
        end
        return promptText
    end

    if not StaticPopupDialogs["LOOTHUNTER_WALL_CHANNEL"] then
        StaticPopupDialogs["LOOTHUNTER_WALL_CHANNEL"] = {
            text    = BuildWallPromptText(),
            button1 = L["STATS_WALL_CHANNEL_LOCAL"]  or "Local",
            button2 = L["STATS_WALL_CHANNEL_GUILD"]  or "Guild",
            button3 = L["STATS_WALL_CHANNEL_RAID"]   or "Raid",
            OnAccept = function() addonTable.AnnounceWallOfShame("LOCAL") end,
            OnCancel = function() end,
            OnAlt    = function() addonTable.AnnounceWallOfShame("RAID")  end,
            OnShow = function(self)
                self:SetHeight(165)

                if self.text then
                    self.text:ClearAllPoints()
                    self.text:SetPoint("TOP", self, "TOP", 0, -22)
                    self.text:SetPoint("LEFT", self, "LEFT", 28, 0)
                    self.text:SetPoint("RIGHT", self, "RIGHT", -28, 0)
                end

                if self.button1 then
                    self.button1:ClearAllPoints()
                    self.button1:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 32, 22)
                    self.button1:SetWidth(168)
                end

                if self.button2 then
                    self.button2:ClearAllPoints()
                    self.button2:SetPoint("BOTTOM", self, "BOTTOM", 0, 22)
                    self.button2:SetWidth(168)
                    self.button2:SetScript("OnClick", function()
                        StaticPopup_Hide("LOOTHUNTER_WALL_CHANNEL")
                        addonTable.AnnounceWallOfShame("GUILD")
                    end)
                end

                if self.button3 then
                    self.button3:ClearAllPoints()
                    self.button3:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -32, 22)
                    self.button3:SetWidth(168)
                end

                if not self.lhCloseButton then
                    local closeButton = CreateFrame("Button", nil, self, "UIPanelCloseButton")
                    closeButton:SetPoint("TOPRIGHT", self, "TOPRIGHT", -4, -4)
                    closeButton:SetScript("OnClick", function()
                        StaticPopup_Hide("LOOTHUNTER_WALL_CHANNEL")
                    end)
                    self.lhCloseButton = closeButton
                end

                self.lhCloseButton:Show()
            end,
            OnHide = function(self)
                if self.lhCloseButton then self.lhCloseButton:Hide() end
            end,
            timeout        = 0,
            whileDead      = true,
            hideOnEscape   = true,
            preferredIndex = 3,
        }
    end

    -- Actualizar texto y botones antes de mostrar (soporta cambios de idioma y de sesión)
    local d = StaticPopupDialogs["LOOTHUNTER_WALL_CHANNEL"]
    d.text    = BuildWallPromptText()
    d.button1 = L["STATS_WALL_CHANNEL_LOCAL"] or d.button1
    d.button2 = L["STATS_WALL_CHANNEL_GUILD"] or d.button2
    d.button3 = L["STATS_WALL_CHANNEL_RAID"]  or d.button3

    StaticPopup_Show("LOOTHUNTER_WALL_CHANNEL")
end
