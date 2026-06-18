#!/bin/sh
# Seed historical images into the UPLOAD/IMAGES directory.
# Only copies files that don't already exist, so new uploads are never overwritten.
SEED_DIR="/app/UPLOAD_SEED/IMAGES"
TARGET_DIR="/app/UPLOAD/IMAGES"

if [ -d "$SEED_DIR" ]; then
  mkdir -p "$TARGET_DIR"
  for f in "$SEED_DIR"/*; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    if [ ! -f "$TARGET_DIR/$name" ]; then
      cp "$f" "$TARGET_DIR/$name"
      echo "[seed] Copied $name"
    fi
  done
fi

exec /app/server "$@"
