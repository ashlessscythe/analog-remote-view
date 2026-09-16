#!/usr/bin/env bash
# Local mirror of the Rust gates in .github/workflows/ci.yml
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> rustfmt"
cargo fmt --all -- --check

echo "==> clippy"
cargo clippy --workspace --all-targets -- -D warnings

echo "==> tests"
cargo test --workspace

echo "==> build"
cargo build --workspace

echo "==> companion smoke (--once)"
cargo run -p analog-remote-view -- --once

echo "All local CI checks passed."
