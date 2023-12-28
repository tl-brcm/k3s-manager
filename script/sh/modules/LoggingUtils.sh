#!/bin/bash

# Function to write log with color
write_log() {
    local message=$1
    local log_type=${2:-INFO}  # Set default log type to INFO if not provided

    # Define colors
    local RED='\033[0;31m'
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local NO_COLOR='\033[0m' # No Color

    # Current timestamp
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Choose color based on log type
    case "$log_type" in
        "INFO")
            color=$GREEN
            ;;
        "WARN")
            color=$YELLOW
            ;;
        "ERROR")
            color=$RED
            ;;
        *)
            color=$NO_COLOR
            ;;
    esac

    # Print colored log message
    echo -e "${color}[$timestamp] [Script] $message${NO_COLOR}"
}

