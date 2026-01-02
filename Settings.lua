local addonName, addonTable = ...
local L = addonTable.L

local isBuilt = false
local selectedCategory = nil
local Settings = {}
local PREVIEW_PREWARN_SOUND = (SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081
local ICON_DIAMOND = (addonTable and addonTable.ICON_DIAMOND) or "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:24|t"
local ICON_STAR = (addonTable and addonTable.ICON_STAR) or "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:24|t"
local ADDON_FOLDER = "Interface\\AddOns\\" .. addonName .. "\\"
local TEX_ARROW = ADDON_FOLDER .. "Textures\\icon_arrow.tga"
local ACCENT_FONT = ADDON_FOLDER .. "Fonts\\Prototype.ttf"
local function GetPrimaryColor()
    if addonTable.GetPrimaryColor then
        return addonTable.GetPrimaryColor()
    end
    local c = addonTable.PRIMARY_COLOR or {}
    return c.r or 1, c.g or 0.82, c.b or 0
end
local function ApplyAccentFont(fs)
    if not fs then return end
    local _, size, flags = fs:GetFont()
    fs:SetFont(ACCENT_FONT, size or 12, flags)
end

local function ShowReloadDialog()
    if not StaticPopupDialogs or not StaticPopup_Show then return end
    local dialog = StaticPopupDialogs["LOOTHUNTER_RELOAD_UI"]
    if not dialog then
        StaticPopupDialogs["LOOTHUNTER_RELOAD_UI"] = {
            text = L["RELOAD_UI_PROMPT"] or "Changes require a UI reload. Reload now?",
            button1 = YES,
            button2 = NO,
            OnAccept = function() ReloadUI() end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
        dialog = StaticPopupDialogs["LOOTHUNTER_RELOAD_UI"]
    end
    dialog.text = L["RELOAD_UI_PROMPT"] or dialog.text
    StaticPopup_Show("LOOTHUNTER_RELOAD_UI")
end

-- Esta funcion la llama UI.lua para construir el panel de configuracion dentro de una pesta?a
function addonTable.BuildSettingsPanelInto(parentFrame)
    -- En llamadas posteriores, solo refrescar valores, no reconstruir
    if isBuilt then
        if addonTable.db and addonTable.db.settings then
            for _, panel in pairs(parentFrame.panels or {}) do
                for _, child in ipairs({panel:GetChildren()}) do
                    if child.key and child.key:find(".") then -- Forma simple de identificar nuestros checkboxes
                        local db_category, db_key = string.match(child.key, "([^.]+)%.([^.]+)")
                        if addonTable.db.settings[db_category] and addonTable.db.settings[db_category][db_key] ~= nil then
                            -- Esta es la logica corregida para nuestro checkbox custom
                            child.isChecked = addonTable.db.settings[db_category][db_key]
                            if child.UpdateCheckVisual then
                                child:UpdateCheckVisual()
                            end
                        end
                    end
                end
            end
        end
        return
    end

    parentFrame.panels = {}

    -- Barra lateral
    local sidebar = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
    sidebar:SetWidth(130)
    sidebar:SetPoint("TOPLEFT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", 0, 0)
    sidebar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    sidebar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    local sidebarRightBorder = sidebar:CreateTexture(nil, "BORDER")
    sidebarRightBorder:SetColorTexture(0, 0, 0, 1)
    sidebarRightBorder:SetWidth(1)
    sidebarRightBorder:SetPoint("TOPRIGHT", 0, 0)
    sidebarRightBorder:SetPoint("BOTTOMRIGHT", 0, 0)

    -- Content Area (alineado similar a la sección de Ayuda: menor margen interno)
    local content = CreateFrame("Frame", nil, parentFrame)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, 0)
    content:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -10, 10)
    
    -- Ayuda para ajustar anchos dinamicamente
    local function LayoutPanel(panel)
        if not panel or not panel._layout then return end
        local y = -(panel._topPadding or 50)
        local rowSpacing = panel._rowSpacing or 12
        local function FallbackHeight(fontString, minLines)
            if not fontString then return 0 end
            local _, size = fontString:GetFont()
            local lineHeight = (size or 12) + 2
            return lineHeight * (minLines or 1)
        end
        for _, entry in ipairs(panel._layout) do
            local height = 0
            if entry.label then
                local labelHeight = entry.label:GetStringHeight() or 0
                if labelHeight == 0 then
                    labelHeight = FallbackHeight(entry.label, 3)
                end
                height = math.max(24, labelHeight)
            end
            if entry.desc then
                local descHeight = entry.desc:GetStringHeight() or 0
                if descHeight == 0 then
                    descHeight = FallbackHeight(entry.desc, 5)
                end
                height = height + descHeight + 6
            end
            if entry.extraHeight then
                height = height + entry.extraHeight
            end
            height = height + 6
            if entry.compact then
                height = math.max(0, height - 6)
            end
            entry.frame:ClearAllPoints()
            entry.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
            entry.frame:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
            entry.frame:SetHeight(height)
            local spacing = entry.afterSpacing
            if spacing == nil then spacing = rowSpacing end
            y = y - height - spacing
        end
        panel._lastY = y
    end

    local function ReflowPanel(panel)
        if not panel then return end
        local w = panel:GetWidth() or 0
        if panel._title then
            panel._title:SetWidth(math.max(200, w - 20))
        end
        local avail = math.max(260, w - 90) -- espacio para checkbox + preview + margen
        if panel._layout then
            for _, entry in ipairs(panel._layout) do
                if entry.label then
                    local labelWidth = avail
                    if entry.buttonWidth and entry.buttonWidth > 0 then
                        labelWidth = math.max(120, avail - entry.buttonWidth - 10)
                    end
                    if entry.previewInline then
                        local previewSpace = 24
                        local textWidth = entry.label:GetStringWidth() or 0
                        if textWidth > 0 then
                            entry.label:SetWidth(math.min(labelWidth - previewSpace, textWidth))
                        else
                            entry.label:SetWidth(labelWidth - previewSpace)
                        end
                    else
                        entry.label:SetWidth(labelWidth)
                    end
                end
                if entry.desc then entry.desc:SetWidth(avail + 40) end
            end
        end
        LayoutPanel(panel)
    end

    local function CreateSectionHeader(panel, text, afterSpacing)
        if not panel then return nil end
        local entryFrame = CreateFrame("Frame", nil, panel)
        entryFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
        entryFrame:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
        local fs = entryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        fs:SetPoint("TOPLEFT", entryFrame, "TOPLEFT", 20, 0)
        fs:SetPoint("RIGHT", entryFrame, "RIGHT", -10, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetText(text or "")
        do
            local pr, pg, pb = GetPrimaryColor()
            fs:SetTextColor(pr + (1 - pr) * 0.5, pg + (1 - pg) * 0.5, pb + (1 - pb) * 0.5)
        end
        ApplyAccentFont(fs)
        table.insert(panel._layout, {
            frame = entryFrame,
            label = fs,
            extraHeight = 0,
            afterSpacing = afterSpacing,
            compact = panel._compactEntries,
        })
        ReflowPanel(panel)
        return entryFrame
    end

    local function CreateButtonRow(panel, buttonText, onClick, onEnter, onLeave, extraPad)
        if not panel then return nil end
        local entryFrame = CreateFrame("Frame", nil, panel)
        entryFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
        entryFrame:SetPoint("RIGHT", panel, "RIGHT", 0, 0)

        local button = CreateFrame("Button", nil, entryFrame, "BackdropTemplate")
        button:SetSize(190, 24)
        button:SetPoint("TOPLEFT", entryFrame, "TOPLEFT", 20, 0)
        button:SetText(buttonText or "")
        button:SetNormalFontObject("GameFontHighlightSmall")
        ApplyAccentFont(button:GetFontString())
        button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        button:SetBackdropColor(0.545, 0.031, 0.031, 1)
        button:SetBackdropBorderColor(0, 0, 0, 1)
        if onClick then button:SetScript("OnClick", onClick) end
        if onEnter then button:SetScript("OnEnter", onEnter) end
        if onLeave then button:SetScript("OnLeave", onLeave) end

        local pad = extraPad
        if type(pad) ~= "number" then pad = 0 end
        table.insert(panel._layout, {
            frame = entryFrame,
            label = nil,
            extraHeight = button:GetHeight() + pad,
            afterSpacing = panel._entryAfterSpacing,
            compact = panel._compactEntries,
        })
        ReflowPanel(panel)
        return button
    end
    
    local sidebarButtons = {}
    -- Funcion para seleccionar una categoria
    function Settings:SelectCategory(categoryButton)
        if selectedCategory then
            -- Deseleccionar boton anterior
            selectedCategory:SetBackdropColor(0.2, 0.2, 0.2, 1)
            selectedCategory:SetBackdropBorderColor(0, 0, 0, 1)
            if parentFrame.panels[selectedCategory.key] then
                parentFrame.panels[selectedCategory.key]:Hide()
            end
        end

        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        -- Seleccionar boton nuevo
        categoryButton:SetBackdropColor(0.3, 0.3, 0.3, 1)
        local pr, pg, pb = GetPrimaryColor()
        categoryButton:SetBackdropBorderColor(pr, pg, pb, 1) -- Borde dorado para activo
        if parentFrame.panels[categoryButton.key] then
            local panel = parentFrame.panels[categoryButton.key]
            panel:Show()
            ReflowPanel(panel)
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if panel and panel:IsShown() then
                        ReflowPanel(panel)
                    end
                end)
            end
        end
        selectedCategory = categoryButton
    end

    -- Funcion para crear un boton de categoria en el sidebar
    local nextCategoryY = -10
    function Settings:CreateCategory(key, name)
        local button = CreateFrame("Button", "LootHunter_SettingsCategory_"..key, sidebar, "BackdropTemplate")
        button:SetSize(120, 22)
        button:SetPoint("TOP", sidebar, "TOP", 0, nextCategoryY)
        button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        button:SetBackdropColor(0.2, 0.2, 0.2, 1)
        button:SetBackdropBorderColor(0, 0, 0, 1)
        button:SetNormalFontObject("GameFontHighlightSmall")
        button:SetText(name)
        button.key = key
        
        local hl = button:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.1)

        button:SetScript("OnClick", function(self)
            Settings:SelectCategory(self)
        end)

        table.insert(sidebarButtons, button)
        nextCategoryY = nextCategoryY - button:GetHeight() - 5

        -- Crear un panel para esta categoria
        local panel = CreateFrame("Frame", "LootHunter_SettingsPanel_"..key, content)
        panel:SetAllPoints(content)
        panel:Hide()
        parentFrame.panels[key] = panel

        -- Agregar un titulo al panel
        panel._layout = {}
        panel._topPadding = 50
        panel._rowSpacing = 1

        local panelTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        panelTitle:SetPoint("TOPLEFT", 10, -15)
        panelTitle:SetWidth((panel:GetWidth() or 0) - 20)
        panelTitle:SetJustifyH("LEFT")
        panelTitle:SetWordWrap(true)
        panelTitle:SetText(name)
        do
            local pr, pg, pb = GetPrimaryColor()
            panelTitle:SetTextColor(pr, pg, pb)
        end
        panel._title = panelTitle
        panel:SetScript("OnSizeChanged", ReflowPanel)
        ReflowPanel(panel)

        return panel
    end

    -- Funcion para crear un checkbox custom desde cero
    function Settings:CreateCheckbox(panel, key, text, description, yOffset, previewHandler)
        local entryFrame = CreateFrame("Frame", nil, panel)
        entryFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
        entryFrame:SetPoint("RIGHT", panel, "RIGHT", 0, 0)

        local cb = CreateFrame("Button", "LootHunter_SettingsCB_"..key:gsub(".", "_"), entryFrame)
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", 20, 0)
        cb.key = key -- Guardar la clave para la logica de refresco

        -- Textura de fondo (caja vacia)
        local bg = cb:CreateTexture(nil, "BACKGROUND")
        bg:SetSize(24, 24)
        bg:SetPoint("CENTER")
        bg:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")

        -- Textura de resaltado
        local hl = cb:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(bg)
        hl:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        hl:SetBlendMode("ADD")
        
        -- Textura de check
        local checkedTex = cb:CreateTexture(nil, "ARTWORK")
        checkedTex:SetSize(24, 24)
        checkedTex:SetPoint("CENTER")
        checkedTex:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        
        -- Funcion para mostrar/ocultar la textura de check
        local function UpdateCheckVisual()
            if cb.isChecked then
                checkedTex:Show()
            else
                checkedTex:Hide()
            end
        end
        cb.UpdateCheckVisual = UpdateCheckVisual -- Exponer funcion al frame

        -- Establecer estado inicial desde la DB
        local db_category, db_key = string.match(key, "([^.]+)%.([^.]+)")
        if addonTable.db and addonTable.db.settings[db_category] and addonTable.db.settings[db_category][db_key] ~= nil then
            cb.isChecked = addonTable.db.settings[db_category][db_key]
        else
            cb.isChecked = false -- Por defecto false si no se encuentra
        end
        UpdateCheckVisual()

        -- Manejador de OnClick
        cb:SetScript("OnClick", function(self)
            PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
            self.isChecked = not self.isChecked
            self:UpdateCheckVisual()
            
            local db_category, db_key = string.match(key, "([^.]+)%.([^.]+)")
            if addonTable.db and addonTable.db.settings[db_category] then
                addonTable.db.settings[db_category][db_key] = self.isChecked
                if key == "general.windowsLocked" then
                    ShowReloadDialog()
                end
            end
        end)

        -- Texto del label
        local label = entryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", cb, "RIGHT", 8, 0)
        label:SetWidth(320) -- Ancho fijo para evitar salto de linea
        label:SetJustifyH("LEFT")
        label:SetWordWrap(true)
        label:SetMaxLines(3)
        if label.SetNonSpaceWrap then
            label:SetNonSpaceWrap(true)
        end
        label:SetText(text or key)

        local previewBtn
        if previewHandler then
            previewBtn = CreateFrame("Button", nil, entryFrame)
            previewBtn:SetSize(14, 14)
            previewBtn:SetPoint("LEFT", label, "RIGHT", 6, 0)
            previewBtn:SetNormalTexture("Interface\\FriendsFrame\\InformationIcon")
            previewBtn:SetPushedTexture("Interface\\FriendsFrame\\InformationIcon")
            previewBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
            previewBtn:SetAlpha(0.9)
            previewBtn:SetScript("OnClick", function()
                PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
                previewHandler()
            end)
            previewBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine("Preview", 1, 1, 1)
                GameTooltip:Show()
            end)
            previewBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end

        -- Texto de descripcion
        if description then
            local desc = entryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -5)
            desc:SetPoint("RIGHT", entryFrame, "RIGHT", -10, 0) -- Anclar a la derecha para forzar el salto de linea
            desc:SetJustifyH("LEFT")
            desc:SetWordWrap(true)
            desc:SetMaxLines(5)
            if desc.SetNonSpaceWrap then
                desc:SetNonSpaceWrap(true)
            end
            if desc.SetSpacing then
                pcall(desc.SetSpacing, desc, 2)
            end
            desc:SetText(description)
            desc:SetTextColor(0.8, 0.8, 0.8)
            table.insert(panel._layout, {
                frame = entryFrame,
                label = label,
                desc = desc,
                previewInline = previewBtn ~= nil,
                afterSpacing = panel._entryAfterSpacing,
                compact = panel._compactEntries,
            })
            ReflowPanel(panel)
            return cb, desc, entryFrame
        end

        table.insert(panel._layout, {
            frame = entryFrame,
            label = label,
            previewInline = previewBtn ~= nil,
            afterSpacing = panel._entryAfterSpacing,
            compact = panel._compactEntries,
        })
        ReflowPanel(panel)

        return cb, nil, entryFrame
    end

    local function CreateDropdownRow(panel, labelText, options, getValue, setValue, description)
        local entryFrame = CreateFrame("Frame", nil, panel)
        entryFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
        entryFrame:SetPoint("RIGHT", panel, "RIGHT", 0, 0)

        local label = entryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("TOPLEFT", entryFrame, "TOPLEFT", 20, 0)
        label:SetPoint("RIGHT", entryFrame, "RIGHT", -110, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(true)
        label:SetMaxLines(2)
        if label.SetNonSpaceWrap then
            label:SetNonSpaceWrap(true)
        end
        local hasLabel = labelText and labelText ~= ""
        if hasLabel then
            label:SetText(labelText)
        else
            label:SetText("")
            label:Hide()
        end

        local dropdown = CreateFrame("Button", nil, entryFrame, "BackdropTemplate")
        dropdown:SetSize(140, 22)
        dropdown:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        dropdown:SetBackdropColor(0.2, 0.2, 0.2, 1)
        dropdown:SetBackdropBorderColor(0, 0, 0, 1)
        local dropdownText = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        dropdownText:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
        dropdownText:SetPoint("RIGHT", dropdown, "RIGHT", -18, 0)
        dropdownText:SetJustifyH("LEFT")
        ApplyAccentFont(dropdownText)
        local arrow = dropdown:CreateTexture(nil, "ARTWORK")
        arrow:SetSize(8, 8)
        arrow:SetPoint("RIGHT", dropdown, "RIGHT", -6, 0)
        arrow:SetTexture(TEX_ARROW)
        do
            local pr, pg, pb = GetPrimaryColor()
            arrow:SetVertexColor(pr, pg, pb, 1)
        end

        local desc
        if description then
            desc = entryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            if hasLabel then
                desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -5)
            else
                desc:SetPoint("TOPLEFT", entryFrame, "TOPLEFT", 20, 0)
            end
            desc:SetPoint("RIGHT", entryFrame, "RIGHT", -10, 0)
            desc:SetJustifyH("LEFT")
            desc:SetWordWrap(true)
            desc:SetMaxLines(5)
            if desc.SetNonSpaceWrap then
                desc:SetNonSpaceWrap(true)
            end
            if desc.SetSpacing then
                pcall(desc.SetSpacing, desc, 2)
            end
            desc:SetText(description)
            desc:SetTextColor(0.8, 0.8, 0.8)
        end

        if desc then
            dropdown:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -6)
        elseif hasLabel then
            dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
        else
            dropdown:SetPoint("TOPLEFT", entryFrame, "TOPLEFT", 20, 0)
        end

        local menuFrame = CreateFrame("Frame", nil, entryFrame, "BackdropTemplate")
        menuFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        menuFrame:SetBackdropColor(0.15, 0.15, 0.15, 0.95)
        menuFrame:SetBackdropBorderColor(0, 0, 0, 1)
        menuFrame:SetFrameStrata("TOOLTIP")
        local baseLevel = (dropdown.GetFrameLevel and dropdown:GetFrameLevel()) or 0
        menuFrame:SetFrameLevel(baseLevel + 50)
        menuFrame:SetClampedToScreen(true)
        menuFrame:Hide()

        local function UpdateDropdownText()
            local current = getValue and getValue()
            local currentLabel = nil
            for _, opt in ipairs(options) do
                if opt.value == current then
                    currentLabel = opt.label
                    break
                end
            end
            dropdownText:SetText(currentLabel or (options[1] and options[1].label) or "")
        end

        local function BuildMenu()
            for _, child in ipairs({ menuFrame:GetChildren() }) do
                child:Hide()
                child:SetParent(nil)
            end
            local y = -5
            for _, opt in ipairs(options) do
                local btn = CreateFrame("Button", nil, menuFrame)
                btn:SetSize(120, 20)
                btn:SetPoint("TOPLEFT", 5, y)
                local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                fs:SetPoint("LEFT", btn, "LEFT", 5, 0)
                fs:SetText(opt.label)
                fs:SetJustifyH("LEFT")
                fs:SetTextColor(1, 1, 1)
                ApplyAccentFont(fs)
                btn:SetScript("OnEnter", function()
                    local pr, pg, pb = GetPrimaryColor()
                    fs:SetTextColor(pr, pg, pb)
                end)
                btn:SetScript("OnLeave", function() fs:SetTextColor(1, 1, 1) end)
                btn:SetScript("OnClick", function()
                    PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
                    if setValue then
                        setValue(opt.value)
                    end
                    UpdateDropdownText()
                    menuFrame:Hide()
                end)
                y = y - 20
            end
            menuFrame:SetHeight(math.abs(y) + 5)
            menuFrame:SetWidth(130)
            menuFrame:ClearAllPoints()
            menuFrame:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
        end

        dropdown:SetScript("OnClick", function()
            if menuFrame:IsShown() then
                menuFrame:Hide()
                return
            end
            BuildMenu()
            menuFrame:Show()
        end)
        UpdateDropdownText()

        local entry = {
            frame = entryFrame,
            label = label,
            desc = desc,
            buttonWidth = 0,
            extraHeight = dropdown:GetHeight() + 8,
            afterSpacing = panel._entryAfterSpacing,
            compact = panel._compactEntries,
        }
        table.insert(panel._layout, entry)
        ReflowPanel(panel)

        return dropdown, entryFrame, entry
    end
    
    local function FormatSecondsText(value)
        local v = math.floor(tonumber(value) or 0)
        if v < 0 then v = 0 end
        local m = math.floor(v / 60)
        local s = v % 60
        if m > 0 then
            return string.format("%dm %02ds", m, s)
        end
        return string.format("%ds", s)
    end

    function Settings:CreateSlider(panel, key, labelText, minValue, maxValue, step, description)
        local entryFrame = CreateFrame("Frame", nil, panel)
        entryFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
        entryFrame:SetPoint("RIGHT", panel, "RIGHT", 0, 0)

        local label = entryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("TOPLEFT", entryFrame, "TOPLEFT", 20, 0)
        label:SetPoint("RIGHT", entryFrame, "RIGHT", -10, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(true)
        label:SetMaxLines(2)
        if label.SetNonSpaceWrap then
            pcall(label.SetNonSpaceWrap, label, true)
        end
        label:SetText(labelText or key)
        do
            local pr, pg, pb = GetPrimaryColor()
            label:SetTextColor((pr + 1) * 0.5, (pg + 1) * 0.5, (pb + 1) * 0.5) -- Subtitle color: primary mixed 50% with white
        end

        local slider = CreateFrame("Slider", "LootHunter_SettingsSlider_"..key:gsub("%.", "_"), entryFrame, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
        slider:SetPoint("RIGHT", entryFrame, "RIGHT", -60, 0)
        slider:SetMinMaxValues(minValue or 0, maxValue or 100)
        slider:SetValueStep(step or 1)
        slider:SetObeyStepOnDrag(true)

        local valueText = entryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
        valueText:SetJustifyH("LEFT")
        do
            local pr, pg, pb = GetPrimaryColor()
            valueText:SetTextColor(pr, pg, pb) -- Primary color for live value
        end

        local low = slider.Low or _G[slider:GetName() .. "Low"]
        local high = slider.High or _G[slider:GetName() .. "High"]
        if low then
            low:SetText(FormatSecondsText(minValue or 0))
            low:SetTextColor(0.75, 0.75, 0.75) -- Light gray min label
        end
        if high then
            high:SetText(FormatSecondsText(maxValue or 0))
            high:SetTextColor(0.75, 0.75, 0.75) -- Light gray max label
        end
        if slider.Text then slider.Text:Hide() end

        local desc
        if description then
            desc = entryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            desc:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -8)
            desc:SetPoint("RIGHT", entryFrame, "RIGHT", -10, 0)
            desc:SetJustifyH("LEFT")
            desc:SetWordWrap(true)
            desc:SetMaxLines(5)
            if desc.SetNonSpaceWrap then
                pcall(desc.SetNonSpaceWrap, desc, true)
            end
            if desc.SetSpacing then
                pcall(desc.SetSpacing, desc, 2)
            end
            desc:SetText(description)
            desc:SetTextColor(0.8, 0.8, 0.8)
        end

        local db_category, db_key = string.match(key, "([^.]+)%.([^.]+)")
        local current = maxValue or 0
        if addonTable.db and addonTable.db.settings[db_category] and addonTable.db.settings[db_category][db_key] ~= nil then
            current = addonTable.db.settings[db_category][db_key]
        end
        current = tonumber(current) or current or (maxValue or 0)
        local minV = minValue or 0
        local maxV = maxValue or 0
        if current < minV then current = minV end
        if current > maxV then current = maxV end
        local isInternalSet = true
        slider:SetValue(current)
        isInternalSet = false
        valueText:SetText(FormatSecondsText(current))

        slider:SetScript("OnValueChanged", function(self, val)
            if isInternalSet then return end
            local st = step or 1
            local rounded = math.floor((val / st) + 0.5) * st
            if rounded < minV then rounded = minV end
            if rounded > maxV then rounded = maxV end
            if rounded ~= val then
                isInternalSet = true
                self:SetValue(rounded)
                isInternalSet = false
            end
            valueText:SetText(FormatSecondsText(rounded))
            if addonTable.db and addonTable.db.settings[db_category] then
                addonTable.db.settings[db_category][db_key] = rounded
            end
        end)

        table.insert(panel._layout, {
            frame = entryFrame,
            label = label,
            desc = desc,
            afterSpacing = panel._entryAfterSpacing,
            compact = panel._compactEntries,
            extraHeight = (slider:GetHeight() or 18) + 14,
        })
        ReflowPanel(panel)

        return slider, desc, entryFrame
    end
        
    -- Ayudas de vista previa para opciones de recordatorio de moneda
    local function PreviewCoinPreWarn()
        local boss = L["COIN_REMINDER_PREVIEW"] or "Preview Boss"
        local msg = string.format(L["COIN_PRE_WARNING"] or "|cff00ff00[Loot Hunter]|r %s might have your loot. Get your coin ready!", boss)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(msg)
        else
            print(msg)
        end
        if addonTable.ShowPreWarningFrame then
            addonTable.ShowPreWarningFrame(msg, 6)
        else
            print(msg)
        end
        if PREVIEW_PREWARN_SOUND then PlaySound(PREVIEW_PREWARN_SOUND, "Master") end
    end

    local function PreviewCoinVisual()
        if addonTable.ResetPreviewVisuals then addonTable.ResetPreviewVisuals() end
        if addonTable.ShowCoinReminderVisual then
            local chatFmt = L["COIN_REMINDER_RAID_CHAT"] or L["COIN_REMINDER_RAID_MSG"]
            local chatMsg = string.format(chatFmt, L["COIN_REMINDER_PREVIEW"] or "Preview Boss")
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage(chatMsg)
            else
                print(chatMsg)
            end
            addonTable.ShowCoinReminderVisual(L["COIN_REMINDER_PREVIEW"] or "Preview Boss")
            local id = (addonTable.db and addonTable.db.settings and addonTable.db.settings.coinReminder and addonTable.db.settings.coinReminder.soundFile) or 12867
            PlaySound(id, "Master")
            return
        end
        -- Respaldo: reutilizar helper de alerta si el visual principal no esta disponible
        local boss = L["COIN_REMINDER_PREVIEW"] or "Preview Boss"
        local title = addonTable.CreateGradient and addonTable.CreateGradient(L["COIN_REMINDER_ALERT_TITLE"] or "Your loot didn't drop!", 1, 0.85, 0.35, 1, 0.75, 0) or (L["COIN_REMINDER_ALERT_TITLE"] or "Your loot didn't drop!")
        local prompt = addonTable.CreateGradient and addonTable.CreateGradient(L["COIN_REMINDER_ALERT_PROMPT"] or "Use your coin now!", 1, 0.85, 0.35, 1, 0.75, 0) or (L["COIN_REMINDER_ALERT_PROMPT"] or "Use your coin now!")
        local text = string.format("%s %s %s\n%s", ICON_DIAMOND, title, ICON_DIAMOND, prompt)
        if addonTable.ShowAlert then addonTable.ShowAlert(text, 1, 0.9, 0.15) else print(text) end
        if addonTable.FlashScreen then addonTable.FlashScreen("YELLOW") end
        local id = (addonTable.db and addonTable.db.settings and addonTable.db.settings.coinReminder and addonTable.db.settings.coinReminder.soundFile) or 12867
        PlaySound(id, "Master")
    end

    local function PreviewCoinSound()
        local id = (addonTable.db and addonTable.db.settings and addonTable.db.settings.coinReminder and addonTable.db.settings.coinReminder.soundFile) or 12867
        PlaySound(id, "Master")
    end


    -- Ayudas de vista previa para alertas de loot
    local function PreviewItemWon()
        if addonTable.ResetPreviewVisuals then addonTable.ResetPreviewVisuals() end
        local winTitle = (addonTable.CreateGradient and addonTable.CreateGradient(L["WIN_ALERT_TITLE"], 0.35, 1, 0.35, 0.65, 1, 0.65)) or (L["WIN_ALERT_TITLE"] or "Congrats! GG!")
        local winDesc = (addonTable.CreateGradient and addonTable.CreateGradient(L["WIN_ALERT_DESC"], 0.35, 1, 0.35, 0.65, 1, 0.65)) or (L["WIN_ALERT_DESC"] or "You won")
        local winBanner = string.format("%s %s %s", ICON_STAR, winTitle, ICON_STAR)
        local itemLine = "|cffa335ee[Preview Item]|r"
        if L["CONGRATS_CHAT_MSG"] then
            print(string.format(L["CONGRATS_CHAT_MSG"], itemLine))
        end
        if addonTable.FlashScreen then addonTable.FlashScreen("WIN") end
        if addonTable.ShowAlert then
            addonTable.ShowAlert(string.format("%s\n%s\n%s", winBanner, winDesc, itemLine), 0, 1, 0)
        else
            print(string.format("%s\n%s\n%s", winBanner, winDesc, itemLine))
        end
        PlaySound(12891, "Master")
    end

    local function PreviewItemSeen()
        if addonTable.ResetPreviewVisuals then addonTable.ResetPreviewVisuals() end
        local itemName = "|cffa335ee[Preview Item]|r"
        if L["DROP_CHAT_MSG"] then
            print(string.format(L["DROP_CHAT_MSG"], itemName))
        end
        if addonTable.FlashScreen then addonTable.FlashScreen("ORANGE") end
        local dropTitle = (addonTable.CreateGradient and addonTable.CreateGradient(L["DROP_ALERT_TITLE"], 1, 0.7, 0.2, 1, 0.45, 0)) or (L["DROP_ALERT_TITLE"] or "[DROP] ALERT")
        local dropHeader = string.format("%s %s %s", ICON_DIAMOND, dropTitle, ICON_DIAMOND)
        local dropItemLine = string.format("%s!", itemName)
        local dropPrompt = (addonTable.CreateGradient and addonTable.CreateGradient(L["DROP_ALERT_PROMPT"], 1, 0.85, 0.35, 1, 0.75, 0)) or (L["DROP_ALERT_PROMPT"] or "Don't forget to roll!")
        local text = string.format("%s\n%s\n%s", dropHeader, dropItemLine, dropPrompt)
        if addonTable.ShowAlert then
            addonTable.ShowAlert(text, 1, 0.55, 0.05)
        else
            print(text)
        end
        PlaySound(12867, "Master")
    end

    local function PreviewOtherWonSound()
        if addonTable.ResetPreviewVisuals then addonTable.ResetPreviewVisuals() end
        local fakeItem = "|cffa335ee[Corrupted Ashbringer]|r"
        local fakeWinner = "Arthas Menethil"
        local coloredWinner = string.format("|cffff0000%s|r", fakeWinner)
        local msg = string.format(L["DROP_OTHER_CHAT_MSG"] or "%s was won by %s.", fakeItem, coloredWinner)
        print(msg)
        if addonTable.PlayOtherWonSound then addonTable.PlayOtherWonSound(true) end
        if addonTable.FlashScreen then addonTable.FlashScreen("RED") end
        if addonTable.ShowPreWarningFrame then
            addonTable.ShowPreWarningFrame(msg, nil, false, true)
        else
            print(msg)
        end
    end

    -- ============================ 
    -- == Construir todas las categorias == 
    -- ============================ 
    local coinPanel = Settings:CreateCategory("CoinReminder", L["COIN_REMINDER_SETTINGS"])
    Settings:CreateCheckbox(coinPanel, "coinReminder.enabled", L["SETTING_COIN_ENABLE_LABEL"], L["SETTING_COIN_ENABLE_DESC"])
    Settings:CreateCheckbox(coinPanel, "coinReminder.preWarning", L["SETTING_COIN_PREWARN_LABEL"], L["SETTING_COIN_PREWARN_DESC"], nil, PreviewCoinPreWarn)
    Settings:CreateCheckbox(coinPanel, "coinReminder.visualAlert", L["SETTING_COIN_VISUAL_LABEL"], L["SETTING_COIN_VISUAL_DESC"], nil, PreviewCoinVisual)
    local _, _, lastCoinEntry = Settings:CreateCheckbox(coinPanel, "coinReminder.soundEnabled", L["SETTING_COIN_SOUND_LABEL"], L["SETTING_COIN_SOUND_DESC"], nil, PreviewCoinSound)
    Settings:CreateSlider(coinPanel, "coinReminder.reminderDelay", L["SETTING_COIN_DELAY_LABEL"], 30, 150, 5, L["SETTING_COIN_DELAY_DESC"])


    local alertsPanel = Settings:CreateCategory("LootAlerts", L["LOOT_ALERTS_SETTINGS"])
    Settings:CreateCheckbox(alertsPanel, "lootAlerts.itemWon", L["SETTING_ALERTS_WON_LABEL"], L["SETTING_ALERTS_WON_DESC"], nil, PreviewItemWon)
    Settings:CreateCheckbox(alertsPanel, "lootAlerts.itemSeen", L["SETTING_ALERTS_SEEN_LABEL"], L["SETTING_ALERTS_SEEN_DESC"], nil, PreviewItemSeen)
    Settings:CreateCheckbox(alertsPanel, "lootAlerts.otherWonSound", L["SETTING_ALERTS_OTHER_SOUND_LABEL"], L["SETTING_ALERTS_OTHER_SOUND_DESC"], nil, PreviewOtherWonSound)
    if alertsPanel._layout and alertsPanel._layout[#alertsPanel._layout] then
        alertsPanel._layout[#alertsPanel._layout].afterSpacing = (alertsPanel._layout[#alertsPanel._layout].afterSpacing or 0) + 10
        ReflowPanel(alertsPanel)
    end
    CreateSectionHeader(alertsPanel, L["SETTING_ALERTS_MISC_TITLE"], -10)
    Settings:CreateCheckbox(alertsPanel, "lootAlerts.bossNoItems", L["SETTING_ALERTS_BOSS_NONE_LABEL"], L["SETTING_ALERTS_BOSS_NONE_DESC"])

    local windowPanel = Settings:CreateCategory("Window", L["WINDOW_SETTINGS"])
    windowPanel._entryAfterSpacing = -2
    windowPanel._compactEntries = true
    CreateSectionHeader(windowPanel, L["SETTING_WINDOW_SECTION_DIMENSIONS"], 0)
    Settings:CreateCheckbox(windowPanel, "general.windowsLocked", L["SETTING_GENERAL_LOCK_LABEL"], L["SETTING_GENERAL_LOCK_DESC"])
    local function GetScaleValue()
        return addonTable.db and addonTable.db.settings and addonTable.db.settings.general and addonTable.db.settings.general.uiScale or 1
    end
    local function SetScaleValue(value)
        if not (addonTable.db and addonTable.db.settings and addonTable.db.settings.general) then return end
        addonTable.db.settings.general.uiScale = value
        if addonTable.ApplyUIScale then
            addonTable.ApplyUIScale(value)
        end
    end
    local scaleOptions = {
        { value = 0.6, label = "60%" },
        { value = 0.7, label = "70%" },
        { value = 0.8, label = "80%" },
        { value = 0.9, label = "90%" },
        { value = 1.0, label = "100%" },
        { value = 1.1, label = "110%" },
        { value = 1.2, label = "120%" },
        { value = 1.3, label = "130%" },
    }
    if windowPanel._layout and windowPanel._layout[#windowPanel._layout] then
        windowPanel._layout[#windowPanel._layout].afterSpacing = (windowPanel._layout[#windowPanel._layout].afterSpacing or 0) + 20
        ReflowPanel(windowPanel)
    end
    CreateSectionHeader(windowPanel, L["SETTING_WINDOW_SECTION_SCALE"], 0)
    CreateDropdownRow(
        windowPanel,
        "",
        scaleOptions,
        GetScaleValue,
        SetScaleValue,
        L["SETTING_GENERAL_SCALE_DESC"]
    )
    if windowPanel._layout and windowPanel._layout[#windowPanel._layout] then
        windowPanel._layout[#windowPanel._layout].afterSpacing = (windowPanel._layout[#windowPanel._layout].afterSpacing or 0) - 20
        ReflowPanel(windowPanel)
    end
    CreateSectionHeader(windowPanel, L["SETTING_WINDOW_SECTION_RESET"], 0)
    CreateButtonRow(
        windowPanel,
        L["SETTING_GENERAL_RESET_SIZE_LABEL"],
        function()
            if addonTable.ResetWindowSize then addonTable.ResetWindowSize() end
        end,
        function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L["SETTING_GENERAL_RESET_SIZE_LABEL"], 1, 1, 1)
            GameTooltip:AddLine(L["SETTING_GENERAL_RESET_SIZE_DESC"], 0.9, 0.9, 0.9, true)
            GameTooltip:Show()
        end,
        function() GameTooltip:Hide() end,
        0
    )

    local languagePanel = Settings:CreateCategory("Language", L["LANGUAGE_SETTINGS"])
    local function GetLanguageValue()
        return addonTable.db and addonTable.db.settings and addonTable.db.settings.general and addonTable.db.settings.general.language or "AUTO"
    end
    local function SetLanguageValue(value)
        if not (addonTable.db and addonTable.db.settings and addonTable.db.settings.general) then return end
        local current = addonTable.db.settings.general.language or "AUTO"
        addonTable.db.settings.general.language = value
        if value ~= current then
            ShowReloadDialog()
        end
        ReflowPanel(languagePanel)
    end
    local languageOptions = {
        { value = "AUTO", label = L["SETTING_LANGUAGE_AUTO"] },
        { value = "EN", label = L["SETTING_LANGUAGE_EN"] },
        { value = "ES", label = L["SETTING_LANGUAGE_ES"] },
    }
    CreateDropdownRow(
        languagePanel,
        "",
        languageOptions,
        GetLanguageValue,
        SetLanguageValue,
        L["SETTING_LANGUAGE_DESC"]
    )

    -- Seleccionar la primera categoria por defecto
    Settings:SelectCategory(_G["LootHunter_SettingsCategory_CoinReminder"])

    isBuilt = true
end
