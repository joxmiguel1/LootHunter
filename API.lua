local _, addonTable = ...

local api = _G.LootHunterAPI or {}
_G.LootHunterAPI = api

local FAVORITE_LABEL = "|TInterface\\AddOns\\LootHunter\\Textures\\minimap_icon.tga:16|t LH"

local function CalledFromBonusRollPreview()
    if type(debugstack) ~= "function" then return false end
    local ok, stack = pcall(debugstack, 2, 6, 0)
    if not ok or type(stack) ~= "string" then return false end
    return stack:find("BonusRollPreview", 1, true) ~= nil
end

local function GetItemCountAll(itemID, includeBank)
    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(itemID, includeBank)
    end
    if GetItemCount then
        return GetItemCount(itemID, includeBank)
    end
    return 0
end

local function GetContainerSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag)
    end
    if GetContainerNumSlots then
        return GetContainerNumSlots(bag)
    end
    return 0
end

local function GetContainerItemId(bag, slot)
    if C_Container and C_Container.GetContainerItemID then
        return C_Container.GetContainerItemID(bag, slot)
    end
    if GetContainerItemID then
        return GetContainerItemID(bag, slot)
    end
    return nil
end

local function FindBoundInBags(itemID, bagFrom, bagTo)
    local found = false
    for bag = bagFrom, bagTo do
        local slots = GetContainerSlots(bag)
        for slot = 1, slots do
            local id = GetContainerItemId(bag, slot)
            if id == itemID then
                found = true
                if ItemLocation and ItemLocation.CreateFromBagAndSlot and C_Item and C_Item.IsBound then
                    local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
                    if loc and C_Item.IsBound(loc) then
                        return true
                    end
                end
            end
        end
    end
    if found then return false end
    return nil
end

local function IsBankOpen()
    return (BankFrame and BankFrame:IsShown()) or (BankFrame and BankFrame:IsVisible())
end

-- Devuelve: boolean isFavorite, string shortLabel
function api:IsFavorite(itemID)
    if not itemID then return false end

    local id = tonumber(itemID)
    if not id then return false end

    local db = addonTable and addonTable.CurrentCharDB
    if not db then return false end

    local data = db[id]
    if not data then return false end

    local fromPreview = CalledFromBonusRollPreview()

    local status = data.status or 0
    if status == 2 then
        if fromPreview then return false, "" end
        return false, ""
    end

    if IsEquippedItem and IsEquippedItem(id) then
        if fromPreview then return false, "" end
        return false, ""
    end

    local countNoBank = GetItemCountAll(id, false)
    if countNoBank and countNoBank > 0 then
        local bound = FindBoundInBags(id, 0, _G.NUM_BAG_SLOTS or 4)
        if bound == true then
            if fromPreview then return false, "" end
            return false, ""
        end
        if fromPreview then return true, FAVORITE_LABEL end
        return true, FAVORITE_LABEL
    end

    local countWithBank = GetItemCountAll(id, true)
    if countWithBank and countWithBank > 0 then
        if not IsBankOpen() then
            if fromPreview then return true, FAVORITE_LABEL end
            return true, FAVORITE_LABEL
        end
        local bankContainer = _G.BANK_CONTAINER or -1
        local boundBank = FindBoundInBags(id, bankContainer, bankContainer)
        if boundBank == true then
            if fromPreview then return false, "" end
            return false, ""
        end
        local numBankBags = _G.NUM_BANKBAGSLOTS or 0
        if numBankBags > 0 then
            local firstBankBag = (_G.NUM_BAG_SLOTS or 4) + 1
            local lastBankBag = firstBankBag + numBankBags - 1
            local boundBags = FindBoundInBags(id, firstBankBag, lastBankBag)
            if boundBags == true then
                if fromPreview then return false, "" end
                return false, ""
            end
        end
        if fromPreview then return true, FAVORITE_LABEL end
        return true, FAVORITE_LABEL
    end

    if fromPreview then return true, FAVORITE_LABEL end
    return true, FAVORITE_LABEL
end
