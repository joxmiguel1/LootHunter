local _, addonTable = ...
local L = addonTable.L

local ACCENT_FONT = "Interface\\AddOns\\LootHunter\\Fonts\\Prototype.ttf"
local TEX_ARROW = "Interface\\AddOns\\LootHunter\\Textures\\icon_arrow.tga"
local TEX_BAG = "Interface\\Buttons\\UI-CheckBox-Check"
local TEX_EQUIPPED = "Interface\\AddOns\\LootHunter\\Textures\\icon_equipped.tga"
local TEX_EQUIPPED_FALLBACK = "Interface\\RaidFrame\\ReadyCheck-Ready"
local TEX_BONUS = "Interface\\Icons\\inv_misc_elvencoins"
local TEX_SPEAKER = "Interface\\AddOns\\LootHunter\\Textures\\icon_alert.tga"
local ENABLE_LEADERBOARD = false
local selectedSessionKey = nil
local sessionMenuFrame, sessionMenuOverlay = nil, nil

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

local function AddStatRow(parent, label, value, yOffset, valueColor)
    local row = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    row:SetText(label or "")
    SetAccentFont(row)
    local val = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    val:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    val:SetText(value or "")
    if valueColor and type(valueColor) == "table" then
        val:SetTextColor(valueColor[1] or 1, valueColor[2] or 1, valueColor[3] or 1)
    end
    SetAccentFont(val)
end

local function GetHistoryData()
    if addonTable.GetHistoryStats then
        return addonTable.GetHistoryStats()
    end
    return { drops = 0, wins = 0, losses = 0, coinReminders = 0, coinsUsed = 0, bossNoLoot = 0, lastWinAt = nil }
end

local function GetLatestSession()
    if not addonTable.GetSessionList then return nil end
    local list = addonTable.GetSessionList()
    if list and #list > 0 then
        return list[1]
    end
    return nil
end

local function FormatSince(timestamp)
    if not timestamp then return "--" end
    local now = (type(time) == "function" and time()) or 0
    local diff = math.max(0, now - timestamp)
    local days = math.floor(diff / 86400)
    local weeks = math.floor(days / 7)
    local remDays = days - (weeks * 7)
    if weeks > 0 then
        local locale = (GetLocale and GetLocale()) or "enUS"
        local isSpanish = locale and locale:lower():find("es")
        local weekWord
        if isSpanish then
            weekWord = (weeks == 1) and "semana" or "semanas"
        else
            weekWord = (weeks == 1) and "week" or "weeks"
        end
        local text = string.format("%d %s", weeks, weekWord)
        if remDays > 0 then
            text = string.format("%s %dd", text, remDays)
        end
        if weeks > 2 then
            text = "|cffff4040" .. text .. "|r"
        end
        return text
    elseif days > 0 then
        return string.format("%dd", days)
    end
    local hours = math.floor(diff / 3600)
    if hours > 0 then
        return string.format("%dh", hours)
    end
    local mins = math.floor(diff / 60)
    return string.format("%dm", mins)
end

local function GetCurrentListStats()
    local db = addonTable.CurrentCharDB
    local tracked, pending, won, priority = 0, 0, 0, 0
    if not db then return tracked, pending, won, priority end
    for id, data in pairs(db) do
        if type(id) == "number" and type(data) == "table" then
            tracked = tracked + 1
            if data.priority then priority = priority + 1 end
            if data.status == 2 then
                won = won + 1
            else
                pending = pending + 1
            end
        end
    end
    return tracked, pending, won, priority
end

local function FormatCountWithPercent(count, total)
    total = total or 0
    if total <= 0 then return tostring(count or 0) end
    local pct = math.floor(((count or 0) / total) * 100 + 0.5)
    local pctColor = "|cff555555"
    local reset = "|r"
    return string.format("%d %s(%d%%)%s", count or 0, pctColor, pct, reset)
end

local function RGBToHex(r, g, b)
    local function clamp(x) return math.max(0, math.min(1, x or 0)) end
    r, g, b = clamp(r), clamp(g), clamp(b)
    return string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function FormatPercentTag(count, total, color)
    total = total or 0
    local pct = 0
    if total > 0 then
        pct = math.floor(((count or 0) / total) * 100 + 0.5)
    end
    local hex = "555555"
    if color and type(color) == "table" then
        hex = RGBToHex(color[1], color[2], color[3])
    end
    return string.format("|cff%s(%d%%)|r", hex, pct)
end

local function GetWallOfShame(session)
    local deaths, revives = session and session.deaths or {}, session and session.revives or {}
    local deadTime = {}
    if session and session.deadTime then
        for name, seconds in pairs(session.deadTime) do
            deadTime[name] = seconds
        end
    end
    -- Include ongoing dead time even if there was no resurrect event.
    if session and session.deathStart then
        local now = (type(time) == "function" and time()) or (GetTime and GetTime()) or 0
        for name, startedAt in pairs(session.deathStart) do
            local delta = math.max(0, now - (startedAt or now))
            deadTime[name] = (deadTime[name] or 0) + delta
        end
    end
    local function topEntry(tbl)
        local bestName, bestCount = nil, 0
        for name, count in pairs(tbl or {}) do
            local c = count or 0
            if c > bestCount then
                bestName, bestCount = name, c
            end
        end
        return bestName, bestCount
    end
    local deathName, deathCount = topEntry(deaths)
    local reviveName, reviveCount = topEntry(revives)
    local deadTimeName, deadTimeSeconds = topEntry(deadTime)
    return deathName, deathCount, reviveName, reviveCount, deadTimeName, deadTimeSeconds
end

local function FormatDeadTime(seconds)
    local total = math.max(0, seconds or 0)
    local mins = math.floor(total / 60)
    local hours = math.floor(mins / 60)
    local remMins = mins - (hours * 60)
    if hours > 0 then
        return string.format("%dh %dm", hours, remMins)
    end
    return string.format("%dm", remMins)
end

local function BuildWallOfShameLines(session)
    local lines = {}
    if session then
        local raidName = session.raidName or "Raid"
        local idx = session.sessionIndex or 1
        local dateStr = (session.startedAt and type(date) == "function") and date("%m/%d/%Y", session.startedAt) or ((type(date) == "function" and date("%m/%d/%Y")) or "")
        local label = session.label or string.format("%s #%d - %s", raidName, idx, dateStr ~= "" and dateStr or "N/A")
        table.insert(lines, label)
    end
    table.insert(lines, tostring(L["STATS_ANNOUNCE_GUILD_WALL"] or "*** WALL OF SHAME ***"))
    local deathName, deathCount, reviveName, reviveCount, deadTimeName, deadTimeSeconds = GetWallOfShame(session)
    table.insert(lines, string.format(L["STATS_WALL_DEATHS"] or "Most time death - %s (%s)", deathName or "N/A", deathCount or 0))
    table.insert(lines, string.format(L["STATS_WALL_REVIVES"] or "More times revived - %s (%s)", reviveName or "N/A", reviveCount or 0))
    table.insert(lines, string.format(L["STATS_WALL_DEADTIME"] or "Most time dead - %s (%s)", deadTimeName or "N/A", FormatDeadTime(deadTimeSeconds)))
    return lines
end

local function AnnounceSessionToGuild(session, leaderboard)
    local raidName = (session and session.raidName) or (leaderboard and leaderboard.raidName) or "Raid"
    local dateStr = (session and session.startedAt and type(date) == "function") and date("%m/%d/%Y", session.startedAt) or (date and date("%m/%d/%Y") or "")
    local lb = leaderboard or {}

    local function row(text)
        return tostring(text or "")
    end
    local lines = {}
    local sep = "+----------------------------------------+"
    table.insert(lines, row(L["STATS_ANNOUNCE_GUILD_HEADER"]))
    table.insert(lines, row(string.format(L["STATS_ANNOUNCE_GUILD_DATE"], raidName, dateStr ~= "" and dateStr or "N/A")))
    table.insert(lines, sep)
    table.insert(lines, row("TOP DROPS"))
    local placements = { "1st", "2nd", "3rd" }
    for i = 1, 3 do
        local entry = lb[i]
        local txt
        if entry and entry.name and entry.name ~= "" then
            txt = string.format("%s - %s (%d items)", placements[i], entry.name, entry.count or 0)
        else
            txt = string.format("%s - --", placements[i])
        end
        table.insert(lines, row(txt))
    end
    table.insert(lines, sep)
    table.insert(lines, row(L["STATS_ANNOUNCE_GUILD_WALL"]))
    table.insert(lines, sep)
    local deathName, deathCount, reviveName, reviveCount, deadTimeName, deadTimeSeconds = GetWallOfShame(session)
    table.insert(lines, row(string.format(L["STATS_WALL_DEATHS"], deathName or "N/A", deathCount or 0)))
    table.insert(lines, row(string.format(L["STATS_WALL_REVIVES"], reviveName or "N/A", reviveCount or 0)))
    table.insert(lines, row(string.format(L["STATS_WALL_DEADTIME"] or "Most time dead - %s (%s)", deadTimeName or "N/A", FormatDeadTime(deadTimeSeconds))))
    table.insert(lines, sep)
    for _, line in ipairs(lines) do
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(line)
        else
            print(line)
        end
    end
    print(L["STATS_ANNOUNCE_SENT"])
end

local function EnsureSessionSelection()
    local list = (addonTable.GetSessionList and addonTable.GetSessionList()) or {}
    if not list or #list == 0 then
        selectedSessionKey = nil
        return list
    end
    local currentKey = addonTable.GetCurrentSessionKey and addonTable.GetCurrentSessionKey()
    if not selectedSessionKey then
        if currentKey then
            for _, entry in ipairs(list) do
                if entry.key == currentKey then
                    selectedSessionKey = currentKey
                    return list
                end
            end
        end
        selectedSessionKey = list[1].key
        return list
    end
    local found = false
    for _, entry in ipairs(list) do
        if entry.key == selectedSessionKey then
            found = true
            break
        end
    end
    if not found then
        selectedSessionKey = list[1].key
    end
    return list
end

local function HideSessionMenu()
    if sessionMenuFrame then sessionMenuFrame:Hide() end
    if sessionMenuOverlay then sessionMenuOverlay:Hide() end
end

local function ShowSessionMenu(anchor, sessions, onSelect)
    if not anchor then return end
    sessions = sessions or {}
    if not sessionMenuFrame then
        sessionMenuFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        sessionMenuFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        sessionMenuFrame:SetBackdropColor(0.12, 0.12, 0.12, 0.95)
        sessionMenuFrame:SetBackdropBorderColor(0, 0, 0, 1)
        sessionMenuFrame:SetFrameStrata("TOOLTIP")
        sessionMenuFrame:SetClampedToScreen(true)
        sessionMenuFrame:SetScript("OnHide", function()
            if sessionMenuOverlay then sessionMenuOverlay:Hide() end
        end)
    end
    if not sessionMenuOverlay then
        sessionMenuOverlay = CreateFrame("Button", nil, UIParent)
        sessionMenuOverlay:SetFrameStrata("TOOLTIP")
        sessionMenuOverlay:EnableMouse(true)
        sessionMenuOverlay:SetAllPoints(UIParent)
        sessionMenuOverlay:SetScript("OnClick", function()
            HideSessionMenu()
        end)
        sessionMenuOverlay:Hide()
    end

    for _, child in ipairs({ sessionMenuFrame:GetChildren() }) do child:Hide(); child:SetParent(nil) end

    local y = -4
    local width = math.max(180, anchor:GetWidth() or 0)
    if #sessions == 0 then
        local msg = sessionMenuFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        msg:SetPoint("TOPLEFT", 6, y)
        msg:SetPoint("TOPRIGHT", -6, y)
        msg:SetJustifyH("LEFT")
        msg:SetText(L["STATS_NO_SESSIONS"] or "No sessions yet")
        msg:SetTextColor(0.25, 0.25, 0.25)
        SetAccentFont(msg, 11)
        y = y - 20
    else
        for _, entry in ipairs(sessions) do
            local btn = CreateFrame("Button", nil, sessionMenuFrame)
            btn:SetSize(width - 8, 20)
            btn:SetPoint("TOPLEFT", 4, y)
            btn:SetNormalFontObject("GameFontHighlightSmall")
            btn:SetText(entry.label or entry.raidName or entry.key or "?")
            SetAccentFont(btn:GetFontString(), 11)
            btn:SetScript("OnClick", function()
                selectedSessionKey = entry.key
                HideSessionMenu()
                if onSelect then onSelect(entry) end
            end)
            btn:SetScript("OnEnter", function(self)
                local pr, pg, pb = GetPrimaryColor()
                self:GetFontString():SetTextColor(pr, pg, pb)
            end)
            btn:SetScript("OnLeave", function(self)
                self:GetFontString():SetTextColor(1, 1, 1)
            end)
            y = y - 20
        end
    end

    sessionMenuFrame:SetWidth(width)
    sessionMenuFrame:SetHeight(math.abs(y) + 6)
    sessionMenuFrame:ClearAllPoints()
    sessionMenuFrame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    sessionMenuOverlay:Show()
    sessionMenuFrame:Show()
end

local function AddStatBlock(parent, title, value, yOffset)
    local pr, pg, pb = GetPrimaryColor()
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    label:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(true)
    label:SetText(title or "")
    label:SetTextColor(pr, pg, pb)
    SetAccentFont(label, 13, "OUTLINE")

    local val = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    val:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
    val:SetText(value or "")
    SetAccentFont(val, 13)
end

local function BuildLeaderboard(parent, data)
    SafeSetBackdrop(parent, { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }, { 0, 0, 0, 0.15 }, { 0, 0, 0, 0.25 })

    local columns = {}
    for i = 1, 3 do
        local col = CreateFrame("Frame", nil, parent)
        col:SetSize(80, 140)
        columns[i] = col
        col:Hide()
    end

    local classColors = _G.RAID_CLASS_COLORS or {}
    local function GetClassColor(classToken)
        local c = classColors[classToken or ""] or {}
        return c.r or 1, c.g or 1, c.b or 1
    end

    local medalTextures = {
        "Interface\\AddOns\\LootHunter\\Textures\\icon_second.tga", -- second place (left)
        "Interface\\AddOns\\LootHunter\\Textures\\icon_first.tga",  -- first place (center)
        "Interface\\AddOns\\LootHunter\\Textures\\icon_third.tga",  -- third place (right)
    }

    local slotData = {}
    if data and #data > 0 then
        slotData[2] = data[1] -- first place center
        if data[2] then slotData[1] = data[2] end -- second place left
        if data[3] then slotData[3] = data[3] end -- third place right
    end

    local function LayoutColumns()
        local width = parent:GetWidth() or 0
        local padding = 14
        local usable = math.max(120, width - (padding * 2))
        local colWidth = math.max(70, usable / 3 - 6)
        local centerX = padding + (usable / 2) - (colWidth / 2)
        local positions = {
            padding,        -- left (second place)
            centerX,        -- center (first place)
            padding + usable - colWidth, -- right (third place)
        }
        for i, col in ipairs(columns) do
            col:SetWidth(colWidth)
            col:ClearAllPoints()
            col:SetPoint("TOPLEFT", parent, "TOPLEFT", positions[i], -10)
        end
    end
    parent:SetScript("OnSizeChanged", LayoutColumns)
    LayoutColumns()

    for i, col in ipairs(columns) do col:Hide() end
    for idx, info in pairs(slotData) do
        local col = columns[idx]
        if col and info and info.name and info.name ~= "" then
            col:Show()
            for _, child in ipairs({ col:GetChildren() }) do child:Hide() end
            for _, region in ipairs({ col:GetRegions() }) do region:Hide() end

            local icon = col:CreateTexture(nil, "ARTWORK")
            local scale = info.scale or 1
            local baseW, baseH = 46, 48
            local scale = info.scale or (idx == 2 and 1.25 or 1)
            local width = (baseW * scale)
            local height = (baseH * scale)
            icon:SetSize(width, height)
            local topOffset = (idx == 1 or idx == 3) and -28 or -5
            icon:SetPoint("TOP", col, "TOP", 0, topOffset)
            icon:SetTexture(medalTextures[idx] or "Interface\\Icons\\inv_misc_questionmark")
            -- Ajuste para 184x192 (recorta menos)
            icon:SetTexCoord(0.03, 0.97, 0.03, 0.97)

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
    end
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

    if not items or #items == 0 then
        local empty = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        empty:SetPoint("TOP", child, "TOP", 0, -4)
        empty:SetText(L["STATS_NO_SESSION_LOOT"] or "No drops in this session")
        empty:SetTextColor(0.25, 0.25, 0.25)
        SetAccentFont(empty, 11)
        child:SetHeight(30)
        return
    end

    local classColors = _G.RAID_CLASS_COLORS or {}
    local function getClassColor(token)
        local c = classColors[token or ""] or {}
        return c.r or 1, c.g or 1, c.b or 1
    end

    local rowHeight = 20
    local y = -2
    for idx = #items, 1, -1 do
        local info = items[idx]
        local row = CreateFrame("Frame", nil, child)
        row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
        row:SetPoint("RIGHT", child, "RIGHT", 0, 0)
        row:SetHeight(rowHeight)
        row:EnableMouse(true)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(14, 14)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        icon:SetTexture(info.icon or "Interface\\Icons\\inv_misc_questionmark")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local itemFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        itemFS:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        itemFS:SetPoint("RIGHT", row, "RIGHT", -120, 0)
        itemFS:SetJustifyH("LEFT")
        itemFS:SetWordWrap(false)
        itemFS:SetMaxLines(1)
        itemFS:SetText(info.name or info.link or "")
        itemFS:SetTextColor(0.73, 0.29, 0.93)
        SetAccentFont(itemFS, 11)

        local diceFrame = CreateFrame("Frame", nil, row)
        diceFrame:SetPoint("RIGHT", row, "RIGHT", -60, 0)
        diceFrame:SetSize(42, rowHeight)
        local diceIcon = diceFrame:CreateTexture(nil, "ARTWORK")
        diceIcon:SetSize(12, 12)
        diceIcon:SetPoint("LEFT", diceFrame, "LEFT", 0, 0)
        local rollFS = diceFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rollFS:SetPoint("LEFT", diceIcon, "RIGHT", 4, 0)
        rollFS:SetJustifyH("LEFT")
        rollFS:SetWordWrap(false)
        rollFS:SetText("")
        SetAccentFont(rollFS, 10)

        -- Loot source icon logic
        local iconTexture = TEX_BAG
        local texCoord = { 0.08, 0.92, 0.08, 0.92 }
        if info.bonus then
            iconTexture = TEX_BONUS
            texCoord = nil
        elseif info.roll then
            iconTexture = "Interface\\Buttons\\UI-GroupLoot-Dice-Up"
            texCoord = nil
            rollFS:SetText(string.format("(%s)", info.roll or 0))
        else
            -- Direct drop; use equipped check icon
            iconTexture = TEX_EQUIPPED
            texCoord = nil
            if not iconTexture or iconTexture == "" then
                iconTexture = TEX_EQUIPPED_FALLBACK
            end
        end
        diceIcon:SetTexture(iconTexture)
        if texCoord then
            diceIcon:SetTexCoord(unpack(texCoord))
        else
            diceIcon:SetTexCoord(0, 1, 0, 1)
        end

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

        row:SetScript("OnEnter", function()
            if info.link and GameTooltip then
                GameTooltip:SetOwner(row, "ANCHOR_CURSOR")
                GameTooltip:SetHyperlink(info.link)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)

        y = y - rowHeight
    end

    child:SetHeight(math.abs(y) + 10)
end
local function BuildStatsPanel(frame)
    if not frame then return end
    HideSessionMenu()
    ClearChildren(frame)

    local colLeft = CreateFrame("Frame", nil, frame)
    local colRight = CreateFrame("Frame", nil, frame)
    colLeft:SetHeight((frame:GetHeight() or 400) - 36)
    colRight:SetHeight((frame:GetHeight() or 400) - 36)

    local function UpdateColumnPositions()
        local w = frame:GetWidth() or 0
        local margin = 12
        local interGap = 20
        local available = math.max(200, w - (margin * 2) - interGap)
        local colWLeft = math.max(140, ((available - 20) / 2) - 40) -- shrink ~80px from previous width
        local colWRight = colWLeft + 95 -- give the right column ~50px extra width
        if colWLeft + colWRight > available then
            colWLeft = math.max(150, (available - 20) / 2)
            colWRight = available - colWLeft
        end
        local leftGap = margin
        colLeft:SetWidth(colWLeft)
        colRight:SetWidth(colWRight)
        colLeft:ClearAllPoints()
        colRight:ClearAllPoints()
        colLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", leftGap, -20)
        colRight:SetPoint("TOPLEFT", frame, "TOPLEFT", leftGap + colWLeft + interGap, -20)
    end
    frame:SetScript("OnSizeChanged", UpdateColumnPositions)
    UpdateColumnPositions()

    -- Left column: Current List + History
    local currentTitle = colLeft:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    currentTitle:SetPoint("TOPLEFT", colLeft, "TOPLEFT", 0, 0)
    SetSectionTitle(currentTitle, L["STATS_CURRENT_LIST"] or "Current List")
    SetAccentFont(currentTitle, 15, "OUTLINE")
    local tracked, pending, won, priority = GetCurrentListStats()
    AddStatRow(colLeft, L["STATS_ITEMS_TRACKED"] or "Items tracked", tostring(tracked), -22)
    local pr, pg, pb = GetPrimaryColor()
    local pendingTag = FormatPercentTag(pending, tracked, { 0.78, 0.78, 0.78 })
    local wonTag = FormatPercentTag(won, tracked, { (pr + 1) * 0.5, (pg + 1) * 0.5, (pb + 1) * 0.5 })
    local pendingLabel = string.format("%s %s", L["STATS_PENDING"] or "Pending", pendingTag)
    local wonLabel = string.format("%s %s", L["STATS_WON"] or "Won", wonTag)
    AddStatRow(colLeft, pendingLabel, tostring(pending), -44)
    AddStatRow(colLeft, wonLabel, tostring(won), -66)
    AddStatRow(colLeft, L["STATS_PRIORITY"] or "Priority", tostring(priority), -88)

    local historyData = GetHistoryData()
    local historyTitle = colLeft:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    historyTitle:SetPoint("TOPLEFT", colLeft, "TOPLEFT", 0, -124)
    SetSectionTitle(historyTitle, (L["STATS_HISTORY"] or "History") .. " ")
    SetAccentFont(historyTitle, 15, "OUTLINE")
    AddStatRow(colLeft, L["STATS_DROPS"] or "Drops detected", tostring(historyData.drops or 0), -146)
    AddStatRow(colLeft, L["STATS_WINS"] or "Wins", tostring(historyData.wins or 0), -168)
    AddStatRow(colLeft, L["STATS_LOSSES"] or "Losses", tostring(historyData.losses or 0), -190)
    AddStatRow(colLeft, L["STATS_REMINDERS"] or "Coin reminders", tostring(historyData.coinReminders or 0), -212)
    AddStatRow(colLeft, L["STATS_COINS_USED"] or "Coins used", tostring(historyData.coinsUsed or 0), -234)
    AddStatRow(colLeft, L["STATS_BOSS_NO_LOOT"] or "Bosses without your loot", tostring(historyData.bossNoLoot or 0), -256)
    AddStatBlock(colLeft, L["STATS_TIME_SINCE_LAST_WIN"] or "Time since last winning drop", FormatSince(historyData.lastWinAt), -284)

    -- Session context
    local sessionList = EnsureSessionSelection()
    addonTable.SelectedSessionKey = selectedSessionKey
    local sessionKey = selectedSessionKey
    local sessionLabel = L["STATS_NO_SESSIONS"] or "No sessions yet"
    if sessionList and #sessionList > 0 then
        for _, entry in ipairs(sessionList) do
            if entry.key == sessionKey then
                sessionLabel = entry.label or entry.raidName or sessionLabel
                break
            end
        end
    end
    local sessionItems = (addonTable.GetSessionItems and addonTable.GetSessionItems(sessionKey)) or nil
    local sessionLB = (addonTable.GetSessionLeaderboard and addonTable.GetSessionLeaderboard(sessionKey)) or {}

    -- Right column header + dropdowns
    local raidTitle = colRight:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    raidTitle:SetPoint("TOPLEFT", colRight, "TOPLEFT", 0, 0)
    raidTitle:SetPoint("TOPRIGHT", colRight, "TOPRIGHT", 0, 0)
    raidTitle:SetJustifyH("CENTER")
    local raidText = L["STATS_RAID_HEADER"] or "Loot Hunters"
    if addonTable.CreateGradient then
        raidText = addonTable.CreateGradient(raidText, 1.0, 0.85, 0.35, 1.0, 0.65, 0.0)
        raidTitle:SetText(raidText)
    else
        SetSectionTitle(raidTitle, raidText)
    end
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
        btn._text = fs
        local arrow = btn:CreateTexture(nil, "OVERLAY")
        arrow:SetSize(10, 10)
        arrow:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
        arrow:SetTexture(TEX_ARROW)
        local pr, pg, pb = GetPrimaryColor()
        arrow:SetVertexColor(pr, pg, pb, 1)
        return btn
    end

    local ddRaid = CreateDropdown(dropdownRow, sessionLabel)
    ddRaid:ClearAllPoints()
    ddRaid:SetPoint("LEFT", dropdownRow, "LEFT", 0, 0)
    ddRaid:SetPoint("RIGHT", dropdownRow, "RIGHT", 0, 0)
    ddRaid:SetHeight(22)
    if ddRaid.SetBackdropColor then
        ddRaid:SetBackdropColor(0.12, 0.12, 0.12, 1)
        ddRaid:SetBackdropBorderColor(0, 0, 0, 1)
    end
    ddRaid:SetScript("OnClick", function()
        ShowSessionMenu(ddRaid, sessionList, function()
            local newLabel = L["STATS_NO_SESSIONS"] or "No sessions yet"
            if sessionList then
                for _, entry in ipairs(sessionList) do
                    if entry.key == selectedSessionKey then
                        newLabel = entry.label or entry.raidName or newLabel
                        break
                    end
                end
            end
            if ddRaid._text then
                ddRaid._text:SetText(newLabel or "")
            end
            BuildStatsPanel(frame)
        end)
    end)

    -- Leaderboard (hidden in this build)
    local leaderboard = CreateFrame("Frame", nil, colRight, "BackdropTemplate")
    leaderboard:SetPoint("TOPLEFT", dropdownRow, "BOTTOMLEFT", 0, -1)
    leaderboard:SetPoint("RIGHT", colRight, "RIGHT", 0, 0)
    leaderboard:SetHeight(ENABLE_LEADERBOARD and 130 or 1)
    local lbData = {}
    if ENABLE_LEADERBOARD then
        lbData = sessionLB or {}
        if not lbData or #lbData == 0 then
            local empty = leaderboard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            empty:SetPoint("CENTER", leaderboard, "CENTER", 0, 0)
            empty:SetText(L["STATS_NO_SESSION_DATA"] or "Session data pending")
            empty:SetTextColor(0.25, 0.25, 0.25)
            SetAccentFont(empty, 12)
        else
            if #lbData > 3 then
                while #lbData > 3 do table.remove(lbData, #lbData) end
            elseif #lbData < 3 then
                for i = #lbData + 1, 3 do
                    lbData[i] = { name = "", class = nil, count = 0, scale = 0.6 }
                end
            end
            pcall(BuildLeaderboard, leaderboard, lbData)
        end
        local announceBtn = CreateFrame("Button", nil, leaderboard)
        announceBtn:SetSize(18, 18)
        announceBtn:SetPoint("TOPRIGHT", leaderboard, "TOPRIGHT", -4, -4)
        announceBtn:SetNormalTexture(TEX_SPEAKER)
        announceBtn:SetHighlightTexture(TEX_SPEAKER)
        announceBtn:SetAlpha(0.9)
        announceBtn:SetScript("OnEnter", function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
                GameTooltip:SetText(L["STATS_ANNOUNCE_GUILD_TOOLTIP"] or "Announce to guild")
                GameTooltip:Show()
            end
        end)
        announceBtn:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
        announceBtn:SetScript("OnClick", function()
            local session = addonTable.GetSessionByKey and addonTable.GetSessionByKey(sessionKey)
            AnnounceSessionToGuild(session, lbData)
        end)
    else
        leaderboard:Hide()
    end

    local lootHeader = colRight:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    if ENABLE_LEADERBOARD then
        lootHeader:SetPoint("TOP", leaderboard, "BOTTOM", 0, -10)
    else
        lootHeader:SetPoint("TOP", dropdownRow, "BOTTOM", 0, -10)
    end
    lootHeader:SetText(L["STATS_LOOT_HISTORY"] or "Loot history")
    SetAccentFont(lootHeader, 12, "OUTLINE")

    -- Contenedor oscuro placeholder para loot (sin contenido)
    local lootContainer = CreateFrame("Frame", nil, colRight, "BackdropTemplate")
    lootContainer:SetPoint("TOP", lootHeader, "BOTTOM", 0, -8)
    lootContainer:SetPoint("LEFT", colRight, "LEFT", 0, 0)
    lootContainer:SetPoint("RIGHT", colRight, "RIGHT", 0, 0)
    lootContainer:SetHeight(300)
    SafeSetBackdrop(lootContainer, { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }, { 0, 0, 0, 0.5 }, { 0, 0, 0, 0.8 })

    BuildLootList(lootContainer, sessionItems)

end

addonTable.BuildStatsPanelInto = function(frame)
    BuildStatsPanel(frame)
end

addonTable.AnnounceWallOfShame = function(channel, sessionKey)
    local key = sessionKey
    if not key and addonTable.SelectedSessionKey then
        key = addonTable.SelectedSessionKey
    end
    if not key and addonTable.GetCurrentSessionKey then
        key = addonTable.GetCurrentSessionKey()
    end
    if not key and addonTable.GetLatestSessionKey then
        key = addonTable.GetLatestSessionKey()
    end
    local session = addonTable.GetSessionByKey and addonTable.GetSessionByKey(key)
    if not session then
        print(L["STATS_NO_SESSIONS"] or "No sessions yet")
        return
    end
    local lines = BuildWallOfShameLines(session)
    local function SanitizeForChat(text)
        text = tostring(text or "")
        text = text:gsub("|T.-|t", "{skull}")
        return text
    end
    local sendChannel = channel and tostring(channel):upper() or "LOCAL"
    if sendChannel ~= "LOCAL" then
        if not (IsInGuild and IsInGuild()) then
            if sendChannel == "GUILD" then
                print(L["STATS_ANNOUNCE_NO_GUILD"] or "You are not in a guild.")
                return
            end
        end
        if C_Timer and C_Timer.After then
            for i, line in ipairs(lines) do
                C_Timer.After((i - 1) * 0.2, function()
                    SendChatMessage(SanitizeForChat(line), sendChannel)
                end)
            end
        else
            for _, line in ipairs(lines) do
                SendChatMessage(SanitizeForChat(line), sendChannel)
            end
        end
        print(L["STATS_ANNOUNCE_SENT"] or "Announcement sent to guild.")
    else
        for _, line in ipairs(lines) do
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage(line)
            else
                print(line)
            end
        end
    end
end
