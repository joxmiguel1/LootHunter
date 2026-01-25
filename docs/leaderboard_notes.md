# Leaderboard module (for future use)

- UI: `Stats.lua` – functions `BuildLeaderboard` and the leaderboard block inside `BuildStatsPanel`. Uses textures `Textures/icon_first.tga`, `icon_second.tga`, `icon_third.tga`. Button icon `Textures/icon_alert.tga` (speaker).
- Data: `LootHunter.lua` – `StatsStore:GetSessionLeaderboard` builds per-player counts from `session.items`. `GetSessionItems`, `GetSessionList`, and `GetSessionByKey` supply session data. Sessions store `items`, `perPlayer`, `deaths`, `revives`.
- Announce: `Stats.lua` – `AnnounceSessionToGuild(session, leaderboard)` formats a message (top 3 + wall of shame) and currently prints locally. Button creation is gated by `ENABLE_LEADERBOARD`.
- Toggle: `Stats.lua` defines `ENABLE_LEADERBOARD` (currently false). Re-enable by setting to true and restoring the leaderboard frame, announce button, and lootHeader anchor to leaderboard.
- Localized strings: `Localization.lua` `STATS_ANNOUNCE_GUILD_*`, `STATS_WALL_*`, tooltip `STATS_ANNOUNCE_GUILD_TOOLTIP`.
- Wall of shame: `Stats.lua` uses `GetWallOfShame` to read `session.deaths` / `session.revives` (populated in `LootHunter.lua` via combat log).
