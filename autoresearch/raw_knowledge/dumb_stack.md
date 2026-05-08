# DUMB (Debrid Unlimited Media Bridge) - The "Super-Stack"
## Core Concept
- **Unified Container:** DUMB is not a single tool, but a wrapper that integrates **Plex/Jellyfin**, **Riven**, **cli_debrid**, **Zurg**, and the **Arr suite** into one Docker image.
- **Goal:** To provide a "Netflix-like" experience with zero-configuration overhead.

## Unique Features
- **Unified Dashboard:** Access all your services (Riven, Zurg, Jellyfin) through a single port (`3005`) and a consolidated UI.
- **Auto-Wiring:** Automatically configures the connections between Zurg, Rclone, and Riven so you don't have to manually edit `settings.json` or `config.yml`.
- **Live Metrics:** Real-time monitoring of your Debrid streaming performance and system resources.
- **Embedded Repair:** Includes CineSync-like logic to handle broken links and library refreshes.

## Integration Path
- **Migration:** If moving to DUMB, you typically stop your individual containers and map your existing `config` and `data` volumes to the DUMB container.
- **Ports:** Primary UI is on `3005`. Internal services (like Riven) still run on their standard ports (`3000`, `8080`) but are managed by DUMB's Traefik proxy.

## Why use it?
- If you are tired of managing 5-10 separate Docker containers.
- If you want a professional-grade dashboard that "just works" with Real-Debrid.
- Best for users who want the "Ultimate" setup without the manual troubleshooting.
