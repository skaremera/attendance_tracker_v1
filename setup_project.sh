#!/usr/bin/env bash
set -euo pipefail

PROJECT_SUFFIX="${1:-}"
if [ -z "$PROJECT_SUFFIX" ]; then
  read -r -p "Enter project name suffix: " PROJECT_SUFFIX
fi

if [ -z "$PROJECT_SUFFIX" ]; then
  echo "Error: project suffix is required."
  exit 1
fi

PROJECT_DIR="attendance_tracker_${PROJECT_SUFFIX}"
ARCHIVE_NAME="attendance_tracker_${PROJECT_SUFFIX}_archive"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE_FILE="${ARCHIVE_NAME}.tar.gz"

fail() {
  echo "Error: $1" >&2
  exit 1
}

is_numeric() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

archive_and_cleanup() {
  echo
  echo "SIGINT received. Archiving current state..."

  if [ -d "$PROJECT_DIR" ]; then
    rm -f "$ARCHIVE_FILE"
    if tar -czf "$ARCHIVE_FILE" "$PROJECT_DIR"; then
      rm -rf "$PROJECT_DIR"
      echo "Archived to $ARCHIVE_FILE and removed incomplete directory."
    else
      echo "Warning: archive creation failed; keeping current directory for safety." >&2
    fi
  else
    echo "No project directory to archive."
  fi

  exit 130
}

trap archive_and_cleanup INT

if [ -e "$PROJECT_DIR" ]; then
  fail "Directory '$PROJECT_DIR' already exists. Use a different suffix or remove it first."
fi

[ -w "." ] || fail "Current directory is not writable."

mkdir -p "$PROJECT_DIR/Helpers" "$PROJECT_DIR/reports" \
  || fail "Could not create project folders (permission denied or invalid path)."

copy_or_create_empty() {
  local src="$1"
  local dst="$2"

  if [ -f "$src" ]; then
    cp "$src" "$dst" || fail "Failed to copy $src to $dst."
  else
    : > "$dst" || fail "Failed to create $dst."
  fi
}

copy_or_create_empty "$SCRIPT_DIR/attendance_checker.py" "$PROJECT_DIR/attendance_checker.py"
copy_or_create_empty "$SCRIPT_DIR/Helpers/assets.csv" "$PROJECT_DIR/Helpers/assets.csv"
copy_or_create_empty "$SCRIPT_DIR/Helpers/config.json" "$PROJECT_DIR/Helpers/config.json"
copy_or_create_empty "$SCRIPT_DIR/reports/reports.log" "$PROJECT_DIR/reports/reports.log"
: > "$PROJECT_DIR/image.png" || fail "Failed to create $PROJECT_DIR/image.png."

if [ ! -s "$PROJECT_DIR/Helpers/config.json" ]; then
  cat > "$PROJECT_DIR/Helpers/config.json" <<'JSON'
{
  "warning_threshold": 75,
  "failure_threshold": 50
}
JSON
fi

echo "Do you want to update attendance thresholds? (y/n)"
read -r UPDATE_THRESHOLDS

if [ "$UPDATE_THRESHOLDS" = "y" ] || [ "$UPDATE_THRESHOLDS" = "Y" ]; then
  read -r -p "Warning threshold (default 75): " WARNING
  read -r -p "Failure threshold (default 50): " FAILURE

  WARNING="${WARNING:-75}"
  FAILURE="${FAILURE:-50}"

  is_numeric "$WARNING" || fail "Warning threshold must be numeric."
  is_numeric "$FAILURE" || fail "Failure threshold must be numeric."

  if [ "$FAILURE" -gt "$WARNING" ]; then
    fail "Failure threshold cannot be greater than warning threshold."
  fi

  sed -i "s/\"warning_threshold\":[[:space:]]*[0-9]\+/\"warning_threshold\": ${WARNING}/" "$PROJECT_DIR/Helpers/config.json" \
    || fail "Failed to update warning threshold with sed."
  sed -i "s/\"failure_threshold\":[[:space:]]*[0-9]\+/\"failure_threshold\": ${FAILURE}/" "$PROJECT_DIR/Helpers/config.json" \
    || fail "Failed to update failure threshold with sed."
fi

echo "Running health checks..."
if python3 --version >/dev/null 2>&1; then
  echo "python3 found: $(python3 --version 2>&1)"
else
  echo "Warning: python3 is not installed or not in PATH."
fi

required_paths=(
  "$PROJECT_DIR/attendance_checker.py"
  "$PROJECT_DIR/Helpers/assets.csv"
  "$PROJECT_DIR/Helpers/config.json"
  "$PROJECT_DIR/reports/reports.log"
  "$PROJECT_DIR/image.png"
)

missing=0
for p in "${required_paths[@]}"; do
  if [ ! -e "$p" ]; then
    echo "Missing: $p"
    missing=1
  fi
done

if [ "$missing" -eq 0 ]; then
  echo "Directory structure validated successfully."
  echo "Setup complete: $PROJECT_DIR"
else
  echo "Warning: directory structure validation failed."
fi
