local addonName, addonTable = ...
local L = addonTable.L

-- Obtiene LibDBIcon de forma diferida para evitar referencia nil si aún no cargó
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

    -- Inicializar las variables guardadas del ícono del minimapa si no existen
    if not LootHunterDB.minimap then
        LootHunterDB.minimap = {
            hide = false,
            minimapPos = 180, -- Ángulo por defecto
        }
    end
    
    -- Objeto de datos del ícono. LibDBIcon lo usa para configurar el botón.
    local iconData = {
        type = "data source", -- Identifica este objeto como LDB para LibDBIcon
        -- Usar barras normales en la ruta para evitar problemas con caracteres de escape
        icon = "Interface/AddOns/"..addonName.."/Textures/minimap_icon.tga",
        iconCoords = { 0, 1, 0, 1 },
        OnClick = function(self, button)
            -- Crea el frame si no existe, o lo muestra si estaba oculto
            if LootHunter_CreateGUI then
                LootHunter_CreateGUI()
            end

            if button == "LeftButton" then
                if addonTable.SelectTab then
                    addonTable.SelectTab(1) -- Cambiar a la pestaña de Lista
                end
            elseif button == "RightButton" then
                if addonTable.SelectTab then
                    addonTable.SelectTab(4) -- Cambiar a la pestaña de Configuración
                end
            end
        end,
        OnEnter = function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            -- Línea 1: Título y versión
            GameTooltip:SetText("LootHunter" .. " |cff9d9d9d" .. "v" .. (addonTable.version or "1.0") .. "|r")
            -- Línea 2: Clic izquierdo
            GameTooltip:AddLine("|cff00ff00" .. L["L_CLICK"] .. "|r |cffffffff" .. L["MINIMAP_LMB_ACTION"] .. "|r")
            -- Línea 3: Clic derecho
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

    -- Registrar el ícono en LibDBIcon. Él se encarga de creación, posición y arrastre.
    minimapLib:Register("LootHunter", iconData, LootHunterDB.minimap)
    EnsureMinimapIconUpdateCoord()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, EnsureMinimapIconUpdateCoord)
    end
end
