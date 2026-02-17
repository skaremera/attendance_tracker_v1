# Attendance Tracker Bootstrap

## Run

```bash
chmod +x setup_project.sh
./setup_project.sh <suffix>
```

Example:

```bash
./setup_project.sh demo
```

If `attendance_tracker_<suffix>` already exists, the script exits with a clear error.

The script creates:
- `attendance_tracker_<suffix>/attendance_checker.py`
- `attendance_tracker_<suffix>/Helpers/assets.csv`
- `attendance_tracker_<suffix>/Helpers/config.json`
- `attendance_tracker_<suffix>/reports/reports.log`
- `attendance_tracker_<suffix>/image.png`

## Features

- Optional threshold update (`warning` default `75`, `failure` default `50`) using `sed -i`.
- Input validation: threshold values must be numeric.
- `SIGINT` (`Ctrl+C`) trap: creates `attendance_tracker_<suffix>_archive.tar.gz` and removes incomplete directory.
- Health check with `python3 --version`.
- Clear failure messages for permission/path/copy errors.

## Quick Test

1. Create project:
```bash
./setup_project.sh test1
```
2. Test threshold update:
```bash
./setup_project.sh test2
```
Choose `y`, then enter values (for example `82` and `58`).
3. Verify config update:
```bash
cat attendance_tracker_test2/Helpers/config.json
```
4. Run attendance app:
```bash
python3 attendance_checker.py
```
5. Verify report output:
```bash
tail -n 10 reports/reports.log
```
6. Test archive behavior:
```bash
./setup_project.sh test3
```
Press `Ctrl+C`, then check:
```bash
ls attendance_tracker_test3_archive.tar.gz
```

## Submission Checklist

- GitHub repository name: `deploy_agent_<your_github_username>`.
- Commit history should show incremental work (script creation, validation improvements, README updates).
- Include a short run-through video explaining:
  - directory automation logic
  - numeric threshold validation + `sed` update
  - `python3 --version` check
  - `SIGINT` trap flow (archive + cleanup)
