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
message_priority=""
configured_priority="" # Default to INFO


init_log() {
    if [ -n "$LOG_LEVEL" ]; then
        case "$LOG_LEVEL" in
            "DEBUG") configured_priority=10 ;;
            "INFO") configured_priority=20 ;;
            "WARN") configured_priority=30 ;;
            "ERROR") configured_priority=40 ;;
            *) printf "Invalid LOG_LEVEL: %s. Defaulting to INFO." "$LOG_LEVEL"; LOG_LEVEL="INFO"; configured_priority=20 ;;
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

    if [ $# -lt 1 ]; then
        log "No message provided to log function.\n" "DEBUG"
        return 1
    elif [ $# -gt 2 ]; then
        log "Too many arguments provided to log function. Only message and optional log level are accepted.\n" "DEBUG"
    fi

    case "$log_level" in
        "DEBUG") message_priority=10 ;;
        "INFO") message_priority=20 ;;
        "WARN") message_priority=30 ;;
        "ERROR") message_priority=40 ;;
        *) message_priority=20;log_level="INFO" ;; # Default to INFO if invalid log level is provided
    esac

    if [ "$message_priority" -ge "$configured_priority" ]; then
        write_log "$log_message" "$log_level"
    fi    
}

write_log() {
    log_message="$1"
    log_level="$2"
    log_line=$(printf "[%s] [%s] %s" "$(date '+%Y-%m-%d %H:%M:%S')" "$log_level" "$log_message")

    case "$log_level" in
        "ERROR"|"WARN")
            printf "%s\n" "$log_line" >> "$log_file"
            printf "%s\n" "$log_line" >&2
            ;;
        *)
            printf "%s\n" "$log_line" >> "$log_file"
            printf "%s\n" "$log_line"
            ;;
    esac
}
