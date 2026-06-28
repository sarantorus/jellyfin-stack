# Moving MastCast into its own repository

MastCast currently lives inside the `jellyfin-stack` repo only because this
session's GitHub access is scoped to that one repo — creating a new repo was
denied (`403 Resource not accessible by integration`). The code is fully
self-contained (zero Jellyfin coupling), so extracting it is a copy.

## Option A — fresh repo, history not needed (simplest)

```sh
# 1. Create an empty repo "MastCast" at https://github.com/new (no README).
# 2. From a clone of jellyfin-stack on the feature branch:
cd jellyfin-stack
cp -R MastCast /tmp/MastCast && cd /tmp/MastCast
git init -b main
git add .
git commit -m "Initial commit: MastCast"
git remote add origin git@github.com:<you>/MastCast.git
git push -u origin main
```

## Option B — preserve history with git subtree

```sh
# From a clone of jellyfin-stack:
git subtree split --prefix=MastCast -b mastcast-only
# Then push that branch to the new empty repo:
git push git@github.com:<you>/MastCast.git mastcast-only:main
```

## Option C — let Claude do it

Create the empty `MastCast` repo and grant this session access to it, then ask
Claude to push — everything under `MastCast/` will be moved over with the same
structure.
