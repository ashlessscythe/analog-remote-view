# Releasing Analog Remote View

GitHub Actions builds the Mod Portal ZIP. You do not need to run `scripts/package_mod.sh` locally unless you want a dry run.

## Steps

1. Bump `factorio-mod/info.json` version and add notes in `CHANGELOG.md`.
2. Commit and push.
3. Tag matching `info.json`: `git tag v0.1.2` then `git push origin v0.1.2`.
4. The **Release** workflow packages the zip, checks it has no executables/scripts, and attaches it to a GitHub Release.
5. Download that zip from the GitHub Release and upload it on the Factorio Mod Portal.
6. If the portal description changed, paste from [mod-portal.md](mod-portal.md).
7. After pushing screenshots, sync `public` so Mod Portal image URLs under `media/` resolve.

CI smoke-tests the same zip rules on pull requests without creating a release.

## Package rules

- Zip name: `analog-remote-view_<version>.zip`
- One top-level folder: `analog-remote-view_<version>/`
- Tag `vX.Y.Z` must match `factorio-mod/info.json` version `X.Y.Z`
- No `.sh` / `.py` / binaries in the zip; execute bits stripped
- `docs/`, packaging `scripts/`, `media/`, and `CHANGELOG.md` stay in git only; Factorio gets generated `changelog.txt`
