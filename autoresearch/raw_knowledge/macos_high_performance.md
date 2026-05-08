# macOS High-Performance Mount Guide (14k+ Torrents)

## 1. Rclone Optimization (The macOS Secret)
Standard Rclone mounts fail on Mac with 14,000 items because macOS tries to "preview" or "index" every folder (Spotlight/Finder), which crashes the FUSE socket.
- **`--dir-cache-time 1000h`**: DO NOT use short times for 14k items. Keep the directory structure in memory as long as possible.
- **`--vfs-cache-mode writes`**: Mandatory for stability.
- **`--attr-timeout 1000h`**: Prevents macOS from constantly asking "has this file size changed?" over the internet.
- **`--no-modtime`**: Speeds up listings by not fetching modification times from RD.

## 2. cli_debrid <-> Jellyseerr Mapping
Jellyseerr expects a Radarr/Sonarr server. `cli_debrid` emulates this on Port `5000`.
- **Radarr Integration in Jellyseerr:**
    - Host: `cli_debrid`
    - Port: `5000`
    - API Key: (Found in `cli_debrid` settings).
    - **Note:** You must set a "Root Folder" in cli_debrid (e.g., `/mnt/zurg/movies`) before Jellyseerr will accept the connection.

## 3. CineSync "Stuck" Avoidance
With 14,000 items, CineSync's first run will take 30-60 minutes. 
- **Fix:** Do not point Jellyfin to the destination folder until CineSync's log says "Initial Scan Complete". This prevents two scanners from fighting over the same files.

## 4. Self-Critique / Edge Cases
- **Edge Case:** Zurg's `config.yml` internal segregation (`movies/`, `shows/`) MUST match the Rclone mount point. If Rclone mounts the root, but CineSync looks for `/source/movies`, and Zurg has it at `/data/movies`, the links will break.
- **Solution:** I will use absolute paths in the `docker-compose.yml` to ensure no mapping errors.
