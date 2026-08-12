All notable changes to this project will be documented in this file.

## v1.2.6 Jerryments

- Wall of Shame: replaced the channel-selection popup with a resizable copy-friendly window. (thanks for the suggestion Jerryments!)
- BoE Tracker: added minimum-quality dropdown (Uncommon/Rare/Epic, default Rare) so you can choose which BoE quality triggers the alert.
- Encoding: fixed double-UTF-8 corruption in some source files :S
- Stats: fixed empty duplicate sessions being created on every death while in a raid group. 

## v1.2.5

- Fixed: `GameTooltip:SetText` missing alpha parameter in spec tooltip causing errors. Thanks RoadBlock!
- BoE Tracker (preview-test): new optional alert detects Bind-on-Equip gear and mounts looted by anyone in a raid, showing the item name, who obtained it, and logging it in the active Stats session with a `[BoE]` badge — ideal for tracking valuable trash drops. Only gear (weapons/armor) and mounts trigger the alert; consumables, materials, and recipes are ignored. (Settings → Miscellaneous → BoE Tracker, disabled by default)

## v1.2.4
- API: updated AddOn functions to use C_AddOns namespace for WoW 5.5.4 PTR compatibility (GetAddOnMetadata, IsAddOnLoaded, LoadAddOn)
- API: added fallback for GetRealmName() for future-proofing

## v1.2.3 RoadBlock
- CLI: added `/lh add <itemID or itemLink>` (also `/loothunter add`) to manually add items to the list from the command line — useful for items missing from the Dungeon Journal. Accepts a plain numeric ID or a Shift-clicked item link. (Thanks RoadBlock for suggestion and help!)

## v1.2.2 Yendy
- Miscellaneous: added "Auto-remove won items from list" option (Disabled by default)
- Stats: added a Wall of Shame skull icon button to the right of the session dropdown for quick access to `/lh_wall`.
- Stats: the `/lh_wall` dialog now shows which session will be announced below the prompt text.
- UI: clear/delete button now shows a context menu with two options: "Delete won items" or "Delete entire list".
- Wall of Shame: Fixed Escape/close-button behavior so closing the dialog no longer sends the message to guild automatically (sorry for that).
- Loot detection: Gargul messages with text content (enchant, award, GDKP, "Reserved by:", etc.) are now ignored and no longer trigger false drop alerts. Gargul's pure item-link announces (ML opens boss corpse) still trigger the alert normally, preserving the `/roll` workflow.

## v1.2.1
- Fixed: critical error in `ShowDropAlert()` when tracking drop alerts 

## v1.2
- Code structure: refactored the monolithic `LootHunter.lua` core into dedicated modules under `Modules/` (`SessionTracker`, `StatsStore`, `LootParser`, `CoinReminder`, `Utils`, etc.) for better maintainability; eliminated duplicate helper functions and localized hardcoded strings.
- Session tracking: raid sessions no longer close on a day change while the player is still in a raid group; the same session continues across midnight and only splits into a new record when leaving the group.
- Stats (Session drops): clicking a player name now opens a small inline input with the name pre-selected for copying (Ctrl+C). The popup closes automatically on scroll, tab switch, focus loss, Enter, or Escape.

## v1.1.6
- API: removed the previous favorites compatibility workaround.
- Heroic queue debug logging: reduced queue update spam so the queue-text log is emitted once per queue start cycle.
- Roll tracking: added chat-system parsing for `need/greed/pass/won` roll events (including no-spam variants) and linked them to player/item metadata.
- Other-won detection: improved fallback logic to use roll metadata when numeric `/roll` values are missing, helping in groups without master looter.
- Group tracking: Roll detection now works for all group members (not just the player); 
- WoW Classic fix: NEED/GREED roll detection now works correctly; messages come via CHAT_MSG_LOOT instead of CHAT_MSG_SYSTEM.

## v1.1.5
- Session tracking: start a new raid loot session on each raid entry; close stale sessions when the day changes.
- Logs UI: added Export/Clear/Disable buttons and confirmation dialogs.
- Logs display: fixed color prefix and improved log line layout.
- Stats: leaderboard UI removed from active code and preserved in ambar

## v1.1.4
- Session tracking: close the active raid session after a disband while inside the instance.
- Session tracking: fixed new raid instances not being recorded.

## v1.1.3
- Stats: multiple fixes; the session list now updates reliably again.
- Settings (Stats): max sessions range is now 25-50 (default 25).
- API: added compatibility for BonusRollPreview favorites tag.
- Loot list: newest items now appear at the top within each quality group.

## v1.1.2
- Boss-no-loot history counter now increments even when the coin reminder is disabled.
- Stats: session loot history list shows full session drops again.
- Heroic queue confirmation now also triggers from group/queue status updates (not just the join button).
- Code sanitized: reduced temporary allocations in UI loops and replaced risky overrides with safer hooks.

## v1.1.1
- Added public API `LootHunterAPI:IsFavorite(itemID)` for third-party favorites providers.(RoadBlock suggestion)
- Documented the API in README (EN/ES).
- Fixed scope/visibility issues by exposing `StatsStore` via addon namespace and hoisting `NormalizeTalentTabInfo`/`flashFrame`. (Thanks RoadBlock!)
- Fixed boss-no-loot history counter when no bonus roll window is visible.
- Session drops list now groups items by quality (Legendary/Epic/Rare/Uncommon) with section headers; added localization strings.
- Bonus roll detection in loot chat is more robust (positional formats, inverted order, bonus markers); other players' roll values now show dice icon + roll number.
- Cleanup: removed unused globals/locals and dead exports, including the old floating button helper.

## v1.1
- Stats tab: Current List counters (tracked/pending/won/priority), History counters (drops/wins/losses/coin reminders/coins used/boss-no-loot/time since last win), session selector, and session drop list with loot source icons (direct drop, roll, bonus roll).
- Settings (Stats): max sessions slider plus two reset actions (raid sessions reset and History-only reset).
- Wall of Shame: shows the selected session and the top deaths/revives/time dead; use `/lh_wall` and choose Local, Guild, or Raid.

## v1.0.5  
- Coin reminder no longer repeats during bonus roll; only WIN shows for tracked loot you win.  
- Fixed spec dropdown in item rows so it no longer shifts position after opening.  
## v1.0.4
- Added a top-left help icon next to settings with first-open pulse and a new empty-state help link.
- Priority drops now show a yellow flash, star icons, and a "PRIORITY LOOT" header line.
## v1.0.3 HOTFIX
- OTHER_WON no longer triggers when another player gets a tracked item via their own bonus roll; only shared /roll losses fire the red alert.
## v1.0.2
- Fixed bonus roll loot messages (self/other) so tracked items won via bonus rolls now trigger the WIN alert and status update.
- Suppressed OTHER_WON alerts when another player receives an item from their own bonus roll (only fires when a shared /roll is lost).
## v1.0 
- First stable release from the 1.5.x test branch.
- Coin reminder flow finalized (post-drop timers stay pending; two-stage lost coin alerts intact).
- Defaults tuned: loot alerts now default to Raids-only, and coin reminder wait is 60s.
## 1.5.3-test
- Added won-row border in primary color and updated Help > Status text (won) plus epic purple title for Equipped.
- Tooltip compare now refreshes when you press/hold Shift while hovering list items (no compare when Shift isn’t held).
- /lh_drop and /lh_won previews play sounds on Master channel; DROP prompt only in raids; when multiple tracked drops happen together, “other won” alerts are suppressed to reduce noise.
- Added scope control (“Raids/Dungeons/All”) to loot alerts and applied it to drop + won + lost alerts; default scope is now “All” and settings are normalized on load.
- Coin reminder no longer blocks on DROP; it stays pending until you win/lose. Reminder alert now matches the preview (title+prompt with diamond icons).
- Added optional mute for global channels (General/Trade/Defense/LFG) while inside raids (Misc setting).
- Credits icon animation softened to a slow alpha pulse; fixed nil call to bonus roll visibility.
## 1.5.2-test
- Added configurable coin reminder wait (30s-150s slider, default 150s) and debug logs showing the chosen value when timers start.
- Hooked Group Loot need/greed (`START_LOOT_ROLL`) to fire DROP alerts in dungeons; registered the event and improved logs with item ID + name.
- Drop prompt line now only appears in raids; dungeon drops show the header/item without dice prompt.
- Styled the coin delay slider (subtitle/primary-light-gray ticks) and hardened settings text widgets (safe SetNonSpaceWrap/SetSpacing calls).
- DROP alert logs now include item names for easier debugging.
- Removed the experimental vendor search feature and its settings tab (was off by default).
- Vendor items that are already on your list now show a subtle green name tint in merchant windows.
- Vendor items you already have equipped now show a bright green name tint and an “already equipped” tooltip line.
- Vendor tooltips for tracked items now include a green Loot Hunter header and localized “already on your list” line.
- Fixed Spanish localization encoding (all accentuated characters render correctly again) and added a tip about adding vendor items via Shift+Click.
- Moved debug/logging helpers into `Modules/Debug.lua` to isolate diagnostics and slash commands.
- Added a confirmation popup before queuing for a heroic random dungeon, styled with the Blizzard alert icon
## 1.5.1-test
- Added debug slash commands: `/lh_boss`, `/lh_drop`, `/lh_won`.
- Added pre-warning shake animation and other-won fade (testable in preview and live).
- Added colored chat formatting for DROP and other-won messages.
- Raised UI frame strata so Loot Hunter stays above other addons.
- Added boss-no-items chat option under Loot Alerts > Miscellaneous.
- Improved coin reminder flow: DROP blocks reminders; no-drop triggers after 30s.
- Added chat output for pre-warning and coin reminder alerts.
- Added `.pkgmeta` for CurseForge packaging.
## 1.5-test
- Queued visual alerts to avoid overlaps (loot/coin/pre-warning).
- Added first-time help button pulse glow until Help is opened.
- Added configurable addon UI scale in Window settings.
- Added hidden Ctrl+Shift+Click reset on Help icon (full reset + reload).
- Adjusted coin pre-warning timing (3s after boss kill when bonus roll window is visible).
- Added equipped icon fallback to Blizzard check when custom texture fails.
- Reworked Window settings layout with subtitles and spacing controls.
- Updated default/min window size to 500x456.
- Stored item specs by ID with automatic migration for multi-language stability.
- Forced spec names to respect addon language (EN/ES) when using spec IDs.
- Added Bug Report help section with copy-friendly links + localized copy hint text.
- Spec row dropdown now closes when clicking outside and stays anchored to the row.
- Removed Status help scrollbar visuals while keeping mousewheel scrolling.
- Coin reminder now waits 30s after boss death if no drop was seen; drop blocks coin reminders until roll resolution.
- Pre-warning now checks 3s after boss death when the bonus roll window is visible.
- Added alert debug logging for prewarning/drop/win/other-won/coin reminders.
- Added optional chat alert when a boss has no items on your list (only if the instance has tracked items).
- Added debug logging for bonus roll window visibility checks.
- Reduced loot debug spam to tracked items only.
- Help icon reset now clears all settings and minimap/window state, but only resets the current character's list.
## 1.4-test
- Added primary color theming via a single hex value and applied it across UI accents.
- Reskinned Help as a right-side icon with active highlight and custom icon support.
- Reworked bottom tabs (My List texture + active/inactive styling, sizing, and borders).
- Added reload confirmation dialog for window lock and language changes.
- Updated Help Guide layout (art, sizing) and adjusted panel spacing/margins.
- Added custom journal icon and updated tooltip text.
- Added debug log entry for coin reminder when another player wins your item and a bonus roll is available.
- Fixed slot category localization to refresh after language changes.
- Added Help Guide content updates (method step 3 and watch-note text).
- Refined Help layouts (Tips/Status ordering, spacing, colors) and added Bug Report/Credits sections.
- Updated loot alert text formatting (WON 3-line format, DROP item line uses item color).
- Added coin pre-warning frame with background; applied to other-won and coin-lost messages.
- Updated other-won gating to require item announcement/loot view + player roll before alerting.
- Adjusted window defaults/min size to 480x436 and updated reset dimensions.
- Added custom equipped icon and tuned equipped label color + inline icon.
- Tweaked filters panel visuals (darker background and dropdowns) and help icon glow sizing.
## 1.3-test
- Colored addon title in the AddOns list (jade).
- Added preview reset to prevent overlapping alert visuals.
- Set "other won" sound to 50% on the SFX channel (preview and real).
- Increased settings text wrapping and widened label/description area.
- Increased default/min window width and adjusted reset position to right with 10% margin.
## 1.2-test
- Automatic spec detection.
- Spec changes per item list entry.
- Added multi-language support.
- Updated coin reminder system alerts.
## 1.0-test
- Initial release.
- Coin system and List emerges from the void.
