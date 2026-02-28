-- =============================================================
-- Módulo: MerchantHook.lua
-- Resalta items rastreados en la ventana del vendedor y
-- agrega información de seguimiento al tooltip del vendedor.
-- =============================================================
local _, addonTable = ...

local L = addonTable.L

-- Colores de resaltado para items rastreados / items equipados
local trackedVendorColor  = { 0.55, 1.0, 0.65 }
local equippedVendorColor = { 0.2,  1.0, 0.2  }

-- Flags para hookear solo una vez
local merchantHooked        = false
local merchantTooltipHooked = false

-- Devuelve si un item está actualmente equipado por el jugador
local function IsItemEquipped(itemID)
    if not itemID then return false end
    if IsEquippableItem then
        local ok, equippable = pcall(IsEquippableItem, itemID)
        if ok and equippable == false then return false end
    end
    if IsEquippedItem then
        local ok, equipped = pcall(IsEquippedItem, itemID)
        if ok and equipped then return true end
    end
    if not GetInventoryItemID then return false end
    for slot = 1, 19 do
        if GetInventoryItemID("player", slot) == itemID then return true end
    end
    return false
end

-- Añade líneas de Loot Hunter al tooltip del vendedor cuando el item está en la lista
local function AddTrackedInfoToMerchantTooltip(target)
    if not GetMerchantItemLink or not GameTooltip then return end
    local slotIndex = nil
    if type(target) == "number" then
        slotIndex = target
    elseif target and target.GetID then
        local perPage = _G.MERCHANT_ITEMS_PER_PAGE or 10
        local page    = MerchantFrame and (MerchantFrame.page or 1) or 1
        slotIndex     = ((page - 1) * perPage) + (target:GetID() or 0)
    end
    if not slotIndex or slotIndex <= 0 then return end

    local link   = GetMerchantItemLink(slotIndex)
    local itemID = link and tonumber(link:match("item:(%d+):"))
    if not itemID then return end

    local CurrentCharDB = addonTable.CurrentCharDB
    local isTracked     = CurrentCharDB and CurrentCharDB[itemID]
    local isEquipped    = IsItemEquipped(itemID)

    if isTracked or isEquipped then
        local FormatLogPrefix = addonTable.FormatLogPrefix or function(t) return "[" .. t .. "]" end
        GameTooltip:AddLine(FormatLogPrefix("Loot Hunter"))
        if isEquipped then
            GameTooltip:AddLine(L["VENDOR_EQUIPPED_TOOLTIP"], equippedVendorColor[1], equippedVendorColor[2], equippedVendorColor[3])
        else
            GameTooltip:AddLine(L["VENDOR_TRACKED_TOOLTIP"], trackedVendorColor[1], trackedVendorColor[2], trackedVendorColor[3])
        end
        GameTooltip:Show()
    end
end

-- Recorre la página actual del vendedor y cambia el color del nombre según el estado
local function HighlightTrackedMerchantItems()
    if not MerchantFrame or not MerchantFrame:IsShown() or not GetMerchantNumItems then return end
    local CurrentCharDB = addonTable.CurrentCharDB
    if not CurrentCharDB then return end
    local perPage = _G.MERCHANT_ITEMS_PER_PAGE or 10
    local page    = MerchantFrame.page or 1
    local offset  = (page - 1) * perPage
    for i = 1, perPage do
        local nameText = _G["MerchantItem" .. i .. "Name"]
        if nameText then
            -- Guardar color original solo una vez
            if not nameText._lh_origColor then
                local r0, g0, b0 = nameText:GetTextColor()
                nameText._lh_origColor = { r0 or 1, g0 or 1, b0 or 1 }
            end
            local idx     = offset + i
            local link    = GetMerchantItemLink and GetMerchantItemLink(idx)
            local itemID  = link and tonumber(link:match("item:(%d+):"))
            local isTracked  = itemID and CurrentCharDB and CurrentCharDB[itemID]
            local isEquipped = IsItemEquipped(itemID)
            if isEquipped then
                nameText:SetTextColor(equippedVendorColor[1], equippedVendorColor[2], equippedVendorColor[3])
            elseif isTracked then
                nameText:SetTextColor(trackedVendorColor[1], trackedVendorColor[2], trackedVendorColor[3])
            else
                local orig = nameText._lh_origColor
                nameText:SetTextColor(orig[1], orig[2], orig[3])
            end
        end
    end
end

-- Instala los hooks en MerchantFrame_UpdateMerchantInfo y GameTooltip:SetMerchantItem
local function HookMerchantHighlight()
    if merchantHooked or not MerchantFrame_UpdateMerchantInfo then return end
    merchantHooked = true
    if hooksecurefunc then
        hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
            HighlightTrackedMerchantItems()
        end)
    end
    if not merchantTooltipHooked and hooksecurefunc and GameTooltip then
        merchantTooltipHooked = true
        hooksecurefunc(GameTooltip, "SetMerchantItem", function(tip, slot)
            AddTrackedInfoToMerchantTooltip(slot)
        end)
    end
end

-- Manejador de los eventos MERCHANT_SHOW y MERCHANT_UPDATE
local function HandleMerchantEvent()
    HookMerchantHighlight()
    HighlightTrackedMerchantItems()
end

-- Exponer en addonTable
addonTable.HandleMerchantEvent          = HandleMerchantEvent
addonTable.HighlightTrackedMerchantItems = HighlightTrackedMerchantItems
