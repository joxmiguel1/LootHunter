local _, addonTable = ...
local L = addonTable.L

local ACCENT_FONT = "Interface\\AddOns\\LootHunter\\Fonts\\Prototype.ttf"
local TEX_ARROW = "Interface\\AddOns\\LootHunter\\Textures\\icon_arrow.tga"

local function ClearChildren(frame)
    for _, child in ipairs({ frame:GetChildren() }) do child:Hide(); child:SetParent(nil) end
    for _, region in ipairs({ frame:GetRegions() }) do region:Hide() end
end

local function GetPrimaryColor()
    if addonTable.GetPrimaryColor then
        return addonTable.GetPrimaryColor()
    end
    return 0.47, 0.71, 0.17
end

local function SetSectionTitle(fs, text)
    if not fs then return end
    local pr, pg, pb = GetPrimaryColor()
    fs:SetText(text or "")
    fs:SetTextColor(pr, pg, pb)
end

local function SetAccentFont(fs, size, flags)
    if not fs then return end
    local _, defaultSize, defaultFlags = fs:GetFont()
    fs:SetFont(ACCENT_FONT, size or defaultSize or 12, flags or defaultFlags)
end

local function SafeSetBackdrop(frame, opts, bgColor, borderColor)
    if frame and frame.SetBackdrop then
        frame:SetBackdrop(opts)
        if frame.SetBackdropColor and bgColor then frame:SetBackdropColor(unpack(bgColor)) end
        if frame.SetBackdropBorderColor and borderColor then frame:SetBackdropBorderColor(unpack(borderColor)) end
    end
end

local function AddStatRow(parent, label, value, yOffset)
    local row = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    row:SetText(label or "")
    SetAccentFont(row)
    local val = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    val:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    val:SetText(value or "")
    SetAccentFont(val)
end

local function AddStatBlock(parent, title, value, yOffset)
    local pr, pg, pb = GetPrimaryColor()
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    label:SetText(title or "")
    label:SetTextColor(pr, pg, pb)
    SetAccentFont(label, 12, "OUTLINE")

    local val = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    val:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset - 16)
    val:SetText(value or "")
    SetAccentFont(val, 12)
end

local function BuildLeaderboard(parent, data)
    SafeSetBackdrop(parent, { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }, { 0, 0, 0, 0.5 }, { 0, 0, 0, 0.8 })

    local columns = {}
    for i = 1, 3 do
        local col = CreateFrame("Frame", nil, parent)
        col:SetSize(80, 140)
        columns[i] = col
    end

    local function LayoutColumns()
        local width = parent:GetWidth() or 0
        local padding = 14
        local usable = math.max(120, width - (padding * 2))
        local colWidth = math.max(70, usable / 3 - 6)
        local offsets = {
            padding,
            padding + colWidth + 12,
            padding + (colWidth + 12) * 2,
        }
        for i, col in ipairs(columns) do
            col:SetWidth(colWidth)
            col:ClearAllPoints()
            col:SetPoint("TOPLEFT", parent, "TOPLEFT", offsets[i], -10)
        end
    end
    parent:SetScript("OnSizeChanged", LayoutColumns)

    local classColors = _G.RAID_CLASS_COLORS or {}
    local function GetClassColor(classToken)
        local c = classColors[classToken or ""] or {}
        return c.r or 1, c.g or 1, c.b or 1
    end

    local medalTextures = {
        "Interface\\Icons\\inv_helm_mask_zulgurub_d_01", -- second
        "Interface\\Icons\\inv_helm_mask_zulgurub_d_01", -- first (placeholder)
        "Interface\\Icons\\inv_helm_mask_zulgurub_d_01", -- third
    }

    for idx, info in ipairs(data) do
        local col = columns[idx]
        local icon = col:CreateTexture(nil, "ARTWORK")
        local scale = info.scale or 1
        icon:SetSize(56 * scale, 56 * scale)
        local topOffset = (idx == 1 or idx == 3) and -40 or -5
        icon:SetPoint("TOP", col, "TOP", 0, topOffset)
        icon:SetTexture(medalTextures[idx] or "Interface\\Icons\\inv_misc_questionmark")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local nameFS = col:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameFS:SetPoint("TOP", icon, "BOTTOM", 0, -8)
        nameFS:SetText(info.name or "")
        nameFS:SetTextColor(GetClassColor(info.class))
        SetAccentFont(nameFS, 14, "OUTLINE")

        local countFS = col:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        countFS:SetPoint("TOP", nameFS, "BOTTOM", 0, -4)
        countFS:SetText(string.format("%s items", info.count or 0))
        countFS:SetTextColor(0.9, 0.9, 0.9)
        SetAccentFont(countFS, 11)
    end

    LayoutColumns()
end

local function BuildLootList(parent, items)
    for _, child in ipairs({ parent:GetChildren() }) do child:Hide(); child:SetParent(nil) end
    for _, region in ipairs({ parent:GetRegions() }) do region:Hide() end

    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 4)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(parent:GetWidth() or 320, 1)
    scroll:SetScrollChild(child)
    scroll:SetScript("OnSizeChanged", function(_, w)
        child:SetWidth(w or (parent:GetWidth() or 320))
    end)

    local sampleItems = items and #items > 0 and items or {
        { name = "Suen-Wo, Spire of the Falling Sun", player = "Xamael", class = "WARLOCK", roll = 99, icon = "Interface\\Icons\\inv_staff_2h_thunderisleraid_d_01" },
        { name = "Astral Gladiator's Fel Bat", player = "Pandacetamol", class = "SHAMAN", roll = 87, icon = "Interface\\Icons\\inv_batpet" },
        { name = "Shin'kak, the Forbidden", player = "Vicvapodruid", class = "DRUID", roll = 45, icon = "Interface\\Icons\\inv_staff_2h_pvpdraenors1_d_01" },
        { name = "Girdle of Night and Day", player = "Arkaboy", class = "SHAMAN", roll = 12, icon = "Interface\\Icons\\inv_belt_armor_maldraxxus_d_01" },
        { name = "Sigil of the Black Hand", player = "Unholykratox", class = "WARLOCK", roll = 54, icon = "Interface\\Icons\\inv_trinket_maldraxxus_02" },
        { name = "Eye of Command", player = "Pandacetamol", class = "SHAMAN", roll = 76, icon = "Interface\\Icons\\inv_misc_eye_04" },
    }

    local classColors = _G.RAID_CLASS_COLORS or {}
    local function getClassColor(token)
        local c = classColors[token or ""] or {}
        return c.r or 1, c.g or 1, c.b or 1
    end

    local rowHeight = 24
    local y = -2
    for _, info in ipairs(sampleItems) do
        local row = CreateFrame("Frame", nil, child)
        row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
        row:SetPoint("RIGHT", child, "RIGHT", 0, 0)
        row:SetHeight(rowHeight)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        icon:SetTexture(info.icon or "Interface\\Icons\\inv_misc_questionmark")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local itemFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        itemFS:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        itemFS:SetPoint("RIGHT", row, "RIGHT", -120, 0)
        itemFS:SetJustifyH("LEFT")
        itemFS:SetWordWrap(false)
        itemFS:SetMaxLines(1)
        itemFS:SetText(info.name or "")
        itemFS:SetTextColor(0.73, 0.29, 0.93)
        SetAccentFont(itemFS, 11)

        local diceFrame = CreateFrame("Frame", nil, row)
        diceFrame:SetPoint("RIGHT", row, "RIGHT", -60, 0)
        diceFrame:SetSize(40, rowHeight)
        local diceIcon = diceFrame:CreateTexture(nil, "ARTWORK")
        diceIcon:SetSize(16, 16)
        diceIcon:SetPoint("LEFT", diceFrame, "LEFT", 0, 0)
        diceIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up")
        local rollFS = diceFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rollFS:SetPoint("LEFT", diceIcon, "RIGHT", 2, 0)
        rollFS:SetJustifyH("LEFT")
        rollFS:SetWordWrap(false)
        rollFS:SetText(string.format("(%s)", info.roll or 0))
        SetAccentFont(rollFS, 10)

        local playerFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        playerFS:SetPoint("LEFT", row, "RIGHT", -50, 0)
        playerFS:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        playerFS:SetJustifyH("LEFT")
        playerFS:SetWordWrap(false)
        playerFS:SetMaxLines(1)
        playerFS:SetText(info.player or "")
        local cr, cg, cb = getClassColor(info.class)
        playerFS:SetTextColor(cr, cg, cb)
        SetAccentFont(playerFS, 11)

        y = y - rowHeight
    end

    child:SetHeight(math.abs(y) + 10)
end
local function BuildStatsPanel(frame)
    if not frame then return end
    ClearChildren(frame)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -12)
    title:SetText(L["TAB_STATS"] or "Statistics")
    local pr, pg, pb = GetPrimaryColor()
    title:SetTextColor(pr, pg, pb)
    SetAccentFont(title, 20, "OUTLINE")

    local colLeft = CreateFrame("Frame", nil, frame)
    local colRight = CreateFrame("Frame", nil, frame)
    colLeft:SetHeight((frame:GetHeight() or 400) - 60)
    colRight:SetHeight((frame:GetHeight() or 400) - 60)

    local function UpdateColumnPositions()
        local w = frame:GetWidth() or 0
        local margin = 12
        local interGap = 20
        local available = math.max(200, w - (margin * 2) - interGap)
        local colWLeft = math.max(140, ((available - 20) / 2) - 40) -- shrink ~80px from previous width
        local colWRight = colWLeft + 20
        if colWLeft + colWRight > available then
            colWLeft = math.max(150, (available - 20) / 2)
            colWRight = available - colWLeft
        end
        local leftGap = margin
        colLeft:SetWidth(colWLeft)
        colRight:SetWidth(colWRight)
        colLeft:ClearAllPoints()
        colRight:ClearAllPoints()
        colLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", leftGap, -50)
        colRight:SetPoint("TOPLEFT", frame, "TOPLEFT", leftGap + colWLeft + interGap, -50)
    end
    frame:SetScript("OnSizeChanged", UpdateColumnPositions)
    UpdateColumnPositions()

    -- Left column: Current List + History
    local currentTitle = colLeft:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    currentTitle:SetPoint("TOPLEFT", colLeft, "TOPLEFT", 0, 0)
    SetSectionTitle(currentTitle, L["STATS_CURRENT_LIST"] or "Current List")
    SetAccentFont(currentTitle, 16, "OUTLINE")
    AddStatRow(colLeft, L["STATS_ITEMS_TRACKED"] or "Items tracked", "20", -22)
    AddStatRow(colLeft, L["STATS_PENDING"] or "Pending", "17", -44)
    AddStatRow(colLeft, L["STATS_WON"] or "Won", "3", -66)
    AddStatRow(colLeft, L["STATS_PRIORITY"] or "Priority", "5", -88)

    local historyTitle = colLeft:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    historyTitle:SetPoint("TOPLEFT", colLeft, "TOPLEFT", 0, -124)
    SetSectionTitle(historyTitle, (L["STATS_HISTORY"] or "History") .. " ")
    SetAccentFont(historyTitle, 16, "OUTLINE")
    AddStatRow(colLeft, L["STATS_DROPS"] or "Drops detected", "0", -146)
    AddStatRow(colLeft, L["STATS_WINS"] or "Wins", "0", -168)
    AddStatRow(colLeft, L["STATS_LOSSES"] or "Losses", "0", -190)
    AddStatRow(colLeft, L["STATS_REMINDERS"] or "Coin reminders", "0", -212)
    AddStatRow(colLeft, L["STATS_COINS_USED"] or "Coins used", "0", -234)
    AddStatRow(colLeft, L["STATS_BOSS_NO_LOOT"] or "Bosses without your loot", "0", -256)
    AddStatBlock(colLeft, "Tiempo desde el último drop ganador", "2d 4h", -284)
    AddStatBlock(colLeft, "Semanas sin loot", "3", -318)

    -- Right column header + dropdowns
    local raidTitle = colRight:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    raidTitle:SetPoint("TOPLEFT", colRight, "TOPLEFT", 0, 0)
    SetSectionTitle(raidTitle, L["STATS_RAID_HEADER"] or "Triumvirate of the Mists")
    SetAccentFont(raidTitle, 16, "OUTLINE")

    local dropdownRow = CreateFrame("Frame", nil, colRight, "BackdropTemplate")
    dropdownRow:SetPoint("TOPLEFT", raidTitle, "BOTTOMLEFT", 0, -8)
    dropdownRow:SetPoint("RIGHT", colRight, "RIGHT", 0, 0)
    dropdownRow:SetHeight(26)

    local function CreateDropdown(parent, text)
        local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
        btn:SetHeight(22)
        SafeSetBackdrop(btn, { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }, { 0.12, 0.12, 0.12, 1 }, { 0, 0, 0, 1 })
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", btn, "LEFT", 8, 0)
        fs:SetPoint("RIGHT", btn, "RIGHT", -18, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        fs:SetText(text or "")
        SetAccentFont(fs, 11)
        local arrow = btn:CreateTexture(nil, "OVERLAY")
        arrow:SetSize(10, 10)
        arrow:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
        arrow:SetTexture(TEX_ARROW)
        local pr, pg, pb = GetPrimaryColor()
        arrow:SetVertexColor(pr, pg, pb, 1)
        return btn
    end

    local ddRaid = CreateDropdown(dropdownRow, "Throne of Thunder  |  1/22/2026")
    ddRaid:ClearAllPoints()
    ddRaid:SetPoint("LEFT", dropdownRow, "LEFT", 0, 0)
    ddRaid:SetPoint("RIGHT", dropdownRow, "RIGHT", 80, 0)
    ddRaid:SetHeight(22)
    if ddRaid.SetBackdropColor then
        ddRaid:SetBackdropColor(0.12, 0.12, 0.12, 1)
        ddRaid:SetBackdropBorderColor(0, 0, 0, 1)
    end

    -- Leaderboard
    local leaderboard = CreateFrame("Frame", nil, colRight, "BackdropTemplate")
    leaderboard:SetPoint("TOPLEFT", dropdownRow, "BOTTOMLEFT", 0, -1)
    leaderboard:SetPoint("RIGHT", colRight, "RIGHT", 80, 0)
    leaderboard:SetHeight(130)
    local okLead = pcall(BuildLeaderboard, leaderboard, {
        { name = "Pandacetamol", class = "SHAMAN", count = 6, scale = 0.6 },
        { name = "Unholykratox", class = "WARLOCK", count = 16, scale = 0.8 },
        { name = "Vicvapodruid", class = "DEATHKNIGHT", count = 4, scale = 0.6 },
    })

    local lootHeader = colRight:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    lootHeader:SetPoint("TOP", leaderboard, "BOTTOM", 0, -10)
    lootHeader:SetText("Historial de loot")
    SetAccentFont(lootHeader, 14, "OUTLINE")

    -- Contenedor oscuro placeholder para loot (sin contenido)
    local lootContainer = CreateFrame("Frame", nil, colRight, "BackdropTemplate")
    lootContainer:SetPoint("TOP", lootHeader, "BOTTOM", 0, -8)
    lootContainer:SetPoint("LEFT", colRight, "LEFT", 0, 0)
    lootContainer:SetPoint("RIGHT", colRight, "RIGHT", 65, 0)
    lootContainer:SetHeight(150)
    SafeSetBackdrop(lootContainer, { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }, { 0, 0, 0, 0.5 }, { 0, 0, 0, 0.8 })

    BuildLootList(lootContainer)

    if not okLead then
        local err = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        err:SetPoint("TOP", frame, "TOP", 0, -40)
        err:SetTextColor(1, 0.3, 0.3)
        err:SetText(L["STATS_PLACEHOLDER"] or "Statistics are coming soon.")
    end
end

addonTable.BuildStatsPanelInto = function(frame)
    BuildStatsPanel(frame)
end
