#!/usr/bin/env bash
# Package analog-remote-view for Factorio Mod Portal upload.
# Produces: analog-remote-view_<version>.zip containing analog-remote-view_<version>/...
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

NAME="$(python3 -c "import json; print(json.load(open('info.json'))['name'])")"
VERSION="$(python3 -c "import json; print(json.load(open('info.json'))['version'])")"
FOLDER="${NAME}_${VERSION}"
ZIP="${FOLDER}.zip"
OUT_DIR="${1:-dist}"

# Factorio in-game / Mod Portal changelog (generated from CHANGELOG.md)
python3 scripts/generate_changelog.py -i CHANGELOG.md -o changelog.txt

rm -rf "${OUT_DIR}/${FOLDER}" "${OUT_DIR}/${ZIP}"
mkdir -p "${OUT_DIR}/${FOLDER}"

should_exclude() {
  local rel="$1"
  case "${rel}" in
    .git|.git/*|.github|.github/*|tests|tests/*|docs|docs/*|dist|dist/*|media|media/*) return 0 ;;
    .gitattributes|.gitignore|CONTRIBUTING.md|CHANGELOG.md) return 0 ;;
    *.sh|*.ps1|*.py|scripts/package_mod.sh|scripts/generate_changelog.py) return 0 ;;
    *.zip|*.exe|*.dll|*.so|*.dylib|*.bat|*.cmd|*.com) return 0 ;;
    .DS_Store|*/.DS_Store) return 0 ;;
  esac
  return 1
}

while IFS= read -r -d '' path; do
  rel="${path#./}"
  if should_exclude "${rel}"; then
    continue
  fi
  dest="${OUT_DIR}/${FOLDER}/${rel}"
  mkdir -p "$(dirname "${dest}")"
  cp "${path}" "${dest}"
  chmod a-x "${dest}"
done < <(find . -type f -print0)

(
  cd "${OUT_DIR}"
  rm -f "${ZIP}"
  zip -qrX "${ZIP}" "${FOLDER}"
)

echo "Created ${OUT_DIR}/${ZIP}"
unzip -l "${OUT_DIR}/${ZIP}" || true
