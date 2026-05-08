# PRD: The 2026 Infinite Media Stack

## 1. Project Objective
Build a "Gold Standard" 2026 media automation stack on macOS that provides a zero-maintenance, infinite-storage streaming experience using Real-Debrid, Zurg, Jellyseerr, CineSync, and cli_debrid.

## 2. The "Autoresearch" Self-Improvement Loop
- **Context Efficiency:** I will prioritize reading the `jellyfin-stack/autoresearch/raw_knowledge` directory before any web search to minimize token usage.
- **Autonomous Intelligence:** If a "Socket Error" or "API Failure" occurs, I will autonomously search GitHub Issues and Reddit for the *current* 2026 fix and save it as a new `.md` file in the Knowledge Base.
- **Registry Growth:** I will continue to download and store "Gold Standard" configs and troubleshooting FAQs to ensure the system gets smarter over time.

## 3. Implementation Roadmap

### Phase 1: The Foundation (Stability)
- **Action:** Shutdown unstable containers and force-unmount `zurg_mnt`.
- **Optimization:** Update Rclone mount flags for macOS (VFS Cache Mode: Writes, Buffer Size: 64MB).
- **Test Case:** Verify `ls -R` performance on the Zurg mount without I/O errors.

### Phase 2: The Doctor (Organization & Repair)
- **Action:** Deploy **CineSync**.
- **Logic:** Map Zurg raw movies to `library_pro`. Set PUID/PGID to 501:20.
- **Integration:** Configure CineSync to auto-repair broken symlinks every 6 hours.
- **Test Case:** Verify that a sample "messy" Zurg folder results in a clean `Movies/Title (Year)` symlink in `library_pro`.

### Phase 3: The Brain (Automation)
- **Action:** Deploy **cli_debrid** and **Jellyseerr**.
- **Logic:** Configure Jellyseerr to send requests to cli_debrid's Radarr/Sonarr API endpoints.
- **Integration:** Sync cli_debrid with your Trakt/Real-Debrid account.
- **Test Case:** Request a movie in Jellyseerr -> Verify it appears in cli_debrid "Added" queue -> Verify it appears in RD account.

### Phase 4: The Frontend (Display)
- **Action:** Re-point Jellyfin to `library_pro`.
- **Logic:** Disable "Chapter Image Extraction" and "Media Probing" during initial scan to prevent rate-limiting.
- **Test Case:** Confirm Jellyfin identifies the movie with 100% metadata accuracy within 60 seconds of request.

## 4. Documentation & Verification
- **Audit Log:** Every major step will be recorded in `jellyfin-stack/IMPLEMENTATION_LOG.md`.
- **Parallel Testing:** I will run `docker logs` and custom `ls` check scripts in parallel with every container start to verify health.
- **Rollback Plan:** Each phase includes a `docker-compose.yml.bak` backup for immediate reversion if stability is compromised.

---
**Status:** Awaiting User Approval of PRD.
