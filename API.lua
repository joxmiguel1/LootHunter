local _, addonTable = ...

local api = _G.LootHunterAPI or {}
_G.LootHunterAPI = api

local FAVORITE_LABEL = "|TInterface\\AddOns\\LootHunter\\Textures\\minimap_icon.tga:16|t LH"

-- Returns: boolean isFavorite, string shortLabel
function api:IsFavorite(itemID)
    if not itemID then return false end

    local id = tonumber(itemID)
    if not id then return false end

    local db = addonTable and addonTable.CurrentCharDB
    if not db then return false end

    local data = db[id]
    if not data then return false end

    local status = data.status or 0
    if status == 2 then return false end

    if IsEquippedItem and IsEquippedItem(id) then return false end

    return true, FAVORITE_LABEL
end

