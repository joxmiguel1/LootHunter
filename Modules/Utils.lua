-- =============================================================
-- Módulo: Utils.lua
-- Funciones utilitarias compartidas entre todos los módulos.
-- Debe cargarse justo después de Debug.lua en el TOC.
-- =============================================================
local _, addonTable = ...

-- Devuelve el tiempo actual en segundos (Unix epoch o uptime de sesión como fallback)
local function NowSeconds()
    if type(time) == "function" then
        return time()
    end
    if GetTime then
        return GetTime()
    end
    return 0
end
addonTable.NowSeconds = NowSeconds

-- Elimina el sufijo de realm de un nombre de jugador (e.g. "Nombre-Realm" → "Nombre")
local function NormalizeUnitName(name)
    if not name or name == "" then return name end
    return name:match("^[^-]+") or name
end
addonTable.NormalizeUnitName = NormalizeUnitName

-- Obtiene la calidad de un item a partir del color en su link
addonTable.GetQualityFromLink = addonTable.GetQualityFromLink or function(link)
    if type(link) ~= "string" or not _G.ITEM_QUALITY_COLORS then return nil end
    local hex = link:match("|c(%x%x%x%x%x%x%x%x)")
    if not hex then return nil end
    hex = hex:lower()
    for q, data in pairs(_G.ITEM_QUALITY_COLORS) do
        if data and data.colorHex and data.colorHex:lower() == hex then
            return q
        end
    end
    return nil
end

-- Iconos de marcadores de raid usados en alertas
local ICON_STAR     = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:24|t"
local ICON_DIAMOND  = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:24|t"
local ICON_TRIANGLE = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:24|t"
addonTable.ICON_STAR     = ICON_STAR
addonTable.ICON_DIAMOND  = ICON_DIAMOND
addonTable.ICON_TRIANGLE = ICON_TRIANGLE

-- =============================================================
-- Helpers de strings
-- =============================================================

-- Elimina espacios al inicio y fin de una cadena
local function TrimString(str)
    if not str then return nil end
    return (str:gsub("^%s+", ""):gsub("%s+$", ""))
end
addonTable.TrimString = TrimString

-- Normaliza un nombre de jugador usando Ambiguate si está disponible,
-- o extrayendo la parte antes del guion (elimina realm suffix).
-- Es la versión extendida de NormalizeUnitName usada para comparar
-- nombres de líderes/asistentes en mensajes de chat.
local function NormalizeName(name)
    if not name or name == "" then return nil end
    if Ambiguate then return Ambiguate(name, "short") end
    return name:match("^[^-]+") or name
end
addonTable.NormalizeName = NormalizeName

-- =============================================================
-- Helpers de rol de grupo (líder, asistente, master looter)
-- =============================================================

-- Devuelve si el nombre dado corresponde al líder del grupo actual
local function IsLeaderName(name)
    local target = NormalizeName(name)
    if not target then return false end
    if UnitIsGroupLeader("player") and target == NormalizeName(UnitName("player")) then return true end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if NormalizeName(UnitName(unit)) == target and UnitIsGroupLeader(unit) then return true end
        end
    else
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            if NormalizeName(UnitName(unit)) == target and UnitIsGroupLeader(unit) then return true end
        end
    end
    return false
end
addonTable.IsLeaderName = IsLeaderName

-- Devuelve si el nombre dado corresponde al master looter del grupo actual
local function IsMasterLooterName(name)
    local target = NormalizeName(name)
    if not target or not GetLootMethod then return false end
    local method, mlParty, mlRaid = GetLootMethod()
    if method ~= "master" then return false end
    local unit
    if mlRaid and mlRaid > 0 then
        unit = "raid" .. mlRaid
    elseif mlParty then
        unit = (mlParty == 0) and "player" or ("party" .. mlParty)
    end
    if unit then return NormalizeName(UnitName(unit)) == target end
    return false
end
addonTable.IsMasterLooterName = IsMasterLooterName

-- Devuelve si el nombre dado corresponde a un asistente de raid
local function IsAssistantName(name)
    local target = NormalizeName(name)
    if not target or not IsInGroup() then return false end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if NormalizeName(UnitName(unit)) == target and UnitIsGroupAssistant(unit) then return true end
        end
    end
    return false
end
addonTable.IsAssistantName = IsAssistantName

-- Devuelve si el remitente está autorizado a hacer anuncios de loot
-- (líder, asistente o master looter)
local function IsAuthorizedAnnounce(sender)
    return IsLeaderName(sender) or IsAssistantName(sender) or IsMasterLooterName(sender)
end
addonTable.IsAuthorizedAnnounce = IsAuthorizedAnnounce

