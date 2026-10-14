# deploy_agent_Ochr1

`deploy_agent.sh` deploys, runs and archives the Student Attendance Tracker (`attendance_checker.py`). The three source files in `templates/` are never modified.

## Requirements

- bash, python3 and zip
- Run the script from this repository folder, so it can find `templates/`

## How to run and select a feature

```bash
chmod +x deploy_agent.sh
./deploy_agent.sh
```

The script shows an interactive numbered menu:

```
1) Deploy the application
2) Run the application
3) Archive the log files
4) Exit
```

Type the number and press Enter. Invalid choices are rejected and the menu is shown again. Options 2 and 3 show a numbered list of the deployed `attendance_tracker_*` projects, and you type the number of the one you want.

## Feature 1: Deploy

1. **Pre-flight checks:** checks that `python3` exists and runs `python3 --version`, checks that `zip` exists, checks that the three template files exist and that the current folder is writable. If anything fails, it stops with a clear error.
2. **Project name:** asks for a name (letters, numbers, `-` or `_` only) and creates `attendance_tracker_{name}/`. If that folder already exists, it asks whether to overwrite it. Answering `n` aborts with an error and leaves the existing folder untouched.
3. **Structure created:**

```
attendance_tracker_{name}/
|-- attendance_checker.py
|-- Helpers/
|   |-- assets.csv
|   `-- config.json
`-- reports/
```

4. **Roster (`Helpers/assets.csv`):**
   - **Option A:** copies the header plus the number of students you choose (1-10) from `templates/assets.csv`.
   - **Option B:** generates the number of students you choose (1-10) from name and email arrays inside the script, with Attendance Count and Absence Count set to 0.
5. **Permissions:** `chmod +x attendance_checker.py` and `chmod 600 Helpers/config.json` (owner read/write only). The script prints `ls -l` of both files as confirmation.
6. **Thresholds:** see below.
7. **Verification:** the deploy ends by starting the application (Feature 2). A successful marking session proves the structure, roster and config work together.

If any step fails (for example, permission denied), the script prints an error, removes the incomplete folder and returns to the menu.

### total_sessions and the roster

`total_sessions` counts all sessions including today's, so it must equal the prior sessions in the roster plus one.

- Option A rows already have 4 prior sessions, so `config.json` is deployed exactly as in the template with `total_sessions: 5`.
- Option B rows have 0 prior sessions, so the script uses `sed` to set `total_sessions: 1` in the deployed copy.

The template file itself is never changed.

## How the threshold update works

After the permissions are set, the script asks `Update the attendance alert thresholds? (y/n)`.

- `n` keeps the template values (warning 75, failure 50).
- `y` asks for the warning value (press Enter for 75) and the failure value (press Enter for 50).

Each value must be a whole number from 0 to 100. Letters, negative numbers, decimals and values above 100 are rejected and asked again. The failure threshold must also be lower than the warning threshold. Only validated numbers reach `sed`:

```bash
sed -i.bak -e "s/\"warning\": [0-9]*/\"warning\": $WARNING/" -e "s/\"failure\": [0-9]*/\"failure\": $FAILURE/" config.json
```

This edits only the `"warning"` and `"failure"` lines in place, without reformatting or reordering the file. The `.bak` backup that `sed -i.bak` creates is deleted afterwards. The `-i.bak` form works with both GNU sed (Linux) and BSD sed (macOS).

## Feature 2: Run

Shows a numbered list of the deployed projects, you choose one by number, it checks that the project files exist, then runs `python3 attendance_checker.py` inside the project folder. The app is interactive: type `P` or `A` for each student.

## Feature 3: How log archiving works

Shows a numbered list of the deployed projects, you choose one by number, then:

1. Creates `archives/attendance/` and `archives/absent/` inside the project if they do not exist.
2. Builds one timestamp with `date +%Y%m%d_%H%M%S`.
3. Moves `reports/attendance.log` to `archives/attendance/attendance_YYYYMMDD_HHMMSS.log` and `reports/absent.log` to `archives/absent/absent_YYYYMMDD_HHMMSS.log`.
4. Prints the final path of each archived log.

The logs are moved, not copied, so each archive holds the sessions since the previous archive and the next run starts fresh logs. If a log does not exist (for example, nobody was absent, so there is no `absent.log`), the script prints `No absent.log found ... skipped.` and continues without crashing.

```
attendance_tracker_{name}/
`-- archives/
    |-- attendance/
    |   `-- attendance_20261014_174335.log
    `-- absent/
        `-- absent_20261014_174335.log
```

## Signal handling: what triggers the archive

When Feature 1 starts, the script runs `trap` for SIGINT (Ctrl+C) and SIGTSTP (Ctrl+Z). If either signal arrives while deploying, the trap function:

1. Prints which signal interrupted the deployment.
2. Zips whatever exists of `attendance_tracker_{name}/` into `attendance_tracker_{name}_archive.zip` with the `zip` command.
3. Deletes the incomplete folder, so no half-made project is left behind.
4. Prints `Session closed.` and exits with status 130.

If the signal arrives before the project folder is created (for example, at the name prompt), there is nothing to zip and the script just exits cleanly. If you interrupt at the "Overwrite it?" prompt, the existing project is left untouched, because the script has not started on it yet.

The trap is removed (`trap - INT TSTP`) as soon as deployment finishes, before `attendance_checker.py` starts. Ctrl+C during a marking session is handled by the Python app itself.

### How to test the Ctrl+C / Ctrl+Z path

1. Run `./deploy_agent.sh`, choose `1`, and enter a name such as `demo`.
2. At `Choose A or B:` press **Ctrl+Z**, or continue to `Update the attendance alert thresholds? (y/n):` and press **Ctrl+C**.
3. Check the result:

```bash
ls -d attendance_tracker_demo        # should say: No such file or directory
unzip -l attendance_tracker_demo_archive.zip
```

The `.zip` contains the partial project as it was at the moment of the interrupt. Interrupting at the roster prompt gives `attendance_checker.py`, `Helpers/config.json` and an empty `reports/`. Interrupting at the threshold prompt also includes `Helpers/assets.csv`.

## How I tested the deployed application

- Option A with 3 and with 10 students, and Option B with 4 students. The app started each time with `total_sessions=5` (A) or `total_sessions=1` (B) and no prior-sessions warning.
- Threshold input: `abc`, `150` and `-5` were rejected, a failure value above the warning value was rejected, and Enter used the default. `config.json` kept its original layout.
- `ls -l` showed `-rwxr-xr-x` for `attendance_checker.py` and `-rw-------` for `config.json`, including after the `sed` edit.
- Existing folder: `n` aborted without changes, `y` replaced the project.
- Permission denied: a read-only folder stopped at the pre-flight check, and a folder that could not be removed gave a clear error.
- Archive: both logs archived, only `attendance.log` archived when nobody was absent, nothing archived on a second run, and an error for a project that does not exist.
- Real Ctrl+C and Ctrl+Z during deployment, as described above.
- Templates unchanged, verified with `md5sum templates/*`:

```
8171bd4911272f2480a306390ffa1e5c  templates/assets.csv
50a59bd7cc0b570839f4921dc7fdaac3  templates/attendance_checker.py
545b85d1057d4ba5d37b6a9898cdca9f  templates/config.json
```

## Video walkthrough

https://your-video-link
