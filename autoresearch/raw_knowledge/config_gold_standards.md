# Community-Vetted Configurations (Gold Standards)
## Zurg Optimization (`config.yml`)
### Performance Tuning
- `realdebrid_timeout_secs: 120` (High for stability with large libraries).
- `check_for_changes_every_secs: 10` (If using a refresh script, otherwise 3600).
- `enable_repair: false` (Keep false if using Riven to manage repairs).

### Segregation Regex
- **Movies:** `/^(?!.*(S\d{2}|Season|Sezon|Complete|E\d{2})).*/i`
- **Shows:** `/\b(S\d{2}|Season|Sezon|Complete|E\d{2})\b/i`
- **Anime:** `/\b(Dual-Audio|Multi-Sub|Subs)\b/i` (Optional).

## Riven Ranking Profiles
### "The Purist" (High Quality)
- **Preferred:** 2160p, Remux, HDR, DV, TrueHD, Atmos.
- **Exclude:** Cam, TS, Scr, 480p.
- **Custom Rank:** `[+500] remux`, `[+300] 2160p`.

### "The Data Saver" (Low Bandwidth)
- **Preferred:** 1080p, Web-DL, x265 (smaller size).
- **Exclude:** Remux, 4K (if TV is 1080p).
