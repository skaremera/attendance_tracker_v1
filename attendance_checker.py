import csv
import json
from datetime import datetime
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
HELPERS_DIR = BASE_DIR / "Helpers"
REPORTS_DIR = BASE_DIR / "reports"

ASSETS_FILE = HELPERS_DIR / "assets.csv"
CONFIG_FILE = HELPERS_DIR / "config.json"
REPORT_FILE = REPORTS_DIR / "reports.log"


def load_config() -> dict:
    default = {"warning_threshold": 75, "failure_threshold": 50}
    try:
        with CONFIG_FILE.open("r", encoding="utf-8") as f:
            config = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return default

    warning = int(config.get("warning_threshold", default["warning_threshold"]))
    failure = int(config.get("failure_threshold", default["failure_threshold"]))

    if failure > warning:
        failure, warning = warning, failure

    return {"warning_threshold": warning, "failure_threshold": failure}


def load_students() -> list[dict]:
    students = []
    with ASSETS_FILE.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                total_classes = int(row["total_classes"])
                classes_attended = int(row["classes_attended"])
            except (ValueError, KeyError):
                continue

            if total_classes <= 0:
                continue

            percent = round((classes_attended / total_classes) * 100, 2)
            students.append(
                {
                    "student_id": row.get("student_id", "").strip(),
                    "name": row.get("name", "").strip(),
                    "attendance_percent": percent,
                }
            )

    return students


def get_status(percent: float, warning: int, failure: int) -> str:
    if percent < failure:
        return "FAIL"
    if percent < warning:
        return "WARNING"
    return "OK"


def write_report(lines: list[str]) -> None:
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with REPORT_FILE.open("a", encoding="utf-8") as f:
        f.write(f"\n=== Attendance Run: {timestamp} ===\n")
        for line in lines:
            f.write(line + "\n")


def main() -> None:
    config = load_config()
    students = load_students()

    if not students:
        print("No valid student data found in Helpers/assets.csv")
        return

    warning = config["warning_threshold"]
    failure = config["failure_threshold"]

    output = []
    for student in students:
        status = get_status(student["attendance_percent"], warning, failure)
        line = (
            f"{student['student_id']} | {student['name']} | "
            f"{student['attendance_percent']}% | {status}"
        )
        output.append(line)

    print("Attendance Summary")
    print("------------------")
    for line in output:
        print(line)

    write_report(output)
    print(f"\nReport appended to: {REPORT_FILE}")


if __name__ == "__main__":
    main()
