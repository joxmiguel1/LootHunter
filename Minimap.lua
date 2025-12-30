local addonName, addonTable = ...
local L = addonTable.L

-- Lazily acquire the LibDBIcon library to avoid nil reference when it isn't loaded yet
local minimapLib
local minimapLibWarned
local function AcquireLibDBIcon()
    local stub = LibStub
    if not stub then
        return nil
    end

    local lib = stub:GetLibrary("LibDBIcon-1.0")
    if not lib and not minimapLibWarned then
        minimapLibWarned = true
        print("[Loot Hunter] Minimap icon disabled because LibDBIcon-1.0 is unavailable.")
    end
    return lib
end

function addonTable.CreateMinimapIcon()
    minimapLib = minimapLib or AcquireLibDBIcon()
    if not minimapLib then
        return
    end

    -- Initialize the saved variables for the minimap icon if they don't exist
    if not LootHunterDB.minimap then
        LootHunterDB.minimap = {
            hide = false,
            minimapPos = 180, -- Default angle
        }
    end
    
    -- Data object for the icon. LibDBIcon uses this to configure the button.
    local iconData = {
        type = "data source", -- This identifies it as a LDB object for LibDBIcon
        -- Use forward slashes for the path to avoid escape character issues
        icon = "Interface/AddOns/"..addonName.."/Textures/minimap_icon.tga",
        iconCoords = { 0, 1, 0, 1 },
        OnClick = function(self, button)
            -- This function will create the frame if it doesn't exist, or show it if it's hidden
            if LootHunter_CreateGUI then
                LootHunter_CreateGUI()
            end

            if button == "LeftButton" then
                if addonTable.SelectTab then
                    addonTable.SelectTab(1) -- Switch to List tab
                end
            elseif button == "RightButton" then
                if addonTable.SelectTab then
                    addonTable.SelectTab(4) -- Switch to Config tab
                end
            end
        end,
        OnEnter = function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            -- Line 1: Title and Version
            GameTooltip:SetText("LootHunter" .. " |cff9d9d9d" .. "v" .. (addonTable.version or "1.0") .. "|r")
            -- Line 2: Left Click
            GameTooltip:AddLine("|cff00ff00" .. L["L_CLICK"] .. "|r |cffffffff" .. L["MINIMAP_LMB_ACTION"] .. "|r")
            -- Line 3: Right Click
            GameTooltip:AddLine("|cff00ff00" .. L["R_CLICK"] .. "|r |cffffffff" .. L["MINIMAP_RMB_ACTION"] .. "|r")
            GameTooltip:Show()
        end,
        OnLeave = function(self)
            GameTooltip:Hide()
        end
    }

    local function EnsureMinimapIconUpdateCoord()
        local button = minimapLib.GetMinimapButton and minimapLib:GetMinimapButton("LootHunter")
        if not button and minimapLib.objects then
            button = minimapLib.objects["LootHunter"]
        end
        if not button or not button.icon then return end
        if not button.icon.UpdateCoord then
            button.icon.UpdateCoord = function(self)
                local coords = iconData.iconCoords or { 0, 1, 0, 1 }
                self:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            end
        end
    end

    -- Register our icon with LibDBIcon. It will handle creation, placement, and dragging.
    minimapLib:Register("LootHunter", iconData, LootHunterDB.minimap)
    EnsureMinimapIconUpdateCoord()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, EnsureMinimapIconUpdateCoord)
    end
end
