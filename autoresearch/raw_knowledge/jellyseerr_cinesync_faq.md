# Jellyseerr & CineSync Technical Dossier & FAQ

## 1. Jellyseerr (The Request Manager)
### Core Architecture
- **Tech Stack:** Node.js / TypeScript.
- **Database:** Default is SQLite (`settings.json`). Supports PostgreSQL for larger multi-user setups via `DB_TYPE=postgresql`.
- **Default Port:** `5055`.

### Essential Config (Environment Variables)
- `LOG_LEVEL`: Set to `debug` for initial setup.
- `TZ`: Set to your local time zone for accurate request scheduling.
- `ORIGIN`: (Crucial for reverse proxies) e.g., `ORIGIN=http://jellyseerr.yourdomain.com`.

### Frequently Asked Questions (FAQ) & Common Errors
- **Q: "Something went wrong while trying to sign in" (500 Error).**
    - **Fix:** Usually a mismatch between Jellyseerr and Jellyfin's version (specifically Jellyfin 10.11+). Ensure both are up to date and that you are using a fresh API key from Jellyfin.
- **Q: "401 Unauthorized" when using Jellyseerr inside a Jellyfin iFrame.**
    - **Fix:** This is a browser cookie security issue. You must enable "Secure" and "SameSite=None" cookies if using HTTPS, or avoid using iFrames and just use the direct URL.
- **Q: Requests aren't appearing in Riven/cli_debrid.**
    - **Fix:** Check the "Webhook" or "Radarr/Sonarr" integration settings. Riven/cli_debrid usually emulate a Radarr API. Point Jellyseerr's Radarr settings to your Riven/cli_debrid port.

---

## 2. CineSync (The Library Doctor)
### Core Architecture
- **Tech Stack:** Python.
- **Primary Function:** Symlink management and repair for Debrid mounts.
- **Default Port:** `5252`.

### Essential Config (Environment Variables)
- `TMDB_API_KEY`: Required for metadata and cleaning folder names.
- `PUID/PGID`: Set to match your Mac's user (usually `501:20`) to prevent permission errors with symlinks.
- `FILE_PATH_CONVERSION`: (Crucial for macOS/Linux mixed environments). Allows CineSync to understand the difference between `/Users/saranpenna/...` and `/data/...`.

### Frequently Asked Questions (FAQ) & Common Errors
- **Q: "Socket not connected" errors during repair.**
    - **Fix:** This means the source (Zurg mount) has crashed. Restart the Zurg/Rclone service before running CineSync repair.
- **Q: CineSync is creating empty folders.**
    - **Fix:** Verify the `SOURCE` path mapping in Docker. Ensure it points to the root where Zurg shows the movies, not a subfolder.
- **Q: How to handle Anime correctly?**
    - **Fix:** Use the built-in "Anime Classification" feature which checks for tags like `Dual-Audio` or `Multi-Sub`.

---

## 3. The 2026 "Rocksolid" Integration Map
1. **Jellyseerr** -> (Order) -> **cli_debrid** -> (Add to RD) -> **Zurg** -> (Mount) -> **CineSync** -> (Symlink/Clean) -> **Jellyfin**.
2. **Key Check:** Ensure all containers share the same `UID/GID` to avoid "Permission Denied" when creating symlinks across stages.
