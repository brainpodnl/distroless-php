#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

MANIFESTS=(
  php/common.yaml
  php/wkhtmltopdf.yaml
  php/7.2/php.yaml
  php/7.4/php.yaml
  php/8.3/php.yaml
  php/8.4/php.yaml
  php/8.5/php.yaml
  nginx/bookworm.yaml
)

LOCK_TARGETS=(
  @php-common//:lock
  @php-wkhtmltopdf//:lock
  @php-7.2//:lock
  @php-7.4//:lock
  @php-8.3//:lock
  @php-8.4//:lock
  @php-8.5//:lock
  @nginx-bookworm//:lock
)

fetch_latest_timestamp() {
  local archive="$1"
  local year month
  year=$(date -u +%Y)
  month=$(date -u +%-m)
  local url="https://snapshot.debian.org/archive/${archive}/?year=${year}&month=${month}"
  curl -sfL "$url" \
    | grep -oE '[0-9]{8}T[0-9]{6}Z' \
    | sort -u \
    | tail -1
}

echo "Fetching latest snapshot timestamps..."
DEBIAN_TS=$(fetch_latest_timestamp "debian")
SECURITY_TS=$(fetch_latest_timestamp "debian-security")

if [[ -z "$DEBIAN_TS" || -z "$SECURITY_TS" ]]; then
  echo "Error: failed to fetch snapshot timestamps" >&2
  exit 1
fi

echo "  debian:          $DEBIAN_TS"
echo "  debian-security: $SECURITY_TS"

echo "Updating YAML manifests..."
for manifest in "${MANIFESTS[@]}"; do
  file="$REPO_ROOT/$manifest"
  perl -pi -e \
    "s#snapshot\.debian\.org/archive/debian-security/\d{8}T\d{6}Z#snapshot.debian.org/archive/debian-security/${SECURITY_TS}#g" \
    "$file"
  perl -pi -e \
    "s#snapshot\.debian\.org/archive/debian/\d{8}T\d{6}Z#snapshot.debian.org/archive/debian/${DEBIAN_TS}#g" \
    "$file"
  echo "  updated $manifest"
done

echo "Regenerating lock files..."
for target in "${LOCK_TARGETS[@]}"; do
  echo "  bazel run $target"
  (cd "$REPO_ROOT" && bazel run "$target")
done

echo "Done."
