-- =============================================================
-- Módulo: HeroicQueue.lua
-- Muestra un diálogo de confirmación cuando el jugador intenta
-- entrar a la cola de mazmorra heroica aleatoria estando ya en cola.
-- =============================================================
local _, addonTable = ...

local L = addonTable.L

-- Icono usado en el diálogo de alerta de heroica
local HEROIC_ALERT_ICON = "|TInterface\\DialogFrame\\UI-Dialog-Icon-AlertNew:24:24:0:0|t "

-- Estado interno de la cola heroica
local currentRandomDungeonID   = nil
local currentRandomDungeonName = nil
local heroicJoinHooked         = false
local dropdownButtonsHooked    = false
local heroPopupShown           = false
local lastHeroicPrompt         = 0
local lastHeroicConfirmedText  = nil
local lastHeroicConfirmedAt    = 0

-- Función auxiliar de log solo para el sistema de cola heroica
local function HeroicLog(msg)
    local LogDebug      = addonTable.LogDebug
    local FormatLogPrefix = addonTable.FormatLogPrefix or function(t) return "[" .. t .. "]" end
    if not LogDebug then return end
    local t = GetTime and GetTime() or 0
    LogDebug(string.format("%s[%0.2f] %s", FormatLogPrefix("HeroicQueue"), t, msg))
end

-- Sale de la cola LFG de forma segura usando la API disponible
local function SafeLeaveLFG()
    if LeaveLFG then
        local ok = pcall(LeaveLFG, _G.LE_LFG_CATEGORY_LFD or 1)
        if ok then return end
    end
    if LFGLeave then pcall(LFGLeave) end
end

-- Devuelve el texto de la cola activa (nombre del dungeon en cola)
local function GetActiveQueueText()
    if not GetLFGQueueStats then return nil end
    for i = 1, 4 do
        local ok, _, _, _, _, _, _, _, _, _, _, queueName = pcall(GetLFGQueueStats, i)
        if ok and queueName and queueName ~= "" then return queueName end
    end
    return nil
end

-- Asegura que el diálogo estático esté registrado
local function EnsureHeroicQueuePopup()
    if not StaticPopupDialogs then return end
    StaticPopupDialogs["LOOTHUNTER_CONFIRM_HEROIC_QUEUE"] = StaticPopupDialogs["LOOTHUNTER_CONFIRM_HEROIC_QUEUE"] or {
        text           = HEROIC_ALERT_ICON .. (L["HEROIC_QUEUE_CONFIRM_TEXT"] or "You are about to queue for a heroic random dungeon. Continue?"),
        button1        = L["HEROIC_QUEUE_CONFIRM_YES"] or YES or "Yes",
        button2        = L["HEROIC_QUEUE_CONFIRM_NO"]  or CANCEL or "Cancel",
        timeout        = 0,
        whileDead      = 1,
        hideOnEscape   = 1,
        preferredIndex = STATICPOPUP_NUMDIALOGS,
    }
end

-- Muestra el popup de confirmación si el jugador intenta entrar a heroica estando en cola
local function PromptHeroicQueueIfNeeded(force)
    if not (LootHunterDB and LootHunterDB.settings and LootHunterDB.settings.misc and LootHunterDB.settings.misc.heroicQueueConfirm ~= false) then return end
    local text = GetActiveQueueText()
    if not text or text == "" then
        lastHeroicConfirmedText            = nil
        addonTable.heroicQueueSearchLogged = false
        return
    end
    if not addonTable.heroicQueueSearchLogged then
        HeroicLog(string.format("Queue text=%s", tostring(text)))
        addonTable.heroicQueueSearchLogged = true
    end
    if text == lastHeroicConfirmedText then return end
    local lower = string.lower(text)
    if not (lower:find("heroic", 1, true) or lower:find("heroico", 1, true)) then return end
    local now = GetTime and GetTime() or 0
    if not force and now - (lastHeroicPrompt or 0) < 1 then return end
    if heroPopupShown then return end
    lastHeroicPrompt = now
    EnsureHeroicQueuePopup()
    local dialog = StaticPopupDialogs and StaticPopupDialogs["LOOTHUNTER_CONFIRM_HEROIC_QUEUE"]
    if dialog then
        dialog.text    = HEROIC_ALERT_ICON .. (L["HEROIC_QUEUE_ALREADY"] or "You are already queued for a heroic random dungeon. Continue?")
        dialog.button1 = L["HEROIC_QUEUE_CONFIRM_YES"] or "Yes, continue"
        dialog.button2 = L["HEROIC_QUEUE_CONFIRM_NO"]  or "No, cancel queue"
        dialog.OnAccept = function()
            lastHeroicConfirmedText = text
            lastHeroicConfirmedAt   = now
            heroPopupShown          = false
        end
        dialog.OnCancel = function()
            heroPopupShown          = false
            lastHeroicConfirmedText = nil
            SafeLeaveLFG()
        end
        heroPopupShown = true
        HeroicLog("Showing heroic queue confirmation popup")
        StaticPopup_Show("LOOTHUNTER_CONFIRM_HEROIC_QUEUE")
    end
end

-- Programa múltiples revisiones escalonadas para capturar el estado de la cola
local function ScheduleHeroicQueueCheck()
    if not C_Timer or not C_Timer.After then return end
    C_Timer.After(0.1, PromptHeroicQueueIfNeeded)
    C_Timer.After(0.4, PromptHeroicQueueIfNeeded)
    C_Timer.After(1.0, PromptHeroicQueueIfNeeded)
    C_Timer.After(2.0, function() PromptHeroicQueueIfNeeded(true) end)
end

-- Hookea los botones del desplegable de tipo de LFD para capturar el dungeon seleccionado
local function HookLFDTypeDropdownButtons()
    if dropdownButtonsHooked or not hooksecurefunc then return end
    dropdownButtonsHooked = true
    hooksecurefunc("ToggleDropDownMenu", function(_, _, dropdownFrame)
        if dropdownFrame ~= _G.LFDQueueFrameTypeDropDown then return end
        currentRandomDungeonName = nil
        currentRandomDungeonID   = nil
        local maxLevels  = _G.UIDROPDOWNMENU_MAXLEVELS  or 2
        local maxButtons = _G.UIDROPDOWNMENU_MAXBUTTONS or 10
        for level = 1, maxLevels do
            local list = _G["DropDownList" .. level]
            if list then
                for i = 1, maxButtons do
                    local btn = _G["DropDownList" .. level .. "Button" .. i]
                    if btn and btn:IsShown() and btn:GetParent() == list and not btn._lh_hooked then
                        btn._lh_hooked = true
                        btn:HookScript("OnClick", function(self)
                            local text  = self.GetText and self:GetText()
                            local value = self.value
                            currentRandomDungeonID   = value
                            currentRandomDungeonName = text
                            HeroicLog(string.format("Captured via dropdown button: value=%s text=%s", tostring(value), tostring(text)))
                        end)
                    end
                end
            end
        end
    end)
end

-- Instala el hook en LFDQueueFrame_Join (solo se hace una vez)
local function SetupHeroicQueueConfirm()
    if heroicJoinHooked then return end
    if not LFDQueueFrame_Join then
        HeroicLog("LFDQueueFrame_Join no disponible aún")
        return
    end
    heroicJoinHooked = true
    HeroicLog("Instalando hook en LFDQueueFrame_Join")

    if hooksecurefunc and LFDQueueFrameRandom_SetDungeonID then
        hooksecurefunc("LFDQueueFrameRandom_SetDungeonID", function(id)
            if id then
                currentRandomDungeonID   = id
                currentRandomDungeonName = nil
                HeroicLog(string.format("Captured via Random_SetDungeonID: %s", tostring(id)))
            end
        end)
    end

    if hooksecurefunc and LFDQueueFrame_SetType then
        hooksecurefunc("LFDQueueFrame_SetType", function(id, typeID)
            if id then
                local dungeonID          = type(id) == "number" and id or nil
                currentRandomDungeonID   = dungeonID or id
                local n                  = (dungeonID and GetLFGDungeonInfo and select(1, GetLFGDungeonInfo(dungeonID))) or nil
                currentRandomDungeonName = n or nil
                HeroicLog(string.format("SetType: id=%s name=%s typeID=%s", tostring(id), tostring(n), tostring(typeID)))
            end
        end)
    end

    if hooksecurefunc and UIDropDownMenu_SetSelectedValue then
        hooksecurefunc("UIDropDownMenu_SetSelectedValue", function(frame, value)
            if frame == _G.LFDQueueFrameTypeDropDown then
                currentRandomDungeonID   = value
                local n = (type(value) == "number" and GetLFGDungeonInfo and select(1, GetLFGDungeonInfo(value))) or nil
                currentRandomDungeonName = n or nil
                HeroicLog(string.format("SetSelectedValue LFD type: %s (name=%s)", tostring(value), tostring(n)))
            end
        end)
    end

    if hooksecurefunc and UIDropDownMenu_SetSelectedID then
        hooksecurefunc("UIDropDownMenu_SetSelectedID", function(frame, id)
            if frame == _G.LFDQueueFrameTypeDropDown then
                local val = UIDropDownMenu_GetSelectedValue(frame)
                currentRandomDungeonID   = val or id
                local n = (type(currentRandomDungeonID) == "number" and GetLFGDungeonInfo and select(1, GetLFGDungeonInfo(currentRandomDungeonID))) or nil
                currentRandomDungeonName = n or nil
                HeroicLog(string.format("SetSelectedID LFD: id=%s val=%s name=%s", tostring(id), tostring(val), tostring(n)))
            end
        end)
    end

    if hooksecurefunc and _G.UIDropDownMenuButton_OnClick then
        hooksecurefunc("UIDropDownMenuButton_OnClick", function(self)
            local parentList = self and self:GetParent()
            if not parentList then return end
            local dropdown = parentList.dropdown
            if dropdown == _G.LFDQueueFrameTypeDropDown then
                local text = (self.GetText and self:GetText())
                    or (self:GetFontString() and self:GetFontString():GetText())
                    or (self.normalText and self.normalText:GetText())
                    or (type(self.value) == "number" and GetLFGDungeonInfo and select(1, GetLFGDungeonInfo(self.value)))
                    or (type(self.value) == "table" and self.value.name)
                    or nil
                currentRandomDungeonID   = self.value
                currentRandomDungeonName = text
                HeroicLog(string.format("Captured via Button_OnClick: value=%s text=%s", tostring(self.value), tostring(text)))
            end
        end)
    end

    HookLFDTypeDropdownButtons()

    if hooksecurefunc then
        hooksecurefunc("LFDQueueFrame_Join", function()
            HeroicLog("LFDQueueFrame_Join invoked")
            ScheduleHeroicQueueCheck()
        end)
    end
end

-- Manejador de eventos LFG_QUEUE_STATUS_UPDATE / LFG_UPDATE / LFG_PROPOSAL_SHOW
local function HandleLFGQueueUpdate()
    ScheduleHeroicQueueCheck()
end

-- Exponer en addonTable
addonTable.SetupHeroicQueueConfirm    = SetupHeroicQueueConfirm
addonTable.ScheduleHeroicQueueCheck   = ScheduleHeroicQueueCheck
addonTable.HandleLFGQueueUpdate       = HandleLFGQueueUpdate
addonTable.heroicQueueSearchLogged    = addonTable.heroicQueueSearchLogged or false
