#!/usr/bin/env bash
set -euo pipefail

# ==============================
# 1. GET PROJECT NAME
# ==============================

PROJECT_SUFFIX="${1:-}"

if [[ -z "$PROJECT_SUFFIX" ]]; then
  read -r -p "Enter project name suffix: " PROJECT_SUFFIX
fi

if [[ -z "$PROJECT_SUFFIX" ]]; then
  echo "Error: project suffix is required."
  exit 1
fi

PROJECT_DIR="attendance_tracker_${PROJECT_SUFFIX}"
ARCHIVE_NAME="attendance_tracker_${PROJECT_SUFFIX}_archive"
ARCHIVE_FILE="${ARCHIVE_NAME}.tar.gz"

# ==============================
# 2. FUNCTIONS
# ==============================

fail() {
  echo "Error: $1" >&2
  exit 1
}

is_numeric() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

archive_and_cleanup() {
  echo
  echo "SIGINT detected. Archiving project..."

  if [[ -d "$PROJECT_DIR" ]]; then
    tar -czf "$ARCHIVE_FILE" "$PROJECT_DIR"
    rm -rf "$PROJECT_DIR"
    echo "Archived as $ARCHIVE_FILE and cleaned workspace."
  fi

  exit 130
}

trap archive_and_cleanup INT

# ==============================
# 3. VALIDATION
# ==============================

[[ -e "$PROJECT_DIR" ]] && fail "Directory already exists."
[[ -w "." ]] || fail "Current directory not writable."

# ==============================
# 4. CREATE STRUCTURE
# ==============================

mkdir -p "$PROJECT_DIR/Helpers"
mkdir -p "$PROJECT_DIR/reports"

# ==============================
# 5. CREATE FILES WITH CONTENT
# ==============================

# attendance_checker.py
cat > "$PROJECT_DIR/attendance_checker.py" <<'PY'
import csv
import json
import os
from datetime import datetime

def run_attendance_check():
    # 1. Load Config
    with open('Helpers/config.json', 'r') as f:
        config = json.load(f)

    # 2. Archive old reports.log if it exists
    if os.path.exists('reports/reports.log'):
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        os.rename('reports/reports.log',
                  f'reports/reports_{timestamp}.log.archive')

    # 3. Process Data
    with open('Helpers/assets.csv', mode='r') as f, open('reports/reports.log', 'w') as log:
        reader = csv.DictReader(f)
        total_sessions = config['total_sessions']

        log.write(f"--- Attendance Report Run: {datetime.now()} ---\n")

        for row in reader:
            name = row['Names']
            email = row['Email']
            attended = int(row['Attendance Count'])

            attendance_pct = (attended / total_sessions) * 100
            message = ""

            if attendance_pct < config['thresholds']['failure']:
                message = f"URGENT: {name}, your attendance is {attendance_pct:.1f}%. You will fail this class."
            elif attendance_pct < config['thresholds']['warning']:
                message = f"WARNING: {name}, your attendance is {attendance_pct:.1f}%. Please be careful."

            if message:
                if config['run_mode'] == "live":
                    log.write(f"[{datetime.now()}] ALERT SENT TO {email}: {message}\n")
                    print(f"Logged alert for {name}")
                else:
                    print(f"[DRY RUN] Email to {email}: {message}")

if __name__ == "__main__":
    run_attendance_check()
PY

# assets.csv
cat > "$PROJECT_DIR/Helpers/assets.csv" <<EOF
Email,Names,Attendance Count,Absence Count
alice@example.com,Alice Johnson,14,1
bob@example.com,Bob Smith,7,8
charlie@example.com,Charlie Davis,4,11
diana@example.com,Diana Prince,15,0
EOF

# config.json
cat > "$PROJECT_DIR/Helpers/config.json" <<EOF
{
    "thresholds": {
        "warning": 75,
        "failure": 50
    },
    "run_mode": "live",
    "total_sessions": 15
}
EOF

# reports.log
touch "$PROJECT_DIR/reports/reports.log"

# ==============================
# 6. DYNAMIC CONFIGURATION
# ==============================

read -r -p "Update attendance thresholds? (y/n): " UPDATE

if [[ "$UPDATE" =~ ^[Yy]$ ]]; then
    read -r -p "Warning threshold (default 75): " WARNING
    read -r -p "Failure threshold (default 50): " FAILURE

    WARNING="${WARNING:-75}"
    FAILURE="${FAILURE:-50}"

    is_numeric "$WARNING" || fail "Warning must be numeric."
    is_numeric "$FAILURE" || fail "Failure must be numeric."

    if (( FAILURE > WARNING )); then
        fail "Failure threshold cannot exceed warning threshold."
    fi

    sed -i \
        -e "s/\"warning\": *[0-9]\+/\"warning\": ${WARNING}/" \
        -e "s/\"failure\": *[0-9]\+/\"failure\": ${FAILURE}/" \
        "$PROJECT_DIR/Helpers/config.json"
fi

# ==============================
# 7. HEALTH CHECK
# ==============================

echo "Running health check..."

if python3 --version >/dev/null 2>&1; then
    echo "python3 detected: $(python3 --version)"
else
    echo "Warning: python3 not installed."
fi

echo "Project setup complete: $PROJECT_DIR"
