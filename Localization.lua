local addonName, addonTable = ...
-- Creamos la tabla L. Si una clave no existe, devolver la propia clave (para evitar errores nil)
local L = setmetatable({}, { __index = function(t, k) return k end })
addonTable.L = L

-- Primary UI color (update here to re-theme accents across the addon).
addonTable.PRIMARY_COLOR = { hex = "77b52b" }

local function HexToRGB(hex)
    if type(hex) ~= "string" then return 1, 0.82, 0 end
    hex = hex:gsub("#", "")
    if #hex ~= 6 then return 1, 0.82, 0 end
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 209
    local b = tonumber(hex:sub(5, 6), 16) or 0
    return r / 255, g / 255, b / 255
end

addonTable.GetPrimaryColor = function()
    local hex = addonTable.PRIMARY_COLOR and addonTable.PRIMARY_COLOR.hex
    return HexToRGB(hex or "ffd700")
end

local function ColorPrimary(text)
    local hex = (addonTable.PRIMARY_COLOR and addonTable.PRIMARY_COLOR.hex) or "ffd700"
    hex = hex:gsub("#", "")
    return string.format("|cff%s%s|r", hex, text or "")
end
addonTable.ColorPrimary = ColorPrimary

-- Iterador seguro para caracteres UTF-8 (evita romper acentos en gradientes)
local function UTF8Chars(str)
    local t = {}
    if not str or str == "" then return t end
    local i = 1
    local len = #str
    while i <= len do
        local c = str:byte(i)
        local n = 1
        if c >= 240 then n = 4
        elseif c >= 224 then n = 3
        elseif c >= 192 then n = 2
        end
        t[#t + 1] = str:sub(i, i + n - 1)
        i = i + n
    end
    return t
end

-- Funcion generadora de gradientes (compatible con UTF-8)
local function CreateGradient(text, r1, g1, b1, r2, g2, b2)
    local chars = UTF8Chars(text or "")
    local len = #chars
    if len <= 1 then
        return text or ""
    end

    local result = ""
    for i, char in ipairs(chars) do
        local percent = (i - 1) / (len - 1)
        local r = r1 + (r2 - r1) * percent
        local g = g1 + (g2 - g1) * percent
        local b = b1 + (b2 - b1) * percent
        result = result .. string.format("|cff%02x%02x%02x%s", r * 255, g * 255, b * 255, char)
    end

    return result .. "|r"
end
addonTable.CreateGradient = CreateGradient


-- =============================================================
-- 1. IDIOMA POR DEFECTO (INGLES)
-- =============================================================
L["RAID_TOKEN"] = "Raid Token / Other"
L["HEAD"] = "Head"
L["NECK"] = "Neck"
L["SHOULDER"] = "Shoulder"
L["CLOAK"] = "Cloak"
L["CHEST"] = "Chest"
L["WRIST"] = "Wrist"
L["HAND"] = "Hands"
L["WAIST"] = "Waist"
L["LEGS"] = "Legs"
L["FEET"] = "Feet"
L["FINGER"] = "Ring"
L["TRINKET"] = "Trinket"
L["WEAPON_1H"] = "Weapon (1H)"
L["WEAPON_MAIN"] = "Weapon (Main)"
L["WEAPON_OFF"] = "Weapon (Off)"
L["SHIELD"] = "Shield/Offhand"
L["HOLDABLE"] = "Held In Off-hand"
L["WEAPON_2H"] = "Weapon (2H)"
L["RANGED"] = "Ranged"
L["RELIC"] = "Relic"
L["MOUNT"] = "Mount"

L["LOADED_MSG"] = "|cff00ff00[Loot Hunter] Loaded.|r Profile: |cff00ffff%s|r. Tracking: |cff00ff00%s|r items."
L["ADDED_MSG"] = "|cff00ff00[Loot Hunter]|r Added %s - %s"
L["UNKNOWN_SOURCE"] = "Unknown Source"
L["ZONE_DROP"] = "(Zone Drop)"
L["LOADING"] = "Loading..."
L["CONGRATS_CHAT_MSG"] = "|cff00ff00[Loot Hunter] Congrats! You received: %s|r"
L["DROP_ALERT_TITLE"] = "ATTENTION! DROP!"
L["DROP_ALERT_PROMPT"] = "Don't forget to /roll !"
L["PRIORITY_DROP_ALERT_LABEL"] = "PRIORITY LOOT\n"
L["PRIORITY_ITEM_TOOLTIP"] = "Priority item"
L["WIN_ALERT_TITLE"] = "Congrats! GG!"
L["WIN_ALERT_DESC"] = "You won"
L["DROP_CHAT_MSG"] = "|cff00ff00[Loot Hunter]|r |cffffa500Attention! Dropped: %s Don't forget to roll!!|r"
L["DROP_OTHER_CHAT_MSG"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:12:12|t %s was taken by %s. |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:12:12|t"
L["VENDOR_TRACKED_TOOLTIP"] = "|TInterface\\Buttons\\UI-CheckBox-Check:14:14|t This item is already on your list"
L["VENDOR_EQUIPPED_TOOLTIP"] = "|TInterface\\Buttons\\UI-CheckBox-Check:14:14|t This item is currently equipped"
L["HEROIC_QUEUE_CONFIRM_TEXT"] = "You are about to queue for a heroic random dungeon. Continue?"
L["HEROIC_QUEUE_CONFIRM_YES"] = "Yes, continue"
L["HEROIC_QUEUE_CONFIRM_NO"] = "No, cancel"
L["HEROIC_QUEUE_ALREADY"] = "You are already queued for a heroic random dungeon. Continue?"

L["COIN_REMINDER_RAID_MSG"] = "No tracked loot from %s. Flip your coin!"
L["COIN_REMINDER_RAID_CHAT"] = "|cff00ff00[Loot Hunter]|r |cffffa500No tracked loot from %s. Flip your coin!|r"
L["COIN_REMINDER_CHAT_MSG"] = ColorPrimary("[Loot Hunter] %s didn't drop your item. Try your bonus roll!")
L["COIN_REMINDER_ALERT_TITLE"] = "Your loot didn't drop!"
L["COIN_REMINDER_ALERT_PROMPT"] = "Use your coin now!"
L["COIN_LOST_REMINDER"] = "|cff00ff00[Loot Hunter]|r You can still use your coin! May RNG be with you."
L["COIN_LOST_REMINDER_FOLLOWUP"] = "|cff00ff00[Loot Hunter]|r Go for it! Maybe the gods haven't forgotten you."
L["COIN_PRE_WARNING"] = "|cff00ff00[Loot Hunter]|r %s might have your loot. Get your coin ready!"
L["COIN_REMINDER_PREVIEW"] = "Preview Boss"

L["LIST_CLEARED_MSG"] = "|cff00ff00[Loot Hunter] Tracker cleared.|r"
L["BTN_TEXT"] = "Loot Hunter"
L["WINDOW_TITLE"] = "Loot Hunter - %s"
L["EMPTY_TITLE"] = CreateGradient("Never miss your BiS again!", 0.208, 0.498, 0.09, 0.729, 0.925, 0.255)
L["EMPTY_QUOTES"] = {
    "Target your rewards. Secure the loot.",
}
L["EMPTY_CTA_INSTRUCTION"] = "Don't rely on luck alone. Scout your upgrades in the Dungeon Journal |cff89e433(Shift+J)|r and mark your targets |cff89e433(Shift+Click)|r. When your item drops, you'll be the first to know."
L["EMPTY_OPEN_JOURNAL"] = "Open Dungeon Journal"
L["EMPTY_HELP_HINT"] = "Need help? Open the user guide."
L["GUIDE_OPEN_JOURNAL"] = "Open Dungeon Journal"
L["HELP_METHOD_1_TITLE"] = "Instructions"
L["HELP_METHOD_1_DESC"] = "1. Open Dungeon Journal (Shift+J) or any gear vendor.\n2. Shift+Click an item to add it.\n3. Done! I will watch your item forever."
L["HELP_GUIDE_WATCH"] = "The addon will always watch your list;\nyou don't need it open for it to work :)"
L["HELP_TIPS_TITLE"] = "Tips"
L["HELP_TIPS_DESC"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:12:12:0:-2|t Tap the little book button (top left) to pop open the Dungeon Journal without any commands.\n\n|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:12:12:0:-2|t Double-Click: Marks it as priority with a |cffffff00yellow|r border, and the item will be ordered at the top of its category.\n\n|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:12:12:0:-2|t Right-Click: Toggles status to Obtained / Won in |cff00ff00green|r.\n\n|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:12:12:0:-2|t Click a row while chat input is open to paste its link.\n\n|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:12:12:0:-2|t Use the Spec column to change an item's spec manually.\n\n|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:12:12:0:-2|t Use filters (Type/Source/Spec) to focus your list.\n\n|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:12:12:0:-2|t Adding items captures your current spec so you can filter them later.\n\n|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:12:12:0:-2|t You can also add vendor items via Shift+Click."
L["HELP_STATUS_TITLE"] = "Status List"
L["HELP_STATUS_PRIORITY"] = "|cffffff00Priority (list status)|r\nThe entire row gets a yellow border to highlight it as a tracked priority."
L["HELP_STATUS_NORMAL"] = "|cffa335eeGeneral (list status)|r\nDefault row styling indicates the item is on your wishlist without extra urgency."
L["HELP_STATUS_DROP"] = CreateGradient("[DROP] (list status)", 1, 0.85, 0.35, 1, 0.65, 0) .. "\n|cffd1d1d1The lines below stay gold so you know it just appeared.|r"
L["HELP_STATUS_WON"] = ColorPrimary("Won (list status)") .. "\nGreen colored row border + green text show the item was already obtained."
L["HELP_STATUS_EQUIPPED"] = "|cffa335eeEquipped|r %s\nA small green check mark on the top-left of the icon shows you are currently wearing it."
L["CREDITS"] = ""
L["TAB_LIST"] = "My List"
L["TAB_STATS"] = "Stats"
L["TAB_HELP"] = "Help"
L["STATS_PLACEHOLDER"] = "Statistics are coming soon. This tab will collect your drops, wins, and priority progress."
L["STATS_VIEW_ALL"] = "View all"
L["STATS_CURRENT_LIST"] = "Current List"
L["STATS_ITEMS_TRACKED"] = "Items tracked"
L["STATS_PENDING"] = "Pending"
L["STATS_WON"] = "Won"
L["STATS_PRIORITY"] = "Priority"
L["STATS_HISTORY"] = "History"
L["STATS_DROPS"] = "Drops detected"
L["STATS_WINS"] = "Wins"
L["STATS_LOSSES"] = "Losses"
L["STATS_REMINDERS"] = "Coin reminders"
L["STATS_COINS_USED"] = "Coins used"
L["STATS_BOSS_NO_LOOT"] = "Bosses without your loot"
L["STATS_RAID_HEADER"] = "Raid Logs"
L["STATS_TIME_SINCE_LAST_WIN"] = "Time since last winning drop"
L["STATS_WEEKS_WITHOUT_LOOT"] = "Weeks without loot"
L["STATS_LOOT_HISTORY"] = "Session drops"
L["STATS_NO_SESSIONS"] = "No sessions yet"
L["STATS_NO_SESSION_DATA"] = "Session data pending"
L["STATS_NO_SESSION_LOOT"] = "No drops in this session"
L["SLOT_HEADER"] = "%s"
L["CONFIRM_CLEAR_TEXT"] = "Are you sure you want to clear the entire list?"
L["COPY_LOG_TITLE"] = "Copy Debug Log"
L["BTN_EXPORT_LOG"] = "Export Log"
L["LOG_DEV_NOTICE"] = "The debug log is for development only; not every event is visible."
L["LOG_EMPTY_PANEL"] = "|cffff9900The log is empty.|r"
L["LOG_EMPTY_ERROR"] = "|cffff0000[Loot Hunter] The log is empty.|r"
L["LOG_EMPTY_CONSOLE"] = "|cffff0000[Loot Hunter] The log is empty.|r"
L["FILTER_TYPE"] = "Type"
L["FILTER_PRIORITY"] = "Priority"
L["FILTER_WON"] = "Won"
L["FILTER_PENDING"] = "Pending"
L["FILTER_ALL"] = "All"
L["FILTER_SOURCE"] = "Source"
L["FILTER_BOSS"] = "Boss / Enemy"
L["FILTER_TOKEN"] = "Token"
L["FILTER_MOUNT"] = "Mount"
L["FILTER_SPEC"] = "Spec"
L["TAB_LOG"] = "Log"
L["FILTER_EMPTY_TITLE"] = CreateGradient("No items found", 0.486, 0.686, 0.831, 1.0, 1.0, 1.0)
L["FILTER_EMPTY_DESC"] = "Try changing your filters."
L["SIDEBAR_GUIDE"] = "User Guide"
L["SIDEBAR_TIPS"] = "Tips"
L["SIDEBAR_STATUS"] = "Status"
L["SIDEBAR_BUGS"] = "Bug Report"
L["SIDEBAR_CREDITS"] = "Credits"
L["HELP_GUIDE_INTRO_TITLE"] = "Welcome to the User Guide."
L["HELP_GUIDE_INTRO_DESC"] = "Learn how to add items to your Loot Hunter list."
L["HELP_TIPS_INTRO"] = "Here are some useful tips to get the most out of Loot Hunter and manage your list efficiently.\n\n"
L["HELP_STATUS_INTRO"] = "Visual cues (borders/checks) show the most recent list status; only one state is displayed at a time so the list stays readable.\n\n"
L["HELP_BUGS_TITLE"] = "Bug Report"
L["HELP_BUGS_DESC"] = "Report bugs using the link below so we can track them and fix them faster."
L["HELP_BUGS_LINK_LABEL"] = "Bug report link:"
L["HELP_BUGS_DISCORD_DESC"] = "\n\nPrefer Discord? Share bugs, feedback, or suggestions with the community."
L["HELP_BUGS_DISCORD_LABEL"] = "Discord link:"
L["HELP_BUGS_COPY_HINT"] = "CTRL + C to copy"
L["COIN_NO_ITEMS_BOSS"] = "|cff00ff00[Loot Hunter]|r %s has no items in your list."
L["HELP_CREDITS_TITLE"] = "Credits"
L["SPEC_TOOLTIP"] = "Click to change spec."
L["BTN_CLEAR_TOOLTIP"] = "|cffff0000Clear entire list|r\nAll saved items will be removed."
L["ASSET_MISSING_MSG"] = "|cffff0000[Loot Hunter] Missing assets: %s|r"
L["ASSET_MISSING_HINT"] = "[Loot Hunter] Verify the addon folder name is LootHunter."
L["RESET_ENV_PROMPT"] = "Reset Loot Hunter data for this character? This will reload the UI."

-- Settings
L["SETTINGS"] = "Settings"
L["COIN_REMINDER_SETTINGS"] = "Coin Reminder"
L["LOOT_ALERTS_SETTINGS"] = "Loot Alerts"
L["STATS_SETTINGS"] = "Statistics"
L["WINDOW_SETTINGS"] = "Window"
L["LANGUAGE_SETTINGS"] = "Language"
L["SETTING_COIN_ENABLE_LABEL"] = "Enable Coin Reminder"
L["SETTING_COIN_ENABLE_DESC"] = "Globally enables or disables the bonus roll reminder feature."
L["SETTING_COIN_PREWARN_LABEL"] = "Enable Pre-Warning"
L["SETTING_COIN_PREWARN_DESC"] = "Personal reminder + subtle sound 3 seconds after boss kill (when bonus roll window is visible)."
L["SETTING_COIN_DELAY_LABEL"] = "Reminder wait time"
L["SETTING_COIN_DELAY_DESC"] = "\nTime to wait after boss death before showing the bonus roll reminder."
L["SETTING_COIN_VISUAL_LABEL"] = "Enable Visual Alert"
L["SETTING_COIN_VISUAL_DESC"] = "Shows a bold visual alert that reminds you to use your coin."
L["SETTING_COIN_SOUND_LABEL"] = "Enable Sound Alert"
L["SETTING_COIN_SOUND_DESC"] = "Plays a sound along with the visual alert."
L["SETTING_ALERTS_WON_LABEL"] = 'Enable "Item Won" Alert'
L["SETTING_ALERTS_WON_DESC"] = "Shows a special alert when you win an item from your list."
L["SETTING_ALERTS_SEEN_LABEL"] = 'Enable "Item Seen" Alert'
L["SETTING_ALERTS_SEEN_DESC"] = "Shows an alert when an item from your list is seen in loot (chat/loot events)"
L["SETTING_ALERTS_LOST_SECTION"] = "\nLost Loot Alert"
L["SETTING_ALERTS_LOST_DESC"] = "Shows a chat message telling you who won your tracked item."
L["SETTING_ALERTS_LOST_ENABLE_LABEL"] = "Enable lost loot alert"
L["SETTING_ALERTS_OTHER_SOUND_LABEL"] = "Play sound when others win your item"
L["SETTING_ALERTS_OTHER_SOUND_DESC"] = "When someone else takes your item, Bolvar's famous lament will play so you never forget the moment.\n"
L["SETTING_ALERTS_LOST_SCOPE_LABEL"] = "\nWhere to show these alerts"
L["SETTING_ALERTS_LOST_SCOPE_ALL"] = "Raids & Dungeons"
L["SETTING_ALERTS_LOST_SCOPE_RAID"] = "Raids"
L["SETTING_ALERTS_LOST_SCOPE_DUNGEON"] = "Dungeons"
L["SETTING_ALERTS_MISC_TITLE"] = "Miscellaneous"
L["SETTING_ALERTS_BOSS_NONE_LABEL"] = "Warn if boss has no items in your list"
L["SETTING_ALERTS_BOSS_NONE_DESC"] = "Shows a chat message on boss death when that boss has no items from your list."
L["SETTING_STATS_RESET_HEADER"] = "Clear raid history"
L["SETTING_STATS_RESET_BUTTON"] = "Clear raid history"
L["SETTING_STATS_RESET_DESC"] = "Deletes recorded raid sessions and their drops for this character. Your overall history counters stay intact."
L["SETTING_STATS_RESET_CONFIRM"] = "This will erase all raid sessions and session drops for this character. Continue?"
L["SETTING_STATS_MAX_SESSIONS"] = "Maximum raid sessions to keep"
L["SETTING_STATS_MAX_SESSIONS_DESC"] = "How many raid sessions to store (default 20, up to 100). Oldest sessions are discarded when the limit is exceeded."
L["STATS_ANNOUNCE_GUILD_TOOLTIP"] = "Announce to guild"
L["STATS_ANNOUNCE_GUILD_HEADER"] = "+--------- Loot Hunters! ---------+"
L["STATS_ANNOUNCE_GUILD_DATE"] = "[- %s - %s -]"
L["STATS_ANNOUNCE_GUILD_WALL"] = "*** WALL OF SHAME ***"
L["STATS_WALL_DEATHS"] = "Most deaths - %s (%s)"
L["STATS_WALL_REVIVES"] = "More times revived - %s (%s)"
L["STATS_WALL_DEADTIME"] = "Most time dead - %s (%s)"
L["STATS_ANNOUNCE_NO_GUILD"] = "You are not in a guild."
L["STATS_ANNOUNCE_SENT"] = "Announcement sent to guild."
L["DE_ANNOUNCE_EN"] = "[Loot Hunter] %s has been disenchanted!"
L["DE_ANNOUNCE_ES"] = "[Loot Hunter] %s ha sido desencantado!"
L["CREDITS_HEADING"] = " "
L["CREDITS_DESC"] = "This project wouldn’t be possible without the\nconstant support, feedback, and QA from Arkaboy.\nThank you!\n\nHuge thanks to every member of Wilds for the Night\nfor testing the addon and helping to make this\nproject a reality."
L["CREDITS_GUILD_TITLE"] = "Wilds for the Night [WftN]"
L["CREDITS_FAREWELL"] = "From the Nether with love... |cFF8787EDXamael|r"
L["SETTING_MISC_TITLE"] = "Miscellaneous"
L["SETTING_MISC_DESC"] = "Additional Loot Hunter features"
L["SETTING_MISC_HEROIC_LABEL"] = "Ask confirmation when queuing heroic random dungeons"
L["SETTING_MISC_HEROIC_DESC"] = "When you start queuing for a heroic random dungeon, show a confirmation popup so you don't enter by mistake."
L["SETTING_MISC_MUTE_RAID_LABEL"] = "Mute global channels while inside raids"
L["SETTING_MISC_MUTE_RAID_DESC"] = "Hide messages from General/Trade/Defense/LFG channels when you are inside a raid instance. Channels are restored normally when you leave."
L["SETTING_GENERAL_LOCK_LABEL"] = "Lock Window Size"
L["SETTING_GENERAL_LOCK_DESC"] = "Prevents the main window from being resized.\n" .. ColorPrimary("(Requires UI reload)")
L["SETTING_GENERAL_SCALE_DESC"] = "Adjusts the overall Loot Hunter UI scale."
L["SETTING_WINDOW_SECTION_DIMENSIONS"] = "Dimensions"
L["SETTING_WINDOW_SECTION_SCALE"] = "Addon Scale"
L["SETTING_WINDOW_SECTION_RESET"] = "Reset"
L["SETTING_GENERAL_RESET_SIZE_LABEL"] = "Reset Window Size"
L["SETTING_GENERAL_RESET_SIZE_DESC"] = "Restores the default window size and recenters the window."
L["SETTING_LANGUAGE_DESC"] = "Change the addon language. " .. ColorPrimary("(Requires UI reload)")
L["SETTING_LANGUAGE_AUTO"] = "Auto"
L["SETTING_LANGUAGE_EN"] = "English"
L["SETTING_LANGUAGE_ES"] = "Spanish"
L["RELOAD_UI_PROMPT"] = "Changes require a UI reload. Reload now?"
L["FILTER_RESET"] = "Reset"
L["MINIMAP_LMB_ACTION"] = "Open LootHunter"
L["MINIMAP_RMB_ACTION"] = "Open Settings"
L["L_CLICK"] = "Left-click:"
L["R_CLICK"] = "Right-click:"


-- =============================================================
-- 2. TRADUCCION ESPANOL (ES)
-- =============================================================
local function GetPreferredLocale()
    local db = LootHunterDB
    local lang = db and db.settings and db.settings.general and db.settings.general.language
    if type(lang) == "string" then
        lang = string.upper(lang)
    end
    if lang == "EN" then
        return "enUS"
    elseif lang == "ES" then
        return "esES"
    end
    return (GetLocale and GetLocale()) or "enUS"
end

local function ApplySpanish()
    L["RAID_TOKEN"] = "Ficha de banda / Otros"
    L["HEAD"] = "Cabeza"
    L["NECK"] = "Cuello"
    L["SHOULDER"] = "Hombros"
    L["CLOAK"] = "Espalda"
    L["CHEST"] = "Pecho"
    L["WRIST"] = "Muñeca"
    L["HAND"] = "Manos"
    L["WAIST"] = "Cintura"
    L["LEGS"] = "Piernas"
    L["FEET"] = "Pies"
    L["FINGER"] = "Anillo"
    L["TRINKET"] = "Abalorio"
    L["WEAPON_1H"] = "Arma (1M)"
    L["WEAPON_MAIN"] = "Arma (Principal)"
    L["WEAPON_OFF"] = "Arma (Secundaria)"
    L["SHIELD"] = "Escudo / Mano secundaria"
    L["HOLDABLE"] = "Sostener en mano izquierda"
    L["WEAPON_2H"] = "Arma (2M)"
    L["RANGED"] = "Distancia"
    L["RELIC"] = "Reliquia"
    L["MOUNT"] = "Montura"
    L["LOADED_MSG"] = "|cff00ff00[Loot Hunter] Cargado.|r Perfil: |cff00ffff%s|r. Rastreando: |cff00ff00%s|r objetos."
    L["ADDED_MSG"] = "|cff00ff00[Loot Hunter]|r Agregado %s - %s"
    L["UNKNOWN_SOURCE"] = "Fuente desconocida"
    L["ZONE_DROP"] = "(Drop de zona)"
    L["LOADING"] = "Cargando..."
    L["CONGRATS_CHAT_MSG"] = "|cff00ff00[Loot Hunter] ¡Felicidades! Has conseguido: %s|r"
    L["DROP_CHAT_MSG"] = "|cff00ff00[Loot Hunter]|r |cffffa500¡Atención! Ha salido: %s. ¡No olvides tirar dados!|r"
    L["DROP_OTHER_CHAT_MSG"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:12:12|t %s fue tomado por %s. |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:12:12|t"
    L["VENDOR_TRACKED_TOOLTIP"] = "|TInterface\\Buttons\\UI-CheckBox-Check:14:14|t Este ítem ya está en tu lista"
    L["VENDOR_EQUIPPED_TOOLTIP"] = "|TInterface\\Buttons\\UI-CheckBox-Check:14:14|t Este ítem ya lo tienes equipado"
    L["HEROIC_QUEUE_CONFIRM_TEXT"] = "Estás a punto de ponerte en cola para un calabozo heroico aleatorio. ¿Quieres continuar?"
    L["HEROIC_QUEUE_CONFIRM_YES"] = "Sí, continuar"
    L["HEROIC_QUEUE_CONFIRM_NO"] = "No, cancelar"
    L["HEROIC_QUEUE_ALREADY"] = "Ya estás en cola para un calabozo heroico. ¿Quieres continuar?"
    L["DROP_ALERT_PROMPT"] = "¡No olvides tirar dados! /roll"
    L["PRIORITY_DROP_ALERT_LABEL"] = "BOTÍN PRIORITARIO\n"
    L["PRIORITY_ITEM_TOOLTIP"] = "Item prioritario"
    L["DROP_ALERT_TITLE"] = "¡Atención! DROP"
    L["WIN_ALERT_TITLE"] = "¡Felicidades! ¡GG!"
    L["WIN_ALERT_DESC"] = "Has ganado"
    L["COIN_REMINDER_RAID_MSG"] = "No salió tu ítem rastreado en %s. ¡Tira la moneda!"
    L["COIN_REMINDER_RAID_CHAT"] = "|cff00ff00[Loot Hunter]|r |cffffa500No salió tu ítem rastreado en %s. ¡Tira la moneda!|r"
    L["COIN_REMINDER_CHAT_MSG"] = ColorPrimary("[Loot Hunter] %s no soltó tu objeto. ¡Usa tu moneda!")
    L["COIN_REMINDER_ALERT_TITLE"] = "¡Tu ítem no salió!"
    L["COIN_REMINDER_ALERT_PROMPT"] = "¡Usa tu moneda ahora!"
    L["COIN_LOST_REMINDER"] = "|cff00ff00[Loot Hunter]|r Aún puedes usar la moneda. ¡Que el RNG te acompañe!"
    L["COIN_LOST_REMINDER_FOLLOWUP"] = "|cff00ff00[Loot Hunter]|r ¡Hazlo! Quizás los dioses aún no te han olvidado."
    L["LIST_CLEARED_MSG"] = "|cff00ff00[Loot Hunter] Lista de rastreo borrada.|r"
    L["COIN_PRE_WARNING"] = "|cff00ff00[Loot Hunter]|r %s podría tener tu ítem. ¡Prepara tu moneda!"
    L["COIN_REMINDER_PREVIEW"] = "Vista previa del jefe"
    L["BTN_TEXT"] = "Loot Hunter"
    L["WINDOW_TITLE"] = "Loot Hunter - %s"
    L["EMPTY_TITLE"] = CreateGradient("¡No te olvides tu BiS!", 0.208, 0.498, 0.09, 0.729, 0.925, 0.255)
    L["EMPTY_QUOTES"] = {
        "Fija el objetivo. Reclama el botín.",
    }
    L["EMPTY_CTA_INSTRUCTION"] = "No dependas solo de la suerte.\nBusca tus mejoras en la Guía de calabozos |cff89e433(Shift+J)|r y marca tus objetivos |cff89e433(Shift+Click)|r. Cuando tu objeto caiga, serás el primero en saberlo."
    L["EMPTY_OPEN_JOURNAL"] = "Abrir Guía de calabozos"
    L["EMPTY_HELP_HINT"] = "?Necesitas ayuda? Abre la gu?a del usuario."
    L["GUIDE_OPEN_JOURNAL"] = "Abrir Guía de calabozos"
    L["HELP_METHOD_1_TITLE"] = "Instrucciones"
    L["HELP_METHOD_1_DESC"] = "1. Abre la Guía de calabozos (Shift+J) o vendedores de equipo.\n2. Haz Shift+Click en un objeto para añadirlo.\n3. ¡Listo! Vigilaré tu objeto por siempre."
    L["HELP_GUIDE_WATCH"] = "El addon siempre estará vigilando tu lista,\nno tienes que tener el addon abierto para que funcione :)"
    L["HELP_TIPS_TITLE"] = "Consejos"
    L["HELP_TIPS_DESC"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:12:12:0:-2|t Pulsa el botoncito de libro (arriba a la izquierda) para abrir la Guía de calabozos directamente.\n\n|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:12:12:0:-2|t Doble click: Se marca como prioritario con un borde en color |cffffff00amarillo|r, el ítem se ordenará al principio de su categoría.\n\n|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:12:12:0:-2|t Click derecho: Alterna el estado a Conseguido / Ganado en |cff00ff00verde|r.\n\n|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:12:12:0:-2|t Click en una fila con el chat activo pega el enlace directamente.\n\n|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:12:12:0:-2|t Usa la columna Espec. para cambiar la especialización del ítem.\n\n|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:12:12:0:-2|t Usa filtros (Tipo/Fuente/Espec.) para enfocarte.\n\n|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:12:12:0:-2|t Al agregar objetos se toma tu espec. actual para filtrarlos después.\n\n|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:12:12:0:-2|t También puedes agregar objetos de vendedores con Shift+Click."
    L["HELP_STATUS_TITLE"] = "Estados de lista"
    L["HELP_STATUS_PRIORITY"] = "|cffffff00Prioridad (estado de lista)|r\nEl borde de la fila se vuelve amarillo para destacar un objeto prioritario."
    L["HELP_STATUS_NORMAL"] = "|cffa335eeGeneral (estado de lista)|r\nEl estilo por defecto indica que el objeto está en tu lista sin urgencia."
    L["HELP_STATUS_DROP"] = CreateGradient("[DROP] (estado de lista)", 1, 0.85, 0.35, 1, 0.65, 0) .. "\n|cffd1d1d1Las líneas de arriba y abajo permanecen doradas para avisarte que acaba de salir.|r"
    L["HELP_STATUS_WON"] = ColorPrimary("Conseguido (estado de lista)") .. "\nBorde en color verde + texto verde muestran que ya lo conseguiste."
    L["HELP_STATUS_EQUIPPED"] = "|cffa335eeEquipado|r %s\nUn pequeño check verde en la esquina superior izquierda del icono indica que lo llevas puesto."
    L["CREDITS"] = "|cffffffffHecho con amor por|r\n|cff8764e8[WftN] Xamael|r"
    L["TAB_LIST"] = "Mi lista"
    L["TAB_STATS"] = "Estadisticas"
    L["TAB_HELP"] = "Ayuda"
    L["STATS_PLACEHOLDER"] = "Las estadisticas llegan pronto. Aqui veras tus drops, ganados y progreso de prioridad."
    L["STATS_VIEW_ALL"] = "Ver todo"
    L["STATS_CURRENT_LIST"] = "Lista actual"
    L["STATS_ITEMS_TRACKED"] = "Objetos rastreados"
    L["STATS_PENDING"] = "Pendientes"
    L["STATS_WON"] = "Ganados"
    L["STATS_PRIORITY"] = "Prioritarios"
    L["STATS_HISTORY"] = "Historial"
    L["STATS_DROPS"] = "Drops detectados"
    L["STATS_WINS"] = "Ganados"
    L["STATS_LOSSES"] = "Perdidos"
    L["STATS_REMINDERS"] = "Recordatorios de moneda"
    L["STATS_COINS_USED"] = "Monedas usadas"
    L["STATS_BOSS_NO_LOOT"] = "Jefes sin tu botín"
    L["STATS_RAID_HEADER"] = "Registro de Bandas"
    L["STATS_TIME_SINCE_LAST_WIN"] = "Tiempo desde el último drop\nganado"
    L["STATS_WEEKS_WITHOUT_LOOT"] = "Semanas sin loot"
    L["STATS_LOOT_HISTORY"] = "Drops de la sesión"
    L["STATS_NO_SESSIONS"] = "Sin sesiones todavía"
    L["STATS_NO_SESSION_DATA"] = "Faltan datos de sesión"
    L["STATS_NO_SESSION_LOOT"] = "Sin drops en esta sesión"
    L["SLOT_HEADER"] = "%s"
    L["CONFIRM_CLEAR_TEXT"] = "¿Estás seguro de que quieres borrar toda la lista?"
    L["COPY_LOG_TITLE"] = "Copiar log de debug"
    L["BTN_EXPORT_LOG"] = "Exportar log"
    L["LOG_DEV_NOTICE"] = "El log de depuración es solo para desarrollo; no todos los eventos son visibles."
    L["LOG_EMPTY_PANEL"] = "|cffff9900El log está vacío.|r"
    L["LOG_EMPTY_ERROR"] = "|cffff0000[Loot Hunter] El log está vacío.|r"
    L["LOG_EMPTY_CONSOLE"] = "|cffff0000[Loot Hunter] El log está vacío.|r"
    L["FILTER_TYPE"] = "Tipo"
    L["FILTER_PRIORITY"] = "Prioridad"
    L["FILTER_WON"] = "Ganados"
    L["FILTER_PENDING"] = "Pendientes"
    L["FILTER_ALL"] = "Todos"
    L["FILTER_SOURCE"] = "Fuente"
    L["FILTER_BOSS"] = "Jefe / Enemigo"
    L["FILTER_TOKEN"] = "Ficha"
    L["FILTER_MOUNT"] = "Montura"
    L["FILTER_SPEC"] = "Espec."
    L["TAB_LOG"] = "Log"
    L["FILTER_EMPTY_TITLE"] = CreateGradient("No se encontraron objetos", 0.486, 0.686, 0.831, 1.0, 1.0, 1.0)
    L["FILTER_EMPTY_DESC"] = "Intenta cambiar los filtros."
    L["SIDEBAR_GUIDE"] = "Guía de uso"
    L["SIDEBAR_TIPS"] = "Consejos"
    L["SIDEBAR_STATUS"] = "Estados"
    L["SIDEBAR_BUGS"] = "Reporte de Bugs"
    L["SIDEBAR_CREDITS"] = "Créditos"
    L["HELP_GUIDE_INTRO_TITLE"] = "Bienvenido a la Guía de Usuario."
    L["HELP_GUIDE_INTRO_DESC"] = "Aprende cómo agregar objetos a tu lista de Loot Hunter."
    L["HELP_TIPS_INTRO"] = "Aquí tienes consejos para sacar el máximo provecho a Loot Hunter y gestionar tu lista eficientemente.\n\n"
    L["HELP_STATUS_INTRO"] = "Las señales visuales (bordes/checks) muestran el estado más reciente de la lista; solo uno se muestra a la vez para mantener la lista limpia.\n\n"
    L["HELP_BUGS_TITLE"] = "Reporte de Bugs"
    L["HELP_BUGS_DESC"] = "Usa este enlace para reportar bugs y poder darles seguimiento."
    L["HELP_BUGS_LINK_LABEL"] = "Enlace para reportar bug:"
    L["HELP_BUGS_DISCORD_DESC"] = "\n\nSi prefieres Discord, comparte bugs, sugerencias o quejas con la comunidad."
    L["HELP_BUGS_DISCORD_LABEL"] = "Enlace de Discord:"
    L["HELP_BUGS_COPY_HINT"] = "CTRL + C para copiar"
    L["COIN_NO_ITEMS_BOSS"] = "|cff00ff00[Loot Hunter]|r %s no tiene ítems en tu lista."
    L["HELP_CREDITS_TITLE"] = "Créditos"
    L["SPEC_TOOLTIP"] = "Haz clic para cambiar la espec."
    L["BTN_CLEAR_TOOLTIP"] = "|cffff0000Borrar toda la lista|r\nTodos los objetos guardados se eliminarán."
    L["ASSET_MISSING_MSG"] = "|cffff0000[Loot Hunter] Faltan archivos: %s|r"
    L["ASSET_MISSING_HINT"] = "[Loot Hunter] Verifica que la carpeta del addon se llame LootHunter."
    L["RESET_ENV_PROMPT"] = "¿Restablecer los datos de Loot Hunter para este personaje? Se recargará la interfaz."

    -- Settings
    L["SETTINGS"] = "Configuración"
    L["COIN_REMINDER_SETTINGS"] = "Alertas de Moneda"
    L["LOOT_ALERTS_SETTINGS"] = "Alertas de Botín"
    L["STATS_SETTINGS"] = "Estadísticas"
    L["WINDOW_SETTINGS"] = "Ventana"
    L["LANGUAGE_SETTINGS"] = "Idioma"
    L["SETTING_COIN_ENABLE_LABEL"] = "Activar Recordatorio de Moneda"
    L["SETTING_COIN_ENABLE_DESC"] = "Activa o desactiva completamente la función de recordatorio de tirada extra."
    L["SETTING_COIN_PREWARN_LABEL"] = "Activar Pre-Aviso"
    L["SETTING_COIN_PREWARN_DESC"] = "Recordatorio personal + sonido sutil 3 segundos después de que muere el jefe (con la ventana de moneda visible)."
    L["SETTING_COIN_DELAY_LABEL"] = "Tiempo de espera"
    L["SETTING_COIN_DELAY_DESC"] = "\nTiempo que se espera tras la muerte del jefe antes de mostrar el recordatorio de moneda."
    L["SETTING_COIN_VISUAL_LABEL"] = "Activar Alerta Visual"
    L["SETTING_COIN_VISUAL_DESC"] = "Muestra una alerta visual llamativa que te avisa de usar tu moneda."
    L["SETTING_COIN_SOUND_LABEL"] = "Activar Sonido de Alerta"
    L["SETTING_COIN_SOUND_DESC"] = "Reproduce un sonido junto con la alerta visual."
    L["SETTING_ALERTS_WON_LABEL"] = 'Activar Alerta de "Objeto Obtenido"'
    L["SETTING_ALERTS_WON_DESC"] = "Muestra una alerta especial cuando ganas un objeto de tu lista."
    L["SETTING_ALERTS_SEEN_LABEL"] = 'Activar Alerta de "Objeto Visto"'
    L["SETTING_ALERTS_SEEN_DESC"] = "Muestra una alerta cuando se detecta un objeto de tu lista en el botín (chat/eventos de botín)."
    L["SETTING_ALERTS_LOST_SECTION"] = "\nAlerta de loot perdido"
    L["SETTING_ALERTS_LOST_DESC"] = "Mostrará un mensaje avisando quién te ganó el loot."
    L["SETTING_ALERTS_LOST_ENABLE_LABEL"] = "Activar alerta de loot perdido"
    L["SETTING_ALERTS_OTHER_SOUND_LABEL"] = "Reproducir sonido cuando otro gana tu objeto"
    L["SETTING_ALERTS_OTHER_SOUND_DESC"] = "Cuando otro se lleva tu ítem, sonará el célebre lamento de Bolvar para no olvidar el momento.\n"
    L["SETTING_ALERTS_LOST_SCOPE_LABEL"] = "\nDónde mostrar estas alertas"
    L["SETTING_ALERTS_LOST_SCOPE_ALL"] = "Bandas y Calabozos"
    L["SETTING_ALERTS_LOST_SCOPE_RAID"] = "Bandas"
    L["SETTING_ALERTS_LOST_SCOPE_DUNGEON"] = "Calabozos"
    L["SETTING_ALERTS_MISC_TITLE"] = "Misceláneos"
    L["SETTING_ALERTS_BOSS_NONE_LABEL"] = "Avisar si el jefe no tiene ítems en tu lista"
    L["SETTING_ALERTS_BOSS_NONE_DESC"] = "Muestra un mensaje en tu chat cuando muere un jefe que no tiene ítems de tu lista."
    L["SETTING_STATS_RESET_HEADER"] = "Borrar historial de raids"
    L["SETTING_STATS_RESET_BUTTON"] = "Borrar historial de raids"
L["SETTING_STATS_RESET_DESC"] = "Elimina las sesiones de raid y sus drops guardados para este personaje. Los contadores generales quedan intactos."
L["SETTING_STATS_RESET_CONFIRM"] = "Esto borrará todas las sesiones de raid y drops guardados de este personaje. ¿Continuar?"
L["SETTING_STATS_MAX_SESSIONS"] = "Máximo de raids a guardar"
L["SETTING_STATS_MAX_SESSIONS_DESC"] = "Sesiones de raid a almacenar (por defecto 20, máximo 100). Las más antiguas se eliminan al superar el límite."
    L["STATS_ANNOUNCE_GUILD_TOOLTIP"] = "Anunciar en la hermandad"
    L["STATS_ANNOUNCE_GUILD_HEADER"] = "--- Loot Hunters! ---"
    L["STATS_ANNOUNCE_GUILD_DATE"] = "[- %s - %s -]"
    L["STATS_ANNOUNCE_GUILD_WALL"] = "*** MURO DE LA VERGÜENZA ***"
L["STATS_WALL_DEATHS"] = "Mas muertes - %s (%s)"
L["STATS_WALL_REVIVES"] = "Más veces resucitado - %s (%s)"
L["STATS_WALL_DEADTIME"] = "Más tiempo muerto - %s (%s)"
L["STATS_ANNOUNCE_NO_GUILD"] = "No estás en una hermandad."
L["STATS_ANNOUNCE_SENT"] = "Anuncio enviado a la hermandad."
    L["CREDITS_HEADING"] = ""
    L["CREDITS_DESC"] = "Este proyecto no sería posible sin el apoyo constante,\nconsejos y QA de Arkaboy.\n¡Gracias!\n\nUn enorme agradecimiento a cada miembro de\nWilds for the Night por probar el addon y ayudar a\nhacer este proyecto una realidad."    L["CREDITS_GUILD_TITLE"] = "Wilds for the Night [WftN]"
    L["CREDITS_GUILD_TITLE"] = "Wilds for the Night [WftN]"
    L["CREDITS_FAREWELL"] = "Desde el Vacío abisal con amor... |cFF8787EDXamael|r"
    L["SETTING_MISC_TITLE"] = "Misceláneos"
    L["SETTING_MISC_DESC"] = "Funciones adicionales de Loot Hunter"
    L["SETTING_MISC_HEROIC_LABEL"] = "Pedir confirmación al hacer cola en heroicos aleatorios"
    L["SETTING_MISC_HEROIC_DESC"] = "Al iniciar una cola para un calabozo heroico aleatorio, muestra un popup de confirmación para evitar entrar por error."
    L["SETTING_MISC_MUTE_RAID_LABEL"] = "Silenciar canales globales dentro de raids"
    L["SETTING_MISC_MUTE_RAID_DESC"] = "Oculta mensajes de General/Comercio/Defensa/LFG cuando estás dentro de una instancia de raid. Los canales vuelven a mostrarse al salir."
    L["SETTING_GENERAL_LOCK_LABEL"] = "Bloquear Dimensiones"
    L["SETTING_GENERAL_LOCK_DESC"] = "Impide que la ventana principal se pueda redimensionar.\n" .. ColorPrimary("(Requiere /reload)")
    L["SETTING_GENERAL_SCALE_DESC"] = "Ajusta el tamaño general de Loot Hunter."
    L["SETTING_WINDOW_SECTION_DIMENSIONS"] = "Dimensiones"
    L["SETTING_WINDOW_SECTION_SCALE"] = "Escala del addon"
    L["SETTING_WINDOW_SECTION_RESET"] = "Restaurar"
    L["SETTING_GENERAL_RESET_SIZE_LABEL"] = "Restablecer tamaño de ventana"
    L["SETTING_GENERAL_RESET_SIZE_DESC"] = "Restaura el tamaño por defecto de la ventana y la centra."
    L["SETTING_LANGUAGE_DESC"] = "Cambia el idioma del addon. " .. ColorPrimary("(Requiere /reload)")
    L["SETTING_LANGUAGE_AUTO"] = "Auto"
    L["SETTING_LANGUAGE_EN"] = "Inglés"
    L["SETTING_LANGUAGE_ES"] = "Español"
    L["RELOAD_UI_PROMPT"] = "Los cambios requieren recargar la interfaz. ¿Recargar ahora?"
    L["FILTER_RESET"] = "Restablecer"
    L["MINIMAP_LMB_ACTION"] = "Abrir LootHunter"
    L["MINIMAP_RMB_ACTION"] = "Abrir configuración"
    L["L_CLICK"] = "Clic izq:"
    L["R_CLICK"] = "Clic der:"
end


local function ApplyLocale()
    local locale = GetPreferredLocale()
    if locale == "esES" or locale == "esMX" then
        ApplySpanish()
    end
end

addonTable.ApplyLocale = ApplyLocale
