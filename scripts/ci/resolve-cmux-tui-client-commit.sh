#!/usr/bin/env bash
# Resolve the immutable official client matching this v0.64.25 backport.
# The published a149b7e build has the same cmux-tui tree and Ghostty gitlink
# as release b685a275. Installation still verifies its manifest attestation
# and binary checksums against the upstream publishing workflow.
set -euo pipefail

CLIENT_COMMIT=a149b7e22dac4df2a99fbfdcfede1bb4640f7a6c
EXPECTED_TUI_TREE=02728bc220faefe56ce1ba35ff248a2739023fee
EXPECTED_GHOSTTY=4a0e9e185313fd9d09b2f3564a3dfbab444453c0
HEAD_REV=HEAD

while [[ $# -gt 0 ]]; do
  case "$1" in
    --head) shift; HEAD_REV="${1:?--head needs a value}" ;;
    --max-fallback)
      shift
      [[ "${1:-}" == 0 ]] || {
        echo "error: this release backport permits no client fallback" >&2
        exit 64
      }
      ;;
    -h|--help)
      echo "usage: $0 [--head <rev>] [--max-fallback 0]"
      exit 0
      ;;
    *) echo "unknown option: $1" >&2; exit 64 ;;
  esac
  shift
done

source_sha="$(git rev-parse --verify "${HEAD_REV}^{commit}")"
actual_tui="$(git rev-parse --verify "$source_sha:cmux-tui")"
actual_ghostty="$(git rev-parse --verify "$source_sha:ghostty")"
if [[ "$actual_tui" != "$EXPECTED_TUI_TREE" || "$actual_ghostty" != "$EXPECTED_GHOSTTY" ]]; then
  echo "error: source client inputs differ from the pinned v0.64.25 client" >&2
  exit 1
fi
printf '%s\n' "$CLIENT_COMMIT"
