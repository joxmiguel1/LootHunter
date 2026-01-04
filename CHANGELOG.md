# Changelog

All notable changes to this project will be documented in this file.

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
