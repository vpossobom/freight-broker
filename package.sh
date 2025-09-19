#!/bin/bash
set -euo pipefail  # safer: stop on errors, undefined vars, and failed pipes

# Root dir for zips
OUTPUT_DIR="infra"
mkdir -p $OUTPUT_DIR

# Functions to package
for fn in eligibility search; do
  echo "📦 Packaging $fn..."

  FN_DIR="api/$fn"
  PKG_DIR="$FN_DIR/package"

  # Start clean
  rm -rf "$PKG_DIR" && mkdir "$PKG_DIR"

  # Install deps if requirements.txt exists
  if [ -f "$FN_DIR/requirements.txt" ]; then
    pip install -r "$FN_DIR/requirements.txt" -t "$PKG_DIR"
  fi

  # Copy handler code
  cp "$FN_DIR/handler.py" "$PKG_DIR/"

  # Zip everything
  ZIP_PATH="$(pwd)/$OUTPUT_DIR/$fn.zip"
  cd "$PKG_DIR"
  zip -rq "$ZIP_PATH" .   # -q quiet, -r recursive
  cd - > /dev/null

  echo "✅ Created $ZIP_PATH"
done