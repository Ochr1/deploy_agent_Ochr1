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
