# Advanced Scraping & Indexing Logic
## Riven Architecture Notes
### Frontend (SvelteKit)
- **State Management:** Uses a local SQLite database (via Drizzle ORM) for authentication and certain UI states. 
- **API Sync:** The frontend generates its API types directly from the backend. If they get out of sync, the UI may show "404" or "Error" even if the backend is fine.
- **Environment:** Requires `ORIGIN` to be set correctly in production to prevent CORS/Cross-Post errors.

## Scraper Meta-Registry
### 1. Comet (Stremio-Comet)
- **Status:** High Performance / Active
- **Source:** https://github.com/stremio-comet/comet
- **Integration:** Add to Riven as a generic Stremio scraper.
- **Why:** Faster than Torrentio for some regions; handles metadata differently, finding links Torrentio misses.

### 2. Zilean (DMM-Search-API)
- **Status:** Essential for Large Libraries
- **Source:** https://github.com/imputnet/zilean
- **Integration:** Requires a separate Docker container; Riven connects via API.
- **Why:** It indexes the Debrid Media Manager (DMM) hashlist. Instead of scraping trackers, it asks Zilean "who has this cached already?" It's instant.

### 3. MediaFusion
- **Status:** Specialized
- **Source:** https://github.com/mhdzumrat/MediaFusion
- **Integration:** Stremio-compatible.
- **Why:** Best for Live TV (IPTV) and niche international content (Bollywood, Anime, etc.).

## Scraper Ranking Logic (Optimization)
1. **Resolution:** 2160p > 1080p > 720p.
2. **Codec:** HEVC (x265) > AVC (x264).
3. **Source:** Remux > Web-DL > HDTV.
4. **Seeders:** In Debrid, seeders don't matter once cached, but for non-cached, prioritize 5+.
