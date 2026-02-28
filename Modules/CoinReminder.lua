-- =============================================================
-- Módulo: CoinReminder.lua
-- Lógica del recordatorio de moneda de bonus roll:
-- detecta kills de boss, programa temporizadores, y muestra
-- alertas si el loot deseado no cayó y el bonus roll está activo.
-- =============================================================
local _, addonTable = ...

local L               = addonTable.L
local LogDebug        = addonTable.LogDebug        or function() end
local FormatLogPrefix = addonTable.FormatLogPrefix or function(t) return "[" .. t .. "]" end
local TrimString      = addonTable.TrimString

-- Constantes de tiempo para el recordatorio de moneda
local COIN_REMINDER_DELAY    = 4
local COIN_REMINDER_MIN_WAIT = 30
local COIN_REMINDER_MAX_WAIT = 150

-- Iconos compartidos
local ICON_DIAMOND  = addonTable.ICON_DIAMOND  or ""
local ICON_TRIANGLE = addonTable.ICON_TRIANGLE or ""
local PREWARN_SOUND_ID  = (SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081
local COIN_LOST_SOUND_ID = (SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081

-- Tabla de recordatorios pendientes indexada por "bossname:encounterID"
local PendingCoinReminders = {}
-- Nombre del último boss que activó un recordatorio (para estadísticas)
local LastCoinReminderBoss  = nil
-- Tiempo en que se usó la moneda por última vez (previene doble registro)
local lastCoinUsedAt        = 0
-- Tiempo del último bonus roll looteado
local lastBonusRollItemID   = nil
local lastBonusRollTime     = 0

-- IDs de los buffs de Seal of Power / Seal of Fate (MoP)
local bonusSpellIDs = { 126938, 128362 }

-- Devuelve si la ventana de Bonus Roll está visible en pantalla
local function IsBonusRollWindowVisible()
    local f = _G.BonusRollFrame
    return f and f:IsShown()
end
addonTable.IsBonusRollWindowVisible = IsBonusRollWindowVisible


-- Devuelve si un item de la wishlist coincide con el boss que acabó de morir
local function ItemMatchesBossSource(itemData, bossName)
    if not itemData or not bossName then return false end
    local source = itemData.boss
    if not source or source == "" or source == L["UNKNOWN_SOURCE"] then return false end
    local srcLower  = string.lower(source)
    local bossLower = string.lower(bossName)
    if srcLower:find(bossLower, 1, true) then return true end
    for token in srcLower:gmatch("[^/]+") do
        token = TrimString(token)
        if token and token ~= "" then
            if token:find(bossLower, 1, true) or bossLower:find(token, 1, true) then return true end
            for dash in token:gmatch("[^%-]+") do
                dash = TrimString(dash)
                if dash and dash ~= "" and (dash:find(bossLower, 1, true) or bossLower:find(dash, 1, true)) then
                    return true
                end
            end
        end
    end
    return false
end

-- Busca en los recordatorios pendientes el key que contiene el itemID dado
local function FindReminderKeyForItem(itemID)
    if not itemID then return nil end
    for key, entry in pairs(PendingCoinReminders) do
        if entry and entry.items then
            for _, pendingID in ipairs(entry.items) do
                if pendingID == itemID then return key end
            end
        end
    end
    return nil
end

-- Marca que el drop de un item rastreado fue detectado en el loot de ese boss
local function MarkDropSeen(itemID, reason)
    local key = FindReminderKeyForItem(itemID)
    if not key then return end
    local entry = PendingCoinReminders[key]
    if not entry then return end
    entry.dropSeen   = true
    entry.dropSeenAt = GetTime()
    if addonTable.LogCoinDebug then
        addonTable.LogCoinDebug(string.format("Drop visto para item %d (razón: %s).", itemID, reason or "desconocida"))
    end
end
addonTable.MarkDropSeen = MarkDropSeen

-- Elimina un item del recordatorio pendiente cuando fue obtenido o descartado
local function RemoveItemFromReminder(itemID)
    local key = FindReminderKeyForItem(itemID)
    if not key then return end
    local entry = PendingCoinReminders[key]
    if not entry or not entry.items then return end
    local remaining = {}
    for _, pendingID in ipairs(entry.items) do
        if pendingID ~= itemID then remaining[#remaining + 1] = pendingID end
    end
    entry.items = remaining
    if #remaining == 0 then PendingCoinReminders[key] = nil end
end
addonTable.RemoveItemFromReminder = RemoveItemFromReminder

-- Cancela todos los recordatorios pendientes (se usó el bonus roll)
local function CancelCoinRemindersForBonusRoll(reason)
    if not PendingCoinReminders or not next(PendingCoinReminders) then return end
    for key, entry in pairs(PendingCoinReminders) do
        if entry then
            entry.blockCoin = true
            PendingCoinReminders[key] = nil
            if addonTable.LogCoinDebug then
                addonTable.LogCoinDebug(string.format("Recordatorio cancelado para %s (%s).", entry.boss or "Unknown", reason or "bonus_roll"))
            end
        end
    end
end

local function ActivatePendingForBonusRoll(reason)
    CancelCoinRemindersForBonusRoll(reason or "bonus_roll_activate")
end

-- Devuelve el tiempo de espera configurado por el usuario para el recordatorio
local function GetCoinReminderWait()
    local value = COIN_REMINDER_MAX_WAIT
    if LootHunterDB and LootHunterDB.settings and LootHunterDB.settings.coinReminder then
        local saved = tonumber(LootHunterDB.settings.coinReminder.reminderDelay)
        if saved then value = saved end
        value = math.max(COIN_REMINDER_MIN_WAIT, math.min(COIN_REMINDER_MAX_WAIT, value))
        LootHunterDB.settings.coinReminder.reminderDelay = value
    end
    return value
end

-- Procesa el recordatorio pendiente: muestra alertas si el boss no dio el item
local function ProcessCoinReminder(key)
    local entry         = PendingCoinReminders[key]
    local CurrentCharDB = addonTable.CurrentCharDB
    if not entry or not CurrentCharDB then return end
    if entry.blockCoin then
        if addonTable.LogCoinDebug then addonTable.LogCoinDebug(string.format("Recordatorio para %s bloqueado.", entry.boss or "Unknown")) end
        return
    end
    PendingCoinReminders[key] = nil
    local stillMissing = {}
    for _, id in ipairs(entry.items) do
        local data = CurrentCharDB[id]
        if data and data.status ~= 2 then stillMissing[#stillMissing + 1] = data end
    end
    if #stillMissing == 0 then
        if addonTable.LogCoinDebug then addonTable.LogCoinDebug(string.format("Recordatorio para %s cancelado: ningún item pendiente.", entry.boss or "Unknown")) end
        return
    end
    local coinEnabled = entry.coinEnabled
    if coinEnabled then
        addonTable.StatsStore:RecordHistoryEvent("coin_reminder", { boss = entry.boss, player = UnitName("player") })
    end
    if not entry.dropSeen then
        addonTable.StatsStore:RecordHistoryEvent("boss_no_loot", { boss = entry.boss, player = UnitName("player") })
    end
    if coinEnabled and LootHunterDB.settings.coinReminder.visualAlert then
        local chatFmt = L["COIN_REMINDER_RAID_CHAT"] or L["COIN_REMINDER_RAID_MSG"]
        local chatMsg = string.format(chatFmt, entry.boss)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(chatMsg)
        else
            print(chatMsg)
        end
        local CreateGradient = addonTable.CreateGradient or function(t) return t end
        local titleRaw  = L["COIN_REMINDER_ALERT_TITLE"] or "Your loot didn't drop!"
        local promptRaw = L["COIN_REMINDER_ALERT_PROMPT"] or "Use your coin now!"
        local title     = CreateGradient(titleRaw,  1, 0.85, 0.35, 1, 0.75, 0)
        local prompt    = CreateGradient(promptRaw, 1, 0.85, 0.35, 1, 0.75, 0)
        local msg       = string.format("%s %s %s\n%s", ICON_DIAMOND, title, ICON_DIAMOND, prompt)
        local EnqueueAlert = addonTable.EnqueueAlert
        if EnqueueAlert then
            EnqueueAlert(6.8, function()
                if addonTable.ShowAlert   then addonTable.ShowAlert(msg, 1, 0.85, 0) end
                if addonTable.FlashScreen then addonTable.FlashScreen("YELLOW") end
            end, 2)
        end
    end
    if coinEnabled and LootHunterDB.settings.coinReminder.soundEnabled then
        PlaySound(LootHunterDB.settings.coinReminder.soundFile or 12867)
    end
    if coinEnabled then
        print(string.format(L["COIN_REMINDER_CHAT_MSG"], entry.boss))
    end
end

-- Inicia el temporizador para mostrar el recordatorio si se cumplen las condiciones
local function StartCoinReminderTimer(key, reason, delay)
    local entry = PendingCoinReminders[key]
    if not entry or entry.timerStarted or entry.blockCoin then return end
    if entry.deferStartUntil and GetTime() < entry.deferStartUntil then return end
    entry.timerStarted = true
    delay = delay or COIN_REMINDER_DELAY
    if addonTable.LogCoinDebug then
        addonTable.LogCoinDebug(string.format("Temporizador iniciado para %s (razón: %s, espera: %.1fs)", entry.boss or "Unknown", reason or "?", delay))
    end
    C_Timer.After(delay, function()
        if addonTable.LogCoinDebug then
            addonTable.LogCoinDebug(string.format("Temporizador listo para %s. Procesando recordatorio.", entry.boss or "Unknown"))
        end
        ProcessCoinReminder(key)
    end)
end

-- Detecta si el jugador tiene el buff de Bonus Roll activo
local function HasBonusRollBuff()
    for i = 1, 40 do
        local _, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", i)
        if not spellID then break end
        for _, id in ipairs(bonusSpellIDs) do
            if spellID == id then return true end
        end
    end
    return false
end

-- Registra que se usó la moneda una sola vez en un intervalo de 5s
local function RecordCoinUsedOnce(reason)
    local now = GetTime and GetTime() or 0
    if (now - (lastCoinUsedAt or 0)) < 5 then return end
    lastCoinUsedAt = now
    addonTable.StatsStore:RecordHistoryEvent("coin_used", { boss = LastCoinReminderBoss, player = UnitName("player"), reason = reason })
end

-- Manejador de BONUS_ROLL_ACTIVATE
local function HandleBonusRollActivate(event, ...)
    if addonTable.LogCoinDebug then
        addonTable.LogCoinDebug(FormatLogPrefix("Coin Debug") .. " BONUS_ROLL_ACTIVATE recibido")
    end
    RecordCoinUsedOnce("bonus_roll_activate")
    ActivatePendingForBonusRoll("bonus_roll_activate")
end

-- Manejador de BONUS_ROLL_RESULT
local function HandleBonusRollResult(event, rollID, result, rewardType, itemID, itemLink)
    local id = itemID
    if not id and type(itemLink) == "string" then
        id = tonumber(itemLink:match("item:(%d+):"))
    end
    if id then
        lastBonusRollItemID = id
        lastBonusRollTime   = GetTime and GetTime() or 0
    end
end
addonTable.lastBonusRollItemID = lastBonusRollItemID
addonTable.lastBonusRollTime   = lastBonusRollTime

-- Manejador de UNIT_AURA para detectar el buff de bonus roll
local function HandleUnitAura(event, unit)
    if unit ~= "player" then return end
    if HasBonusRollBuff() then
        if addonTable.LogCoinDebug then addonTable.LogCoinDebug(FormatLogPrefix("Coin Debug") .. " Buff de Bonus Roll detectado") end
        ActivatePendingForBonusRoll("bonus_roll_buff")
    end
end

-- Detecta actividad de loot para un itemID rastreado en recordatorios pendientes
local function TriggerLootActivityTimerForItemID(itemID)
    if not itemID then return end
    itemID = tonumber(itemID)
    if not itemID then return end
    for key, entry in pairs(PendingCoinReminders) do
        for _, pendingID in ipairs(entry.items) do
            if pendingID == itemID then
                if addonTable.LogCoinDebug then
                    addonTable.LogCoinDebug(string.format("Actividad de loot detectada para itemID %d.", itemID))
                end
                MarkDropSeen(itemID, "loot_activity")
            end
        end
    end
end
addonTable.TriggerLootActivityTimerForItemID = TriggerLootActivityTimerForItemID

-- Procesa temporizadores de loot al abrir/recibir loot (llamado desde HandleLootEvent)
local function TriggerLootReadyTimers()
    for key, entry in pairs(PendingCoinReminders) do
        if entry then
            if not entry.timerStarted then
                if addonTable.LogCoinDebug then
                    addonTable.LogCoinDebug(string.format("Loot abierto para %s (drop visto=%s).", entry.boss or "?", tostring(entry.dropSeen)))
                end
            elseif entry.isTwoStage then
                if addonTable.LogCoinDebug then addonTable.LogCoinDebug("Loot abierto durante espera de 2 fases. Procesando inmediatamente.") end
                ProcessCoinReminder(key)
            end
        end
    end
end
addonTable.TriggerLootReadyTimers = TriggerLootReadyTimers

-- Programa el recordatorio de moneda tras un kill de boss
local function ScheduleCoinReminder(encounterID, bossName, forceRaid, forcePreWarn)
    local CurrentCharDB = addonTable.CurrentCharDB
    if not CurrentCharDB or not bossName or bossName == "" then return end
    if not (LootHunterDB and LootHunterDB.settings and LootHunterDB.settings.coinReminder) then return end
    local coinEnabled    = LootHunterDB.settings.coinReminder.enabled
    local _, instanceType = IsInInstance()
    LastCoinReminderBoss = bossName
    local instanceName   = (GetInstanceInfo and select(1, GetInstanceInfo())) or nil
    local reminderDelay  = GetCoinReminderWait()

    -- Encontrar items de la lista que coincidan con este boss
    local pendingItems = {}
    for id, data in pairs(CurrentCharDB) do
        if type(id) == "number" and type(data) == "table" and data.status == 0 then
            if ItemMatchesBossSource(data, bossName) then
                pendingItems[#pendingItems + 1] = id
            end
        end
    end

    if #pendingItems == 0 then
        -- Notificación opcional si el boss no tiene items en la lista pero la instancia sí
        if instanceName and instanceName ~= "" and LootHunterDB.settings.lootAlerts and LootHunterDB.settings.lootAlerts.bossNoItems then
            local instanceLower = string.lower(instanceName)
            local hasInstanceItems = false
            for id, data in pairs(CurrentCharDB) do
                if type(id) == "number" and type(data) == "table" and data.boss and data.boss ~= "" and data.boss ~= L["UNKNOWN_SOURCE"] then
                    if string.lower(data.boss):find(instanceLower, 1, true) then hasInstanceItems = true ; break end
                end
            end
            if hasInstanceItems then
                print(string.format(L["COIN_NO_ITEMS_BOSS"], string.format("|cffff0000%s|r", bossName)))
            end
        end
        return
    end

    if not forceRaid and instanceType ~= "raid" then return end

    local key = string.lower(bossName) .. ":" .. tostring(encounterID or 0)
    PendingCoinReminders[key] = {
        boss           = bossName,
        encounterID    = encounterID,
        items          = pendingItems,
        timerStarted   = false,
        dropSeen       = false,
        blockCoin      = false,
        coinEnabled    = coinEnabled,
        deathTime      = GetTime(),
    }

    -- Pre-aviso visual si el bonus roll window estará visible
    if coinEnabled and LootHunterDB.settings.coinReminder.preWarning then
        C_Timer.After(3, function()
            local entry = PendingCoinReminders[key]
            if not entry then return end
            local windowVisible = IsBonusRollWindowVisible()
            if windowVisible or forcePreWarn then
                local msg = string.format(L["COIN_PRE_WARNING"] or "[Loot Hunter] %s podría tener tu loot. ¡Prepara tu moneda!", entry.boss)
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    DEFAULT_CHAT_FRAME:AddMessage(msg)
                else
                    print(msg)
                end
                local EnqueueAlert = addonTable.EnqueueAlert
                if addonTable.ShowPreWarningFrame and EnqueueAlert then
                    EnqueueAlert(6, function()
                        addonTable.ShowPreWarningFrame(msg, 6)
                        if PREWARN_SOUND_ID then PlaySound(PREWARN_SOUND_ID, "Master") end
                    end, 3)
                elseif PREWARN_SOUND_ID then
                    PlaySound(PREWARN_SOUND_ID, "Master")
                end
            end
        end)
    end

    -- Temporizador principal: lanza el recordatorio si el bonus roll sigue visible
    C_Timer.After(reminderDelay, function()
        local entry = PendingCoinReminders[key]
        if not entry or entry.blockCoin then return end
        if not entry.coinEnabled then
            if not entry.dropSeen and not entry.bossNoLootRecorded then
                entry.bossNoLootRecorded = true
                addonTable.StatsStore:RecordHistoryEvent("boss_no_loot", { boss = entry.boss, player = UnitName("player") })
            end
            PendingCoinReminders[key] = nil
            return
        end
        if not IsBonusRollWindowVisible() then
            if not entry.dropSeen and not entry.bossNoLootRecorded then
                entry.bossNoLootRecorded = true
                addonTable.StatsStore:RecordHistoryEvent("boss_no_loot", { boss = entry.boss, player = UnitName("player") })
            end
            PendingCoinReminders[key] = nil
            return
        end
        StartCoinReminderTimer(key, "no_drop", 0)
    end)
end
addonTable.ScheduleCoinReminder = ScheduleCoinReminder

-- Muestra la alerta visual del recordatorio manualmente (desde botón de la UI)
local function ShowCoinReminderVisual(bossName)
    local CreateGradient = addonTable.CreateGradient or function(t) return t end
    local title  = CreateGradient(L["COIN_REMINDER_ALERT_TITLE"], 1, 0.85, 0.35, 1, 0.75, 0)
    local prompt = CreateGradient(L["COIN_REMINDER_ALERT_PROMPT"], 1, 0.85, 0.35, 1, 0.75, 0)
    local text   = string.format("%s %s %s\n%s", ICON_TRIANGLE, title, ICON_TRIANGLE, prompt)
    local EnqueueAlert = addonTable.EnqueueAlert
    if EnqueueAlert then
        EnqueueAlert(6.8, function()
            if addonTable.ShowAlert   then addonTable.ShowAlert(text, 1, 0.9, 0.15) end
            if addonTable.FlashScreen then addonTable.FlashScreen("YELLOW") end
            local soundID = (SOUNDKIT and SOUNDKIT.UI_BONUS_ROLL_START) or 12867
            PlaySound(soundID)
        end, 2)
    end
end
addonTable.ShowCoinReminderVisual = ShowCoinReminderVisual

-- Exponer manejadores de eventos en addonTable
addonTable.HandleBonusRollActivate = HandleBonusRollActivate
addonTable.HandleBonusRollResult   = HandleBonusRollResult
addonTable.HandleUnitAura          = HandleUnitAura
