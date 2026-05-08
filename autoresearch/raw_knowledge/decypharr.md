# Decypharr - Lightweight Filename Renamer
## Core Purpose
A specialized tool that "decyphers" and renames files within a Debrid mount to make them readable by Plex/Jellyfin.

## Key Features
- **Regex Renaming:** Strips junk like `[10bit][x265][RARBG]` from filenames.
- **Zurg Native:** Built specifically to sit on top of a Zurg mount.
- **Increase Match Rate:** Dramatically improves Jellyfin's ability to identify movies/shows automatically.

## Setup
- **Type:** CLI or Docker.
- **Input:** Points to the Zurg `/__all__` or `/movies` path.
- **Output:** A virtual view or symlinked folder with clean names.

## Why use it?
- If you want to keep the Zurg mount direct but hate the messy filenames.
- Lowest overhead of all management tools.
