-- =============================================================
-- Módulo: LootParser.lua
-- Parseo de mensajes de chat de loot y rolls.
-- Gestión de patrones de loot, detección de Need/Greed/Pass,
-- filtro de canales de raid y manejadores de eventos de chat.
-- =============================================================
local _, addonTable = ...

local L               = addonTable.L
local LogDebug        = addonTable.LogDebug        or function() end
local FormatLogPrefix = addonTable.FormatLogPrefix or function(t) return "[" .. t .. "]" end
local NormalizeUnitName    = addonTable.NormalizeUnitName
local NormalizeName        = addonTable.NormalizeName
local IsAuthorizedAnnounce = addonTable.IsAuthorizedAnnounce

-- =============================================================
-- PATRONES DE LOOT
-- =============================================================

-- Normaliza un formato de loot de GlobalStrings reemplazando %s/%d con capturas Lua
local function NormalizeLootFormat(fmt)
    if not fmt then return nil end
    local patternStr = fmt:gsub("%(", "%%("):gsub("%)", "%%)"):gsub("%%[sd]", "(.-)")
    return "^" .. patternStr .. "$"
end

-- Construye patrones que identifican mensajes de loot del propio jugador
local function BuildSelfLootPatterns()
    local patterns = {}
    local selfFormats = {
        { key = "LOOT_ITEM_SELF",         isBonusRoll = false },
        { key = "LOOT_ITEM_SELF_MULTIPLE", isBonusRoll = false },
        { key = "LOOT_ITEM_BONUS_ROLL",    isBonusRoll = true  },
    }
    for _, entry in ipairs(selfFormats) do
        local fmt = _G[entry.key]
        if fmt then
            local pat = NormalizeLootFormat(fmt)
            if pat then
                patterns[#patterns + 1] = { pattern = pat, isBonusRoll = entry.isBonusRoll }
            end
        end
    end
    -- Fallback EN/ES por si los GlobalStrings faltan
    local fallbacks = {
        { pattern = "^You receive loot: (.+)$",              isBonusRoll = false },
        { pattern = "^You receive loot: (.+) x%d+%.$",       isBonusRoll = false },
        { pattern = "^You receive bonus loot: (.+)$",        isBonusRoll = true  },
        { pattern = "^Recibes: (.+)%.$",                     isBonusRoll = false },
        { pattern = "^Recibes botín extra: (.+)%.$",         isBonusRoll = true  },
    }
    for _, fb in ipairs(fallbacks) do
        patterns[#patterns + 1] = fb
    end
    return patterns
end

-- Construye patrones que identifican mensajes de loot de OTROS jugadores
local function BuildOtherLootPatterns()
    local patterns = {}
    local otherFormats = {
        { key = "LOOT_ITEM_PUSHED_SELF",    isBonusRoll = false },
        { key = "LOOT_ITEM_MULTIPLE",        isBonusRoll = false },
    }
    for _, entry in ipairs(otherFormats) do
        local fmt = _G[entry.key]
        if fmt then
            local pat = NormalizeLootFormat(fmt)
            if pat then
                patterns[#patterns + 1] = { pattern = pat, isBonusRoll = entry.isBonusRoll }
            end
        end
    end
    -- Fallback
    local fallbacks = {
        { pattern = "^(.+) receives loot: (.+)$",        isBonusRoll = false },
        { pattern = "^(.+) receives loot: (.+) x%d+%.$", isBonusRoll = false },
        { pattern = "^(.+) recibe: (.+)%.$",             isBonusRoll = false },
    }
    for _, fb in ipairs(fallbacks) do
        patterns[#patterns + 1] = fb
    end
    return patterns
end

-- Construye marcadores de texto de Bonus Roll en los mensajes de loot
local function BuildBonusRollMarkers()
    local markers = {}
    local keys    = { "BONUS_ROLL_REWARD", "BONUS_ROLL_REWARD_INFO", "BONUS_ROLL_EMPTY" }
    for _, key in ipairs(keys) do
        local val = _G[key]
        if val then markers[#markers + 1] = string.lower(val) end
    end
    markers[#markers + 1] = "bonus loot"
    markers[#markers + 1] = "botín extra"
    return markers
end

-- Construye patrones de sistema para detectar tiradas de dado (1-100)
local function BuildSystemRollChoicePatterns()
    local patterns = {}
    local globalRoll = _G.RANDOM_ROLL_RESULT
    if globalRoll then
        local pat = NormalizeLootFormat(globalRoll)
        if pat then patterns[#patterns + 1] = pat end
    end
    patterns[#patterns + 1] = "^(.+) rolls (%d+) %(1%-100%)$"
    patterns[#patterns + 1] = "^(.+) lanza el dado: (%d+) %(1%-100%)$"
    return patterns
end

-- Patrones construidos en tiempo de carga (GlobalStrings ya disponibles)
local selfLootPatterns    = BuildSelfLootPatterns()
local otherLootPatterns   = BuildOtherLootPatterns()
local createdLootPatterns = {}
local bonusRollMarkers    = BuildBonusRollMarkers()
addonTable.SystemRollChoicePatterns = BuildSystemRollChoicePatterns()

-- =============================================================
-- ESTADO DE ROLLS (Need/Greed/Pass y dados)
-- =============================================================

-- Ventana de tiempo (segundos) para asociar un roll con un item anunciado
local ROLL_TRACK_WINDOW = 30

-- Tablas de rolls recientes: { [playerNameNorm] = rollValue }
local RecentRolls    = {}   -- valor numérico de dado
local RecentRollMeta = {}   -- metadatos (choice, isWin, roll, time)
addonTable.RecentRolls    = RecentRolls
addonTable.RecentRollMeta = RecentRollMeta

-- Variables del roll más reciente del propio jugador
local lastPlayerRollValue  = nil
local lastPlayerRollTime   = nil
local lastPlayerRollItemID = nil
local lastPlayerRollChoice = nil

-- Item anunciado más recientemente mediante START_LOOT_ROLL o chat del líder
local lastAnnouncedRollItemID = nil
local lastAnnouncedRollTime   = nil

-- Consume y devuelve el valor de roll de otro jugador (y lo borra del buffer)
local function ConsumeRecentRollForPlayer(playerName)
    if not playerName then return nil end
    local norm = NormalizeUnitName(playerName)
    if not norm then return nil end
    local val = RecentRolls[norm]
    RecentRolls[norm] = nil
    return val
end
addonTable.ConsumeRecentRollForPlayer = ConsumeRecentRollForPlayer

-- Consume y devuelve los metadatos de roll de otro jugador para un item dado
local function ConsumeRecentRollMetaForPlayer(playerName, itemID)
    if not playerName then return nil end
    local norm = NormalizeUnitName(playerName)
    if not norm or not RecentRollMeta[norm] then return nil end
    local meta = RecentRollMeta[norm]
    local now  = GetTime and GetTime() or 0
    if meta.time and (now - meta.time) > ROLL_TRACK_WINDOW then
        RecentRollMeta[norm] = nil
        return nil
    end
    RecentRollMeta[norm] = nil
    return meta
end
addonTable.ConsumeRecentRollMetaForPlayer = ConsumeRecentRollMetaForPlayer


-- =============================================================
-- HELPERS: ESTADO DE LOOT RECIENTE
-- =============================================================

-- Tabla de items que cayeron en los últimos N segundos para asociar loot a drop
local RecentDropTimes = {}
local RECENT_DROP_WINDOW = 60

-- Marca un item como recientemente visto en el loot
local function MarkRecentDrop(itemID)
    local now = GetTime and GetTime() or 0
    RecentDropTimes[itemID] = now
end
addonTable.MarkRecentDrop = MarkRecentDrop

-- Devuelve si un item cayó recientemente (dentro de la ventana de tiempo)
local function RecentlyDropped(itemID)
    if not itemID then return false end
    local t = RecentDropTimes[itemID]
    if not t then return false end
    local now = GetTime and GetTime() or 0
    return (now - t) <= RECENT_DROP_WINDOW
end

-- Devuelve el valor de dado del propio jugador asociado a un item reciente
local function GetRecentPlayerRollForItem(itemID)
    if not lastPlayerRollValue or not lastPlayerRollItemID then return nil end
    if lastPlayerRollItemID ~= itemID then return nil end
    local now = GetTime and GetTime() or 0
    if (now - (lastPlayerRollTime or 0)) > ROLL_TRACK_WINDOW then return nil end
    return lastPlayerRollValue
end

-- Devuelve si el contexto actual indica que OTRO jugador ganó el item (basado en rolls)
local function ShouldTriggerOtherWon(itemID)
    if not lastAnnouncedRollItemID or lastAnnouncedRollItemID ~= itemID then return false end
    local now = GetTime and GetTime() or 0
    return (now - (lastAnnouncedRollTime or 0)) <= ROLL_TRACK_WINDOW
end

-- =============================================================
-- FILTRO DE CANALES GLOBALES EN RAID
-- Silencia General / Comercio / Defensa / LFG mientras el jugador
-- está dentro de un grupo de raid y el ajuste está habilitado.
-- =============================================================

local globalChatFilterActive = false


-- Filtro aplicado a CHAT_MSG_CHANNEL.
-- CHAT_MSG_CHANNEL solo recibe canales numerados públicos (General, Comercio,
-- Defensa, LFG, etc.) — nunca raid, party, guild ni officer.
-- Si el filtro está activo simplemente bloqueamos el mensaje.
local function GlobalChatFilter(self, event, msg, sender, language,
                                 channelString, target, flags, zoneID,
                                 channelIndex, channelBaseName, ...)
    return globalChatFilterActive
end

-- Devuelve true solo si el jugador está físicamente dentro de una instancia de raid
local function PlayerIsInRaid()
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "raid"
end

-- Actualiza el estado del filtro según la configuración y el contexto actual.
-- Se llama desde HandleInstanceChange (GROUP_ROSTER_UPDATE, PLAYER_ENTERING_WORLD,
-- ZONE_CHANGED_NEW_AREA) y al cambiar el checkbox en Settings.
local function UpdateRaidChatFilter()
    local settingEnabled = LootHunterDB
        and LootHunterDB.settings
        and LootHunterDB.settings.misc
        and LootHunterDB.settings.misc.muteRaidChannels
    -- El filtro se activa solo si el ajuste está ON y el jugador está en raid
    globalChatFilterActive = (settingEnabled and PlayerIsInRaid()) and true or false
    if ChatFrame_AddMessageEventFilter and ChatFrame_RemoveMessageEventFilter then
        -- Siempre quitar primero para evitar registros duplicados
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_CHANNEL", GlobalChatFilter)
        if globalChatFilterActive then
            ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", GlobalChatFilter)
        end
    end
end
addonTable.UpdateRaidChatFilter = UpdateRaidChatFilter



-- =============================================================
-- IsScopeAllowed: controla si las alertas aplican en el contexto actual
-- =============================================================
local function IsScopeAllowed(scope)
    local inInstance, instanceType = IsInInstance()
    local inRaid  = IsInRaid and IsInRaid() or false
    local inGroup = IsInGroup and IsInGroup() or false
    if not scope or scope == "always" then return true end
    if scope == "raid_only"  then return inRaid and inInstance and instanceType == "raid" end
    if scope == "group_only" then return inGroup or inRaid end
    if scope == "instance"   then return inInstance end
    return true
end
addonTable.IsScopeAllowed = IsScopeAllowed

-- Devuelve si la alerta de loot perdido debe mostrarse en el alcance configurado
local function ShouldShowLostAlert()
    local db = LootHunterDB
    if not db or not db.settings or not db.settings.lootAlerts then return false end
    if not db.settings.lootAlerts.lostAlertEnabled then return false end
    return IsScopeAllowed(db.settings.lootAlerts.lostAlertScope)
end

-- =============================================================
-- HANDLEINSTANCECHANGE (cambio de zona/grupo)
-- =============================================================
local function HandleInstanceChange(event)
    local StatsStore = addonTable.StatsStore
    if not StatsStore then return end
    local inInstance, instanceType = IsInInstance()
    local inRaid           = IsInRaid and IsInRaid() or false
    local inRaidInstance   = inInstance and instanceType == "raid"
    if inRaidInstance or inRaid then
        StatsStore:EnsureCurrentSession(true)
    else
        StatsStore:CloseCurrentSession("left_instance")
    end
    UpdateRaidChatFilter()
end
addonTable.HandleInstanceChange = HandleInstanceChange

-- =============================================================
-- MANEJADOR DE CHAT SYSTEM (dado de 1-100)
-- =============================================================
local function HandleChatSystem(event, msg, ...)
    if not msg or type(msg) ~= "string" then return end
    local SystemRollChoicePatterns = addonTable.SystemRollChoicePatterns
    if not SystemRollChoicePatterns then return end
    for _, pat in ipairs(SystemRollChoicePatterns) do
        local a, b = msg:match(pat)
        if a then
            local playerName, rollVal
            if tonumber(a) then
                rollVal    = tonumber(a)
                playerName = b
            else
                playerName = a
                rollVal    = tonumber(b)
            end
            if playerName and rollVal then
                local norm = NormalizeUnitName(playerName)
                if norm then
                    RecentRolls[norm]    = rollVal
                    RecentRollMeta[norm] = RecentRollMeta[norm] or {}
                    RecentRollMeta[norm].roll = rollVal
                    RecentRollMeta[norm].time = GetTime and GetTime() or 0
                end
                -- Si el jugador es el propio personaje, guardarlo en la variable local
                local myName = UnitName("player")
                if myName and NormalizeUnitName(myName) == norm then
                    local now = GetTime and GetTime() or 0
                    if lastAnnouncedRollItemID and lastAnnouncedRollTime
                       and (now - lastAnnouncedRollTime) <= ROLL_TRACK_WINDOW then
                        lastPlayerRollItemID = lastAnnouncedRollItemID
                    else
                        lastPlayerRollItemID = nil
                    end
                    lastPlayerRollValue = rollVal
                    lastPlayerRollTime  = now
                    LogDebug(string.format("%s Roll del jugador detectado: valor=%s item=%s",
                        FormatLogPrefix("Roll"), tostring(rollVal), tostring(lastPlayerRollItemID)))
                end
            end
            return
        end
    end
end
addonTable.HandleChatSystem = HandleChatSystem

-- =============================================================
-- MANEJADOR DE CHAT LOOT (CHAT_MSG_LOOT)
-- =============================================================
local function HandleChatLoot(event, msg, ...)
    local CurrentCharDB = addonTable.CurrentCharDB
    if not CurrentCharDB or type(msg) ~= "string" then return end

    -- Cadenas de localización del juego para Need/Greed/Pass
    local needStr  = _G.LOOT_ROLL_NEED  or "Need"
    local greedStr = _G.LOOT_ROLL_GREED or "Greed"
    local passStr  = _G.LOOT_ROLL_PASS  or "Pass"

    -- Detectar elección Need/Greed/Pass del jugador
    local rollChoice = nil
    if msg:find("You have selected " .. needStr  .. " for:", 1, true) or msg:find("You have selected Need for:", 1, true) then
        rollChoice = "need" ; lastPlayerRollChoice = "need"
    elseif msg:find("You have selected " .. greedStr .. " for:", 1, true) or msg:find("You have selected Greed for:", 1, true) then
        rollChoice = "greed" ; lastPlayerRollChoice = "greed"
    elseif msg:find("You have selected " .. passStr .. " for:", 1, true) or msg:find("You have selected Pass for:", 1, true) then
        rollChoice = "pass"  ; lastPlayerRollChoice = "pass"
    end

    -- Detectar elección de OTROS jugadores
    local otherPlayerName, otherPlayerChoice = nil, nil
    if msg:find(" has selected " .. needStr .. " for:", 1, true) or msg:find(" has selected Need for:", 1, true) then
        otherPlayerName   = msg:match("^(.+) has selected " .. needStr .. " for:") or msg:match("^(.+) has selected Need for:")
        otherPlayerChoice = "need"
    elseif msg:find(" has selected " .. greedStr .. " for:", 1, true) or msg:find(" has selected Greed for:", 1, true) then
        otherPlayerName   = msg:match("^(.+) has selected " .. greedStr .. " for:") or msg:match("^(.+) has selected Greed for:")
        otherPlayerChoice = "greed"
    elseif msg:find(" has selected " .. passStr .. " for:", 1, true) or msg:find(" has selected Pass for:", 1, true) then
        otherPlayerName   = msg:match("^(.+) has selected " .. passStr .. " for:") or msg:match("^(.+) has selected Pass for:")
        otherPlayerChoice = "pass"
    elseif msg:find(" won:", 1, true) then
        otherPlayerName = msg:match("^(.+) won:")
        if otherPlayerName then
            local norm = NormalizeUnitName(otherPlayerName)
            if norm then
                RecentRollMeta[norm] = RecentRollMeta[norm] or {}
                RecentRollMeta[norm].isWin = true
            end
        end
    end

    -- Guardar elección de otros jugadores en RecentRollMeta
    if otherPlayerName and otherPlayerChoice then
        local norm = NormalizeUnitName(otherPlayerName)
        if norm then
            RecentRollMeta[norm] = RecentRollMeta[norm] or {}
            RecentRollMeta[norm].choice = otherPlayerChoice
            RecentRollMeta[norm].time   = GetTime and GetTime() or 0
        end
    end

    -- Ignorar mensajes de loot ya procesados por el addon
    if createdLootPatterns then
        for _, pattern in ipairs(createdLootPatterns) do
            if msg:match(pattern) then return end
        end
    end

    -- Detectar si el propio jugador obtuvo el item
    local itemLink, playerName
    local isMine        = false
    local lootViaBonusRoll = false
    for _, pattern in ipairs(selfLootPatterns) do
        local capturedLink = pattern.pattern and msg:match(pattern.pattern) or nil
        if capturedLink then
            isMine         = true
            lootViaBonusRoll = pattern.isBonusRoll or false
            itemLink       = capturedLink
            break
        end
    end

    -- Si no fue del jugador, revisar si fue de otro
    if not itemLink then
        for _, pattern in ipairs(otherLootPatterns) do
            local capPlayer, capLink = msg:match(pattern.pattern)
            if capPlayer and capLink then
                -- Corregir orden invertido si el link viene primero
                if capPlayer:find("|Hitem:") and not capLink:find("|Hitem:") then
                    capPlayer, capLink = capLink, capPlayer
                end
                playerName       = capPlayer
                itemLink         = capLink
                isMine           = (playerName == UnitName("player"))
                lootViaBonusRoll = pattern.isBonusRoll or false
                break
            end
        end
    end
    if not itemLink then return end

    local id = tonumber(string.match(itemLink, "item:(%d+):"))
    if not id then return end

    -- Verificar si el loot fue vía bonus roll
    local bonusItemID = addonTable.lastBonusRollItemID
    local bonusTime   = addonTable.lastBonusRollTime or 0
    if not lootViaBonusRoll and bonusItemID and id == bonusItemID then
        local now = GetTime and GetTime() or 0
        if (now - bonusTime) <= 12 then lootViaBonusRoll = true end
    end
    if not lootViaBonusRoll and bonusRollMarkers and #bonusRollMarkers > 0 then
        local msgLower = string.lower(msg)
        for _, marker in ipairs(bonusRollMarkers) do
            if marker ~= "" and msgLower:find(marker, 1, true) then
                lootViaBonusRoll = true ; break
            end
        end
    end

    LogDebug(string.format("%s Loot detectado en chat: item=%s (id=%s) fuente=%s jugador=%s rastreado=%s bonus=%s",
        FormatLogPrefix("Alert"),
        tostring(itemLink), tostring(id),
        isMine and "self" or "other",
        tostring(playerName or UnitName("player") or "?"),
        tostring(CurrentCharDB[id] ~= nil),
        tostring(lootViaBonusRoll)))

    addonTable.TriggerLootActivityTimerForItemID(id)
    MarkRecentDrop(id)

    -- Determinar roll del jugador o de otro
    local playerRollValue = isMine and GetRecentPlayerRollForItem(id) or nil
    local otherRollMeta   = nil
    if not isMine and playerName then
        playerRollValue = ConsumeRecentRollForPlayer(playerName)
        otherRollMeta   = ConsumeRecentRollMetaForPlayer(playerName, id)
        if playerRollValue == nil and otherRollMeta and otherRollMeta.roll then
            playerRollValue = tonumber(otherRollMeta.roll)
        end
    end

    -- Registrar ingreso en la sesión actual
    local tradeActive   = addonTable.tradeActive or false
    local skipSessionLog = tradeActive and isMine
    if not skipSessionLog then
        local rollTypeForSession = nil
        if not isMine and otherRollMeta and otherRollMeta.choice then
            rollTypeForSession = otherRollMeta.choice
        elseif isMine then
            if lastPlayerRollChoice and lastPlayerRollChoice ~= "pass" then
                rollTypeForSession = lastPlayerRollChoice
            else
                local myNorm = NormalizeUnitName(UnitName("player"))
                if myNorm and RecentRollMeta[myNorm] and RecentRollMeta[myNorm].choice ~= "pass" then
                    rollTypeForSession = RecentRollMeta[myNorm].choice
                end
            end
        end
        addonTable.StatsStore:AddSessionLootEntry(
            id, itemLink,
            playerName or (isMine and UnitName("player")) or playerName,
            nil, playerRollValue, playerRollValue ~= nil, nil,
            lootViaBonusRoll, rollTypeForSession
        )
    end

    -- Lógica específica si el item está en la lista del jugador
    local itemData = CurrentCharDB[id]
    if not itemData then return end

    if isMine then
        -- El jugador obtuvo el item
        if playerRollValue then
            lastPlayerRollItemID = nil ; lastPlayerRollValue = nil
            lastPlayerRollTime   = nil ; lastPlayerRollChoice = nil
        end
        if itemData.status ~= 2 then
            itemData.status    = 2
            itemData.lastState = "won"
            addonTable.StatsStore:RecordHistoryEvent("won", { itemID = id, link = itemData.link or itemData.name, boss = itemData.boss, player = UnitName("player") })
            if LootHunter_RefreshUI then LootHunter_RefreshUI() end
            
            -- Auto-remove from list if setting is enabled
            if LootHunterDB.settings.misc and LootHunterDB.settings.misc.autoRemoveFromList then
                CurrentCharDB[id] = nil
            end
            
            addonTable.RemoveItemFromReminder(id)
            local allowScope = IsScopeAllowed(LootHunterDB and LootHunterDB.settings and LootHunterDB.settings.lootAlerts and LootHunterDB.settings.lootAlerts.lostAlertScope)
            if allowScope and LootHunterDB.settings.lootAlerts.itemWon then
                local CreateGradient = addonTable.CreateGradient or function(t) return t end
                local ICON_STAR      = addonTable.ICON_STAR or ""
                local winTitle  = CreateGradient(L["WIN_ALERT_TITLE"], 0.35, 1, 0.35, 0.65, 1, 0.65)
                local winDesc   = CreateGradient(L["WIN_ALERT_DESC"],  0.35, 1, 0.35, 0.65, 1, 0.65)
                local winBanner = string.format("%s %s %s", ICON_STAR, winTitle, ICON_STAR)
                local itemLine  = itemData.link or itemData.name or "?"
                local EnqueueAlert = addonTable.EnqueueAlert
                if EnqueueAlert then
                    EnqueueAlert(6, function()
                        if addonTable.FlashScreen then addonTable.FlashScreen("WIN") end
                        if addonTable.ShowAlert   then addonTable.ShowAlert(string.format("%s\n%s\n%s", winBanner, winDesc, itemLine), 0, 1, 0) end
                        PlaySound(12891)
                    end, 1)
                end
                print(string.format(L["CONGRATS_CHAT_MSG"], itemData.link))
            end
        end
    else
        -- Otro jugador obtuvo el item
        if itemData.status ~= 2 then
            local viaRoll = ShouldTriggerOtherWon(id)
            if not viaRoll and otherRollMeta then
                viaRoll = (otherRollMeta.isWin == true)
                    or (otherRollMeta.choice == "need" or otherRollMeta.choice == "greed" or otherRollMeta.choice == "won")
            end
            local viaRecentDrop = not viaRoll and RecentlyDropped(id)
            if viaRoll or viaRecentDrop then
                itemData.status = 1
                addonTable.StatsStore:RecordHistoryEvent("lost", { itemID = id, link = itemData.link or itemData.name, boss = itemData.boss, player = playerName or L["UNKNOWN_SOURCE"] })
                if LootHunter_RefreshUI then LootHunter_RefreshUI() end
                if ShouldShowLostAlert() and LootHunterDB.settings.lootAlerts.itemSeen then
                    local looter       = playerName or L["UNKNOWN_SOURCE"]
                    local coloredLooter = string.format("|cffff0000%s|r", looter)
                    local otherMsg      = string.format(L["DROP_OTHER_CHAT_MSG"], itemData.link or itemData.name or "?", coloredLooter)
                    print(otherMsg)
                    local EnqueueAlert = addonTable.EnqueueAlert
                    if addonTable.ShowPreWarningFrame and EnqueueAlert then
                        EnqueueAlert(6, function()
                            addonTable.ShowPreWarningFrame(otherMsg, 6, false, true)
                            if addonTable.PlayOtherWonSound then addonTable.PlayOtherWonSound() end
                            if addonTable.FlashScreen      then addonTable.FlashScreen("RED")   end
                        end, 1)
                    else
                        if addonTable.PlayOtherWonSound then addonTable.PlayOtherWonSound() end
                        if addonTable.FlashScreen       then addonTable.FlashScreen("RED")   end
                    end
                    -- Recordatorio adicional si el bonus roll sigue activo
                    if LootHunterDB.settings.coinReminder and LootHunterDB.settings.coinReminder.enabled and addonTable.IsBonusRollWindowVisible() then
                        C_Timer.After(3, function()
                            if not addonTable.IsBonusRollWindowVisible() then return end
                            local lostMsg = L["COIN_LOST_REMINDER"]
                            print(lostMsg)
                            if addonTable.ShowPreWarningFrame and EnqueueAlert then
                                EnqueueAlert(6, function()
                                    addonTable.ShowPreWarningFrame(lostMsg, 6)
                                    PlaySound(3081, "Master")
                                end, 3)
                            end
                        end)
                    end
                    addonTable.RemoveItemFromReminder(id)
                end
                -- Auto-reset tras 45s si sigue en estado "drop visto"
                C_Timer.After(45, function()
                    if CurrentCharDB and CurrentCharDB[id] and CurrentCharDB[id].status == 1 then
                        CurrentCharDB[id].status = 0
                        if LootHunter_RefreshUI then LootHunter_RefreshUI() end
                    end
                end)
                C_Timer.After(120, function()
                    if CurrentCharDB and CurrentCharDB[id] and CurrentCharDB[id].status == 1 then
                        CurrentCharDB[id].status = 0
                        if LootHunter_RefreshUI then LootHunter_RefreshUI() end
                    end
                end)
            end
        end
    end
end
addonTable.HandleChatLoot = HandleChatLoot

-- =============================================================
-- HANDLECHATLINKANOUNCE: link de item en chat de raid por líderes
-- =============================================================


local function HandleChatLinkAnnounce(event, msg, sender, ...)
    local CurrentCharDB = addonTable.CurrentCharDB
    if not CurrentCharDB or type(msg) ~= "string" then return end
    if not IsAuthorizedAnnounce(sender) then return end
    for link in msg:gmatch("|Hitem:[-%d:]+|h.-|h") do
        local itemID = tonumber(link:match("item:(%d+):"))
        if itemID and CurrentCharDB[itemID] and CurrentCharDB[itemID].status == 0 then
            if addonTable.ShowDropAlert then addonTable.ShowDropAlert(itemID, CurrentCharDB[itemID]) end
            if LootHunter_RefreshUI then LootHunter_RefreshUI() end
        end
        if itemID then
            lastAnnouncedRollItemID = itemID
            lastAnnouncedRollTime   = GetTime()
        end
    end
end
addonTable.HandleChatLinkAnnounce = HandleChatLinkAnnounce

-- Detecta inicio de tirada Need/Greed en mazmorra (Group Loot)
local function HandleStartLootRoll(event, rollID, rollTime)
    local CurrentCharDB = addonTable.CurrentCharDB
    if not rollID or not GetLootRollItemLink or not CurrentCharDB then return end
    local link = GetLootRollItemLink(rollID)
    if not link then return end
    local id = tonumber(string.match(link, "item:(%d+):"))
    if not id or not CurrentCharDB[id] or CurrentCharDB[id].status ~= 0 then return end
    local itemData = CurrentCharDB[id]
    local itemName = (itemData and itemData.name) or link
    LogDebug(string.format("%s START_LOOT_ROLL para item pendiente %d (%s)", FormatLogPrefix("Alert"), id, itemName))
    if addonTable.ShowDropAlert then addonTable.ShowDropAlert(id, itemData) end
    if LootHunter_RefreshUI then LootHunter_RefreshUI() end
    lastAnnouncedRollItemID = id
    lastAnnouncedRollTime   = GetTime()
    lastPlayerRollItemID    = id
    lastPlayerRollTime      = GetTime()
end
addonTable.HandleStartLootRoll = HandleStartLootRoll
