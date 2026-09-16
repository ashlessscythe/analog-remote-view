#!/usr/bin/env bash
# Package analog-remote-view for Factorio Mod Portal upload.
# Produces: analog-remote-view_<version>.zip containing analog-remote-view_<version>/...
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOD_ROOT="${ROOT}/factorio-mod"

if [[ ! -f "${MOD_ROOT}/info.json" ]]; then
  echo "Missing ${MOD_ROOT}/info.json" >&2
  exit 1
fi

NAME="$(python3 -c "import json; print(json.load(open('${MOD_ROOT}/info.json'))['name'])")"
VERSION="$(python3 -c "import json; print(json.load(open('${MOD_ROOT}/info.json'))['version'])")"
FOLDER="${NAME}_${VERSION}"
ZIP="${FOLDER}.zip"
OUT_DIR="${1:-dist}"

# Factorio in-game / Mod Portal changelog (generated from root CHANGELOG.md)
python3 "${ROOT}/scripts/generate_changelog.py" -i "${ROOT}/CHANGELOG.md" -o "${MOD_ROOT}/changelog.txt"

rm -rf "${OUT_DIR}/${FOLDER}" "${OUT_DIR}/${ZIP}"
mkdir -p "${ROOT}/${OUT_DIR}/${FOLDER}"

should_exclude() {
  local rel="$1"
  case "${rel}" in
    .git|.git/*|.github|.github/*|tests|tests/*|docs|docs/*|dist|dist/*|media|media/*) return 0 ;;
    .gitattributes|.gitignore|CONTRIBUTING.md|CHANGELOG.md) return 0 ;;
    *.sh|*.ps1|*.py) return 0 ;;
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
  dest="${ROOT}/${OUT_DIR}/${FOLDER}/${rel}"
  mkdir -p "$(dirname "${dest}")"
  cp "${MOD_ROOT}/${rel}" "${dest}"
  chmod a-x "${dest}"
done < <(cd "${MOD_ROOT}" && find . -type f -print0)

(
  cd "${ROOT}/${OUT_DIR}"
  rm -f "${ZIP}"
  zip -qrX "${ZIP}" "${FOLDER}"
)

# Keep generated changelog out of the working tree by default; it lives in the zip.
rm -f "${MOD_ROOT}/changelog.txt"

echo "Created ${OUT_DIR}/${ZIP}"
unzip -l "${ROOT}/${OUT_DIR}/${ZIP}" || true
