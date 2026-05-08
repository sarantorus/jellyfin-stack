# CineSync - Library Organization & Repair
## Core Purpose
A Python-based management tool designed to organize debrid & local libraries without needing Sonarr/Radarr.

## Unique Features
- **Symlink Repair Flow:** Automatically identifies broken symlinks (due to RD link expiration) and repairs them.
- **Smart Separation:** Automatically puts 4K, Kids, and Anime content into separate folders using TMDB metadata.
- **Layout Options:** Can use "CineSync Layout" (Clean Movies/Shows folders) or preserve original source structure.
- **Web UI:** Modern, JWT-authenticated dashboard for easy management.

## Setup for Jellyfin-Stack
- **Image:** `sureshfizzy/cinesync`
- **Volumes:** Maps Zurg mount (source) to organized media folder (destination).
- **Metatdata:** Requires a TMDB API Key.

## Why use it?
- Perfect for fixing "Socket not connected" or "Broken link" issues.
- Best for organizing large, messy Debrid mounts into clean folders for Jellyfin.
