#!/bin/bash
set -euo pipefail
[ "${1:-}" = "--yes" ] || { echo "Usage: restore.sh --yes [timestamp]. This replaces current data."; exit 1; }
cd "$(dirname "$0")/.."
set -a; source .env; set +a
export PATH="$PATH:/snap/bin"
TS="${2:-$(aws s3 ls "s3://$S3_BUCKET/backups/" | awk '{print $2}' | sort | tail -n 1 | tr -d '/')}"
echo "Restoring backup $TS"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
aws s3 cp "s3://$S3_BUCKET/backups/$TS/" "$WORK" --recursive --only-show-errors
( cd "$WORK" && sha256sum -c SHA256SUMS )
docker compose exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
gunzip -c "$WORK/db.sql.gz" | docker compose exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
tar -C "$(dirname "$FILES_DIR")" -xzf "$WORK/files.tar.gz"
echo "Restore complete"
