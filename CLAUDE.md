# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Brackets is a sports tournament management iOS app built with SwiftUI (iOS 17+). It displays league standings, game schedules, player stats, and tournament brackets. The app connects to a Rails API at `getbrackets.app`. All UI text is in Spanish.

## Build & Run

No terminal build tools available — use Xcode directly:
- **Scheme:** `Brackets`
- **Open:** `Brackets.xcodeproj`
- No third-party dependencies (pure Swift/SwiftUI + URLSession)

## Architecture

**Entry flow:** `BracketsApp` → `LeagueSelectionView` (customer/league picker) → `ContentView` (tournament list with gender filter) → `TournamentContainerView` (tabbed: Standings, Bracket, Games, Stats)

**Networking:** `APIService` singleton with async/await. All endpoints under `{baseURL}/api/`. Base URL is set dynamically when user picks a league. Customer list uses a separate fixed URL with bearer token auth.

**Models:** All `Codable`, `Sendable`, `Identifiable`. Use explicit `CodingKeys` for snake_case mapping. Some models have custom `init(from:)` decoders to handle flexible API responses (e.g., `Venue` can be object or string, `game_sets` can be object or empty array).

**State:** `@Observable` ViewModels (`TournamentsViewModel`, `GamesViewModel`). Most views load data directly via `APIService` in `.task {}`.

**Theming:** `AppConfig` (constants, API config, feature flags) + `AppTheme` (SwiftUI colors, typography, spacing, reusable view components). Design system documented in `Brackets/DESIGN_SYSTEM.md`.

## Key Conventions

- **Dark mode only** — enforced globally in `BracketsApp`
- **Accent color:** Lime green `#C7F24A` — used for winners, buttons, highlights
- **Timezone:** All dates parsed and displayed using `AppConfig.DateTime.apiTimeZone` (`America/Tijuana`). API date strings have timezone offsets stripped before parsing to prevent conversion. Never use `ISO8601DateFormatter` (assumes UTC).
- **Locale:** `es_MX` for all date formatting
- **API flexibility:** Decoders handle multiple date formats, nullable fields, and type variations (string/int/object). When adding new fields, use `decodeIfPresent` with sensible defaults.
- **`gameSets` fallback:** In game detail views (`UpcomingGameView`, `GameResultView`), team info falls back to `teamStats` when `gameSets` is empty/nil.
- **Bracket seeding:** Quarterfinals use standings order: 1v8, 4v5, 2v7, 3v6. Winners propagate to next round placeholders.
- **Player stats:** Filter by `game_played` (show/hide row) and `played` (dim if false). Both default to `false` when null from API.

## API Endpoints

All prefixed with `APIConfig.apiURL` (`{baseURL}/api`):

| Endpoint | Returns |
|----------|---------|
| `/v1/customers` (fixed URL) | `[Customer]` |
| `/tournaments.json` | `[Tournament]` |
| `/tournaments/{id}/standings.json` | `StandingsResult` (flat or grouped) |
| `/tournaments/{id}/games.json` | `GamesResponse` (games by date) |
| `/tournaments/{id}/games/{gameId}.json` | `GameDetailResponse` |
| `/tournaments/{id}/top_stats.json` | `[StatCategory]` |
| `/team_seasons/{id}.json` | `TeamSeasonDetail` |
| `/player_seasons/{id}.json` | `PlayerSeasonDetailResponse` |

## Stage Names

Game `stage` values from the API: `"Ronda regular"`, `"Cuartos de final"`, `"Semifinal"`, `"Final"`. When filtering, use exact match for `"Final"` to avoid matching `"Cuartos de Final"`. The `"Semifinal"` filter also checks for `"Semifinales"`.

## Standings

The standings endpoint can return `"standings"` (flat list) or `"group_standings"` (multiple named groups). A single group named `"DEFAULT"` is treated as flat. The `StandingsResult` enum handles both cases.
