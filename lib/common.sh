#!/bin/sh
# Common functions for the Main Script

# =============================================================================
# Logging-Function
# =============================================================================
# Logging Level configuration works as follows:
# 0 DEBUG - Provides all logging output
# 1 INFO  - Provides all but debug messages
# 2 WARN  - Provides all but debug and info
# 3 ERROR - Provides all but debug, info and warn

LOG_LEVEL=${LOG_LEVEL:-"INFO"}

init_log() {
    if [ -n "$LOG_LEVEL" ]; then
        case "$LOG_LEVEL" in
            "DEBUG") printf "Log level set to DEBUG\n" ;;
            "INFO") printf "Log level set to INFO\n" ;;
            "WARN") printf "Log level set to WARN\n" ;;
            "ERROR") printf "Log level set to ERROR\n" ;;
            *) printf "Invalid LOG_LEVEL: %s. Defaulting to INFO." "$LOG_LEVEL"; LOG_LEVEL="INFO" ;;
        esac
    fi

    log_dir="/var/log/5etools-docker"

    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
    fi

    log_file="${log_dir}/$(date '+%Y%m%d_%H%M%S').log"
    touch "$log_file"

    log "Logging initialisiert: $log_file" "INFO"
}

# TODO: creating a log file and writing to it instead of stdout.
# Function to log messages with timestamps and log levels
log() {
    log_message="$1"
    log_level="${2:-"INFO"}"

    case "$log_level" in
        "DEBUG")
            if [ "$LOG_LEVEL" = "DEBUG" ] || [ "$LOG_LEVEL" = "INFO" ] || [ "$LOG_LEVEL" = "WARN" ] || [ "$LOG_LEVEL" = "ERROR" ]; then
                write_log "$log_message" "DEBUG"
            fi
            ;;
        "INFO")
            if [ "$LOG_LEVEL" = "INFO" ] || [ "$LOG_LEVEL" = "WARN" ] || [ "$LOG_LEVEL" = "ERROR" ]; then
                write_log "$log_message" "INFO"
            fi
            ;;
        "WARN")
            if [ "$LOG_LEVEL" = "WARN" ] || [ "$LOG_LEVEL" = "ERROR" ]; then
                write_log "$log_message" "WARN"
            fi
            ;;
        "ERROR")
            if [ "$LOG_LEVEL" = "ERROR" ]; then
                write_log "$log_message" "ERROR"
            fi
            ;;
        *)
            write_log "Invalid log level: $log_level. Message: $log_message" "ERROR"
            ;;
    esac
}

write_log() {
    log_message="$1"
    log_level="$2"
    printf "[%s] [%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$log_level" "$log_message" >> "$log_file"
}