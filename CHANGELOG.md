# Changelog

All notable changes to this project will be documented in this file.

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
