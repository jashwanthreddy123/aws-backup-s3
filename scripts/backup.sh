#!/bin/bash
set -euo pipefail
umask 077
cd "$(dirname "$0")/.."
set -a; source .env; set +a
export PATH="$PATH:/snap/bin"
TS=$(date +%Y%m%d-%H%M%S)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

docker compose exec -T db pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | gzip > "$WORK/db.sql.gz"
tar -C "$(dirname "$FILES_DIR")" -czf "$WORK/files.tar.gz" "$(basename "$FILES_DIR")"
( cd "$WORK" && sha256sum db.sql.gz files.tar.gz > SHA256SUMS )

aws s3 cp "$WORK" "s3://$S3_BUCKET/backups/$TS/" --recursive --only-show-errors
echo "Backup OK: s3://$S3_BUCKET/backups/$TS/"
