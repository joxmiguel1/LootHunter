local addonName, addonTable = ...
local L = addonTable.L
local CreateGradient = addonTable.CreateGradient or function(text) return text end

-- Variables locales de UI -
local mainFrame = nil
local floatBtn = nil
local panelList, panelHelp, panelConfig, panelLog = nil, nil, nil, nil
local scrollChild = nil
local listScrollFrame = nil
local emptyJournalButton, emptyInstruction, emptyHeader, emptyQuote, ghostIcon, logoIcon = nil, nil, nil, nil, nil, nil
local ghostAnim, logoAnim = nil, nil
local emptyContainer = nil
local copyLogFrame = nil
local currentSpecFilter = "ALL"
local currentSourceFilter = "ALL"
local currentTypeFilter = "ALL"
local topPanel = nil
local pendingRefresh = false
local specRowMenuFrame = nil
local specRowMenuOverlay = nil
local typeMenuFrame, sourceMenuFrame, specMenuFrame = nil, nil, nil
local DEFAULT_WINDOW_WIDTH = 530
local DEFAULT_WINDOW_HEIGHT = 456
addonTable.DEFAULT_WINDOW_WIDTH = DEFAULT_WINDOW_WIDTH
addonTable.DEFAULT_WINDOW_HEIGHT = DEFAULT_WINDOW_HEIGHT

local function ElevateDropdown(frame, anchor)
    if not frame then return end
    frame:SetFrameStrata("TOOLTIP")
    local base = (anchor and anchor.GetFrameLevel and anchor:GetFrameLevel()) or 0
    frame:SetFrameLevel(base + 50)
end
local function AdjustFontSize(fs, delta)
    if not fs then return end
    local font, size, flags = fs:GetFont()
    if font and size then
        fs:SetFont(font, math.max(8, size + delta), flags)
    end
end

local ACCENT_FONT = "Interface\\AddOns\\LootHunter\\Fonts\\Prototype.ttf"
local EQUIPPED_ICON_PATH = "Interface\\AddOns\\LootHunter\\Textures\\icon_equipped.tga"
local EQUIPPED_ICON_FALLBACK = "Interface\\RaidFrame\\ReadyCheck-Ready"
local function ApplyAccentFont(fs, size, flags)
    if not fs then return end
    local _, currentSize, currentFlags = fs:GetFont()
    fs:SetFont(ACCENT_FONT, size or currentSize or 12, flags or currentFlags)
end
local function GetPrimaryColor()
    if addonTable.GetPrimaryColor then
        return addonTable.GetPrimaryColor()
    end
    local c = addonTable.PRIMARY_COLOR or {}
    return c.r or 1, c.g or 0.82, c.b or 0
end
local function GetEquippedIconTag()
    local path = (addonTable and addonTable.UseFallbackEquippedIcon) and EQUIPPED_ICON_FALLBACK or EQUIPPED_ICON_PATH
    return string.format("|T%s:14:14|t", path)
end

local function RefreshRowTooltip(row, showCompare)
    if not row or not row._tooltipLink or not GameTooltip then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(row._tooltipLink)
    if showCompare and GameTooltip_ShowCompareItem then
        pcall(GameTooltip_ShowCompareItem, GameTooltip)
    end
    GameTooltip:Show()
end

-- Fuerza nuestra fuente en todas las FontStrings de un frame (recursivo)
local function ApplyAccentFontRecursive(frame)
    if not frame or type(frame) ~= "table" then return end
    local regions = { frame:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
            local _, size, flags = region:GetFont()
            region:SetFont(ACCENT_FONT, size or 12, flags)
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        ApplyAccentFontRecursive(child)
    end
end

local function CloseAllDropdowns()
    if typeMenuFrame then typeMenuFrame:Hide() end
    if sourceMenuFrame then sourceMenuFrame:Hide() end
    if specMenuFrame then specMenuFrame:Hide() end
    if specRowMenuFrame then specRowMenuFrame:Hide() end
    if specRowMenuOverlay then specRowMenuOverlay:Hide() end
end

-- Desplegable de selección de spec por fila
local function ShowRowSpecMenu(anchor, entry)
    if not anchor or not entry or not entry.data then return end
    if specRowMenuFrame and specRowMenuFrame:IsShown() and specRowMenuFrame._ownerRow == entry.row then
        specRowMenuFrame:Hide()
        return
    end
    CloseAllDropdowns()
    local specs = (addonTable.GetAvailableSpecsWithIDs and addonTable.GetAvailableSpecsWithIDs()) or (addonTable.GetAvailableSpecs and addonTable.GetAvailableSpecs()) or {}
    if not specRowMenuFrame then
        specRowMenuFrame = CreateFrame("Frame", "LootHunterRowSpecMenu", UIParent, "BackdropTemplate")
        specRowMenuFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        specRowMenuFrame:SetBackdropColor(0.15, 0.15, 0.15, 0.95)
        specRowMenuFrame:SetBackdropBorderColor(0, 0, 0, 1)
        specRowMenuFrame:EnableMouse(true)
        specRowMenuFrame:SetScript("OnHide", function(self)
            if self._ownerRow then
                self._ownerRow._specMenuOpen = nil
                self._ownerRow = nil
            end
            if specRowMenuOverlay then specRowMenuOverlay:Hide() end
        end)
    end
    if not specRowMenuOverlay then
        specRowMenuOverlay = CreateFrame("Button", nil, UIParent)
        specRowMenuOverlay:SetFrameStrata("TOOLTIP")
        specRowMenuOverlay:EnableMouse(true)
        specRowMenuOverlay:SetAllPoints(UIParent)
        specRowMenuOverlay:Hide()
        specRowMenuOverlay:SetScript("OnClick", function()
            if specRowMenuFrame then specRowMenuFrame:Hide() end
        end)
    end
    -- Limpiar botones previos
    for _, child in ipairs({ specRowMenuFrame:GetChildren() }) do child:Hide(); child:SetParent(nil) end

    local yPos = -5
    local function CreateOption(text, specID)
        local btn = CreateFrame("Button", nil, specRowMenuFrame)
        btn:SetSize(100, 20)
        btn:SetPoint("TOPLEFT", 5, yPos)
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", btn, "LEFT", 5, 0)
        fs:SetText(text)
        fs:SetJustifyH("LEFT")
        fs:SetTextColor(1, 1, 1)
        ApplyAccentFont(fs)
        btn:SetScript("OnEnter", function()
            local pr, pg, pb = GetPrimaryColor()
            fs:SetTextColor(pr, pg, pb)
        end)
        btn:SetScript("OnLeave", function() fs:SetTextColor(1, 1, 1) end)
        btn:SetScript("OnClick", function()
            if specID then
                entry.data.specID = specID
            end
            entry.data.spec = text
            specRowMenuFrame:Hide()
            LootHunter_RefreshUI()
        end)
    end

    for _, specEntry in ipairs(specs) do
        local specName = specEntry.name or specEntry
        local specID = specEntry.id or (addonTable.GetSpecIDFromName and addonTable.GetSpecIDFromName(specName)) or nil
        CreateOption(specName, specID)
        yPos = yPos - 20
    end
    specRowMenuFrame:SetHeight(math.abs(yPos) + 5)
    specRowMenuFrame:SetWidth(110)
    specRowMenuFrame:ClearAllPoints()
    specRowMenuFrame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    ElevateDropdown(specRowMenuFrame, anchor)
    specRowMenuOverlay:Show()
    if entry.row then
        entry.row._specMenuOpen = true
        specRowMenuFrame._ownerRow = entry.row
    end
    specRowMenuFrame:Show()
end

local function GetEmptyQuoteText()
    local quotes = L["EMPTY_QUOTES"]
    if type(quotes) == "table" then
        return (quotes[1] or "") .. "\n\n"
    end
    return (quotes or L["EMPTY_QUOTE"] or "") .. "\n\n"
end

local function ResolveVisualState(info)
    if not info then return nil end
    if info.lastState == "priority" and info.priority then
        return "priority"
    end
    if info.lastState == "won" and info.status == 2 then
        return "won"
    end
    if info.status == 2 then
        return "won"
    end
    if info.priority then
        return "priority"
    end
    return nil
end

-- Referencias a texturas
local function ResolveAddonFolder()
    local stack = debugstack(1, 1, 0)
    local folder = stack and stack:match("Interface\\AddOns\\([^\\]+)\\UI%.lua")
    if not folder then folder = addonName end
    return "Interface\\AddOns\\" .. folder .. "\\"
end

local ADDON_FOLDER = ResolveAddonFolder()
local TEX_ARROW = ADDON_FOLDER .. "Textures\\icon_arrow.tga"
local DELETE_ICON_PATH = ADDON_FOLDER .. "Textures\\icon_delete.tga"

-- === SISTEMA DE ALERTAS DE TEXTO ===
local alertMsgFrame = CreateFrame("MessageFrame", "LootHunterMsgFrame", UIParent)
alertMsgFrame:SetSize(600, 100)
alertMsgFrame:SetPoint("CENTER", 0, 150)
alertMsgFrame:SetFrameStrata("FULLSCREEN_DIALOG")
alertMsgFrame:SetInsertMode("TOP")
alertMsgFrame:SetFading(true)
alertMsgFrame:SetFadeDuration(0.5)
alertMsgFrame:SetTimeVisible(6.8)

alertMsgFrame:SetFont(ACCENT_FONT, 35, "THICKOUTLINE")
ApplyAccentFontRecursive(alertMsgFrame)

local ALERT_DEFAULT_DURATION = 6.8
local alertQueue = {}
local alertActive = false
local function ProcessAlertQueue()
    if alertActive then return end
    local item = table.remove(alertQueue, 1)
    if not item then return end
    alertActive = true
    item.action()
    C_Timer.After(item.duration, function()
        alertActive = false
        ProcessAlertQueue()
    end)
end

local function EnqueueAlert(duration, action, priority)
    if type(action) ~= "function" then return end
    local entry = {
        duration = duration or ALERT_DEFAULT_DURATION,
        action = action,
        priority = priority or 5,
    }
    local inserted = false
    for i = 1, #alertQueue do
        if entry.priority < alertQueue[i].priority then
            table.insert(alertQueue, i, entry)
            inserted = true
            break
        end
    end
    if not inserted then
        table.insert(alertQueue, entry)
    end
    if not alertActive then
        ProcessAlertQueue()
    end
end

addonTable.EnqueueAlert = EnqueueAlert
addonTable.GetAlertDefaultDuration = function() return ALERT_DEFAULT_DURATION end

function addonTable.ShowAlert(text, r, g, b)
    if StaticPopup1 and StaticPopup1:IsVisible() then return end
    alertMsgFrame:AddMessage(text, r, g, b)
end

-- Frame temporal de pre-aviso (mensaje con fondo).
local preWarnFrame = CreateFrame("Frame", "LootHunterPreWarnFrame", UIParent, "BackdropTemplate")
preWarnFrame:SetSize(760, 60)
preWarnFrame:SetPoint("TOP", UIParent, "TOP", 0, -160)
preWarnFrame:SetFrameStrata("FULLSCREEN_DIALOG")
preWarnFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
})
preWarnFrame:SetBackdropColor(0, 0, 0, 0.75)
preWarnFrame:SetBackdropBorderColor(0, 0, 0, 1)
preWarnFrame:Hide()
preWarnFrame.fadeAnim = preWarnFrame:CreateAnimationGroup()
local fadeOut = preWarnFrame.fadeAnim:CreateAnimation("Alpha")
fadeOut:SetFromAlpha(1)
fadeOut:SetToAlpha(0)
fadeOut:SetDuration(3.6)
fadeOut:SetSmoothing("IN_OUT")
preWarnFrame.shakeAnim = preWarnFrame:CreateAnimationGroup()
preWarnFrame.shakeAnim:SetLooping("NONE")
local shakeLeft = preWarnFrame.shakeAnim:CreateAnimation("Translation")
shakeLeft:SetOffset(-12, 0)
shakeLeft:SetDuration(0.12)
shakeLeft:SetOrder(1)
local shakeRight = preWarnFrame.shakeAnim:CreateAnimation("Translation")
shakeRight:SetOffset(24, 0)
shakeRight:SetDuration(0.12)
shakeRight:SetOrder(2)
local shakeCenter = preWarnFrame.shakeAnim:CreateAnimation("Translation")
shakeCenter:SetOffset(-12, 0)
shakeCenter:SetDuration(0.12)
shakeCenter:SetOrder(3)
preWarnFrame.shakeAnim:SetScript("OnFinished", function(self)
    local loops = (self._loops or 0) + 1
    self._loops = loops
    if loops < 2 then
        self:Play()
    end
end)

local preWarnText = preWarnFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
preWarnText:SetPoint("CENTER")
preWarnText:SetWidth(720)
preWarnText:SetWordWrap(true)
preWarnText:SetJustifyH("CENTER")
preWarnText:SetTextColor(1, 1, 1)
preWarnText:SetFont(ACCENT_FONT, 18, "THICKOUTLINE")
ApplyAccentFontRecursive(preWarnFrame)

function addonTable.ShowPreWarningFrame(text, duration, enableShake, enableFade)
    if not text or text == "" then return end
    do
        preWarnText:SetFont(ACCENT_FONT, 18, "THICKOUTLINE")
        preWarnText:SetTextColor(1, 1, 1)
        preWarnText:Show()
    end
    preWarnText:SetText(text)
    preWarnFrame:Show()
    preWarnFrame:SetAlpha(1)
    local shake = (enableShake == nil) and true or enableShake
    local fade = (enableFade == true)
    if shake and preWarnFrame.shakeAnim then
        if preWarnFrame.shakeAnim:IsPlaying() then
            preWarnFrame.shakeAnim:Stop()
        end
        preWarnFrame.shakeAnim._loops = 0
        preWarnFrame.shakeAnim:Play()
    end
    local displayTime = duration or 4
    local fadeDuration = (fade and fadeOut and fadeOut.GetDuration and fadeOut:GetDuration()) or 0
    if fade and preWarnFrame.fadeAnim then
        if preWarnFrame.fadeAnim:IsPlaying() then
            preWarnFrame.fadeAnim:Stop()
        end
        local delay = math.max(0, displayTime)
        fadeOut:SetStartDelay(delay)
        preWarnFrame.fadeAnim:Play()
    end
    C_Timer.After(displayTime + fadeDuration, function()
        if preWarnFrame and preWarnFrame.shakeAnim then
            preWarnFrame.shakeAnim:Stop()
        end
        if preWarnFrame then preWarnFrame:Hide() end
    end)
end

function addonTable.ResetPreviewVisuals()
    if alertMsgFrame and alertMsgFrame.Clear then
        alertMsgFrame:Clear()
    end
    if flashFrame then
        if UIFrameFlashStop then
            UIFrameFlashStop(flashFrame)
        end
        flashFrame:Hide()
    end
end

-- === SISTEMA DE FLASH (Alertas Visuales) ===
local flashFrame = CreateFrame("Frame", "LootHunterFlash", UIParent)
flashFrame:SetAllPoints()
flashFrame:SetFrameStrata("FULLSCREEN_DIALOG")
flashFrame:Hide()

local flashTex = flashFrame:CreateTexture(nil, "BACKGROUND")
flashTex:SetAllPoints()
flashTex:SetBlendMode("ADD") 

function addonTable.FlashScreen(type)
    if StaticPopup1 and StaticPopup1:IsVisible() then return end
    flashTex:SetAlpha(1)
    if type == "RED" then
        flashTex:SetTexture("Interface\\FullScreenTextures\\LowHealth")
        flashTex:SetVertexColor(1, 0.15, 0.15, 1) 
    elseif type == "WIN" then
        flashTex:SetTexture("Interface\\Buttons\\WHITE8X8")
        flashTex:SetVertexColor(0, 1, 0, 0.55)
    elseif type == "GREEN" then
        flashTex:SetTexture("Interface\\Buttons\\WHITE8X8")
        flashTex:SetVertexColor(0, 1, 0, 0.25) 
    elseif type == "YELLOW" then
        flashTex:SetTexture("Interface\\Buttons\\WHITE8X8")
        flashTex:SetVertexColor(1, 0.85, 0.2, 0.45)
    elseif type == "ORANGE" then
        flashTex:SetTexture("Interface\\Buttons\\WHITE8X8")
        flashTex:SetVertexColor(1, 0.6, 0, 0.35)
    end
    UIFrameFlash(flashFrame, 0.5, 2.0, 2.5, false, 0, 0)
end

-- === POPUPS ===
local LOOTHUNTER_CONFIRM_CLEAR = {
    text = L["CONFIRM_CLEAR_TEXT"],
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        local db = addonTable.CurrentCharDB
        if db then
            local keysToRemove = {}
            for k in pairs(db) do if type(k) == "number" then table.insert(keysToRemove, k) end end
            for _, key in ipairs(keysToRemove) do db[key] = nil end
            print(L["LIST_CLEARED_MSG"])
            LootHunter_RefreshUI()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    showAlert = 1,
}
if type(StaticPopupDialogs) == "table" then
    StaticPopupDialogs["LOOTHUNTER_CONFIRM_CLEAR"] = LOOTHUNTER_CONFIRM_CLEAR
end

local LOOTHUNTER_CONFIRM_RESET = {
    text = L["RESET_ENV_PROMPT"] or "Reset Loot Hunter settings and saved data? This will reload the UI.",
    button1 = OKAY,
    button2 = CANCEL,
    OnAccept = function()
        if LootHunterDB then
            local name = UnitName("player") or ""
            local realm = GetRealmName and GetRealmName() or ""
            local charKey = name .. " - " .. realm
            if LootHunterDB.Characters then
                LootHunterDB.Characters[charKey] = {}
                if addonTable then
                    addonTable.CurrentCharDB = LootHunterDB.Characters[charKey]
                end
            end
            LootHunterDB.settings = nil
            LootHunterDB.windowSettings = nil
            LootHunterDB.buttonPos = nil
            LootHunterDB.minimap = nil
            if addonTable then addonTable.db = LootHunterDB end
        end
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    showAlert = 1,
}
if type(StaticPopupDialogs) == "table" then
    StaticPopupDialogs["LOOTHUNTER_CONFIRM_RESET"] = LOOTHUNTER_CONFIRM_RESET
end

-- === FUNCIONES DE UI ===

local function IsDebugLoggingEnabled()
    return addonTable.IsDebugEnabled and addonTable.IsDebugEnabled()
end

function CreateFloatingButton()
    if floatBtn then return end
    floatBtn = CreateFrame("Button", "LootHunterFloatBtn", UIParent, "UIPanelButtonTemplate")
    floatBtn:SetSize(80, 20)
    floatBtn:SetText(L["BTN_TEXT"])
    floatBtn:SetMovable(true)
    floatBtn:EnableMouse(true)
    floatBtn:RegisterForDrag("LeftButton")
    floatBtn:SetScript("OnDragStart", floatBtn.StartMoving)
    floatBtn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        LootHunterDB.buttonPos = { point = point, relativePoint = relPoint, x = x, y = y }
    end)
    
    local pos = LootHunterDB.buttonPos
    floatBtn:SetPoint(pos.point, UIParent, pos.relativePoint or "CENTER", pos.x, pos.y)
    floatBtn:SetScript("OnClick", function() LootHunter_CreateGUI() end)
    if addonTable.ApplyUIScale then
        addonTable.ApplyUIScale()
    end
    floatBtn:Show()
end

local function SaveWindowPosition()
    if not mainFrame then return end
    local point, _, relativePoint, x, y = mainFrame:GetPoint()
    LootHunterDB.windowSettings.point = point
    LootHunterDB.windowSettings.relativePoint = relativePoint
    LootHunterDB.windowSettings.x = x
    LootHunterDB.windowSettings.y = y
    LootHunterDB.windowSettings.height = mainFrame:GetHeight()
    LootHunterDB.windowSettings.width = mainFrame:GetWidth()
end

function addonTable.ResetWindowSize()
    if not mainFrame then return end
    local screenWidth = (GetScreenWidth and GetScreenWidth()) or (UIParent and UIParent:GetWidth()) or 0
    local defaultX = -math.floor((screenWidth or 0) * 0.10)
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint("RIGHT", UIParent, "RIGHT", defaultX, 0)
    mainFrame:SetSize(DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT)
    SaveWindowPosition()
end

local function GetUIScale()
    local scale = LootHunterDB and LootHunterDB.settings and LootHunterDB.settings.general and LootHunterDB.settings.general.uiScale
    if type(scale) ~= "number" then
        scale = 1
    end
    return scale
end

function addonTable.ApplyUIScale(scale)
    local target = scale or GetUIScale()
    if mainFrame then mainFrame:SetScale(target) end
    if alertMsgFrame then alertMsgFrame:SetScale(target) end
    if preWarnFrame then preWarnFrame:SetScale(target) end
    if floatBtn then floatBtn:SetScale(target) end
    if copyLogFrame then copyLogFrame:SetScale(target) end
end

local function CreateHelpText(parent, text, relativeTo, yOff, isTitle)
    local fs = parent:CreateFontString(nil, "OVERLAY", isTitle and "GameFontNormalLarge" or "GameFontHighlight")
    if relativeTo then
        fs:SetPoint("TOPLEFT", relativeTo, "BOTTOMLEFT", 0, yOff)
    else
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOff)
    end
    fs:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    if not isTitle and fs.SetSpacing then
        fs:SetSpacing(2)
    end
    fs:SetText(text)
    if isTitle then
        local pr, pg, pb = GetPrimaryColor()
        fs:SetTextColor(pr, pg, pb)
    end
    return fs
end

function CreateCopyLogWindow()
    local DebugLog = addonTable.DebugLog or {}
    if #DebugLog == 0 then
        print(L["LOG_EMPTY_ERROR"])
        return
    end

    if copyLogFrame then
        local scroll = copyLogFrame.scroll
        local editBox = scroll:GetScrollChild()
        editBox:SetText(table.concat(DebugLog, "\n"))
        editBox:HighlightText(0, -1)
        copyLogFrame:Show()
        return
    end

    copyLogFrame = CreateFrame("Frame", "LootHunterCopyLog", UIParent, "BackdropTemplate")
    copyLogFrame:SetSize(500, 400)
    copyLogFrame:SetPoint("CENTER")
    copyLogFrame:SetFrameStrata("DIALOG")
    copyLogFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    local title = copyLogFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -15)
    title:SetText(L["COPY_LOG_TITLE"])

    copyLogFrame.scroll = CreateFrame("ScrollFrame", nil, copyLogFrame, "UIPanelScrollFrameTemplate")
    copyLogFrame.scroll:SetPoint("TOPLEFT", 20, -60)
    copyLogFrame.scroll:SetPoint("BOTTOMRIGHT", -30, 20)

    local editBox = CreateFrame("EditBox", nil, copyLogFrame.scroll)
    editBox:SetMultiLine(true); editBox:SetFontObject("ChatFontNormal"); editBox:SetWidth(430); editBox:SetMaxLetters(0); editBox:SetAutoFocus(true)
    copyLogFrame.scroll:SetScrollChild(editBox)
    editBox:SetText(table.concat(DebugLog, "\n")); editBox:HighlightText(0, -1)

    local btnClose = CreateFrame("Button", nil, copyLogFrame, "UIPanelCloseButton"); btnClose:SetPoint("TOPRIGHT", -5, -5)
    copyLogFrame:Show()
    ApplyAccentFontRecursive(copyLogFrame)
end

function LootHunter_CreateGUI()
    if mainFrame then 
        if mainFrame:IsShown() then 
            mainFrame:Hide() 
        else 
            if emptyQuote then
                emptyQuote.selectedText = GetEmptyQuoteText()
                emptyQuote:SetText(emptyQuote.selectedText)
            end
            mainFrame:Show(); LootHunter_RefreshUI() 
        end
        return 
    end
    local SelectTab

    mainFrame = CreateFrame("Frame", "LootHunterFrame", UIParent, "BackdropTemplate")
    mainFrame:SetFrameStrata("DIALOG")
    mainFrame:SetFrameLevel(10)
    mainFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    mainFrame:SetBackdropColor(0.11, 0.11, 0.11, 0.95)
    mainFrame:SetBackdropBorderColor(0, 0, 0, 1)
    mainFrame:SetResizable(true)
    -- Mantener el mínimo igual al tamaño por defecto para que no se pueda encoger más tras reset.
    mainFrame:SetResizeBounds(DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT, 28000, 28000)
    
    local settings = LootHunterDB.windowSettings
    mainFrame:SetSize(settings.width or DEFAULT_WINDOW_WIDTH, settings.height or DEFAULT_WINDOW_HEIGHT)
    mainFrame:SetPoint(settings.point or "CENTER", UIParent, settings.relativePoint or "CENTER", settings.x or 0, settings.y or 0)
    if addonTable.ApplyUIScale then
        addonTable.ApplyUIScale()
    end
    
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SaveWindowPosition() end)
    mainFrame:SetScript("OnHide", function()
        CloseAllDropdowns()
    end)
    if type(UISpecialFrames) == "table" then
        local found = false
        for _, frameName in ipairs(UISpecialFrames) do
            if frameName == "LootHunterFrame" then
                found = true
                break
            end
        end
        if not found then
            table.insert(UISpecialFrames, "LootHunterFrame")
        end
    end
    addonTable.MainFrame = mainFrame
    
    local configBtn = CreateFrame("Button", nil, mainFrame)
    configBtn:SetSize(16, 16)
    configBtn:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -7)
    configBtn:SetNormalTexture(ADDON_FOLDER .. "Textures\\icon_config.tga")
    configBtn:SetFrameLevel(mainFrame:GetFrameLevel() + 6)
    configBtn:SetScript("OnClick", function()
        if addonTable.SelectTab then
            CloseAllDropdowns()
            if panelConfig and panelConfig:IsShown() then
                addonTable.SelectTab(1) -- Regresa a la lista
            else
                addonTable.SelectTab(4) -- Abre configuración
            end
        end
    end)

    local helpTopBtn = CreateFrame("Button", nil, mainFrame)
    helpTopBtn:SetSize(16, 16)
    helpTopBtn:SetPoint("LEFT", configBtn, "RIGHT", 8, 0)
    helpTopBtn:SetNormalTexture(ADDON_FOLDER .. "Textures\\icon_help_top.tga")
    helpTopBtn:SetPushedTexture(ADDON_FOLDER .. "Textures\\icon_help_top.tga")
    helpTopBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    helpTopBtn:SetFrameLevel(mainFrame:GetFrameLevel() + 6)
    local helpTopNormal = helpTopBtn:GetNormalTexture()
    if helpTopNormal then helpTopNormal:SetAllPoints() end
    local helpTopPushed = helpTopBtn:GetPushedTexture()
    if helpTopPushed then helpTopPushed:SetAllPoints() end
    helpTopBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["TAB_HELP"] or "Help", 1, 1, 1)
        GameTooltip:Show()
    end)
    helpTopBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    helpTopBtn.pulse = helpTopBtn:CreateTexture(nil, "OVERLAY")
    helpTopBtn.pulse:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    helpTopBtn.pulse:SetBlendMode("ADD")
    helpTopBtn.pulse:SetPoint("CENTER", 0, 0)
    helpTopBtn.pulse:SetSize(34, 34)
    helpTopBtn.pulse:Hide()
    helpTopBtn.pulseAnim = helpTopBtn.pulse:CreateAnimationGroup()
    helpTopBtn.pulseAnim:SetLooping("REPEAT")
    local topFadeIn = helpTopBtn.pulseAnim:CreateAnimation("Alpha")
    topFadeIn:SetFromAlpha(0.2)
    topFadeIn:SetToAlpha(1)
    topFadeIn:SetDuration(0.8)
    topFadeIn:SetOrder(1)
    local topFadeOut = helpTopBtn.pulseAnim:CreateAnimation("Alpha")
    topFadeOut:SetFromAlpha(1)
    topFadeOut:SetToAlpha(0.2)
    topFadeOut:SetDuration(0.8)
    topFadeOut:SetOrder(2)

    local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -10, -7)
    closeBtn:SetNormalTexture(ADDON_FOLDER .. "Textures\\close.tga")
    closeBtn:SetPushedTexture(ADDON_FOLDER .. "Textures\\close.tga")
    closeBtn:SetHighlightTexture(ADDON_FOLDER .. "Textures\\close.tga")
    closeBtn:SetSize(18, 18)
    closeBtn:SetFrameLevel(mainFrame:GetFrameLevel() + 6)
    local closeNormal = closeBtn:GetNormalTexture()
    if closeNormal then closeNormal:SetVertexColor(1, 1, 1, 1) end
    local closePushed = closeBtn:GetPushedTexture()
    if closePushed then closePushed:SetVertexColor(1, 1, 1, 1) end
    local closeHighlight = closeBtn:GetHighlightTexture()
    if closeHighlight then closeHighlight:SetVertexColor(1, 1, 1, 1) end

    mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mainFrame.title:SetPoint("TOP", mainFrame, "TOP", 0, -10)
    mainFrame.title:SetText(string.format(L["WINDOW_TITLE"], UnitName("player")))

    if not (LootHunterDB and LootHunterDB.settings and LootHunterDB.settings.general.windowsLocked) then
        local resizeButton = CreateFrame("Button", nil, mainFrame)
        resizeButton:SetSize(16, 16)
        resizeButton:SetPoint("BOTTOMRIGHT", -5, 5)
        resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        resizeButton:SetScript("OnMouseDown", function(self, button) mainFrame:StartSizing("BOTTOMRIGHT") end)
        resizeButton:SetScript("OnMouseUp", function(self, button) mainFrame:StopMovingOrSizing(); SaveWindowPosition() end)
    end

    panelList = CreateFrame("Frame", nil, mainFrame)
    panelList:SetPoint("TOPLEFT", 0, -25)
    panelList:SetPoint("BOTTOMRIGHT", 0, 30)

    -- === PANEL DE CONTROL SUPERIOR ===
    topPanel = CreateFrame("Frame", nil, panelList, "BackdropTemplate")
    topPanel:SetPoint("TOPLEFT", panelList, "TOPLEFT", 5, -5)
    topPanel:SetPoint("TOPRIGHT", panelList, "TOPRIGHT", -5, -5)
    topPanel:SetHeight(40)
    topPanel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    topPanel:SetBackdropColor(0.06, 0.06, 0.06, 0.92)
    topPanel:SetBackdropBorderColor(0, 0, 0, 1)

    local btnJournal = CreateFrame("Button", nil, topPanel, "BackdropTemplate")
    btnJournal:SetSize(24, 24)
    btnJournal:SetPoint("LEFT", topPanel, "LEFT", 5, 0)
    btnJournal:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    btnJournal:SetBackdropColor(0.12, 0.12, 0.12, 1)

    btnJournal:SetBackdropBorderColor(0, 0, 0, 1)

    local journalIcon = btnJournal:CreateTexture(nil, "ARTWORK")
    journalIcon:SetSize(16, 16)
    journalIcon:SetPoint("CENTER")
    journalIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_05")

    btnJournal:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        if not IsAddOnLoaded("Blizzard_EncounterJournal") and EncounterJournal_LoadUI then
            EncounterJournal_LoadUI()
        end
        if ToggleEncounterJournal then
            ToggleEncounterJournal()
        end
    end)
    btnJournal:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText(L["EMPTY_OPEN_JOURNAL"], nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    btnJournal:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- === FILTRO 1: TIPO (Prioridad) ===
    local btnTypeFilter = CreateFrame("Button", nil, topPanel, "BackdropTemplate")
    btnTypeFilter:SetSize(85, 24)
    btnTypeFilter:SetPoint("LEFT", btnJournal, "RIGHT", 6, 0)
    btnTypeFilter:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    btnTypeFilter:SetBackdropColor(0.12, 0.12, 0.12, 1)
    btnTypeFilter:SetBackdropBorderColor(0, 0, 0, 1)

    local function GetTypeFilterLabel(value)
        if value == "ALL" then return L["FILTER_TYPE"]
        elseif value == "PRIORITY" then return L["FILTER_PRIORITY"]
        elseif value == "WON" then return L["FILTER_WON"]
        elseif value == "PENDING" then return L["FILTER_PENDING"]
        end
        return L["FILTER_TYPE"]
    end

    local typeFilterText = btnTypeFilter:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    typeFilterText:SetPoint("LEFT", btnTypeFilter, "LEFT", 8, 0)
    typeFilterText:SetPoint("RIGHT", btnTypeFilter, "RIGHT", -15, 0)
    typeFilterText:SetJustifyH("LEFT")
    typeFilterText:SetText(GetTypeFilterLabel(currentTypeFilter))

    local typeArrow = btnTypeFilter:CreateTexture(nil, "ARTWORK")
    typeArrow:SetSize(8, 8)
    typeArrow:SetPoint("RIGHT", btnTypeFilter, "RIGHT", -5, 0)
    typeArrow:SetTexture(TEX_ARROW)
    do
        local pr, pg, pb = GetPrimaryColor()
        typeArrow:SetVertexColor(pr, pg, pb, 1)
    end

    typeMenuFrame = CreateFrame("Frame", "LootHunterTypeMenuFrame", UIParent, "BackdropTemplate")
    typeMenuFrame:SetWidth(110)
    typeMenuFrame:SetPoint("TOPLEFT", btnTypeFilter, "BOTTOMLEFT", 0, -2)
    typeMenuFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    typeMenuFrame:SetBackdropColor(0.12, 0.12, 0.12, 0.95)
    typeMenuFrame:SetBackdropBorderColor(0, 0, 0, 1)
    typeMenuFrame:Hide()
    ElevateDropdown(typeMenuFrame, btnTypeFilter)

    local function CreateTypeMenuButton(parent, text, value, yPos)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(75, 20)
        btn:SetPoint("TOPLEFT", 5, yPos)
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", btn, "LEFT", 5, 0)
        fs:SetText(text)
        fs:SetJustifyH("LEFT")
        ApplyAccentFont(fs)
        do
            local pr, pg, pb = GetPrimaryColor()
            fs:SetTextColor(currentTypeFilter == value and pr or 0.7, currentTypeFilter == value and pg or 0.7, currentTypeFilter == value and pb or 0.7)
        end
        btn:SetScript("OnEnter", function() fs:SetTextColor(1, 1, 1) end)
        btn:SetScript("OnLeave", function()
            local pr, pg, pb = GetPrimaryColor()
            fs:SetTextColor(currentTypeFilter == value and pr or 0.7, currentTypeFilter == value and pg or 0.7, currentTypeFilter == value and pb or 0.7)
        end)
        btn:SetScript("OnClick", function()
            currentTypeFilter = value
            typeFilterText:SetText(GetTypeFilterLabel(value))
            LootHunter_RefreshUI()
            parent:Hide()
        end)
        return btn
    end

    btnTypeFilter:SetScript("OnClick", function(self)
        CloseAllDropdowns()
        if typeMenuFrame:IsShown() then typeMenuFrame:Hide() return end
        local kids = { typeMenuFrame:GetChildren() }
        for _, child in ipairs(kids) do child:Hide(); child:SetParent(nil) end
        local yPos = -5
        CreateTypeMenuButton(typeMenuFrame, L["FILTER_ALL"], "ALL", yPos)
        yPos = yPos - 20
        CreateTypeMenuButton(typeMenuFrame, L["FILTER_PRIORITY"], "PRIORITY", yPos)
        yPos = yPos - 20
        CreateTypeMenuButton(typeMenuFrame, L["FILTER_WON"], "WON", yPos)
        yPos = yPos - 20
        CreateTypeMenuButton(typeMenuFrame, L["FILTER_PENDING"], "PENDING", yPos)
        yPos = yPos - 20
        typeMenuFrame:SetHeight(math.abs(yPos) + 5)
        typeMenuFrame:Show()
    end)

    -- === FILTRO 2: FUENTE ===
    local btnSourceFilter = CreateFrame("Button", nil, topPanel, "BackdropTemplate")
    btnSourceFilter:SetSize(95, 24)
    btnSourceFilter:SetPoint("LEFT", btnTypeFilter, "RIGHT", 5, 0)
    btnSourceFilter:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    btnSourceFilter:SetBackdropColor(0.12, 0.12, 0.12, 1)
    btnSourceFilter:SetBackdropBorderColor(0, 0, 0, 1)

    local sourceFilterText = btnSourceFilter:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sourceFilterText:SetPoint("LEFT", btnSourceFilter, "LEFT", 8, 0)
    sourceFilterText:SetPoint("RIGHT", btnSourceFilter, "RIGHT", -15, 0)
    sourceFilterText:SetJustifyH("LEFT")
    sourceFilterText:SetText(L["FILTER_SOURCE"])

    local sourceArrow = btnSourceFilter:CreateTexture(nil, "ARTWORK")
    sourceArrow:SetSize(8, 8)
    sourceArrow:SetPoint("RIGHT", btnSourceFilter, "RIGHT", -5, 0)
    sourceArrow:SetTexture(TEX_ARROW)
    do
        local pr, pg, pb = GetPrimaryColor()
        sourceArrow:SetVertexColor(pr, pg, pb, 1)
    end

    sourceMenuFrame = CreateFrame("Frame", "LootHunterSourceMenuFrame", UIParent, "BackdropTemplate")
    sourceMenuFrame:SetWidth(110)
    sourceMenuFrame:SetPoint("TOPLEFT", btnSourceFilter, "BOTTOMLEFT", 0, -2)
    sourceMenuFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    sourceMenuFrame:SetBackdropColor(0.12, 0.12, 0.12, 0.95)
    sourceMenuFrame:SetBackdropBorderColor(0, 0, 0, 1)
    sourceMenuFrame:Hide()
    ElevateDropdown(sourceMenuFrame, btnSourceFilter)

    local function CreateSourceMenuButton(parent, text, value, yPos)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(100, 20)
        btn:SetPoint("TOPLEFT", 5, yPos)
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", btn, "LEFT", 5, 0)
        fs:SetText(text)
        fs:SetJustifyH("LEFT")
        ApplyAccentFont(fs)
        do
            local pr, pg, pb = GetPrimaryColor()
            fs:SetTextColor(currentSourceFilter == value and pr or 0.7, currentSourceFilter == value and pg or 0.7, currentSourceFilter == value and pb or 0.7)
        end
        btn:SetScript("OnEnter", function() fs:SetTextColor(1, 1, 1) end)
        btn:SetScript("OnLeave", function()
            local pr, pg, pb = GetPrimaryColor()
            fs:SetTextColor(currentSourceFilter == value and pr or 0.7, currentSourceFilter == value and pg or 0.7, currentSourceFilter == value and pb or 0.7)
        end)
        btn:SetScript("OnClick", function()
            currentSourceFilter = value
            local label = value
            if value == "ALL" then label = L["FILTER_SOURCE"]
            elseif value == "SOURCE_DROP" then label = L["FILTER_BOSS"]
            elseif value == "SOURCE_TOKEN" then label = L["FILTER_TOKEN"]
            elseif value == "SOURCE_MOUNT" then label = L["FILTER_MOUNT"] end
            sourceFilterText:SetText(label)
            LootHunter_RefreshUI()
            parent:Hide()
        end)
        return btn
    end

    btnSourceFilter:SetScript("OnClick", function(self)
        CloseAllDropdowns()
        if sourceMenuFrame:IsShown() then sourceMenuFrame:Hide() return end
        local kids = { sourceMenuFrame:GetChildren() }
        for _, child in ipairs(kids) do child:Hide(); child:SetParent(nil) end
        local yPos = -5
        CreateSourceMenuButton(sourceMenuFrame, L["FILTER_ALL"], "ALL", yPos)
        yPos = yPos - 20
        CreateSourceMenuButton(sourceMenuFrame, L["FILTER_BOSS"], "SOURCE_DROP", yPos)
        yPos = yPos - 20
        CreateSourceMenuButton(sourceMenuFrame, L["FILTER_TOKEN"], "SOURCE_TOKEN", yPos)
        yPos = yPos - 20
        CreateSourceMenuButton(sourceMenuFrame, L["FILTER_MOUNT"], "SOURCE_MOUNT", yPos)
        yPos = yPos - 20
        sourceMenuFrame:SetHeight(math.abs(yPos) + 5)
        sourceMenuFrame:Show()
    end)

    -- === FILTRO 3: SPEC ===
    local btnSpecFilter = CreateFrame("Button", nil, topPanel, "BackdropTemplate")
    btnSpecFilter:SetSize(95, 24)
    btnSpecFilter:SetPoint("LEFT", btnSourceFilter, "RIGHT", 5, 0)
    btnSpecFilter:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    btnSpecFilter:SetBackdropColor(0.12, 0.12, 0.12, 1)
    btnSpecFilter:SetBackdropBorderColor(0, 0, 0, 1)

    local function GetSpecFilterLabel(value)
        if value == "ALL" then return L["FILTER_SPEC"] end
        if addonTable.GetSpecNameFromID then
            return addonTable.GetSpecNameFromID(value) or L["FILTER_SPEC"]
        end
        return tostring(value or L["FILTER_SPEC"])
    end

    local specFilterText = btnSpecFilter:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    specFilterText:SetPoint("LEFT", btnSpecFilter, "LEFT", 8, 0)
    specFilterText:SetPoint("RIGHT", btnSpecFilter, "RIGHT", -15, 0)
    specFilterText:SetJustifyH("LEFT")
    specFilterText:SetText(GetSpecFilterLabel(currentSpecFilter))

    local specArrow = btnSpecFilter:CreateTexture(nil, "ARTWORK")
    specArrow:SetSize(8, 8)
    specArrow:SetPoint("RIGHT", btnSpecFilter, "RIGHT", -5, 0)
    specArrow:SetTexture(TEX_ARROW)
    do
        local pr, pg, pb = GetPrimaryColor()
        specArrow:SetVertexColor(pr, pg, pb, 1)
    end

    specMenuFrame = CreateFrame("Frame", "LootHunterSpecMenuFrame", UIParent, "BackdropTemplate")
    specMenuFrame:SetWidth(110)
    specMenuFrame:SetPoint("TOPLEFT", btnSpecFilter, "BOTTOMLEFT", 0, -2)
    specMenuFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    specMenuFrame:SetBackdropColor(0.12, 0.12, 0.12, 0.95)
    specMenuFrame:SetBackdropBorderColor(0, 0, 0, 1)
    specMenuFrame:Hide()
    ElevateDropdown(specMenuFrame, btnSpecFilter)

    local function CreateSpecMenuButton(parent, text, value, yPos)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(100, 20)
        btn:SetPoint("TOPLEFT", 5, yPos)
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", btn, "LEFT", 5, 0)
        fs:SetText(text)
        fs:SetJustifyH("LEFT")
        ApplyAccentFont(fs)
        do
            local pr, pg, pb = GetPrimaryColor()
            fs:SetTextColor(currentSpecFilter == value and pr or 0.7, currentSpecFilter == value and pg or 0.7, currentSpecFilter == value and pb or 0.7)
        end
        btn:SetScript("OnEnter", function() fs:SetTextColor(1, 1, 1) end)
        btn:SetScript("OnLeave", function()
            local pr, pg, pb = GetPrimaryColor()
            fs:SetTextColor(currentSpecFilter == value and pr or 0.7, currentSpecFilter == value and pg or 0.7, currentSpecFilter == value and pb or 0.7)
        end)
        btn:SetScript("OnClick", function()
            currentSpecFilter = value
            specFilterText:SetText(GetSpecFilterLabel(value))
            LootHunter_RefreshUI()
            parent:Hide()
        end)
        return btn
    end

    btnSpecFilter:SetScript("OnClick", function(self)
        CloseAllDropdowns()
        if specMenuFrame:IsShown() then specMenuFrame:Hide() return end
        local kids = { specMenuFrame:GetChildren() }
        for _, child in ipairs(kids) do child:Hide(); child:SetParent(nil) end
        local yPos = -5
        CreateSpecMenuButton(specMenuFrame, L["FILTER_ALL"], "ALL", yPos)
        yPos = yPos - 20
        local specs = (addonTable.GetAvailableSpecsWithIDs and addonTable.GetAvailableSpecsWithIDs()) or (addonTable.GetAvailableSpecs and addonTable.GetAvailableSpecs()) or {}
        local hasCurrent = currentSpecFilter == "ALL"
        if #specs == 0 then
            specMenuFrame:Hide()
            return
        end
        for _, specEntry in ipairs(specs) do
            local specName = specEntry.name or specEntry
            local specID = specEntry.id or (addonTable.GetSpecIDFromName and addonTable.GetSpecIDFromName(specName)) or specName
            CreateSpecMenuButton(specMenuFrame, specName, specID, yPos)
            yPos = yPos - 20
            if specID == currentSpecFilter then hasCurrent = true end
        end
        if not hasCurrent then
            currentSpecFilter = "ALL"
            specFilterText:SetText(L["FILTER_SPEC"])
        end
        specMenuFrame:SetHeight(math.abs(yPos) + 5)
        specMenuFrame:Show()
    end)

    local resetFilters = CreateFrame("Button", nil, topPanel)
    resetFilters:SetSize(80, 18)
    resetFilters:SetPoint("LEFT", btnSpecFilter, "RIGHT", 8, 0)
    resetFilters:EnableMouse(true)
    resetFilters:SetFrameLevel(topPanel:GetFrameLevel() + 5)
    resetFilters:SetHitRectInsets(-4, -4, -4, -4)
    local resetText = resetFilters:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resetText:SetPoint("LEFT", resetFilters, "LEFT", 0, 0)
    resetText:SetPoint("RIGHT", resetFilters, "RIGHT", 0, 0)
    resetText:SetJustifyH("LEFT")
    resetText:SetText(L["FILTER_RESET"] or "Resetear")
    do
        local pr, pg, pb = GetPrimaryColor()
        resetText:SetTextColor(pr, pg, pb, 1)
    end
    resetFilters:SetScript("OnEnter", function()
        local pr, pg, pb = GetPrimaryColor()
        resetText:SetTextColor(pr, pg, pb, 1)
    end)
    resetFilters:SetScript("OnLeave", function()
        local pr, pg, pb = GetPrimaryColor()
        resetText:SetTextColor(pr, pg, pb, 1)
    end)
    resetFilters:SetScript("OnClick", function()
        currentTypeFilter = "ALL"
        currentSourceFilter = "ALL"
        currentSpecFilter = "ALL"
        typeFilterText:SetText(GetTypeFilterLabel(currentTypeFilter))
        sourceFilterText:SetText(L["FILTER_SOURCE"])
        specFilterText:SetText(L["FILTER_SPEC"])
        LootHunter_RefreshUI()
    end)

    -- Botón Borrar Lista
    local btnClear = CreateFrame("Button", nil, topPanel, "BackdropTemplate")
    btnClear:SetSize(24, 24)
    btnClear:SetPoint("RIGHT", topPanel, "RIGHT", -10, 0)
    btnClear:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    btnClear:SetBackdropColor(0.4, 0.2, 0.2, 0.4)
    btnClear:SetBackdropBorderColor(0.4, 0.2, 0.2, 0.7)

    local clearIcon = btnClear:CreateTexture(nil, "ARTWORK")
    clearIcon:SetSize(16, 16)
    clearIcon:SetPoint("CENTER")
    clearIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")

    btnClear:SetScript("OnClick", function()
        if StaticPopupDialogs and StaticPopupDialogs["LOOTHUNTER_CONFIRM_CLEAR"] then
            StaticPopupDialogs["LOOTHUNTER_CONFIRM_CLEAR"].text = L["CONFIRM_CLEAR_TEXT"]
        end
        StaticPopup_Show("LOOTHUNTER_CONFIRM_CLEAR")
    end)
    btnClear:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText(L["BTN_CLEAR_TOOLTIP"], nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    btnClear:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Elementos de Lista Vacía
    emptyContainer = CreateFrame("Frame", nil, panelList)
    emptyContainer:SetSize(300, 220)
    emptyContainer:SetPoint("CENTER", panelList, "CENTER", 0, 0)

    logoIcon = emptyContainer:CreateTexture(nil, "ARTWORK")
    logoIcon:SetSize(284, 80)
    logoIcon:SetPoint("TOP", emptyContainer, "TOP", 0, -5)
    logoIcon:SetTexture(ADDON_FOLDER .. "Textures\\logo.tga")
    logoIcon:SetAlpha(0.95)
    logoAnim = logoIcon:CreateAnimationGroup()
    logoAnim:SetLooping("REPEAT")
    local logoFadeIn = logoAnim:CreateAnimation("Alpha")
    logoFadeIn:SetFromAlpha(0.92)
    logoFadeIn:SetToAlpha(1)
    logoFadeIn:SetDuration(1.8)
    logoFadeIn:SetSmoothing("IN_OUT")
    logoFadeIn:SetOrder(1)
    local logoFadeOut = logoAnim:CreateAnimation("Alpha")
    logoFadeOut:SetFromAlpha(1)
    logoFadeOut:SetToAlpha(0.92)
    logoFadeOut:SetDuration(1.8)
    logoFadeOut:SetSmoothing("IN_OUT")
    logoFadeOut:SetOrder(2)

    ghostIcon = emptyContainer:CreateTexture(nil, "ARTWORK")
    ghostIcon:SetSize(100, 100)
    ghostIcon:SetPoint("TOP", emptyContainer, "TOP", 0, -5)
    ghostIcon:SetTexture(ADDON_FOLDER .. "Textures\\ghost1.tga")
    ghostIcon:SetAlpha(0.35)
    ghostAnim = ghostIcon:CreateAnimationGroup()
    ghostAnim:SetLooping("REPEAT")
    local ghostFadeIn = ghostAnim:CreateAnimation("Alpha")
    ghostFadeIn:SetFromAlpha(0.25)
    ghostFadeIn:SetToAlpha(0.4)
    ghostFadeIn:SetDuration(1.2)
    ghostFadeIn:SetSmoothing("IN_OUT")
    ghostFadeIn:SetOrder(1)
    local ghostFadeOut = ghostAnim:CreateAnimation("Alpha")
    ghostFadeOut:SetFromAlpha(0.4)
    ghostFadeOut:SetToAlpha(0.25)
    ghostFadeOut:SetDuration(1.2)
    ghostFadeOut:SetSmoothing("IN_OUT")
    ghostFadeOut:SetOrder(2)
    local ghostMoveUp = ghostAnim:CreateAnimation("Translation")
    ghostMoveUp:SetOffset(0, 10)
    ghostMoveUp:SetDuration(1.2)
    ghostMoveUp:SetSmoothing("IN_OUT")
    ghostMoveUp:SetOrder(1)
    local ghostMoveDown = ghostAnim:CreateAnimation("Translation")
    ghostMoveDown:SetOffset(0, -10)
    ghostMoveDown:SetDuration(1.2)
    ghostMoveDown:SetSmoothing("IN_OUT")
    ghostMoveDown:SetOrder(2)
    emptyContainer:HookScript("OnShow", function()
        if logoAnim:IsPlaying() then
            logoAnim:Stop()
        end
        if ghostAnim:IsPlaying() then
            ghostAnim:Stop()
        end
        logoAnim:Play()
    end)
    emptyContainer:HookScript("OnHide", function()
        if logoAnim:IsPlaying() then
            logoAnim:Stop()
        end
        if ghostAnim:IsPlaying() then
            ghostAnim:Stop()
        end
    logoIcon:SetAlpha(0.95)
        ghostIcon:SetAlpha(0.35)
    end)

    emptyHeader = emptyContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    emptyHeader:SetPoint("TOP", ghostIcon, "BOTTOM", 0, -10)
    emptyHeader:SetText(L["EMPTY_TITLE"])
    ApplyAccentFont(emptyHeader)
    AdjustFontSize(emptyHeader, 4)

    emptyQuote = emptyContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyQuote:SetPoint("TOP", emptyHeader, "BOTTOM", 0, -2)
    emptyQuote:SetPoint("LEFT", emptyContainer, "LEFT", 4, 0)
    emptyQuote:SetPoint("RIGHT", emptyContainer, "RIGHT", -4, 0)
    emptyQuote:SetJustifyH("CENTER")
    if emptyQuote.SetSpacing then
        emptyQuote:SetSpacing(2)
    end
    local baseFont, baseSize, baseFlags = emptyQuote:GetFont()
    emptyQuote.baseFont = baseFont
    emptyQuote.baseSize = baseSize
    emptyQuote.baseFlags = baseFlags
    if baseFont and baseSize then
        emptyQuote.smallFontSize = math.max(8, baseSize)
    end
    
    -- Seleccionar cita aleatoria
    local defaultQuote = GetEmptyQuoteText()
    emptyQuote:SetText(defaultQuote)
    emptyQuote.selectedText = defaultQuote
    local function ApplyQuoteFont(useDefaultFont)
        local size = emptyQuote.smallFontSize or emptyQuote.baseSize or 12
        local font = useDefaultFont and emptyQuote.baseFont or ACCENT_FONT
        emptyQuote:SetFont(font or ACCENT_FONT, size, emptyQuote.baseFlags)
    end
    ApplyQuoteFont(false)
    emptyQuote:HookScript("OnShow", function()
        ApplyQuoteFont(false)
    end)

    emptyInstruction = emptyContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyInstruction:SetPoint("TOP", emptyQuote, "BOTTOM", 0, -25)
    -- Dar un poco más de ancho al texto para que envuelva menos temprano
    emptyInstruction:SetPoint("LEFT", emptyContainer, "LEFT", -20, 0)
    emptyInstruction:SetPoint("RIGHT", emptyContainer, "RIGHT", 20, 0)
    emptyInstruction:SetJustifyH("CENTER")
    if emptyInstruction.SetSpacing then
        emptyInstruction:SetSpacing(3)
    end
    emptyInstruction:SetText(L["EMPTY_CTA_INSTRUCTION"])
    ApplyAccentFont(emptyInstruction)
    AdjustFontSize(emptyInstruction, -1)


    emptyJournalButton = CreateFrame("Button", nil, emptyContainer, "BackdropTemplate")
    emptyJournalButton:SetPoint("TOP", emptyInstruction, "BOTTOM", 0, -20)
    emptyJournalButton:SetSize(190, 28)
    emptyJournalButton:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    emptyJournalButton:SetBackdropColor(0.545, 0.031, 0.031, 1) -- #8b0808
    emptyJournalButton:SetBackdropBorderColor(0, 0, 0, 1)

    local emptyJournalLabel = emptyJournalButton:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyJournalLabel:SetPoint("CENTER")
    emptyJournalLabel:SetText(L["EMPTY_OPEN_JOURNAL"])
    ApplyAccentFont(emptyJournalLabel)

    emptyJournalButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.72, 0.043, 0.043, 1)
    end)
    emptyJournalButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.545, 0.031, 0.031, 1)
    end)
    emptyJournalButton:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        if not IsAddOnLoaded("Blizzard_EncounterJournal") and EncounterJournal_LoadUI then
            EncounterJournal_LoadUI()
        end
        if ToggleEncounterJournal then
            ToggleEncounterJournal()
        end
    end)

    local emptyHelpButton = CreateFrame("Button", nil, emptyContainer)
    emptyHelpButton:SetPoint("TOP", emptyJournalButton, "BOTTOM", 0, -10)
    emptyHelpButton:SetSize(260, 18)
    local emptyHelpLabel = emptyHelpButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyHelpLabel:SetPoint("CENTER")
    emptyHelpLabel:SetText(L["EMPTY_HELP_HINT"] or "Need help? Open the user guide.")
    emptyHelpLabel:SetTextColor(0.41, 0.78, 1, 1)
    emptyHelpButton:SetScript("OnEnter", function()
        emptyHelpLabel:SetTextColor(0.78, 0.92, 1, 1)
    end)
    emptyHelpButton:SetScript("OnLeave", function()
        emptyHelpLabel:SetTextColor(0.41, 0.78, 1, 1)
    end)

    listScrollFrame = CreateFrame("ScrollFrame", nil, panelList, "UIPanelScrollFrameTemplate")
    listScrollFrame:SetPoint("TOPLEFT", panelList, "TOPLEFT", 10, -50)
    listScrollFrame:SetPoint("BOTTOMRIGHT", panelList, "BOTTOMRIGHT", -30, 5)

    scrollChild = CreateFrame("Frame", nil, listScrollFrame)
    scrollChild:SetSize(290, 1)
    listScrollFrame:SetScrollChild(scrollChild)
    
    listScrollFrame:SetScript("OnSizeChanged", function(self, w, h)
        scrollChild:SetWidth(w)
    end)

    -- PANEL DE AYUDA
    panelHelp = CreateFrame("Frame", nil, mainFrame)
    panelHelp:SetPoint("TOPLEFT", 0, -25)
    panelHelp:SetPoint("BOTTOMRIGHT", 0, 0)
    panelHelp:Hide()

    -- === SIDEBAR (Izquierda) ===
    local sidebar = CreateFrame("Frame", nil, panelHelp, "BackdropTemplate")
    sidebar:SetWidth(130)
    sidebar:SetPoint("TOPLEFT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", 0, 0)
    sidebar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    sidebar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    local sidebarLeftBorder = sidebar:CreateTexture(nil, "BORDER")
    sidebarLeftBorder:SetColorTexture(0, 0, 0, 1)
    sidebarLeftBorder:SetWidth(1)
    sidebarLeftBorder:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, 0)
    sidebarLeftBorder:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 0, 0)
    local sidebarRightBorder = sidebar:CreateTexture(nil, "BORDER")
    sidebarRightBorder:SetColorTexture(0, 0, 0, 1)
    sidebarRightBorder:SetWidth(1)
    sidebarRightBorder:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, 0)
    sidebarRightBorder:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, 0)

    -- === CONTENIDO (Derecha) ===
    local content = CreateFrame("Frame", nil, panelHelp)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, -10)
    content:SetPoint("BOTTOMRIGHT", -10, 10)

    -- Vistas
    local viewGuide = CreateFrame("Frame", nil, content); viewGuide:SetAllPoints()
    local viewTips = CreateFrame("Frame", nil, content); viewTips:SetAllPoints(); viewTips:Hide()
    local viewStatus = CreateFrame("Frame", nil, content); viewStatus:SetAllPoints(); viewStatus:Hide()
    local viewBugs = CreateFrame("Frame", nil, content); viewBugs:SetAllPoints(); viewBugs:Hide()
    local viewCredits = CreateFrame("Frame", nil, content); viewCredits:SetAllPoints(); viewCredits:Hide()
    local statusScroll = CreateFrame("ScrollFrame", nil, viewStatus, "UIPanelScrollFrameTemplate")
    statusScroll:SetPoint("TOPLEFT", viewStatus, "TOPLEFT", 0, -5)
    statusScroll:SetPoint("BOTTOMRIGHT", viewStatus, "BOTTOMRIGHT", 0, 5)
    if statusScroll.ScrollBar then
        statusScroll.ScrollBar:Hide()
        statusScroll.ScrollBar.Show = function() end
    end
    local statusScrollChild = CreateFrame("Frame", nil, statusScroll)
    statusScrollChild:SetSize(1, 1)
    statusScroll:SetScrollChild(statusScrollChild)
    statusScroll:SetScript("OnSizeChanged", function(self, w)
        statusScrollChild:SetWidth(w)
    end)
    statusScroll:SetScript("OnMouseWheel", function(self, delta)
        local height = self:GetVerticalScrollRange()
        local step = 20
        local newValue = math.max(0, math.min(self:GetVerticalScroll() - (delta * step), height))
        self:SetVerticalScroll(newValue)
    end)
    statusScrollChild:SetHeight(600)

    local creditsScroll = CreateFrame("ScrollFrame", nil, viewCredits, "UIPanelScrollFrameTemplate")
    creditsScroll:SetPoint("TOPLEFT", viewCredits, "TOPLEFT", 0, -5)
    creditsScroll:SetPoint("BOTTOMRIGHT", viewCredits, "BOTTOMRIGHT", 0, 5)
    if creditsScroll.ScrollBar then
        creditsScroll.ScrollBar:ClearAllPoints()
        creditsScroll.ScrollBar:SetPoint("TOPRIGHT", creditsScroll, "TOPRIGHT", -2, -16)
        creditsScroll.ScrollBar:SetPoint("BOTTOMRIGHT", creditsScroll, "BOTTOMRIGHT", -2, 16)
        creditsScroll.ScrollBar:Show()
    end
    local creditsScrollChild = CreateFrame("Frame", nil, creditsScroll)
    creditsScrollChild:SetSize(1, 1)
    creditsScroll:SetScrollChild(creditsScrollChild)
    creditsScroll:SetScript("OnSizeChanged", function(self, w)
        local width = w
        if creditsScroll.ScrollBar and creditsScroll.ScrollBar:IsShown() then
            width = math.max(1, w - 20)
        end
        creditsScrollChild:SetWidth(width)
    end)
    creditsScroll:SetScript("OnMouseWheel", function(self, delta)
        local height = self:GetVerticalScrollRange()
        local step = 20
        local newValue = math.max(0, math.min(self:GetVerticalScroll() - (delta * step), height))
        self:SetVerticalScroll(newValue)
    end)
    creditsScrollChild:SetHeight(1)

    local function SelectHelpView(view)
        viewGuide:Hide(); viewTips:Hide(); viewStatus:Hide(); viewBugs:Hide(); viewCredits:Hide()
        view:Show()
    end

    -- Botones de la barra lateral
    local sidebarButtons = {}
    local function CreateSidebarBtn(text, yOffset, view, onSelect)
        local btn = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
        btn:SetSize(120, 22)
        btn:SetPoint("TOP", sidebar, "TOP", 0, yOffset)
        btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        btn:SetBackdropColor(0.2, 0.2, 0.2, 1)
        btn:SetBackdropBorderColor(0, 0, 0, 1)
        btn:SetNormalFontObject("GameFontHighlightSmall")
        btn:SetText(text)
        
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.1)

        btn:SetScript("OnClick", function(self)
            SelectHelpView(view)
            for _, b in ipairs(sidebarButtons) do
                b:SetBackdropColor(0.2, 0.2, 0.2, 1)
                b:SetBackdropBorderColor(0, 0, 0, 1)
            end
            self:SetBackdropColor(0.3, 0.3, 0.3, 1)
            do
                local pr, pg, pb = GetPrimaryColor()
                self:SetBackdropBorderColor(pr, pg, pb, 1) -- Borde dorado para activo
            end
            if onSelect then
                onSelect()
            end
        end)
        table.insert(sidebarButtons, btn)
        return btn
    end

    local function PlayPeonQuote()
        if PlaySoundFile then
            PlaySoundFile("Sound\\Creature\\Peon\\PeonPissed1.ogg", "Master")
        end
    end

    local btnGuide = CreateSidebarBtn(L["SIDEBAR_GUIDE"], -10, viewGuide)
    do
        local pr, pg, pb = GetPrimaryColor()
        btnGuide:SetBackdropColor(0.3, 0.3, 0.3, 1); btnGuide:SetBackdropBorderColor(pr, pg, pb, 1) -- Activo por defecto
    end
    CreateSidebarBtn(L["SIDEBAR_TIPS"], -35, viewTips)
    CreateSidebarBtn(L["SIDEBAR_STATUS"], -60, viewStatus)
    CreateSidebarBtn(L["SIDEBAR_BUGS"], -85, viewBugs)
    CreateSidebarBtn(L["SIDEBAR_CREDITS"], -110, viewCredits)

    -- 1. VISTA GUÍA
    local guideArt = viewGuide:CreateTexture(nil, "ARTWORK")
    guideArt:SetSize(165, 168)
    guideArt:SetPoint("TOPLEFT", viewGuide, "TOPLEFT", 0, 0)
    guideArt:SetPoint("TOP", viewGuide, "TOP", 0, 0)
    guideArt:SetTexture(ADDON_FOLDER .. "Textures\\succubo_read.tga")

    local introGuideTitle = CreateHelpText(viewGuide, L["HELP_GUIDE_INTRO_TITLE"], guideArt, -10, true)
    local fontName, fontSize, fontFlags = introGuideTitle:GetFont()
    if fontName then
        introGuideTitle:SetFont(fontName, math.max(18, fontSize or 18), fontFlags)
    end
    local introGuideDesc = CreateHelpText(viewGuide, L["HELP_GUIDE_INTRO_DESC"], introGuideTitle, -5, false)
    local methodFont, methodSize, methodFlags
    local subtitleFontSize = 14
    local function ApplySubtitleStyle(fs)
        if not fs or not methodFont then return end
        fs:SetFont(methodFont, subtitleFontSize, methodFlags)
    end
    local hm1 = CreateHelpText(viewGuide, L["HELP_METHOD_1_TITLE"], introGuideDesc, -15, true)
    methodFont, methodSize, methodFlags = hm1:GetFont()
    subtitleFontSize = math.max(14, (methodSize or 16) - 2)
    if methodFont then
        hm1:SetFont(methodFont, subtitleFontSize, methodFlags)
    end
    ApplySubtitleStyle(hm1)
    do
        local pr, pg, pb = GetPrimaryColor()
        hm1:SetTextColor(pr + (1 - pr) * 0.5, pg + (1 - pg) * 0.5, pb + (1 - pb) * 0.5)
    end
    local tm1 = CreateHelpText(viewGuide, L["HELP_METHOD_1_DESC"], hm1, -5, false)
    local function ColorGuideShortcuts(fs)
        if not fs then return end
        local text = fs:GetText()
        if not text then return end
        local pr, pg, pb = GetPrimaryColor()
        local function clamp(v) return math.max(0, math.min(255, math.floor((v or 0) * 255))) end
        local colorCode = string.format("|cff%02x%02x%02x", clamp(pr), clamp(pg), clamp(pb))
        local resetCode = "|r"
        local function wrapShortcut(pattern)
            text = text:gsub(pattern, function(match)
                return colorCode .. match .. resetCode
            end)
        end
        wrapShortcut("Shift%+J")
        wrapShortcut("Shift%+Click")
        fs:SetText(text)
    end
    ColorGuideShortcuts(tm1)
    local btnGuideJournal = CreateFrame("Button", nil, viewGuide, "BackdropTemplate")
    btnGuideJournal:SetSize(160, 25)
    btnGuideJournal:SetPoint("TOPLEFT", tm1, "BOTTOMLEFT", 0, -10)
    btnGuideJournal:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    btnGuideJournal:SetBackdropColor(0.2, 0.2, 0.2, 1)
    btnGuideJournal:SetBackdropBorderColor(0, 0, 0, 1)
    btnGuideJournal:SetNormalFontObject("GameFontHighlightSmall")
    btnGuideJournal:SetText(L["GUIDE_OPEN_JOURNAL"])
    local hlGuideJournal = btnGuideJournal:CreateTexture(nil, "HIGHLIGHT")
    hlGuideJournal:SetAllPoints()
    hlGuideJournal:SetColorTexture(1, 1, 1, 0.1)
    btnGuideJournal:SetScript("OnClick", function()
        if addonTable.SelectTab then addonTable.SelectTab(1) end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        if not IsAddOnLoaded("Blizzard_EncounterJournal") and EncounterJournal_LoadUI then
            EncounterJournal_LoadUI()
        end
        if ToggleEncounterJournal then
            ToggleEncounterJournal()
        end
    end)
     
    local watchNote = CreateHelpText(viewGuide, L["HELP_GUIDE_WATCH"], btnGuideJournal, -15, false)
    do
        local pr, pg, pb = GetPrimaryColor()
        watchNote:SetTextColor(pr + (1 - pr) * 0.8, pg + (1 - pg) * 0.8, pb + (1 - pb) * 0.8)
    end

    -- 2. VISTA TIPS
    local ht1 = CreateHelpText(viewTips, L["HELP_TIPS_TITLE"], nil, -4, true)
    ApplySubtitleStyle(ht1)
    local introTips = CreateHelpText(viewTips, L["HELP_TIPS_INTRO"], ht1, -10, false)
    introTips:ClearAllPoints()
    introTips:SetPoint("TOPLEFT", ht1, "BOTTOMLEFT", 0, -10)
    introTips:SetPoint("RIGHT", viewTips, "RIGHT", -10, 0)
    local function CreateTipsList(parent, text, anchor)
        if type(text) ~= "string" then return end
        local parts = {}
        local startPos = 1
        while true do
            local s, e = text:find("\n\n", startPos, true)
            if not s then
                table.insert(parts, text:sub(startPos))
                break
            end
            table.insert(parts, text:sub(startPos, s - 1))
            startPos = e + 1
        end
        local yOffset = -5
        if anchor and anchor.GetBottom then
            local top = parent:GetTop()
            local bottom = anchor:GetBottom()
            if top and bottom then
                yOffset = bottom - top - 14
            end
        end
        for _, chunk in ipairs(parts) do
            local clean = chunk:gsub("^|T.-|t%s*", "")
            clean = clean:gsub("^%s+", ""):gsub("%s+$", "")
            if clean ~= "" then
                local icon = parent:CreateTexture(nil, "ARTWORK")
                icon:SetSize(12, 12)
                icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_3")
                icon:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)

                local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, yOffset)
                fs:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
                fs:SetJustifyH("LEFT")
                fs:SetWordWrap(true)
                if fs.SetSpacing then
                    fs:SetSpacing(2)
                end
                fs:SetText(clean)
                fs:SetTextColor(0.82, 0.82, 0.82)
                local height = fs:GetStringHeight() or 12
                yOffset = yOffset - height - 8
            end
        end
    end
    CreateTipsList(viewTips, L["HELP_TIPS_DESC"], introTips)

    -- 3. VISTA ESTADOS
    local h2 = CreateHelpText(statusScrollChild, L["HELP_STATUS_TITLE"], nil, 0, true)
    ApplySubtitleStyle(h2)
    local introStatus = CreateHelpText(statusScrollChild, L["HELP_STATUS_INTRO"], h2, -10, false)
    introStatus:ClearAllPoints()
    introStatus:SetPoint("TOPLEFT", h2, "BOTTOMLEFT", 0, -10)
    introStatus:SetPoint("RIGHT", statusScrollChild, "RIGHT", -10, 0)
    local t_prio = CreateHelpText(statusScrollChild, L["HELP_STATUS_PRIORITY"], introStatus, -14, false)
    local t2 = CreateHelpText(statusScrollChild, L["HELP_STATUS_NORMAL"], t_prio, -10, false)
    local t3 = CreateHelpText(statusScrollChild, L["HELP_STATUS_DROP"], t2, -10, false)
    local t4 = CreateHelpText(statusScrollChild, L["HELP_STATUS_WON"], t3, -10, false)
    local t5 = CreateHelpText(statusScrollChild, string.format(L["HELP_STATUS_EQUIPPED"], GetEquippedIconTag()), t4, -10, false)
    local function AlignStatusRow(fs, anchor, offsetY)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
        fs:SetPoint("RIGHT", statusScrollChild, "RIGHT", -10, 0)
        fs:SetJustifyH("LEFT")
    end
    AlignStatusRow(t_prio, introStatus, -14)
    AlignStatusRow(t2, t_prio, -10)
    AlignStatusRow(t3, t2, -10)
    AlignStatusRow(t4, t3, -10)
    AlignStatusRow(t5, t4, -10)
    t_prio:SetTextColor(0.82, 0.82, 0.82)
    t2:SetTextColor(0.82, 0.82, 0.82)
    t3:SetTextColor(0.82, 0.82, 0.82)
    t4:SetTextColor(0.82, 0.82, 0.82)
    t5:SetTextColor(0.82, 0.82, 0.82)
    local function RefreshStatusScrollHeight()
        if not statusScrollChild or not t5 then return end
        local top = statusScrollChild:GetTop()
        local bottom = t5:GetBottom()
        if top and bottom then
            statusScrollChild:SetHeight(math.max(1, top - bottom + 20))
        end
    end
    RefreshStatusScrollHeight()

    -- 4. VISTA REPORTE DE BUGS
    local BUG_REPORT_URL = "https://github.com/joxmiguel1/LootHunter/issues/new"
    local DISCORD_URL = "https://discord.gg/E3QMp6Eg"
    local bugsTitle = CreateHelpText(viewBugs, L["HELP_BUGS_TITLE"], nil, -4, true)
    ApplySubtitleStyle(bugsTitle)
    local bugsDesc = CreateHelpText(viewBugs, L["HELP_BUGS_DESC"], bugsTitle, -8, false)
    bugsDesc:SetPoint("RIGHT", viewBugs, "RIGHT", -10, 0)

    local function CreateCopyLinkBox(parent, text, anchor, yOffset)
        local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        box:SetAutoFocus(false)
        box:SetSize(300, 20)
        box:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 6, yOffset or -6)
        box:SetText(text or "")
        box:SetCursorPosition(0)
        box:SetTextInsets(6, 6, 0, 0)
        ApplyAccentFont(box)
        box:SetScript("OnEditFocusGained", function(self)
            self:HighlightText(0, -1)
        end)
        box:SetScript("OnMouseUp", function(self)
            self:HighlightText(0, -1)
        end)
        local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 6, -2)
        hint:SetText(L["HELP_BUGS_COPY_HINT"] or "CTRL + C")
        hint:SetTextColor(0.65, 0.65, 0.65)
        return box
    end

    local bugsLinkLabel = CreateHelpText(viewBugs, L["HELP_BUGS_LINK_LABEL"], bugsDesc, -12, false)
    local bugsTitleFont, bugsTitleSize, bugsTitleFlags = bugsTitle:GetFont()
    if bugsTitleFont and bugsTitleSize then
        bugsLinkLabel:SetFont(bugsTitleFont, math.max(12, bugsTitleSize - 4), bugsTitleFlags)
    end
    do
        local pr, pg, pb = GetPrimaryColor()
        bugsLinkLabel:SetTextColor(pr + (1 - pr) * 0.5, pg + (1 - pg) * 0.5, pb + (1 - pb) * 0.5)
    end
    local bugsLinkBox = CreateCopyLinkBox(viewBugs, BUG_REPORT_URL, bugsLinkLabel, -6)

    local discordDesc = CreateHelpText(viewBugs, L["HELP_BUGS_DISCORD_DESC"], bugsLinkBox, -22, false)
    discordDesc:ClearAllPoints()
    discordDesc:SetPoint("TOPLEFT", bugsLinkBox, "BOTTOMLEFT", -6, -14)
    discordDesc:SetPoint("RIGHT", viewBugs, "RIGHT", -10, 0)
    local discordLabel = CreateHelpText(viewBugs, L["HELP_BUGS_DISCORD_LABEL"], discordDesc, -12, false)
    if bugsTitleFont and bugsTitleSize then
        discordLabel:SetFont(bugsTitleFont, math.max(12, bugsTitleSize - 4), bugsTitleFlags)
    end
    do
        local pr, pg, pb = GetPrimaryColor()
        discordLabel:SetTextColor(pr + (1 - pr) * 0.5, pg + (1 - pg) * 0.5, pb + (1 - pb) * 0.5)
    end
    local discordBox = CreateCopyLinkBox(viewBugs, DISCORD_URL, discordLabel, -6)

    viewBugs:HookScript("OnShow", function()
        if bugsLinkBox then
            bugsLinkBox:ClearFocus()
        end
    end)
    viewBugs:HookScript("OnHide", function()
        if bugsLinkBox then bugsLinkBox:ClearFocus() end
    end)

    -- 5. VISTA CREDITOS
    local creditsTitle = CreateHelpText(creditsScrollChild, L["HELP_CREDITS_TITLE"], nil, -4, true)
    ApplySubtitleStyle(creditsTitle)
    local creditsArt = creditsScrollChild:CreateTexture(nil, "ARTWORK")
    creditsArt:SetSize(165, 168)
    creditsArt:SetPoint("TOP", creditsTitle, "BOTTOM", 0, -10)
    creditsArt:SetTexture(ADDON_FOLDER .. "Textures\\icon_credits.tga")
    do
        -- Keep the icon size fixed; use only a soft alpha pulse.
        local pulse = creditsArt:CreateAnimationGroup()
        pulse:SetLooping("REPEAT")
        local fadeIn = pulse:CreateAnimation("Alpha")
        fadeIn:SetOrder(1)
        fadeIn:SetDuration(1.4)
        fadeIn:SetFromAlpha(0.85)
        fadeIn:SetToAlpha(1)
        fadeIn:SetSmoothing("IN_OUT")
        local fadeOut = pulse:CreateAnimation("Alpha")
        fadeOut:SetOrder(2)
        fadeOut:SetDuration(1.4)
        fadeOut:SetFromAlpha(1)
        fadeOut:SetToAlpha(0.85)
        fadeOut:SetSmoothing("IN_OUT")
        pulse:Play()
    end

    local creditsBody = CreateHelpText(creditsScrollChild, L["CREDITS_DESC"], creditsArt, -10, false)
    creditsBody:SetJustifyH("CENTER")
    creditsBody:ClearAllPoints()
    creditsBody:SetPoint("TOP", creditsArt, "BOTTOM", 0, -10)
    creditsBody:SetWidth(460)

    local creditsContainer = CreateFrame("Frame", nil, creditsScrollChild)
    creditsContainer:SetSize(340, 150)
    creditsContainer:SetPoint("TOP", creditsBody, "BOTTOM", 0, -20)

    local guildTitle = creditsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    guildTitle:SetPoint("TOP", creditsContainer, "TOP", 0, 0)
    guildTitle:SetText(L["CREDITS_GUILD_TITLE"])
    ApplyAccentFont(guildTitle)
    guildTitle:SetTextColor(0.8, 0.9, 0.8)
    guildTitle:SetSpacing(2)

    local classColors = {
        SHAMAN   = { 0.0, 0.44, 0.87 },
        PRIEST   = { 1.0, 1.0, 1.0 },
        PALADIN  = { 0.96, 0.55, 0.73 },
        DEATHKNIGHT = { 0.77, 0.12, 0.23 },
        MONK     = { 0.0, 1.0, 0.59 },
        HUNTER   = { 0.67, 0.83, 0.45 },
        WARLOCK  = { 0.53, 0.53, 0.93 },
    }

    local creditsList = {
        { "Anoclos", "MONK", 28822 },     -- Pandaren death
        { "Arkaboy", "SHAMAN" },
        { "Eridion", "DEATHKNIGHT" },
        { "Keendaal", "PALADIN" },
        { "Kokushibo", "HUNTER", 3310 },  -- Troll death
        { "Motecuhzoma", "MONK" },
        { "Onykronos", "PRIEST" },
        { "Unholykratox", "DEATHKNIGHT" },
        { "Yendyuwu", "PRIEST" },
        { "Zahaya", "SHAMAN" },
    }

    local columns = 2
    local rowsPerCol = math.ceil(#creditsList / columns)
    local colWidth = 150
    local function PlayRaceDeath(soundRef)
        if not soundRef then return end
        local soundID = soundRef
        if type(soundRef) == "string" then
            if soundRef == "PANDAREN" then
                soundID = (SOUNDKIT and SOUNDKIT.RACE_PANDAREN_MALE_DEATH) or nil
            elseif soundRef == "TROLL" then
                soundID = (SOUNDKIT and SOUNDKIT.RACE_TROLL_MALE_DEATH) or nil
            else
                soundID = tonumber(soundRef)
            end
        end
        if soundID then PlaySound(soundID, "Master") end
    end

    for col = 1, columns do
        local colFrame = CreateFrame("Frame", nil, creditsContainer)
        local xOffset = (col == 1) and -80 or 80
        colFrame:SetPoint("TOP", creditsContainer, "TOP", xOffset, -36)
        colFrame:SetSize(colWidth, 130)
        for i = 1, rowsPerCol do
            local index = (col - 1) * rowsPerCol + i
            local entry = creditsList[index]
            if entry then
                local name, classTag, raceSound = entry[1], entry[2], entry[3]
                local btn = CreateFrame("Button", nil, colFrame)
                btn:SetSize(colWidth, 18)
                btn:SetPoint("TOP", colFrame, "TOP", 0, -(i - 1) * 18)
                local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                fs:SetPoint("CENTER")
                fs:SetJustifyH("CENTER")
                fs:SetText(name)
                ApplyAccentFont(fs)
                local clr = classColors[classTag] or { 0.9, 0.9, 0.9 }
                fs:SetTextColor(clr[1], clr[2], clr[3])
                if name == "Arkaboy" then
                    fs:SetTextColor(0.0, 0.44, 0.87) -- ensure shaman blue
                end
                btn:SetScript("OnClick", function()
                    PlayRaceDeath(raceSound)
                end)
            end
        end
    end

    local farewellBtn = CreateFrame("Button", nil, creditsScrollChild)
    farewellBtn:SetPoint("TOP", creditsContainer, "BOTTOM", 0, 2)
    farewellBtn:SetWidth(320)
    local farewell = CreateHelpText(farewellBtn, L["CREDITS_FAREWELL"], nil, 0, true)
    farewell:SetJustifyH("CENTER")
    farewell:SetTextColor(1, 1, 1)
    farewell:ClearAllPoints()
    farewell:SetPoint("CENTER", farewellBtn, "CENTER", 0, 0)
    farewell:SetWidth(320)
    do
        local ffont, fsize, fflags = farewell:GetFont()
        if ffont and fsize then
            farewell:SetFont(ffont, math.max(10, fsize - 4), fflags)
        end
    end
    farewellBtn:SetHeight((farewell:GetStringHeight() or 14) + 6)
    farewellBtn:SetScript("OnClick", function()
        PlaySound(9100, "Master")
    end)

    local function RefreshCreditsHeight()
        if not creditsScroll or not creditsScrollChild then return end
        local top = creditsTitle:GetTop() or 0
        local bottom = (farewellBtn and farewellBtn:GetBottom()) or (farewell and farewell:GetBottom()) or 0
        local totalHeight = (top - bottom) + 20
        local minHeight = creditsScroll:GetHeight() or 0
        creditsScrollChild:SetHeight(math.max(totalHeight, minHeight))
    end

    creditsScroll:SetScript("OnSizeChanged", function(self, w)
        creditsScrollChild:SetWidth(w)
        RefreshCreditsHeight()
    end)
    viewCredits:SetScript("OnShow", RefreshCreditsHeight)
    C_Timer.After(0, RefreshCreditsHeight)

    -- Créditos (En el sidebar abajo)
    local creditsBtn = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
    creditsBtn:SetSize(110, 32)
    creditsBtn:SetPoint("BOTTOM", sidebar, "BOTTOM", 0, 10)
    creditsBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
    creditsBtn:SetBackdropColor(0,0,0,0)
    creditsBtn:SetBackdropBorderColor(0,0,0,0)
    creditsBtn:EnableMouse(true)
    creditsBtn:SetFrameLevel(sidebar:GetFrameLevel() + 2)

    creditsBtn:SetNormalFontObject("GameFontHighlightSmall")
    creditsBtn:SetText(L["CREDITS"])
    local fs = creditsBtn:GetFontString()
    if fs then
        fs:SetTextColor(0.53, 0.53, 0.93) -- Warlock purple
    end
    -- Eliminar feedback visual al click
    creditsBtn:SetPushedTextOffset(0, 0)

    creditsBtn:SetScript("OnClick", function()
    end)
    creditsBtn:Hide()

    -- PANEL CONFIG
    panelConfig = CreateFrame("Frame", nil, mainFrame)
    panelConfig:SetPoint("TOPLEFT", 0, -25)
    panelConfig:SetPoint("BOTTOMRIGHT", 0, 0)
    panelConfig:Hide()

    -- PANEL LOG
    local debugMode = IsDebugLoggingEnabled()
    panelLog = CreateFrame("Frame", nil, mainFrame)
    panelLog:SetPoint("TOPLEFT", 0, -25)
    panelLog:SetPoint("BOTTOMRIGHT", 0, 30)
    panelLog:Hide()

    local btnCopyLog = CreateFrame("Button", nil, panelLog, "BackdropTemplate")
    btnCopyLog:SetSize(70, 20)
    btnCopyLog:SetPoint("TOPRIGHT", panelLog, "TOPRIGHT", -5, -5)
    btnCopyLog:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    btnCopyLog:SetBackdropColor(0.2, 0.4, 0.2, 1)
    btnCopyLog:SetBackdropBorderColor(0, 0, 0, 1)
    btnCopyLog:SetNormalFontObject("GameFontHighlightSmall")
    btnCopyLog:SetText(L["BTN_EXPORT_LOG"])
    btnCopyLog:SetScript("OnClick", CreateCopyLogWindow)
    btnCopyLog:SetShown(debugMode)

    local logScrollFrame = CreateFrame("ScrollFrame", nil, panelLog, "UIPanelScrollFrameTemplate")
    logScrollFrame:SetPoint("TOPLEFT", 5, -30)
    logScrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)
    local logScrollChild = CreateFrame("Frame", nil, logScrollFrame)
    logScrollChild:SetSize(280, 1)
    logScrollFrame:SetScrollChild(logScrollChild)

    addonTable.RefreshLogPanel = function()
        if logScrollChild then logScrollChild:Hide(); logScrollChild:SetParent(nil) end
        logScrollChild = CreateFrame("Frame", nil, logScrollFrame)
        logScrollChild:SetSize(280, 1)
        logScrollFrame:SetScrollChild(logScrollChild)
        local DebugLog = addonTable.DebugLog or {}
        if #DebugLog == 0 then
            local devNotice = logScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            devNotice:SetPoint("TOPLEFT", logScrollChild, "TOPLEFT", 5, 0)
            devNotice:SetWidth(260)
            devNotice:SetJustifyH("LEFT")
            devNotice:SetWordWrap(true)
            devNotice:SetText(L["LOG_DEV_NOTICE"])
            devNotice:SetTextColor(1, 1, 1)
            local emptyLog = logScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            emptyLog:SetPoint("TOPLEFT", devNotice, "BOTTOMLEFT", 0, -6)
            emptyLog:SetText(L["LOG_EMPTY_PANEL"])
            logScrollChild:SetHeight((devNotice:GetStringHeight() or 0) + 30)
        else
            local yOffset = 0
            local startIdx = math.max(1, #DebugLog - 1000)
            for i = startIdx, #DebugLog do
                local line = logScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                line:SetPoint("TOPLEFT", logScrollChild, "TOPLEFT", 5, yOffset)
                line:SetWidth(260)
                line:SetJustifyH("LEFT")
                line:SetWordWrap(true)
                line:SetText(DebugLog[i])
                yOffset = yOffset - line:GetStringHeight() - 2
            end
            logScrollChild:SetHeight(math.abs(yOffset) + 10)
        end
    end

    local function SetTabStyle(btn)
        btn:SetNormalFontObject("GameFontNormalSmall")
        btn:SetHeight(28); btn:SetWidth(90)
        btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        btn:SetBackdropColor(0.2, 0.2, 0.2, 1)
        btn:SetBackdropBorderColor(0, 0, 0, 1)
        if btn.bg then btn.bg:Hide() end
        if btn.shadow then btn.shadow:Hide() end
        if not btn.topBorder then
            btn.topBorder = btn:CreateTexture(nil, "OVERLAY")
            btn.topBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
            btn.topBorder:SetPoint("TOPLEFT", 0, 0)
            btn.topBorder:SetPoint("TOPRIGHT", 0, 0)
            btn.topBorder:SetHeight(2)
            btn.topBorder:SetVertexColor(0, 0, 0, 1)
        end
    end
    local function BlendWithWhite(r, g, b, amount)
        local t = amount or 0.5
        return r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t
    end
    local function BlendWithBlack(r, g, b, amount)
        local t = amount or 0.5
        return r * (1 - t), g * (1 - t), b * (1 - t)
    end

    local function SetTabState(tab, isActive)
        if not tab then return end
        if tab.bg then
            tab.bg:Show()
            tab.bg:SetAlpha(isActive and 1 or 0.5)
        end
        local fs = tab:GetFontString()
        if fs then
            if isActive then
                if tab._usePrimaryTextBlend then
                    local pr, pg, pb = GetPrimaryColor()
                    local textR, textG, textB = BlendWithWhite(pr, pg, pb, 0.2)
                    fs:SetTextColor(textR, textG, textB)
                    if fs.SetShadowColor and fs.SetShadowOffset then
                        fs:SetShadowColor(0, 0, 0, 0)
                        fs:SetShadowOffset(0, 0)
                    end
                    local fontPath, fontSize, _ = fs:GetFont()
                    if fontPath and fontSize then
                        fs:SetFont(fontPath, fontSize, "THICKOUTLINE")
                    end
                else
                    fs:SetTextColor(1, 1, 1)
                    if fs.SetShadowColor and fs.SetShadowOffset then
                        fs:SetShadowColor(0, 0, 0, 0)
                        fs:SetShadowOffset(0, 0)
                    end
                    local fontPath, fontSize, _ = fs:GetFont()
                    if fontPath and fontSize then
                        fs:SetFont(fontPath, fontSize, "")
                    end
                end
            else
                fs:SetTextColor(0.35, 0.35, 0.35)
                if fs.SetShadowColor and fs.SetShadowOffset then
                    fs:SetShadowColor(0, 0, 0, 0)
                    fs:SetShadowOffset(0, 0)
                end
                local fontPath, fontSize, _ = fs:GetFont()
                if fontPath and fontSize then
                    fs:SetFont(fontPath, fontSize, "")
                end
            end
        end
        if isActive then
            tab:SetBackdropColor(0, 0, 0, 0)
            tab:SetBackdropBorderColor(0, 0, 0, 1)
        else
            tab:SetBackdropColor(0.2, 0.2, 0.2, 1)
            tab:SetBackdropBorderColor(0, 0, 0, 0)
        end
        if tab.SetNormalTexture and tab:GetNormalTexture() then
            local inset = isActive and 0 or 1
            tab:GetNormalTexture():SetPoint("TOPLEFT", inset, -inset)
            tab:GetNormalTexture():SetPoint("BOTTOMRIGHT", -inset, inset)
        end
    end

    local tab1 = CreateFrame("Button", nil, mainFrame, "BackdropTemplate"); SetTabStyle(tab1); tab1:SetPoint("TOPLEFT", mainFrame, "BOTTOMLEFT", 10, 1); tab1:SetText(L["TAB_LIST"])
    tab1._usePrimaryTextBlend = true
    tab1:SetBackdropColor(0, 0, 0, 0)
    tab1.bg = tab1:CreateTexture(nil, "ARTWORK")
    tab1.bg:SetAllPoints()
    tab1.bg:SetTexture(ADDON_FOLDER .. "Textures\\backbutton.tga")
    tab1.bg:SetVertexColor(1, 1, 1, 1)
    local tab3 = CreateFrame("Button", nil, mainFrame, "BackdropTemplate"); SetTabStyle(tab3); tab3:SetPoint("LEFT", tab1, "RIGHT", 5, 0); tab3:SetText(L["TAB_LOG"])
    tab3:SetBackdropColor(0, 0, 0, 0)
    tab3.bg = tab3:CreateTexture(nil, "ARTWORK")
    tab3.bg:SetAllPoints()
    tab3.bg:SetTexture(ADDON_FOLDER .. "Textures\\backbutton.tga")
    tab3.bg:SetVertexColor(1, 1, 1, 1)
    tab1:SetFrameLevel(mainFrame:GetFrameLevel() + 6)
    tab3:SetFrameLevel(mainFrame:GetFrameLevel() + 6)
    tab3:SetShown(debugMode)
    tab3:SetEnabled(debugMode)

    local helpHolder = _G.LootHunterHelpHolder
    if not helpHolder then
        helpHolder = CreateFrame("Frame", "LootHunterHelpHolder", mainFrame, "BackdropTemplate")
        helpHolder:SetSize(44, 44)
        helpHolder:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        helpHolder:SetBackdropColor(0.12, 0.12, 0.12, 0.95)
        helpHolder:SetBackdropBorderColor(0, 0, 0, 1)
        helpHolder.leftBorderCover = helpHolder:CreateTexture(nil, "OVERLAY")
        helpHolder.leftBorderCover:SetPoint("TOPLEFT", 0, 0)
        helpHolder.leftBorderCover:SetPoint("BOTTOMLEFT", 0, 0)
        helpHolder.leftBorderCover:SetWidth(1)
        helpHolder.leftBorderCover:SetColorTexture(0.12, 0.12, 0.12, 0.95)
    end
    helpHolder:SetParent(mainFrame)
    helpHolder:ClearAllPoints()
    helpHolder:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", -1, -24)
    helpHolder:SetFrameLevel(mainFrame:GetFrameLevel() + 5)
    helpHolder:Show()

    local helpBtn = helpHolder.button
    if not helpBtn then
        helpBtn = CreateFrame("Button", nil, helpHolder)
        helpHolder.button = helpBtn
        helpBtn:SetSize(38, 38)
        helpBtn:SetPoint("CENTER", 0, 0)
        helpBtn:SetNormalTexture(ADDON_FOLDER .. "Textures\\icon_help.tga")
        helpBtn:SetPushedTexture(ADDON_FOLDER .. "Textures\\icon_help.tga")
        helpBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        helpBtn.active = helpBtn:CreateTexture(nil, "OVERLAY")
        helpBtn.active:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        helpBtn.active:SetBlendMode("ADD")
        helpBtn.active:SetPoint("CENTER", 0, 0)
        helpBtn.active:SetSize(62, 62)
        helpBtn.active:SetVertexColor(0.553, 0.878, 0.176, 1)
        helpBtn.active:Hide()

        helpBtn.pulse = helpBtn:CreateTexture(nil, "OVERLAY")
        helpBtn.pulse:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        helpBtn.pulse:SetBlendMode("ADD")
        helpBtn.pulse:SetPoint("CENTER", 0, 0)
        helpBtn.pulse:SetSize(72, 72)
        helpBtn.pulse:Hide()
        helpBtn.pulseAnim = helpBtn.pulse:CreateAnimationGroup()
        helpBtn.pulseAnim:SetLooping("REPEAT")
        local fadeIn = helpBtn.pulseAnim:CreateAnimation("Alpha")
        fadeIn:SetFromAlpha(0.2)
        fadeIn:SetToAlpha(1)
        fadeIn:SetDuration(0.8)
        fadeIn:SetOrder(1)
        local fadeOut = helpBtn.pulseAnim:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(1)
        fadeOut:SetToAlpha(0.2)
        fadeOut:SetDuration(0.8)
        fadeOut:SetOrder(2)
    end
    helpBtn:SetFrameLevel(helpHolder:GetFrameLevel() + 1)
    local normalTex = helpBtn:GetNormalTexture()
    if normalTex then normalTex:SetAllPoints() end
    local pushedTex = helpBtn:GetPushedTexture()
    if pushedTex then pushedTex:SetAllPoints() end
    helpBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["TAB_HELP"] or "Help", 1, 1, 1)
        GameTooltip:Show()
    end)
    helpBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local function StopHelpPulse()
        if helpBtn and helpBtn.pulseAnim then helpBtn.pulseAnim:Stop() end
        if helpBtn and helpBtn.pulse then helpBtn.pulse:Hide() end
        if helpTopBtn and helpTopBtn.pulseAnim then helpTopBtn.pulseAnim:Stop() end
        if helpTopBtn and helpTopBtn.pulse then helpTopBtn.pulse:Hide() end
    end
    local function StartHelpPulse()
        local pr, pg, pb = GetPrimaryColor()
        if helpBtn and helpBtn.pulse and helpBtn.pulseAnim then
            helpBtn.pulse:SetVertexColor(pr, pg, pb, 1)
            helpBtn.pulse:Show()
            helpBtn.pulseAnim:Play()
        end
        if helpTopBtn and helpTopBtn.pulse and helpTopBtn.pulseAnim then
            helpTopBtn.pulse:SetVertexColor(pr, pg, pb, 1)
            helpTopBtn.pulse:Show()
            helpTopBtn.pulseAnim:Play()
        end
    end

    addonTable.SelectTab = function(id)
        CloseAllDropdowns()
        panelList:Hide(); panelHelp:Hide(); panelConfig:Hide(); panelLog:Hide()
        tab1:Enable(); tab3:Enable()
        helpBtn:SetButtonState("NORMAL")
        helpBtn.active:Hide()
        if helpTopBtn then helpTopBtn:SetButtonState("NORMAL") end
        SetTabState(tab1, false)
        SetTabState(tab3, false)
        if id == 1 then
            panelList:Show(); tab1:Disable()
            ApplyAccentFontRecursive(panelList)
        elseif id == 2 then
            panelHelp:Show(); helpBtn:SetButtonState("PUSHED"); helpBtn.active:Show()
            if helpTopBtn then helpTopBtn:SetButtonState("PUSHED") end
            ApplyAccentFontRecursive(panelHelp)
            if LootHunterDB and LootHunterDB.settings and LootHunterDB.settings.general and not LootHunterDB.settings.general.helpSeen then
                LootHunterDB.settings.general.helpSeen = true
                StopHelpPulse()
            end
        elseif id == 3 then
            panelLog:Show(); tab3:Disable(); addonTable.RefreshLogPanel()
            ApplyAccentFontRecursive(panelLog)
        elseif id == 4 then
            if addonTable.BuildSettingsPanelInto then
                addonTable.BuildSettingsPanelInto(panelConfig)
            end
            panelConfig:Show()
            ApplyAccentFontRecursive(panelConfig)
        end
        if id == 1 then
            SetTabState(tab1, true)
        elseif id == 3 then
            SetTabState(tab3, true)
        end
    end
    tab1:SetScript("OnClick", function() addonTable.SelectTab(1) end)
    tab3:SetScript("OnClick", function() addonTable.SelectTab(3) end)
    local function OpenHelpPanel()
        if addonTable.SelectTab then
            addonTable.SelectTab(2)
        end
    end
    local function ToggleHelpPanel()
        if panelHelp and panelHelp:IsShown() then
            addonTable.SelectTab(1)
        else
            addonTable.SelectTab(2)
        end
    end
    local function HandleHelpClick()
        if IsControlKeyDown() and IsShiftKeyDown() then
            if StaticPopup_Show then
                if StaticPopupDialogs and StaticPopupDialogs["LOOTHUNTER_CONFIRM_RESET"] then
                    StaticPopupDialogs["LOOTHUNTER_CONFIRM_RESET"].text = L["RESET_ENV_PROMPT"] or "Reset Loot Hunter settings and saved data? This will reload the UI."
                end
                StaticPopup_Show("LOOTHUNTER_CONFIRM_RESET")
            end
            return
        end
        ToggleHelpPanel()
    end
    helpBtn:SetScript("OnClick", HandleHelpClick)
    if helpTopBtn then
        helpTopBtn:SetScript("OnClick", HandleHelpClick)
    end
    if emptyHelpButton then
        emptyHelpButton:SetScript("OnClick", OpenHelpPanel)
    end
    if LootHunterDB and LootHunterDB.settings and LootHunterDB.settings.general and not LootHunterDB.settings.general.helpSeen then
        StartHelpPulse()
    else
        StopHelpPulse()
    end
    addonTable.SelectTab(1)

    local function GetAddonVersion()
        if addonTable and addonTable.version then
            return addonTable.version
        end
        local meta = GetAddOnMetadata and GetAddOnMetadata(addonName, "Version")
        return meta or "dev"
    end
    local versionLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    versionLabel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -10, 5)
    versionLabel:SetTextColor(0.35, 0.35, 0.35)
    versionLabel:SetText("v." .. tostring(GetAddonVersion()) .. "     ")
    addonTable.SwitchToList = function()
        if addonTable.SelectTab then addonTable.SelectTab(1) end
    end
    LootHunter_RefreshUI()
    ApplyAccentFontRecursive(mainFrame)
end

function LootHunter_RefreshUI()
    if addonTable.isRefreshing then
        pendingRefresh = true
        return
    end
    pendingRefresh = false
    addonTable.isRefreshing = true

    if not scrollChild then 
        addonTable.isRefreshing = false
        return 
    end
    local db = addonTable.CurrentCharDB
    if not db then 
        addonTable.isRefreshing = false
        return 
    end

    local kids = { scrollChild:GetChildren() }
    for _, child in ipairs(kids) do child:Hide(); child:SetParent(nil) end
    local regions = { scrollChild:GetRegions() }
    for _, region in ipairs(regions) do region:Hide() end

    local SLOT_INFO = addonTable.SLOT_INFO or {}
    local sortedList = {}
    local hasItemsInDB = false

    for id, data in pairs(db) do 
        if type(id) == "number" then 
            hasItemsInDB = true
            if not data.status then data.status = (data.found and 1) or 0 end
            
            if not data.slot or data.slot == "" or not SLOT_INFO[data.slot] then
                data.slot = "RAID_TOKEN"
            end
            
            local displayBoss = data.boss or ""
            local staticSourceFunc = addonTable.GetItemSourceFromCache
            if staticSourceFunc and (displayBoss == "" or displayBoss == L["UNKNOWN_SOURCE"] or (L["ZONE_DROP"] ~= "" and displayBoss:find(L["ZONE_DROP"], 1, true))) then
                local cached = staticSourceFunc(id)
                if cached and cached ~= "" then
                    displayBoss = cached
                end
            end
            local bossLower = string.lower(displayBoss)
            
            -- Filtro 1: Tipo (Prioridad / Ganados / Pendientes)
            local matchType = true
            local isEquippedNow = IsEquippedItem(id)
            if currentTypeFilter == "PRIORITY" then
                matchType = data.priority
            elseif currentTypeFilter == "WON" then
                matchType = (data.status == 2) or isEquippedNow
            elseif currentTypeFilter == "PENDING" then
                local statusValue = data.status or 0
                matchType = (statusValue ~= 2) and not isEquippedNow
            end

            -- Filtro 2: Spec
            local matchSpec = (currentSpecFilter == "ALL")
                or (data.specID and data.specID == currentSpecFilter)
                or (data.spec and data.spec == currentSpecFilter)
            
            -- Filtro 3: Source
            local sourceLocation = (data.SourceLocation or ""):lower()
            local function containsAny(text, tokens)
                for _, token in ipairs(tokens) do
                    if token ~= "" and string.find(text, token, 1, true) then
                        return true
                    end
                end
                return false
            end

            local matchSource = false
            if currentSourceFilter == "ALL" then
                matchSource = true
            elseif currentSourceFilter == "SOURCE_TOKEN" then
                if data.slot == "RAID_TOKEN" or containsAny(bossLower, { "tier", "token", "ficha" }) or containsAny(sourceLocation, { "tier", "token", "ficha" }) then
                    matchSource = true
                end
            elseif currentSourceFilter == "SOURCE_MOUNT" then
                if data.slot == "MOUNT" or containsAny(bossLower, { "mount", "riding", "montura" }) or containsAny(sourceLocation, { "mount", "riding", "montura" }) then
                    matchSource = true
                end
            elseif currentSourceFilter == "SOURCE_DROP" then
                local isToken = data.slot == "RAID_TOKEN" or containsAny(bossLower, { "tier", "token", "ficha" }) or containsAny(sourceLocation, { "tier", "token", "ficha" })
                local isMount = data.slot == "MOUNT" or containsAny(bossLower, { "mount", "riding", "montura" }) or containsAny(sourceLocation, { "mount", "riding", "montura" })
                if not isToken and not isMount then matchSource = true end
            end
            
            if matchType and matchSpec and matchSource then
                table.insert(sortedList, { id = id, data = data, displayBoss = displayBoss }) 
            end
        end
    end
    
    if topPanel then
        if hasItemsInDB then
            topPanel:Show()
        else
            topPanel:Hide()
        end
    end

    if listScrollFrame then
        if #sortedList == 0 then listScrollFrame:Hide() else listScrollFrame:Show() end
    end

    if #sortedList == 0 then
        if emptyInstruction then
            emptyInstruction:SetShown(not hasItemsInDB)
        end
        if emptyJournalButton then
            emptyJournalButton:SetShown(not hasItemsInDB)
        end
        if emptyHeader then 
            emptyHeader:SetText(hasItemsInDB and L["FILTER_EMPTY_TITLE"] or L["EMPTY_TITLE"])
            emptyHeader:Show() 
        end
        if emptyQuote then
            emptyQuote:SetText(hasItemsInDB and L["FILTER_EMPTY_DESC"] or emptyQuote.selectedText)
            local targetSize
            if hasItemsInDB and emptyQuote.baseSize then
                targetSize = emptyQuote.baseSize
            else
                targetSize = emptyQuote.smallFontSize or (emptyQuote.baseSize or 12) + 2
            end
            if targetSize then
                emptyQuote:SetFont(ACCENT_FONT, targetSize, emptyQuote.baseFlags)
            end
            emptyQuote:Show()
        end
        if logoIcon then logoIcon:Show() end
        if ghostIcon then ghostIcon:Show() end
        if emptyContainer then emptyContainer:Show() end
        if emptyContainer then
            emptyContainer:ClearAllPoints()
            local verticalOffset = hasItemsInDB and -44 or 33
            emptyContainer:SetPoint("CENTER", panelList, "CENTER", 0, verticalOffset)
        end
        if hasItemsInDB then
            if logoIcon then logoIcon:Hide() end
            if logoAnim and logoAnim:IsPlaying() then
                logoAnim:Stop()
            end
            if ghostIcon then
                ghostIcon:Show()
                if ghostAnim and not ghostAnim:IsPlaying() then
                    ghostAnim:Play()
                end
            end
            if emptyHeader then
                emptyHeader:ClearAllPoints()
                emptyHeader:SetPoint("TOP", ghostIcon, "BOTTOM", 0, -10)
            end
        else
            if ghostIcon then ghostIcon:Hide() end
            if ghostAnim and ghostAnim:IsPlaying() then
                ghostAnim:Stop()
            end
            if logoIcon then
                logoIcon:Show()
                if logoAnim and not logoAnim:IsPlaying() then
                    logoAnim:Play()
                end
            end
            if emptyHeader then
                emptyHeader:ClearAllPoints()
                emptyHeader:SetPoint("TOP", logoIcon, "BOTTOM", 0, -10)
            end
        end
    else
        if emptyInstruction then emptyInstruction:Hide() end
        if emptyJournalButton then emptyJournalButton:Hide() end
        if emptyHeader then emptyHeader:Hide() end
        if emptyQuote then emptyQuote:Hide() end
        if ghostIcon then ghostIcon:Hide() end
        if logoIcon then logoIcon:Hide() end
        if emptyContainer then emptyContainer:Hide() end
    end

    table.sort(sortedList, function(a, b)
        local slotDataA = SLOT_INFO[a.data.slot] or { order = 99 }
        local slotDataB = SLOT_INFO[b.data.slot] or { order = 99 }
        if slotDataA.order ~= slotDataB.order then return slotDataA.order < slotDataB.order 
        else 
            local pA = a.data.priority and 1 or 0
            local pB = b.data.priority and 1 or 0
            if pA ~= pB then return pA > pB end
            return a.data.name < b.data.name 
        end
    end)

    local yOffset = -5 
    local lastHeader = ""

    for i, entry in ipairs(sortedList) do
        local info = entry.data
        local bossText = entry.displayBoss or info.boss or ""
        if bossText == L["UNKNOWN_SOURCE"] then bossText = "" end

        -- Actualizar información del item si ya está disponible en caché (Loading fix)
        local iName, iLink, _, _, _, _, _, _, iEquipLoc, iIcon = GetItemInfo(entry.id)
        if iName then
            info.name = iName
            info.link = iLink
            info.icon = iIcon
            -- Si el slot era desconocido (RAID_TOKEN) y ahora lo tenemos, actualizamos
            if info.slot == "RAID_TOKEN" and iEquipLoc and SLOT_INFO[iEquipLoc] then
                info.slot = iEquipLoc
            end
        end

        local slotConfig = SLOT_INFO[info.slot] or { name = "Otro" }
        local slotName = slotConfig.name

        if slotName ~= lastHeader then
            if yOffset ~= -5 then yOffset = yOffset - 15 end
            local header = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 5, yOffset)
            header:SetText(string.format(L["SLOT_HEADER"], string.upper(slotName)))
            ApplyAccentFont(header)
            do
                local pr, pg, pb = GetPrimaryColor()
                header:SetTextColor(pr, pg, pb)
            end
            yOffset = yOffset - 18
            lastHeader = slotName
        end

        local isEquippedNow = IsEquippedItem(entry.id)
        local rowState = ResolveVisualState(info)

        local row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
        row:SetHeight(38)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, yOffset)
        row:EnableMouse(true)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        row:SetBackdropColor(0, 0, 0, 0.3)

        local borderColor = {0, 0, 0, 0}
        if rowState == "priority" then
            borderColor = {1, 0.9, 0, 0.8}
        elseif rowState == "won" then
            local pr, pg, pb = GetPrimaryColor()
            borderColor = {pr, pg, pb, 0.8}
        end
        row:SetBackdropBorderColor(unpack(borderColor))

        local iconTex = row:CreateTexture(nil, "ARTWORK")
        iconTex:SetSize(32, 32)
        iconTex:SetPoint("LEFT", row, "LEFT", 5, 0)
        iconTex:SetTexture(info.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

        local equipCheck = row:CreateTexture(nil, "OVERLAY")
        equipCheck:SetSize(18, 18)
        equipCheck:SetPoint("TOPLEFT", iconTex, "TOPLEFT", -2, 2)
        equipCheck:SetTexture(EQUIPPED_ICON_PATH)
        if not equipCheck:GetTexture() then
            equipCheck:SetTexture(EQUIPPED_ICON_FALLBACK)
            addonTable.UseFallbackEquippedIcon = true
        end
        if not isEquippedNow then equipCheck:Hide() end

        local delBtn = CreateFrame("Button", nil, row, "UIPanelCloseButton")
        delBtn:SetSize(20, 20)
        delBtn:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        delBtn:SetNormalTexture(DELETE_ICON_PATH)
        delBtn:SetPushedTexture(DELETE_ICON_PATH)
        delBtn:SetHighlightTexture(DELETE_ICON_PATH)
        local delNormal = delBtn:GetNormalTexture()
        if delNormal then delNormal:SetVertexColor(1, 1, 1, 0.9) end
        local delPushed = delBtn:GetPushedTexture()
        if delPushed then delPushed:SetVertexColor(0.85, 0.85, 0.85, 1) end
        local delHighlight = delBtn:GetHighlightTexture()
        if delHighlight then
            delHighlight:SetVertexColor(1, 1, 1, 1)
            delHighlight:SetBlendMode("ADD")
        end
        delBtn:SetScript("OnEnter", function()
            if delNormal then delNormal:SetVertexColor(1, 1, 1, 1) end
        end)
        delBtn:SetScript("OnLeave", function()
            if delNormal then delNormal:SetVertexColor(1, 1, 1, 0.9) end
        end)
        delBtn:SetScript("OnClick", function() db[entry.id] = nil; LootHunter_RefreshUI() end)

        local function IsHeroicLocal(itemInfo)
            if itemInfo.isHeroic ~= nil then return itemInfo.isHeroic end
            local link = itemInfo.link or ""
            local plainLink = link:match("|H(item:.-)|h") or link
            if plainLink == "" then return false end
            if addonTable.IsHeroicItem then
                return addonTable.IsHeroicItem(plainLink, itemInfo.boss)
            end
            return false
        end

        local isHeroic = IsHeroicLocal(info)
        info.isHeroic = isHeroic

        local typeLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        typeLabel:SetPoint("RIGHT", delBtn, "LEFT", -5, 0)
        ApplyAccentFont(typeLabel)
        local typeText = ""
        local specName = (addonTable.GetSpecNameFromID and addonTable.GetSpecNameFromID(info.specID)) or info.spec
        if specName and specName ~= "" then
            typeText = specName
        end
        if info.bisType then 
            if typeText ~= "" then typeText = typeText .. " | " end
            typeText = typeText .. info.bisType 
        end
        typeLabel:SetText(typeText)
        typeLabel:SetTextColor(1, 1, 1)
        typeLabel:EnableMouse(true)
        typeLabel:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                row._skipNextClick = true
                ShowRowSpecMenu(self, { data = info, row = row })
            end
        end)
        typeLabel:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
            GameTooltip:SetText(L["SPEC_TOOLTIP"], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        typeLabel:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        local textName = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        textName:SetPoint("TOPLEFT", iconTex, "TOPRIGHT", 8, -2)
        textName:SetPoint("RIGHT", typeLabel, "LEFT", -10, 0)
        textName:SetJustifyH("LEFT")
        textName:SetWordWrap(false)
        ApplyAccentFont(textName)
        
        local textBoss = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        textBoss:SetPoint("TOPLEFT", textName, "BOTTOMLEFT", 0, -2)
        textBoss:SetPoint("RIGHT", typeLabel, "LEFT", -10, 0)
        textBoss:SetJustifyH("LEFT")
        textBoss:SetWordWrap(false)
        textBoss:SetTextColor(0.6, 0.6, 0.6) 
        textBoss:SetText(bossText)
        ApplyAccentFont(textBoss)

        -- Construir el nombre a mostrar; añadir [H] al final si es heroico
        local baseName = info.link or info.name or ""
        local displayName = baseName
        if isHeroic then
            displayName = displayName .. " |cff00ff00[H]|r"
        end

        -- Aplicar color de estado y mantener el borde adecuado
        if info.status == 2 then 
            local pr, pg, pb = GetPrimaryColor()
            textName:SetText("|cff00ff00" .. displayName .. "|r")
            textBoss:SetTextColor(0, 1, 0)
            row:SetBackdropBorderColor(pr, pg, pb, 0.9)
        elseif info.status == 1 then
            local dropLabel = CreateGradient("[DROP]: ", 1, 0.85, 0.35, 1, 0.65, 0)
            textName:SetText(dropLabel .. "|cffffd700" .. displayName .. "|r")
            textBoss:SetTextColor(1, 0.85, 0)
            row:SetBackdropBorderColor(1, 0.55, 0, 0.8)
        else
            textName:SetText(displayName)
            row:SetBackdropBorderColor(unpack(borderColor))
        end

        row:SetScript("OnEnter", function(self)
            self._tooltipLink = info.link
            self._lastCompare = IsModifiedClick and IsModifiedClick("COMPAREITEMS") or false
            RefreshRowTooltip(self, self._lastCompare)
            self:SetScript("OnUpdate", function(f)
                local cmp = IsModifiedClick and IsModifiedClick("COMPAREITEMS") or false
                if cmp ~= f._lastCompare then
                    f._lastCompare = cmp
                    RefreshRowTooltip(f, cmp)
                end
            end)
        end)
        row:SetScript("OnLeave", function(self)
            self._tooltipLink = nil
            self._lastCompare = nil
            self:SetScript("OnUpdate", nil)
            GameTooltip:Hide()
        end)
        
        local lastClick = 0
        row:SetScript("OnMouseDown", function(self, button)
            if (specRowMenuFrame and specRowMenuFrame:IsShown()) then return end
            if typeLabel and _G.MouseIsOver and MouseIsOver(typeLabel) then return end
            if self._specMenuOpen then return end
            if self._skipNextClick then self._skipNextClick = nil; return end
            if button == "LeftButton" then
                if info.link and IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() then
                    ChatEdit_InsertLink(info.link)
                    return
                end
                local now = GetTime()
                if now - lastClick < 0.4 then
                    local newPriority = not db[entry.id].priority
                    db[entry.id].priority = newPriority
                    if newPriority then
                        db[entry.id].lastState = "priority"
                    else
                        if db[entry.id].status == 2 then
                            db[entry.id].lastState = "won"
                        else
                            db[entry.id].lastState = nil
                        end
                    end
                    LootHunter_RefreshUI()
                    lastClick = 0
                else lastClick = now end
            elseif button == "RightButton" then
                if db[entry.id].status == 2 then
                    db[entry.id].status = 0
                    if db[entry.id].priority then
                        db[entry.id].lastState = "priority"
                    else
                        db[entry.id].lastState = nil
                    end
                else
                    db[entry.id].status = 2
                    db[entry.id].lastState = "won"
                end
                LootHunter_RefreshUI()
            end
        end)
        yOffset = yOffset - 42 
    end
    scrollChild:SetHeight(math.abs(yOffset) + 20)

    C_Timer.After(0, function()
        addonTable.isRefreshing = false
        if pendingRefresh then
            pendingRefresh = false
            LootHunter_RefreshUI()
        end
    end)
end
