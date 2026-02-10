local _, addonTable = ...
local L = addonTable.L

local ACCENT_FONT = "Interface\\AddOns\\LootHunter\\Fonts\\Prototype.ttf"
local TEX_ARROW = "Interface\\AddOns\\LootHunter\\Textures\\icon_arrow.tga"
local TEX_BAG = "Interface\\Buttons\\UI-CheckBox-Check"
local TEX_EQUIPPED = "Interface\\AddOns\\LootHunter\\Textures\\icon_equipped.tga"
local TEX_EQUIPPED_FALLBACK = "Interface\\RaidFrame\\ReadyCheck-Ready"
local TEX_BONUS = "Interface\\Icons\\inv_misc_elvencoins"
local selectedSessionKey = nil
local sessionMenuFrame, sessionMenuOverlay = nil, nil

local function ForEachChild(frame, fn)
    if not frame or not frame.GetChildren then return end
    local n = select("#", frame:GetChildren())
    for i = 1, n do
        local child = select(i, frame:GetChildren())
        if child then fn(child) end
    end
end

local function DrainChildren(frame, fn)
    if not frame or not frame.GetChildren then return end
    local child = frame:GetChildren()
    while child do
        fn(child)
        child = frame:GetChildren()
    end
end

local function ForEachRegion(frame, fn)
    if not frame or not frame.GetRegions then return end
    local n = select("#", frame:GetRegions())
    for i = 1, n do
        local region = select(i, frame:GetRegions())
        if region then fn(region) end
    end
end

local function ClearChildren(frame)
    DrainChildren(frame, function(child)
        child:Hide()
        child:SetParent(nil)
    end)
    ForEachRegion(frame, function(region)
        region:Hide()
    end)
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

local function FormatSince(timestamp)
    if not timestamp then return "--" end
    local now = (type(time) == "function" and time()) or 0
    local diff = math.max(0, now - timestamp)
    local days = math.floor(diff / 86400)
    local weeks = math.floor(days / 7)
    local remDays = days - (weeks * 7)
    local remHours = math.floor((diff - (days * 86400)) / 3600)
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
        text = string.format("%s %dd %dh", text, remDays, remHours)
        if weeks > 2 then
            text = "|cffff4040" .. text .. "|r"
        end
        return text
    elseif days > 0 then
        return string.format("%dd %dh", days, remHours)
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

local function EnsureSessionSelection()
    local list = (addonTable.GetSessionList and addonTable.GetSessionList()) or {}
    if not list or #list == 0 then
        selectedSessionKey = nil
        return list
    end
    if not selectedSessionKey then
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
        sessionMenuFrame:SetClipsChildren(true)
        sessionMenuFrame:SetScript("OnHide", function()
            if sessionMenuOverlay then sessionMenuOverlay:Hide() end
        end)
    end
    if not sessionMenuOverlay then
        sessionMenuOverlay = CreateFrame("Button", nil, UIParent)
        sessionMenuOverlay:SetFrameStrata("LOW")
        sessionMenuOverlay:SetFrameLevel(1)
        sessionMenuOverlay:EnableMouse(true)
        sessionMenuOverlay:SetAllPoints(UIParent)
        sessionMenuOverlay:SetScript("OnClick", function()
            HideSessionMenu()
        end)
        sessionMenuOverlay:Hide()
    end

    DrainChildren(sessionMenuFrame, function(child)
        child:Hide()
        child:SetParent(nil)
    end)

    local y = -4
    local rowHeight = 20
    local width = math.max(180, anchor:GetWidth() or 0)
    if #sessions == 0 then
        local msg = sessionMenuFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        msg:SetPoint("TOPLEFT", 6, y)
        msg:SetPoint("TOPRIGHT", -6, y)
        msg:SetJustifyH("LEFT")
        msg:SetText(L["STATS_NO_SESSIONS"] or "No sessions yet")
        msg:SetTextColor(0.25, 0.25, 0.25)
        SetAccentFont(msg, 11)
        y = y - rowHeight
    else
        for _, entry in ipairs(sessions) do
            local entryData = entry
            local entryKey = entryData and entryData.key or nil
            local entryLabel = entryData and (entryData.label or entryData.raidName or entryData.key) or "?"
            local btn = CreateFrame("Button", nil, sessionMenuFrame)
            btn:SetSize(width - 8, rowHeight)
            btn:SetPoint("TOPLEFT", 4, y)
            btn:SetNormalFontObject("GameFontHighlightSmall")
            btn:SetText(entryLabel or "?")
            btn:SetFrameStrata("TOOLTIP")
            btn:SetFrameLevel((sessionMenuFrame:GetFrameLevel() or 1) + 1)
            local btnFS = btn:GetFontString()
            if btnFS then
                SetAccentFont(btnFS, 11)
                btnFS:ClearAllPoints()
                btnFS:SetPoint("LEFT", btn, "LEFT", 6, 0)
                btnFS:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
                btnFS:SetJustifyH("LEFT")
            end
            btn:SetScript("OnClick", function()
                selectedSessionKey = entryKey
                HideSessionMenu()
                if onSelect then onSelect(entryData) end
            end)
            btn:SetScript("OnEnter", function(self)
                local pr, pg, pb = GetPrimaryColor()
                self:GetFontString():SetTextColor(pr, pg, pb)
            end)
            btn:SetScript("OnLeave", function(self)
                self:GetFontString():SetTextColor(1, 1, 1)
            end)
            y = y - rowHeight
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

local function BuildLootList(parent, items)
    local scroll = parent._lootScroll
    local child = parent._lootScrollChild
    parent._lootLastItems = items
    local scrollOffset = scroll and scroll.GetVerticalScroll and scroll:GetVerticalScroll() or 0
    if scroll and child then
        DrainChildren(child, function(sub)
            sub:Hide()
            sub:SetParent(nil)
        end)
        ForEachRegion(child, function(region)
            region:Hide()
        end)
    else
        DrainChildren(parent, function(sub)
            sub:Hide()
            sub:SetParent(nil)
        end)
        ForEachRegion(parent, function(region)
            region:Hide()
        end)
        scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4)
        scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 4)
        child = CreateFrame("Frame", nil, scroll)
        child:SetSize(parent:GetWidth() or 320, 1)
        scroll:SetScrollChild(child)
        scroll:SetScript("OnSizeChanged", function(_, w)
            child:SetWidth(w or (parent:GetWidth() or 320))
        end)
        parent._lootScroll = scroll
        parent._lootScrollChild = child
    end

    if not items or #items == 0 then
        local empty = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        empty:SetPoint("TOP", child, "TOP", 0, -4)
        empty:SetText(L["STATS_NO_SESSION_LOOT"] or "No drops in this session")
        empty:SetTextColor(0.25, 0.25, 0.25)
        SetAccentFont(empty, 11)
        child:SetHeight(30)
        if scroll and scroll.SetVerticalScroll then
            scroll:SetVerticalScroll(0)
        end
        return
    end

    local classColors = _G.RAID_CLASS_COLORS or {}
    local function getClassColor(token)
        local c = classColors[token or ""] or {}
        return c.r or 1, c.g or 1, c.b or 1
    end

    if C_Item and C_Item.RequestLoadItemDataByID then
        local needsRefresh = false
        for _, info in ipairs(items) do
            local id = info and info.itemID
            if id then
                local cached = C_Item.IsItemDataCachedByID and C_Item.IsItemDataCachedByID(id)
                if not cached and GetItemInfo then
                    local name = GetItemInfo(id)
                    cached = name ~= nil
                end
                if not cached then
                    C_Item.RequestLoadItemDataByID(id)
                    needsRefresh = true
                end
            end
        end
        if needsRefresh and not parent._lootPrefetchScheduled and C_Timer and C_Timer.After then
            parent._lootPrefetchScheduled = true
            C_Timer.After(0.2, function()
                parent._lootPrefetchScheduled = false
                if parent._lootLastItems == items then
                    BuildLootList(parent, items)
                end
            end)
        end
    end

    local qualityCache = {}
    local function CacheKey(info)
        if info.itemID then return tostring(info.itemID) end
        if info.link then return tostring(info.link) end
        return nil
    end
    local function GetQualityFromEntry(info)
        if not info then return nil end
        local key = CacheKey(info)
        if key and qualityCache[key] ~= nil then
            return qualityCache[key]
        end
        local quality = info.quality
        if quality ~= nil then
            if key then qualityCache[key] = quality end
            return quality
        end
        quality = nil
        if info.itemID and C_Item and C_Item.GetItemQualityByID then
            quality = C_Item.GetItemQualityByID(info.itemID)
        end
        if not quality and info.itemID and GetItemInfo then
            quality = select(3, GetItemInfo(info.itemID))
        end
        if not quality and info.link and GetItemInfo then
            quality = select(3, GetItemInfo(info.link))
        end
        if not quality and info.link and type(info.link) == "string" and _G.ITEM_QUALITY_COLORS then
            local hex = info.link:match("|c(%x%x%x%x%x%x%x%x)")
            if hex then
                hex = hex:lower()
                for q, data in pairs(_G.ITEM_QUALITY_COLORS) do
                    if data and data.colorHex and data.colorHex:lower() == hex then
                        quality = q
                        break
                    end
                end
            end
        end
        if key then qualityCache[key] = quality end
        return quality
    end

    local function AddLootRow(info, y, rowHeight)
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
        return y - rowHeight
    end

    local rowHeight = 20
    local y = -2

    local function AddSection(title, count, entries, titleColor, useGradient)
        if not entries or #entries == 0 then return end
        local header = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
        local label = string.format("%s (%d)", title or "", count or 0)
        if useGradient and addonTable.CreateGradient then
            label = addonTable.CreateGradient(label, 1, 0.85, 0.35, 1, 0.75, 0)
            header:SetText(label)
        else
            header:SetText(label)
            if titleColor then
                header:SetTextColor(titleColor[1] or 1, titleColor[2] or 1, titleColor[3] or 1)
            end
        end
        SetAccentFont(header, 12, "OUTLINE")
        y = y - 18
        for _, info in ipairs(entries) do
            y = AddLootRow(info, y, rowHeight)
        end
        y = y - 6
    end

    local legendaryItems = {}
    local epicItems = {}
    local rareItems = {}
    local uncommonItems = {}
    for idx = #items, 1, -1 do
        local info = items[idx]
        local quality = GetQualityFromEntry(info)
        if quality == 5 then
            legendaryItems[#legendaryItems + 1] = info
        elseif quality == 4 then
            epicItems[#epicItems + 1] = info
        elseif quality == 3 then
            rareItems[#rareItems + 1] = info
        elseif quality == 2 then
            uncommonItems[#uncommonItems + 1] = info
        end
    end
    local function SortByNewest(a, b)
        return (a and a.time or 0) > (b and b.time or 0)
    end
    table.sort(legendaryItems, SortByNewest)
    table.sort(epicItems, SortByNewest)
    table.sort(rareItems, SortByNewest)
    table.sort(uncommonItems, SortByNewest)

    local legendLabel = L["STATS_LOOT_LEGENDARY"] or "Legendary"
    local epicLabel = L["STATS_LOOT_EPIC"] or "Epic"
    local rareLabel = L["STATS_LOOT_RARE"] or "Rare"
    local uncommonLabel = L["STATS_LOOT_UNCOMMON"] or "Uncommon"
    local qualityColors = _G.ITEM_QUALITY_COLORS or {}
    local epicColor = qualityColors[4] and { qualityColors[4].r, qualityColors[4].g, qualityColors[4].b } or { 0.64, 0.21, 0.93 }
    local rareColor = qualityColors[3] and { qualityColors[3].r, qualityColors[3].g, qualityColors[3].b } or { 0, 0.44, 0.87 }
    local uncommonColor = qualityColors[2] and { qualityColors[2].r, qualityColors[2].g, qualityColors[2].b } or { 0.12, 1, 0 }

    AddSection(legendLabel, #legendaryItems, legendaryItems, nil, true)
    AddSection(epicLabel, #epicItems, epicItems, epicColor, false)
    AddSection(rareLabel, #rareItems, rareItems, rareColor, false)
    AddSection(uncommonLabel, #uncommonItems, uncommonItems, uncommonColor, false)

    child:SetHeight(math.abs(y) + 10)
    if scroll and scroll.SetVerticalScroll then
        scroll:SetVerticalScroll(scrollOffset)
    end
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

    local lootHeader = colRight:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    lootHeader:SetPoint("TOP", dropdownRow, "BOTTOM", 0, -10)
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
