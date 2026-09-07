-- =============================================================
-- Módulo: SessionTracker.lua
-- Rastreo de muertes/resurrecciones vía CombatLog,
-- detección de intercambio activo y sonido de "otro jugador ganó".
-- =============================================================
local _, addonTable = ...

local NormalizeUnitName = addonTable.NormalizeUnitName
local NormalizeName     = addonTable.NormalizeName

-- Buffer de últimos daños entre aliados para detectar killing blows (target murió 0-1.5s después del daño).
-- Cada entrada: { killerName, victimName, expireAt }.
local allyKBBuffer = {}

-- Elimina entradas vencidas del buffer (mayor a 1.5s)
local function PruneAllyKBBuffer(now)
    if not now then now = (type(GetTime) == "function" and GetTime()) or 0 end
    local kept = {}
    for i = 1, #allyKBBuffer do
        local e = allyKBBuffer[i]
        if e and e.expireAt >= now then
            kept[#kept + 1] = e
        end
    end
    allyKBBuffer = kept
end

-- Estado de intercambio activo (evita registrar loot recibido por trade como new drop)
local tradeActive = false
addonTable.tradeActive = false  -- referencia compartida; actualizamos ambas

local function HandleTradeShow()
    tradeActive             = true
    addonTable.tradeActive  = true
end

local function HandleTradeClosed()
    tradeActive             = false
    addonTable.tradeActive  = false
end

-- Devuelve si una unidad es rastreable (player, party, raid)
local function IsTrackableUnit(unit)
    if not unit then return false end
    if unit == "player" then return true end
    if unit:match("^party%d+$") or unit:match("^raid%d+$") then return true end
    return false
end

-- Finaliza temporizadores de muerte para todos los miembros que siguen vivos
local function SweepDeathTimers()
    local StatsStore = addonTable.StatsStore
    if not StatsStore or not StatsStore.EndDeathTimer then return end
    local function maybeEnd(unit)
        if not unit then return end
        if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then return end
        local name = UnitName(unit)
        if not name or name == "" then return end
        StatsStore:EndDeathTimer(NormalizeUnitName(name))
    end
    maybeEnd("player")
    if IsInRaid and IsInRaid() then
        local n = GetNumGroupMembers and GetNumGroupMembers() or 0
        for i = 1, n do maybeEnd("raid" .. i) end
    elseif IsInGroup and IsInGroup() then
        local n = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
        for i = 1, n do maybeEnd("party" .. i) end
    end
end

-- Procesa eventos de UNIT_HEALTH / UNIT_FLAGS para cerrar temporizadores de muerte
local function HandleUnitLifeState(event, unit)
    local StatsStore = addonTable.StatsStore
    if IsTrackableUnit(unit) then
        if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then return end
        local name = UnitName(unit)
        if not name or name == "" then return end
        if StatsStore and StatsStore.EndDeathTimer then
            StatsStore:EndDeathTimer(NormalizeUnitName(name))
        end
        return
    end
    SweepDeathTimers()
end

-- Maneja COMBAT_LOG_EVENT_UNFILTERED para registrar muertes y resurrecciones en raid
local function HandleCombatLogEvent()
    if not CombatLogGetCurrentEventInfo then return end
    local info = { CombatLogGetCurrentEventInfo() }
    -- Formato MoP Classic (incluye "hideCaster" en la posición 3):
    -- 1=timestamp 2=event 3=hideCaster 4=sourceGUID 5=sourceName 6=sourceFlags
    -- 7=sourceRaidFlags 8=destGUID 9=destName 10=destFlags 11=destRaidFlags 12+ args
    local subEvent      = info[2]
    local srcName       = info[5]
    local srcFlags      = info[6]
    local destName      = info[9]
    local destFlags     = info[10]
    if not subEvent then return end

    local function IsPlayerFlag(flags)
        if not flags then return false end
        -- En MoP Classic los flags del CombatLog llegan como STRING (ej. "Player-4385-05FEEF33").
        -- CombatLog_Object_IsA está deprecado y revienta con strings; hacemos whitelist estricta
        -- de prefijos: solo "Player" pasa; cualquier otro prefijo (Pet, Guardian, NPC, Object,
        -- Vehicle, Totem, ...) se rechaza explícitamente.
        if type(flags) == "string" then
            local ftype = flags:match("^(%a+)%-")
            return ftype == "Player"
        end
        -- Fallback defensivo: si por algún motivo flags viniera numérico (cliente/API C), usar bitmask
        local TYPE_PLAYER   = _G.COMBATLOG_OBJECT_TYPE_PLAYER   or 0x00000400
        local TYPE_PET      = _G.COMBATLOG_OBJECT_TYPE_PET      or 0x00004000
        local TYPE_GUARDIAN = _G.COMBATLOG_OBJECT_TYPE_GUARDIAN or 0x00002000
        local TYPE_NPC      = _G.COMBATLOG_OBJECT_TYPE_NPC      or 0x00000004
        local band = (bit and bit.band) or (bit32 and bit32.band)
        if not band then return false end
        if band(flags, TYPE_PLAYER) == 0 then return false end
        if band(flags, TYPE_PET)      > 0 then return false end
        if band(flags, TYPE_GUARDIAN) > 0 then return false end
        if band(flags, TYPE_NPC)      > 0 then return false end
        return true
    end

    local function IsGroupMemberName(normName)
        if not normName or normName == "" then return false end
        if normName == NormalizeUnitName(UnitName("player")) then return true end
        if IsInRaid() then
            for i = 1, GetNumGroupMembers() do
                local unit = "raid" .. i
                if NormalizeUnitName(UnitName(unit)) == normName then return true end
            end
            return false
        end
        if IsInGroup() then
            for i = 1, GetNumSubgroupMembers() do
                local unit = "party" .. i
                if NormalizeUnitName(UnitName(unit)) == normName then return true end
            end
        end
        return false
    end

    local normDest         = NormalizeName(destName)
    local normSrc          = NormalizeName(srcName)
    local isDestMember     = normDest and IsGroupMemberName(normDest) or false
    local isSrcMember      = normSrc  and IsGroupMemberName(normSrc)  or false
    local isPlayerOrMember = normDest and (IsPlayerFlag(destFlags) or isDestMember)
    local isSrcPlayer      = normSrc  and IsPlayerFlag(srcFlags)
    local StatsStore       = addonTable.StatsStore


    if subEvent == "UNIT_DIED" then
        if isPlayerOrMember and normDest then
            if StatsStore then
                StatsStore:AddPlayerToPull(normDest)
                StatsStore:AddDeath(normDest)
            end
            -- Buscar si 0-1.5s antes hubo un daño de aliado → killing blow
            PruneAllyKBBuffer()
            for i = #allyKBBuffer, 1, -1 do
                local e = allyKBBuffer[i]
                if e and e.victimName == normDest and e.killerName ~= normDest then
                    StatsStore:RecordAllyKill(e.killerName, normDest)
                    table.remove(allyKBBuffer, i)
                end
            end
        else
            -- En raid: cualquier NPC muerto puede marcar el inicio de loot
            local inRaid = IsInRaid and IsInRaid() or false
            if inRaid and destName and destName ~= "" and StatsStore then
                StatsStore:EnsureCurrentSession(false)
            end
        end
    elseif subEvent == "SPELL_RESURRECT" and isPlayerOrMember and normDest then
        if StatsStore then StatsStore:AddRevive(normDest) end
    else
        -- Friendly Fire: cualquier evento de daño donde source y dest son jugadores del grupo y source != dest
        local isFFEvent = (subEvent == "SWING_DAMAGE"
                        or subEvent == "RANGE_DAMAGE"
                        or subEvent == "SPELL_DAMAGE"
                        or subEvent == "SPELL_PERIODIC_DAMAGE"
                        or subEvent == "DAMAGE_SHIELD"
                        or subEvent == "DAMAGE_SPLIT")
        if isFFEvent and isDestMember and isSrcMember and isSrcPlayer and normSrc and normDest and normSrc ~= normDest then
            -- Posición del campo "amount" varía según el tipo de evento.
            -- Con el formato MoP (hideCaster en 3), los args empiezan en el índice 12:
            --   SWING_DAMAGE / DAMAGE_SHIELD / DAMAGE_SPLIT: amount = 12
            --   SPELL_DAMAGE / SPELL_PERIODIC_DAMAGE / RANGE_DAMAGE: spellId=12, spellName=13, spellSchool=14, amount=15
            local amount
            if subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" or subEvent == "RANGE_DAMAGE" then
                amount = tonumber(info[15])
            else
                amount = tonumber(info[12])
            end
            if StatsStore and amount and amount > 0 then
                StatsStore:RecordFriendlyFire(normDest, normSrc, amount)
                -- Registrar el daño en el buffer por si luego el víctima muere (killing blow de aliado)
                PruneAllyKBBuffer()
                local now = (type(GetTime) == "function" and GetTime()) or 0
                allyKBBuffer[#allyKBBuffer + 1] = {
                    killerName = normSrc,
                    victimName = normDest,
                    expireAt   = now + 1.5,
                }
            end
        end
    end
end

-- Reproduce el sonido de lamento cuando otro jugador gana un item de la lista
local function PlayOtherWonSound(force)
    local OTHER_WON_SOUND = "Sound\\Creature\\ArthasPrisoner\\UR_ArthasPrisoner_YSVisThree01.ogg"
    if not force and not (LootHunterDB and LootHunterDB.settings and LootHunterDB.settings.lootAlerts.otherWonSound) then return end
    local volumeCVar = "Sound_SFXVolume"
    if GetCVar and SetCVar then
        local originalVolume = tonumber(GetCVar(volumeCVar) or 1)
        if originalVolume then
            local target = math.max(0, math.min(originalVolume * 0.9, 1))
            if target ~= originalVolume then
                SetCVar(volumeCVar, target)
                C_Timer.After(1, function() SetCVar(volumeCVar, originalVolume) end)
            end
        end
    end
    if not PlaySoundFile(OTHER_WON_SOUND, "SFX") then
        PlaySoundFile(OTHER_WON_SOUND, "Master")
    end
end

-- Exponer en addonTable
addonTable.HandleTradeShow       = HandleTradeShow
addonTable.HandleTradeClosed     = HandleTradeClosed
addonTable.HandleUnitLifeState   = HandleUnitLifeState
addonTable.HandleCombatLogEvent  = HandleCombatLogEvent
addonTable.PlayOtherWonSound     = PlayOtherWonSound
