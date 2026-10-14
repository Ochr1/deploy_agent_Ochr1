#!/bin/bash

TEMPLATE_DIR="templates"
PROJECT_DIR=""

ask() {
    if ! read -r -p "$1" ANSWER; then
        echo
        echo "No more input. Exiting."
        exit 1
    fi
}

ask_project_name() {
    while true; do
        ask "Enter the project name (letters, numbers, - or _): "
        if [[ "$ANSWER" =~ ^[A-Za-z0-9_-]+$ ]]; then
            PROJECT_NAME="$ANSWER"
            return 0
        fi
        echo "Invalid name. Use only letters, numbers, - or _."
    done
}

ask_number() {
    while true; do
        ask "$1"
        if [[ "$ANSWER" =~ ^(0|[1-9][0-9]{0,2})$ ]] && [ "$ANSWER" -ge "$2" ] && [ "$ANSWER" -le "$3" ]; then
            NUMBER="$ANSWER"
            return 0
        fi
        echo "Invalid value '$ANSWER'. Enter a whole number from $2 to $3."
    done
}

on_interrupt() {
    echo
    echo "Deployment interrupted by $1. Cleaning up..."
    if [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR" ]; then
        rm -f "${PROJECT_DIR}_archive.zip"
        if zip -rq "${PROJECT_DIR}_archive.zip" "$PROJECT_DIR"; then
            echo "Incomplete project saved to ${PROJECT_DIR}_archive.zip"
            rm -rf "$PROJECT_DIR"
            echo "Removed incomplete directory $PROJECT_DIR"
        else
            echo "ERROR: could not create ${PROJECT_DIR}_archive.zip, so $PROJECT_DIR was kept."
        fi
    else
        echo "No project directory was created yet, so there is nothing to archive."
    fi
    echo "Session closed."
    exit 130
}

start_trap() {
    trap 'on_interrupt "Ctrl+C (SIGINT)"' INT
    trap 'on_interrupt "Ctrl+Z (SIGTSTP)"' TSTP
}

stop_trap() {
    trap - INT TSTP
}

preflight_checks() {
    echo "Running pre-flight checks..."
    if ! command -v python3 > /dev/null 2>&1; then
        echo "ERROR: python3 is not installed. Install it and try again."
        return 1
    fi
    if ! python3 --version; then
        echo "ERROR: python3 is installed but does not run."
        return 1
    fi
    if ! command -v zip > /dev/null 2>&1; then
        echo "ERROR: zip is not installed. Install it and try again."
        return 1
    fi
    echo "zip found at $(command -v zip)"
    for f in attendance_checker.py assets.csv config.json; do
        if [ ! -f "$TEMPLATE_DIR/$f" ]; then
            echo "ERROR: $TEMPLATE_DIR/$f is missing. Run this script from the folder that contains templates/."
            return 1
        fi
    done
    if [ ! -w . ]; then
        echo "ERROR: no write permission in $(pwd)."
        return 1
    fi
    echo "Pre-flight checks passed."
}

NAMES=("Amara Uwase" "Brian Mugisha" "Chloe Ingabire" "David Habimana" "Esther Mukamana" "Felix Niyonzima" "Grace Umutoni" "Henry Kamanzi" "Irene Uwimana" "James Nkurunziza")
EMAILS=("amara@example.com" "brian@example.com" "chloe@example.com" "david@example.com" "esther@example.com" "felix@example.com" "grace@example.com" "henry@example.com" "irene@example.com" "james@example.com")

build_roster() {
    local roster="$PROJECT_DIR/Helpers/assets.csv"
    echo "How should the roster be built?"
    echo "  A) Copy students from the template roster"
    echo "  B) Generate a fresh roster"
    while true; do
        ask "Choose A or B: "
        case "$ANSWER" in
            A|a) ROSTER_OPTION="A"; break ;;
            B|b) ROSTER_OPTION="B"; break ;;
            *) echo "Please enter A or B." ;;
        esac
    done

    if [ "$ROSTER_OPTION" = "A" ]; then
        local available
        available=$(tail -n +2 "$TEMPLATE_DIR/assets.csv" | grep -c .)
        ask_number "How many students to copy (1-$available)? " 1 "$available"
        head -n $((NUMBER + 1)) "$TEMPLATE_DIR/assets.csv" > "$roster" || return 1
        echo "Copied $NUMBER students from $TEMPLATE_DIR/assets.csv (total_sessions stays 5)."
    else
        ask_number "How many students to generate (1-${#NAMES[@]})? " 1 "${#NAMES[@]}"
        echo "Email,Names,Attendance Count,Absence Count" > "$roster" || return 1
        for ((i = 0; i < NUMBER; i++)); do
            echo "${EMAILS[$i]},${NAMES[$i]},0,0" >> "$roster" || return 1
        done
        sed -i.bak 's/"total_sessions": [0-9]*/"total_sessions": 1/' "$PROJECT_DIR/Helpers/config.json" || return 1
        rm -f "$PROJECT_DIR/Helpers/config.json.bak"
        echo "Generated $NUMBER new students (total_sessions set to 1)."
    fi
}

ask_threshold() {
    while true; do
        ask "$1"
        if [ -z "$ANSWER" ]; then
            NUMBER="$2"
            return 0
        fi
        if [[ "$ANSWER" =~ ^(0|[1-9][0-9]{0,2})$ ]] && [ "$ANSWER" -le 100 ]; then
            NUMBER="$ANSWER"
            return 0
        fi
        echo "Invalid value '$ANSWER'. Enter a whole number from 0 to 100, or press Enter for $2."
    done
}

update_thresholds() {
    local config="$PROJECT_DIR/Helpers/config.json"
    while true; do
        ask "Update the attendance alert thresholds? (y/n): "
        case "$ANSWER" in
            y|Y) break ;;
            n|N) echo "Thresholds left unchanged."; return 0 ;;
            *) echo "Please enter y or n." ;;
        esac
    done
    while true; do
        ask_threshold "Warning threshold [75]: " 75
        WARNING="$NUMBER"
        ask_threshold "Failure threshold [50]: " 50
        FAILURE="$NUMBER"
        if [ "$FAILURE" -lt "$WARNING" ]; then
            break
        fi
        echo "The failure threshold must be lower than the warning threshold. Try again."
    done
    sed -i.bak -e "s/\"warning\": [0-9]*/\"warning\": $WARNING/" -e "s/\"failure\": [0-9]*/\"failure\": $FAILURE/" "$config" || return 1
    rm -f "$config.bak"
    echo "Thresholds updated in $config:"
    grep -E '"(warning|failure)"' "$config"
}

deploy_failed() {
    echo "ERROR: $1"
    if [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR" ]; then
        rm -rf "$PROJECT_DIR"
        echo "Removed incomplete directory $PROJECT_DIR"
    fi
    PROJECT_DIR=""
    stop_trap
}

deploy_app() {
    PROJECT_DIR=""
    start_trap
    if ! preflight_checks; then
        stop_trap
        return 1
    fi
    ask_project_name
    local target="attendance_tracker_${PROJECT_NAME}"
    if [ -e "$target" ]; then
        echo "$target already exists."
        while true; do
            ask "Overwrite it? This deletes the existing project. (y/n): "
            case "$ANSWER" in
                y|Y) break ;;
                n|N) echo "ERROR: deployment aborted. $target was not changed."; stop_trap; return 1 ;;
                *) echo "Please enter y or n." ;;
            esac
        done
        if ! rm -rf "$target"; then
            deploy_failed "could not remove $target (permission denied?)"
            return 1
        fi
        echo "Removed the old $target"
    fi

    PROJECT_DIR="$target"
    if ! mkdir -p "$PROJECT_DIR/Helpers" "$PROJECT_DIR/reports"; then
        deploy_failed "could not create $PROJECT_DIR (permission denied?)"
        return 1
    fi
    if ! cp "$TEMPLATE_DIR/attendance_checker.py" "$PROJECT_DIR/"; then
        deploy_failed "could not copy attendance_checker.py"
        return 1
    fi
    if ! cp "$TEMPLATE_DIR/config.json" "$PROJECT_DIR/Helpers/"; then
        deploy_failed "could not copy config.json"
        return 1
    fi
    echo "Created $PROJECT_DIR with Helpers/ and reports/"

    if ! build_roster; then
        deploy_failed "could not write Helpers/assets.csv"
        return 1
    fi

    if ! chmod +x "$PROJECT_DIR/attendance_checker.py" || ! chmod 600 "$PROJECT_DIR/Helpers/config.json"; then
        deploy_failed "could not set file permissions"
        return 1
    fi
    echo "Permissions set: attendance_checker.py is executable, config.json is owner read/write only (600)."
    ls -l "$PROJECT_DIR/attendance_checker.py" "$PROJECT_DIR/Helpers/config.json"

    if ! update_thresholds; then
        deploy_failed "could not update thresholds in config.json"
        return 1
    fi

    stop_trap
    echo "Deployment complete: $PROJECT_DIR"
    echo "Verifying the deployment by starting the application..."
    run_project "$PROJECT_DIR"
}

run_project() {
    local dir="$1"
    if [ ! -f "$dir/attendance_checker.py" ] || [ ! -f "$dir/Helpers/assets.csv" ] || [ ! -f "$dir/Helpers/config.json" ]; then
        echo "ERROR: $dir is missing required files. Deploy it again (option 1)."
        return 1
    fi
    echo "Starting attendance_checker.py in $dir"
    (cd "$dir" && python3 attendance_checker.py)
    local status=$?
    if [ $status -eq 0 ]; then
        echo "Application finished successfully."
    else
        echo "Application exited with status $status."
    fi
}

run_app() {
    ask_project_name
    local dir="attendance_tracker_${PROJECT_NAME}"
    if [ ! -d "$dir" ]; then
        echo "ERROR: $dir does not exist. Deploy it first (option 1)."
        return 1
    fi
    run_project "$dir"
}

archive_logs() {
    ask_project_name
    local dir="attendance_tracker_${PROJECT_NAME}"
    if [ ! -d "$dir" ]; then
        echo "ERROR: $dir does not exist. Deploy it first (option 1)."
        return 1
    fi
    if ! mkdir -p "$dir/archives/attendance" "$dir/archives/absent"; then
        echo "ERROR: could not create $dir/archives (permission denied?)"
        return 1
    fi
    local stamp
    stamp=$(date +%Y%m%d_%H%M%S)
    local count=0
    for log in attendance absent; do
        local src="$dir/reports/$log.log"
        local dest="$dir/archives/$log/${log}_${stamp}.log"
        if [ -f "$src" ]; then
            if mv "$src" "$dest"; then
                echo "Archived $src -> $dest"
                count=$((count + 1))
            else
                echo "ERROR: could not archive $src"
            fi
        else
            echo "No $log.log found in $dir/reports/, skipped."
        fi
    done
    echo "$count log file(s) archived."
}

main_menu() {
    while true; do
        echo
        echo "===== Attendance Tracker Deploy Agent ====="
        echo "1) Deploy the application"
        echo "2) Run the application"
        echo "3) Archive the log files"
        echo "4) Exit"
        ask "Choose an option (1-4): "
        case "$ANSWER" in
            1) deploy_app ;;
            2) run_app ;;
            3) archive_logs ;;
            4) echo "Goodbye."; exit 0 ;;
            *) echo "Invalid choice. Enter 1, 2, 3 or 4." ;;
        esac
    done
}

main_menu
