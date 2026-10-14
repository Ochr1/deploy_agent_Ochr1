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
