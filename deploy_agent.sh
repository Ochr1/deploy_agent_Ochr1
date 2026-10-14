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
