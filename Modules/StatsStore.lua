-- =============================================================
-- Módulo: StatsStore.lua
-- Gestión de historial global y sesiones de raid por personaje.
-- Inicializa addonTable.StatsStore con todas sus constantes y métodos.
-- =============================================================
local _, addonTable = ...

local NowSeconds      = addonTable.NowSeconds
local LogDebug        = addonTable.LogDebug      or function() end
local FormatLogPrefix = addonTable.FormatLogPrefix or function(t) return "[" .. t .. "]" end
local L               = addonTable.L

-- Objeto principal con constantes configurables
addonTable.StatsStore = {
    MAX_HISTORY_EVENTS              = 200,
    MAX_SESSION_LOGS                = 25,
    currentHistory                  = nil,
    currentSessionKey               = nil,
    lastClosedSessionKey            = nil,
    lastClosedSessionAt             = nil,
    LAST_SESSION_LOOT_GRACE_SECONDS = 45,
    -- El "día de raid" empieza a las 6:00 AM (21600 segundos)
    -- Raids de 11pm a 2am quedan en el mismo día lógico
    RAID_DAY_OFFSET_SECONDS         = 21600,
}
local StatsStore = addonTable.StatsStore

-- Devuelve la fecha "lógica" de un timestamp.
-- El día de raid empieza a las 6:00 AM, por lo que las horas
-- entre medianoche y las 5:59 AM pertenecen al día anterior.
local function LogicalDay(ts)
    if not ts or ts <= 0 or not date then return nil end
    return date("%Y-%m-%d", ts - StatsStore.RAID_DAY_OFFSET_SECONDS)
end

-- =============================================================
-- HISTORIAL GLOBAL
-- =============================================================

-- Asegura que la DB de historial exista para el personaje actual
function StatsStore:EnsureHistoryDB()
    local charKey = addonTable.charKey
    if not LootHunterDB or not charKey then return nil end
    if not LootHunterDB.History then LootHunterDB.History = {} end
    if not LootHunterDB.History[charKey] then
        LootHunterDB.History[charKey] = { events = {}, counters = {}, lastWinAt = nil, lastWinLink = nil }
    end
    local hist = LootHunterDB.History[charKey]
    hist.events   = hist.events   or {}
    hist.counters = hist.counters or {}
    hist.counters.drops         = hist.counters.drops         or 0
    hist.counters.wins          = hist.counters.wins          or 0
    hist.counters.losses        = hist.counters.losses        or 0
    hist.counters.coinReminders = hist.counters.coinReminders or 0
    hist.counters.coinsUsed     = hist.counters.coinsUsed     or 0
    hist.counters.bossNoLoot    = hist.counters.bossNoLoot    or 0
    hist.counters.boeDetected   = hist.counters.boeDetected   or 0
    self.currentHistory = hist
    return hist
end

-- Elimina eventos antiguos que superan el límite máximo — O(n) sin desplazamientos
function StatsStore:TrimHistory(hist)
    if not hist or not hist.events then return end
    local events = hist.events
    local max    = self.MAX_HISTORY_EVENTS
    local count  = #events
    if count <= max then return end
    -- Reconstruir descartando los más antiguos (primeros elementos)
    local excess  = count - max
    local trimmed = {}
    for i = excess + 1, count do
        trimmed[#trimmed + 1] = events[i]
    end
    hist.events = trimmed
end

-- Registra un evento en el historial (drop, won, lost, coin_reminder, coin_used, boss_no_loot)
function StatsStore:RecordHistoryEvent(kind, payload)
    local hist = self:EnsureHistoryDB()
    if not hist then return end
    local now = (type(time) == "function" and time()) or (GetTime and math.floor(GetTime())) or 0
    local event = {
        kind   = kind,
        time   = now,
        itemID = payload and payload.itemID or nil,
        link   = payload and payload.link   or nil,
        player = payload and payload.player or nil,
        roll   = payload and payload.roll   or nil,
        boss   = payload and payload.boss   or payload and payload.source or nil,
    }
    hist.events[#hist.events + 1] = event
    local c = hist.counters
    if     kind == "drop"          then c.drops         = c.drops         + 1
    elseif kind == "won"           then c.wins          = c.wins          + 1 ; hist.lastWinAt = now ; hist.lastWinLink = payload and payload.link or hist.lastWinLink
    elseif kind == "lost"          then c.losses        = c.losses        + 1
    elseif kind == "coin_reminder" then c.coinReminders = c.coinReminders + 1
    elseif kind == "coin_used"     then c.coinsUsed     = c.coinsUsed     + 1
    elseif kind == "boss_no_loot"  then c.bossNoLoot    = c.bossNoLoot    + 1
    elseif kind == "boe_detected" then c.boeDetected   = (c.boeDetected or 0) + 1
    end
    self:TrimHistory(hist)
end

-- Retorna los contadores de historial del personaje actual
function StatsStore:GetHistoryStats()
    local hist = self.currentHistory or self:EnsureHistoryDB()
    local c    = hist and hist.counters or {}
    return {
        drops         = c.drops         or 0,
        wins          = c.wins          or 0,
        losses        = c.losses        or 0,
        coinReminders = c.coinReminders or 0,
        coinsUsed     = c.coinsUsed     or 0,
        bossNoLoot    = c.bossNoLoot    or 0,
        lastWinAt     = hist and hist.lastWinAt  or nil,
        lastWinLink   = hist and hist.lastWinLink or nil,
    }
end
addonTable.GetHistoryStats = function() return StatsStore:GetHistoryStats() end

-- Reinicia solo los contadores de historial (las sesiones permanecen intactas)
function StatsStore:ResetHistory()
    local charKey = addonTable.charKey
    if not LootHunterDB or not charKey then return false end
    if LootHunterDB.History then
        LootHunterDB.History[charKey] = { events = {}, counters = {}, lastWinAt = nil, lastWinLink = nil }
    end
    self.currentHistory = nil
    self:EnsureHistoryDB()
    return true
end
addonTable.ResetHistory = function() return StatsStore:ResetHistory() end

-- Reinicia todos los stats incluyendo sesiones
function StatsStore:ResetAllStats()
    local charKey = addonTable.charKey
    if not LootHunterDB or not charKey then return false end
    if LootHunterDB.Sessions then
        LootHunterDB.Sessions[charKey] = { sessions = {}, counters = {} }
    end
    self.currentSessionKey = nil
    self:EnsureSessionDB()
    return true
end
addonTable.ResetAllStats = function() return StatsStore:ResetAllStats() end

-- =============================================================
-- SESIONES DE RAID
-- =============================================================

-- Asegura que la DB de sesiones exista para el personaje actual
function StatsStore:EnsureSessionDB()
    local charKey = addonTable.charKey
    if not LootHunterDB or not charKey then return nil end
    if not LootHunterDB.Sessions then LootHunterDB.Sessions = {} end
    if not LootHunterDB.Sessions[charKey] then
        LootHunterDB.Sessions[charKey] = { sessions = {}, counters = {} }
    end
    local db = LootHunterDB.Sessions[charKey]
    db.sessions = db.sessions or {}
    db.counters = db.counters or {}
    return db
end

-- Construye la etiqueta visible para una sesión (ej. "Mogu'shan Vaults #2 - 02/22/2026")
function StatsStore:BuildSessionLabel(raidName, sessionIndex, startedAt)
    local dateStr = (type(date) == "function" and date("%m/%d/%Y", startedAt or time())) or tostring(startedAt or "")
    return string.format("%s #%d - %s", raidName or L["STATS_DEFAULT_RAID_NAME"] or "Raid", sessionIndex or 1, dateStr)
end

-- Devuelve la sesión abierta más reciente para un raid/instancia dado
function StatsStore:GetMostRecentSession(raidName, instanceID)
    local db = self:EnsureSessionDB()
    if not db then return nil end
    local best = nil
    for _, session in pairs(db.sessions) do
        if session and not session.closedAt and session.raidName == raidName then
            if not instanceID or not session.instanceID or session.instanceID == instanceID then
                if not best or (session.startedAt or 0) > (best.startedAt or 0) then
                    best = session
                end
            end
        end
    end
    return best
end

-- Crea y registra una nueva sesión de raid
function StatsStore:StartSession(raidName, difficultyName, instanceID)
    local db = self:EnsureSessionDB()
    if not db then return nil end
    raidName = raidName or (L and L["STATS_DEFAULT_RAID_NAME"]) or "Raid"
    db.counters[raidName] = (db.counters[raidName] or 0) + 1
    local idx       = db.counters[raidName]
    local startedAt = (type(time) == "function" and time()) or (GetTime and math.floor(GetTime())) or 0
    local key       = string.format("%s|%d|%s", raidName, idx, tostring(startedAt))
    db.sessions[key] = {
        key          = key,
        raidName     = raidName,
        difficulty   = difficultyName,
        instanceID   = instanceID,
        sessionIndex = idx,
        startedAt    = startedAt,
        lastEventAt  = startedAt,
        items        = {},
        perPlayer    = {},
        deaths       = {},
        revives      = {},
        deadTime     = {},
        deathStart   = {},
        firstDeath   = nil,
        label        = self:BuildSessionLabel(raidName, idx, startedAt),
    }
    self.currentSessionKey = key
    return key, db.sessions[key]
end

-- Asegura que haya una sesión activa; opcionalmente inicia una nueva
function StatsStore:EnsureCurrentSession(allowStart)
    if allowStart == nil then allowStart = false end
    local inInstance, instanceType = IsInInstance()
    local inRaidInstance = inInstance and instanceType == "raid"
    local inRaidGroup    = IsInRaid and IsInRaid() or false
    if not inRaidGroup and not inRaidInstance then
        self.currentSessionKey = nil
        return nil
    end
    local raidName, _, _, difficultyName, _, _, _, instanceID = GetInstanceInfo()
    local db  = self:EnsureSessionDB()
    if not db then return nil end
    local now    = (type(time) == "function" and time()) or (GetTime and math.floor(GetTime())) or 0
    local nowDay = LogicalDay(now)

    -- Fuera de instancia raid: mantener sesión del día si existe
    if not inInstance or instanceType ~= "raid" then
        if self.currentSessionKey and db.sessions[self.currentSessionKey] then
            local sess = db.sessions[self.currentSessionKey]
            if sess and not sess.closedAt then
                local lastEvent = sess.lastEventAt or sess.startedAt or 0
                local lastDay   = LogicalDay(lastEvent)
                -- Solo cerrar por cambio de día si NO estamos en un grupo de raid activo
                if nowDay and lastDay and lastDay ~= nowDay and not inRaidGroup then
                    sess.closedAt    = now
                    sess.closedReason = "new_day"
                    self.currentSessionKey = nil
                    return nil
                end
                sess.deaths    = sess.deaths    or {}
                sess.revives   = sess.revives   or {}
                sess.deadTime  = sess.deadTime  or {}
                sess.deathStart = sess.deathStart or {}
                return self.currentSessionKey, sess
            end
        end
        return nil
    end
    if not raidName then return nil end

    -- Forzar nueva sesión si se solicitó (cambio de grupo)
    if self.forceNewSession then
        self.forceNewSession = nil
        if allowStart then
            return self:StartSession(raidName, difficultyName, instanceID)
        end
        return nil
    end

    -- Reusar sesión actual si corresponde al mismo raid y día
    if self.currentSessionKey and db.sessions[self.currentSessionKey] then
        local sess = db.sessions[self.currentSessionKey]
        if sess.closedAt then
            self.currentSessionKey = nil
        else
            local lastEvent = sess.lastEventAt or sess.startedAt or 0
            local lastDay   = LogicalDay(lastEvent)
            if nowDay and lastDay and lastDay ~= nowDay then
                sess.closedAt     = now
                sess.closedReason = "new_day"
                self.currentSessionKey = nil
            elseif sess.raidName == raidName and (not sess.instanceID or not instanceID or sess.instanceID == instanceID) then
                sess.deaths     = sess.deaths     or {}
                sess.revives    = sess.revives    or {}
                sess.deadTime   = sess.deadTime   or {}
                sess.deathStart = sess.deathStart or {}
                return self.currentSessionKey, sess
            end
        end
    end

    -- Segundo intento con currentSessionKey (puede haberse limpiado arriba)
    if self.currentSessionKey and db.sessions[self.currentSessionKey] then
        local sess = db.sessions[self.currentSessionKey]
        if sess.raidName == raidName and (not sess.instanceID or not instanceID or sess.instanceID == instanceID) then
            sess.deaths    = sess.deaths    or {}
            sess.revives   = sess.revives   or {}
            sess.deadTime  = sess.deadTime  or {}
            sess.deathStart = sess.deathStart or {}
            return self.currentSessionKey, sess
        end
    end

    -- Buscar sesión reciente abierta del mismo raid
    local recent = self:GetMostRecentSession(raidName, instanceID)
    if recent then
        local lastEvent = recent.lastEventAt or recent.startedAt or 0
        local lastDay   = LogicalDay(lastEvent)
        if nowDay and lastDay and lastDay ~= nowDay then
            recent.closedAt     = now
            recent.closedReason = "new_day"
        else
            self.currentSessionKey = recent.key
            recent.deaths     = recent.deaths     or {}
            recent.revives    = recent.revives    or {}
            recent.deadTime   = recent.deadTime   or {}
            recent.deathStart = recent.deathStart or {}
            return recent.key, recent
        end
    end

    if allowStart then
        return self:StartSession(raidName, difficultyName, instanceID)
    end
    return nil
end

-- Cierra la sesión actual y la marca con motivo
function StatsStore:CloseCurrentSession(reason)
    if not self.currentSessionKey then return end
    local db = self:EnsureSessionDB()
    if not db or not db.sessions then return end
    local session = db.sessions[self.currentSessionKey]
    if not session then return end
    session.closedAt    = NowSeconds()
    session.closedReason = reason or "left_instance"
    self.lastClosedSessionKey = self.currentSessionKey
    self.lastClosedSessionAt  = session.closedAt
    self.currentSessionKey    = nil
end

-- Fallback para registrar loot de la sesión recién cerrada (gracia de 45s tras salir)
function StatsStore:GetLateLootSessionFallback()
    local db  = self:EnsureSessionDB()
    if not db or not db.sessions then return nil, nil end
    local key = self.lastClosedSessionKey
    if not key then return nil, nil end
    local session = db.sessions[key]
    if not session or not session.closedAt then return nil, nil end
    local now   = NowSeconds()
    local grace = tonumber(self.LAST_SESSION_LOOT_GRACE_SECONDS) or 45
    if grace < 1 then grace = 1 end
    if (now - (self.lastClosedSessionAt or session.closedAt or now)) > grace then return nil, nil end
    local nowDay    = LogicalDay(now)
    local lastEvent = session.lastEventAt or session.startedAt or 0
    local lastDay   = LogicalDay(lastEvent)
    if nowDay and lastDay and nowDay ~= lastDay then return nil, nil end
    return key, session
end

-- =============================================================
-- MUERTES Y RESURRECCIONES
-- =============================================================

-- Resuelve el token de clase de un jugador buscando en el grupo
function StatsStore:ResolveClassToken(name)
    if not name or name == "" then return nil end
    local base = name:match("^[^-]+") or name
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitName(unit) == base then
                local _, classToken = UnitClass(unit)
                return classToken
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            if UnitName(unit) == base then
                local _, classToken = UnitClass(unit)
                return classToken
            end
        end
    end
    if base == UnitName("player") then
        local _, classToken = UnitClass("player")
        return classToken
    end
    return nil
end

-- Registra la muerte de un jugador en la sesión actual
function StatsStore:AddDeath(name)
    local _, session = self:EnsureCurrentSession(false)
    if not session and self.currentSessionKey then
        local db = self:EnsureSessionDB()
        if db and db.sessions then session = db.sessions[self.currentSessionKey] end
    end
    if not session then return end
    name = name or (L and L["STATS_UNKNOWN_PLAYER"]) or "Unknown"
    session.deaths     = session.deaths     or {}
    session.deathStart = session.deathStart or {}
    session.deaths[name] = (session.deaths[name] or 0) + 1
    if not session.deathStart[name] then
        session.deathStart[name] = NowSeconds()
    end
    if not session.firstDeath then
        session.firstDeath = { name = name, time = NowSeconds() }
    end
end

-- Registra la resurrección de un jugador y finaliza su temporizador de muerte
function StatsStore:AddRevive(name)
    name = name or (L and L["STATS_UNKNOWN_PLAYER"]) or "Unknown"
    local _, session = self:EnsureCurrentSession(false)
    if not session and self.currentSessionKey then
        local db = self:EnsureSessionDB()
        if db and db.sessions then session = db.sessions[self.currentSessionKey] end
    end
    if not session then return end
    session.revives       = session.revives or {}
    session.revives[name] = (session.revives[name] or 0) + 1
    self:EndDeathTimer(name)
end

-- Finaliza el temporizador de tiempo muerto para un jugador
function StatsStore:EndDeathTimer(name)
    local _, session = self:EnsureCurrentSession(false)
    if not session and self.currentSessionKey then
        local db = self:EnsureSessionDB()
        if db and db.sessions then session = db.sessions[self.currentSessionKey] end
    end
    if not session then return end
    name = name or (L and L["STATS_UNKNOWN_PLAYER"]) or "Unknown"
    session.deathStart = session.deathStart or {}
    session.deadTime   = session.deadTime   or {}
    local startedAt = session.deathStart[name]
    if startedAt then
        local delta = math.max(0, NowSeconds() - startedAt)
        session.deadTime[name]   = (session.deadTime[name] or 0) + delta
        session.deathStart[name] = nil
    end
end

-- =============================================================
-- LOOT DE SESIÓN
-- =============================================================

-- Agrega una entrada de loot a la sesión actual
function StatsStore:AddSessionLootEntry(itemID, link, playerName, classToken, rollValue, wonViaRoll, boss, isBonusLoot, rollType, isBOE)
    local key, session = self:EnsureCurrentSession(true)
    if not key or not session then
        key, session = self:GetLateLootSessionFallback()
    end
    if not key or not session then return end

    -- Ignorar items grises y blancos en el log de sesión (excepto BoE)
    if itemID and GetItemInfo then
        local _, _, quality = GetItemInfo(itemID)
        if not isBOE and quality ~= nil and quality <= 1 then return end
    end

    local icon    = itemID and select(10, GetItemInfo(itemID)) or nil
    local quality = nil
    if itemID and C_Item and C_Item.GetItemQualityByID then
        quality = C_Item.GetItemQualityByID(itemID)
    end
    if not quality and GetItemInfo then
        quality = itemID and select(3, GetItemInfo(itemID)) or (link and select(3, GetItemInfo(link)))
    end
    if not quality and link then
        local getQual = addonTable.GetQualityFromLink
        quality = getQual and getQual(link) or nil
    end

    local now   = (type(time) == "function" and time()) or (GetTime and math.floor(GetTime())) or 0
    local entry = {
        itemID      = itemID,
        link        = link,
        icon        = icon,
        quality     = quality,
        player      = playerName or UnitName("player"),
        class       = classToken or self:ResolveClassToken(playerName),
        roll        = rollValue,
        rollType    = rollType,
        wonViaRoll  = wonViaRoll,
        time        = now,
        boss        = boss,
        bonus       = isBonusLoot or false,
        isBOE       = isBOE or false,
        destroyed   = false,
    }
    session.items[#session.items + 1] = entry
    session.lastEventAt = now

    local perPlayer = session.perPlayer
    local playerKey = entry.player or (L and L["STATS_UNKNOWN_PLAYER"]) or "Unknown"
    if not perPlayer[playerKey] then
        perPlayer[playerKey] = { count = 0, class = entry.class }
    end
    perPlayer[playerKey].count = perPlayer[playerKey].count + 1
    if entry.class and not perPlayer[playerKey].class then
        perPlayer[playerKey].class = entry.class
    end

    -- Purgar sesiones antiguas al agregar loot; mantener solo las más recientes
    local db = self:EnsureSessionDB()
    if db then
        local keys = {}
        for k in pairs(db.sessions) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b)
            local sa = db.sessions[a] and db.sessions[a].startedAt or 0
            local sb = db.sessions[b] and db.sessions[b].startedAt or 0
            return sa > sb
        end)
        local limit = math.max(1, tonumber(self.MAX_SESSION_LOGS) or 20)
        for i = limit + 1, #keys do
            db.sessions[keys[i]] = nil
        end
    end
end

-- =============================================================
-- CONSULTAS DE SESIÓN
-- =============================================================

-- Devuelve la lista de sesiones ordenada por más reciente primero
function StatsStore:GetSessionList()
    local db = self:EnsureSessionDB()
    if not db then return {} end
    local items = {}
    for key, session in pairs(db.sessions) do
        items[#items + 1] = {
            key          = key,
            label        = session.label or self:BuildSessionLabel(session.raidName, session.sessionIndex, session.startedAt),
            raidName     = session.raidName,
            startedAt    = session.startedAt or 0,
            difficulty   = session.difficulty,
            sessionIndex = session.sessionIndex or 1,
        }
    end
    table.sort(items, function(a, b) return (a.startedAt or 0) > (b.startedAt or 0) end)
    return items
end

function StatsStore:GetSessionByKey(key)
    local db = self:EnsureSessionDB()
    if not db then return nil end
    return db.sessions[key]
end

function StatsStore:GetLatestSessionKey()
    local list = self:GetSessionList()
    return list[1] and list[1].key or nil
end

-- Tabla de loot por jugador ordenada de mayor a menor cantidad de items
function StatsStore:GetSessionLeaderboard(key)
    local session = self:GetSessionByKey(key or self.currentSessionKey)
    if not session then return {} end
    local counts = {}
    for _, entry in ipairs(session.items or {}) do
        local p = entry.player or (L and L["STATS_UNKNOWN_PLAYER"]) or "Unknown"
        if not counts[p] then counts[p] = { count = 0, class = entry.class } end
        counts[p].count = counts[p].count + 1
        if entry.class and not counts[p].class then counts[p].class = entry.class end
    end
    local out = {}
    for name, data in pairs(counts) do
        out[#out + 1] = { name = name, count = data.count or 0, class = data.class }
    end
    table.sort(out, function(a, b)
        if (a.count or 0) == (b.count or 0) then return (a.name or "") < (b.name or "") end
        return (a.count or 0) > (b.count or 0)
    end)
    return out
end

function StatsStore:GetSessionItems(key)
    local session = self:GetSessionByKey(key or self.currentSessionKey)
    if not session then return {} end
    return session.items or {}
end

-- Exponer accesos al StatsStore en addonTable para que otros módulos y la UI los usen
addonTable.GetSessionList      = function()    return StatsStore:GetSessionList() end
addonTable.GetSessionItems     = function(key) return StatsStore:GetSessionItems(key) end
addonTable.GetSessionLeaderboard = function(key) return StatsStore:GetSessionLeaderboard(key) end
addonTable.GetLatestSessionKey = function()    return StatsStore:GetLatestSessionKey() end
addonTable.GetSessionByKey     = function(key) return StatsStore:GetSessionByKey(key) end
addonTable.GetCurrentSessionKey = function()   return StatsStore.currentSessionKey end
