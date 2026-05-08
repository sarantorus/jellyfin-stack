# Debrid-Streaming Knowledge Base (DS-KB)
## Core Components
- **Zurg:** Self-hosted Real-Debrid WebDAV server. Mounts RD library to local filesystem via Rclone.
- **Riven:** Modern, automated Debrid Media Manager. Replaces `plex_debrid`. Handles scraping, downloading (to RD), and symlinking.
- **Real-Debrid (RD):** The backbone. Provides high-speed streaming from torrent sources without local downloading.
- **Jellyfin:** The frontend. Serves organized media to clients.

## Scraping & Indexing
- **Scrapers:**
    - **Torrentio:** The gold standard. Fast and reliable.
    - **Comet:** A high-performance alternative to Torrentio.
    - **Knightcrawler:** Often buggy (as seen in current logs); should be used as a secondary backup or disabled if failing.
    - **Mediafusion:** Good for niche content and IPTV.
- **Indexers:**
    - **Trakt:** Best for syncing watchlists and history.
    - **Overseerr/Jellyseerr:** Best for user requests.

## Best Practices
1. **Segregation:** Use Zurg's `config.yml` to separate movies and shows.
2. **Symlinking:** Always point Jellyfin to Riven's `library` folder, NOT the raw Zurg mount. This ensures clean metadata and faster scanning.
3. **Mount Stability:** On macOS, use `--vfs-cache-mode off` for Zurg mounts to prevent socket errors, but ensure the mount is stable before starting Riven.
4. **API Management:** Keep one dedicated RD account for the stack to avoid IP bans.

## Troubleshooting
- **Socket not connected:** Usually a Fuse/Rclone crash. Requires `docker-compose down` and potentially a manual `umount`.
- **No streams found:** Check scraper health (Torrentio/Comet) and Ranking settings in Riven.
- **Jellyfin not updating:** Verify API key and ensure Riven's Jellyfin Updater is enabled.

## Future Upgrades
- **Navidrome:** Add for high-quality music streaming from RD.
- **Prowlarr/Jackett:** Integrate if Torrentio isn't enough (requires more setup).
- **Zilean:** A DMM-style scraper for Riven to search existing RD hashes faster.
