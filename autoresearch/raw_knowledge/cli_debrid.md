# cli_debrid (by godver3) - Stable Alternative to Riven
## Core Architecture
- **State Machine:** Uses a robust queue system (Wanted -> Scraping -> Adding -> Checking -> Upgrading).
- **Metadata Battery:** Keeps a local database of your library to minimize external API calls.
- **Collector Logic:** Monitors Plex/Jellyfin to confirm content is "collected" before stopping the automation.

## Key Features
- **Rocksolid Reliability:** Known for not getting "stuck" like Riven often does.
- **Built-in Symlinking:** Can manage a symlinked library structure directly.
- **Multi-Scraper Support:** Works with Zilean, Torrentio, Jackett, and Prowlarr.
- **Upgrade System:** Automatically looks for better quality versions (e.g., replaces 1080p with 4K) if configured.

## Integration with Zurg/Jellyfin
- **Mount Point:** Expects a Zurg/Rclone mount at `/mnt`.
- **API Access:** Requires Real-Debrid API and Trakt API (for metadata).
- **Jellyfin:** Connects via API to scan libraries automatically after adding content.

## Why use it?
- Best for users who find Riven too unstable or "beta".
- Best for massive libraries (14k+ torrents) due to local metadata tracking.
