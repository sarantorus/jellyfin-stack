# Jellyfin Stack Knowledge Transfer (May 8, 2026)

## 🚀 Project Overview
This project is a high-performance, automated media orchestration stack designed for macOS. It leverages Real-Debrid for infinite cloud storage, bypassing the need for large local disk arrays.

### Key Components:
- **Zurg:** Serves Real-Debrid content via WebDAV.
- **Rclone:** Mounts Zurg's WebDAV to the local filesystem (`./mounts/zurg`) using FUSE.
- **CineSync:** (The Doctor) Performs smart sorting and symlinking of raw Zurg content into a clean library structure (`./library_pro`).
- **cli_debrid / Riven:** (The Brain) Manages media requests, scraping, and Trakt synchronization.
- **Jellyfin:** (The Frontend) The media server that presents the clean library to users.
- **Jellyseerr:** User-friendly request interface.

---

## 📈 Current Status: PHASE 4 (Frontend Deployment)
- **Foundation:** COMPLETE. Zurg is mounted stably via Rclone on the host Mac.
- **Sorting:** COMPLETE. CineSync is successfully categorizing ~14.5k torrents.
- **Frontend:** IN PROGRESS. Jellyfin is currently performing its initial deep scan of `./library_pro`.
- **Backend:** Riven is healthy but requires a minor configuration fix for the UI.

---

## 🛠 Critical Files & Directories
- `docker-compose.yml`: The heart of the stack. Contains service definitions.
- `autoresearch/PRD_2026_STACK.md`: The original project requirements and roadmap.
- `IMPLEMENTATION_LOG.md`: Detailed history of changes made during setup.
- `cleaner.py`: A utility script for library maintenance.
- `DS_KNOWLEDGE_BASE.md`: Core concepts and troubleshooting tips for Debrid streaming.

---

## ⚠️ Known Issues & Potential Errors
1. **Riven CORS Error:** 
   - **Symptom:** Unable to save settings in the Riven UI (`http://localhost:3000`).
   - **Fix:** Add `ORIGIN=http://localhost:3000` to the `riven-frontend` environment variables in `docker-compose.yml`.
2. **Broken FUSE Mounts:**
   - **Symptom:** `ls ./mounts/zurg` returns "Socket not connected".
   - **Fix:** Run `docker-compose down`, force unmount using `umount -f ./mounts/zurg`, and restart the Rclone daemon on the host.
3. **Jellyfin Scan Time:**
   - The first scan takes a long time. Ensure the Mac does not go to sleep (use `caffeinate`).

---

## ⏭ Next Steps
1. **Fix Riven CORS:** Apply the `ORIGIN` environment variable.
2. **Complete Jellyfin Scan:** Monitor the scan progress. Once finished, verify metadata for posters and grouping.
3. **Configure Trakt:** Link your Trakt account in Riven to sync watchlists.
4. **Maintenance:** Periodically run `cleaner.py` if symlinks become stale.

---

## 🔒 Security Note
Sensitve files (`.env`, `config.yml`, `*.db`) have been excluded from Git. 
Refer to `config.yml.example` and `cli_debrid_config/config.json.example` to restore your API keys and tokens.
