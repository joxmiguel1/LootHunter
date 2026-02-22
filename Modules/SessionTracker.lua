-- =============================================================
-- Módulo: SessionTracker.lua
-- Rastreo de muertes/resurrecciones vía CombatLog,
-- detección de intercambio activo y sonido de "otro jugador ganó".
-- =============================================================
local _, addonTable = ...

local NormalizeUnitName = addonTable.NormalizeUnitName
local NormalizeName     = addonTable.NormalizeName

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
    local _, subEvent, _, _, _, _, _, _, destName, destFlags = CombatLogGetCurrentEventInfo()
    if not subEvent then return end

    local function IsPlayerFlag(flags)
        if not flags then return false end
        local TYPE_PLAYER = _G.COMBATLOG_OBJECT_TYPE_PLAYER or 0x00000400
        if CombatLog_Object_IsA then return CombatLog_Object_IsA(flags, TYPE_PLAYER) end
        local band = (bit and bit.band) or (bit32 and bit32.band)
        return band and band(flags, TYPE_PLAYER) > 0
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
    local isPlayerOrMember = normDest and (IsPlayerFlag(destFlags) or IsGroupMemberName(normDest))
    local StatsStore       = addonTable.StatsStore


    if subEvent == "UNIT_DIED" then
        if isPlayerOrMember then
            if StatsStore then StatsStore:AddDeath(normDest) end
        else
            -- En raid: cualquier NPC muerto puede marcar el inicio de loot
            local inRaid = IsInRaid and IsInRaid() or false
            if inRaid and destName and destName ~= "" and StatsStore then
                StatsStore:EnsureCurrentSession(true)
            end
        end
    elseif subEvent == "SPELL_RESURRECT" and isPlayerOrMember then
        if StatsStore then StatsStore:AddRevive(normDest) end
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
