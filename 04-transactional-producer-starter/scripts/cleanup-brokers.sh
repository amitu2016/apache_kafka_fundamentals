#!/bin/bash

# Kafka Broker Cleanup Script
# This script stops all Kafka brokers and cleans up log files

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KAFKA_HOME=${KAFKA_HOME:-/Users/amitupadhyay/confluent-8.0.0}
PROJECT_DIR=$(pwd)
LOG_DIR="$PROJECT_DIR/logs"
BACKUP_DIR="$PROJECT_DIR/logs-backup"

# Broker configurations - using regular arrays for compatibility
BROKER_IDS=(1 2 3)
BROKER_CONFIGS=("server-1.properties" "server-2.properties" "server-3.properties")
BROKER_PORTS=(9092 9096 9097)
CONTROLLER_PORTS=(9093 9094 9095)

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "INFO") echo -e "${BLUE}[INFO]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}[WARNING]${NC} $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
    esac
}

# Function to get broker config by ID
get_broker_config() {
    local broker_id=$1
    local index=$((broker_id - 1))
    echo "${BROKER_CONFIGS[$index]}"
}

# Function to check if a broker is running
check_broker_status() {
    local broker_id=$1
    local config_file=$(get_broker_config $broker_id)
    
    if pgrep -f "kafka.Kafka.*$config_file" > /dev/null; then
        return 0  # Broker is running
    else
        return 1  # Broker is not running
    fi
}

# Function to stop a single broker gracefully
stop_broker() {
    local broker_id=$1
    local config_file=$(get_broker_config $broker_id)
    
    print_status "INFO" "Stopping broker $broker_id..."
    
    # Find the process ID
    local pid=$(pgrep -f "kafka.Kafka.*$config_file" || echo "")
    
    if [ -n "$pid" ]; then
        print_status "INFO" "Found broker $broker_id process (PID: $pid)"
        
        # Try graceful shutdown first
        print_status "INFO" "Attempting graceful shutdown..."
        kill -TERM "$pid" 2>/dev/null || true
        
        # Wait for graceful shutdown
        local wait_time=0
        local max_wait=30
        
        while [ $wait_time -lt $max_wait ] && kill -0 "$pid" 2>/dev/null; do
            sleep 1
            wait_time=$((wait_time + 1))
        done
        
        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
            print_status "WARNING" "Graceful shutdown failed, force killing broker $broker_id"
            kill -KILL "$pid" 2>/dev/null || true
            sleep 2
        fi
        
        # Verify process is stopped
        if ! kill -0 "$pid" 2>/dev/null; then
            print_status "SUCCESS" "Broker $broker_id stopped successfully"
            return 0
        else
            print_status "ERROR" "Failed to stop broker $broker_id"
            return 1
        fi
    else
        print_status "WARNING" "Broker $broker_id is not running"
        return 0
    fi
}

# Function to stop all brokers
stop_all_brokers() {
    print_status "INFO" "Stopping all Kafka brokers..."
    
    local stop_errors=0
    
    # Stop brokers in reverse order (3, 2, 1) to minimize impact
    for broker_id in 3 2 1; do
        if ! stop_broker $broker_id; then
            stop_errors=$((stop_errors + 1))
        fi
    done
    
    if [ $stop_errors -eq 0 ]; then
        print_status "SUCCESS" "All brokers stopped successfully"
    else
        print_status "WARNING" "$stop_errors broker(s) had issues during shutdown"
    fi
    
    # Wait a bit for cleanup
    sleep 3
    
    # Final check for any remaining processes
    local remaining_processes=$(pgrep -f "kafka.Kafka" 2>/dev/null | wc -l)
    if [ "$remaining_processes" -gt 0 ]; then
        print_status "WARNING" "Found $remaining_processes remaining Kafka processes, force killing..."
        pkill -KILL -f "kafka.Kafka" 2>/dev/null || true
        sleep 2
    fi
    
    return $stop_errors
}

# Function to backup logs before cleanup
backup_logs() {
    if [ "$1" = "--no-backup" ]; then
        print_status "INFO" "Skipping log backup as requested"
        return 0
    fi
    
    if [ -d "$LOG_DIR" ]; then
        print_status "INFO" "Creating backup of log files..."
        
        # Create backup directory with timestamp
        local timestamp=$(date +"%Y%m%d_%H%M%S")
        local backup_path="$BACKUP_DIR/kafka-logs-$timestamp"
        
        mkdir -p "$BACKUP_DIR"
        
        if cp -r "$LOG_DIR" "$backup_path" 2>/dev/null; then
            print_status "SUCCESS" "Logs backed up to: $backup_path"
            
            # Compress backup
            if command -v tar >/dev/null 2>&1; then
                cd "$BACKUP_DIR"
                tar -czf "kafka-logs-$timestamp.tar.gz" "kafka-logs-$timestamp" 2>/dev/null
                if [ $? -eq 0 ]; then
                    rm -rf "kafka-logs-$timestamp"
                    print_status "SUCCESS" "Backup compressed: kafka-logs-$timestamp.tar.gz"
                fi
                cd "$PROJECT_DIR"
            fi
        else
            print_status "WARNING" "Failed to backup logs, proceeding with cleanup anyway"
        fi
    else
        print_status "INFO" "No log directory found to backup"
    fi
}

# Function to clean log files
clean_logs() {
    print_status "INFO" "Cleaning up log files..."
    
    local cleaned_items=0
    
    # Clean project log directory
    if [ -d "$LOG_DIR" ]; then
        print_status "INFO" "Removing project log directory: $LOG_DIR"
        rm -rf "$LOG_DIR"
        cleaned_items=$((cleaned_items + 1))
    fi
    
    # Clean Confluent logs (optional)
    if [ -d "$KAFKA_HOME/logs" ]; then
        print_status "INFO" "Cleaning Confluent log files..."
        
        # Remove log files but keep directory structure
        find "$KAFKA_HOME/logs" -name "*.log" -type f -delete 2>/dev/null || true
        find "$KAFKA_HOME/logs" -name "*.log.*" -type f -delete 2>/dev/null || true
        find "$KAFKA_HOME/logs" -name "*.out" -type f -delete 2>/dev/null || true
        
        cleaned_items=$((cleaned_items + 1))
        print_status "SUCCESS" "Confluent logs cleaned"
    fi
    
    # Clean temporary files
    print_status "INFO" "Cleaning temporary files..."
    
    # Remove any remaining Kafka processes
    pkill -f "kafka" 2>/dev/null || true
    
    # Clean system temp files related to Kafka
    find /tmp -name "*kafka*" -type d -exec rm -rf {} + 2>/dev/null || true
    find /tmp -name "*kraft*" -type d -exec rm -rf {} + 2>/dev/null || true
    
    cleaned_items=$((cleaned_items + 1))
    
    if [ $cleaned_items -gt 0 ]; then
        print_status "SUCCESS" "Cleanup completed successfully"
    else
        print_status "INFO" "No cleanup needed"
    fi
}

# Function to reset storage (format again)
reset_storage() {
    if [ "$1" = "--reset-storage" ]; then
        print_status "WARNING" "Resetting Kafka storage (this will delete all data)..."
        
        # Remove all log directories
        if [ -d "$LOG_DIR" ]; then
            rm -rf "$LOG_DIR"
            print_status "INFO" "Removed existing log directories"
        fi
        
        # Remove backup directories if requested
        if [ "$2" = "--clean-backups" ] && [ -d "$BACKUP_DIR" ]; then
            print_status "INFO" "Removing backup directories..."
            rm -rf "$BACKUP_DIR"
        fi
        
        print_status "SUCCESS" "Storage reset completed. Run format-storage.sh to reinitialize."
    fi
}

# Function to show cleanup summary
show_summary() {
    print_status "INFO" "=== Cleanup Summary ==="
    
    # Check remaining processes
    local remaining_kafka=$(pgrep -f "kafka" 2>/dev/null | wc -l)
    local remaining_confluent=$(pgrep -f "confluent" 2>/dev/null | wc -l)
    
    if [ "$remaining_kafka" -eq 0 ] && [ "$remaining_confluent" -eq 0 ]; then
        print_status "SUCCESS" "All Kafka processes stopped"
    else
        print_status "WARNING" "Remaining processes: Kafka=$remaining_kafka, Confluent=$remaining_confluent"
    fi
    
    # Check log directories
    if [ ! -d "$LOG_DIR" ]; then
        print_status "SUCCESS" "Project logs cleaned"
    else
        print_status "WARNING" "Project logs still exist"
    fi
    
    if [ -d "$KAFKA_HOME/logs" ]; then
        local log_files=$(find "$KAFKA_HOME/logs" -name "*.log" -o -name "*.log.*" 2>/dev/null | wc -l)
        if [ "$log_files" -eq 0 ]; then
            print_status "SUCCESS" "Confluent logs cleaned"
        else
            print_status "WARNING" "$log_files Confluent log files remain"
        fi
    fi
    
    print_status "INFO" "=== End Summary ==="
}

# Main execution
main() {
    print_status "INFO" "Kafka Broker Cleanup Script Started"
    print_status "INFO" "KAFKA_HOME: $KAFKA_HOME"
    print_status "INFO" "Project Directory: $PROJECT_DIR"
    
    # Check if KAFKA_HOME is set
    if [ ! -d "$KAFKA_HOME" ]; then
        print_status "ERROR" "KAFKA_HOME directory not found: $KAFKA_HOME"
        exit 1
    fi
    
    # Check if we're in the right directory
    if [ ! -f "scripts/format-storage.sh" ]; then
        print_status "ERROR" "Please run this script from the project root directory"
        exit 1
    fi
    
    # Parse command line arguments
    local backup_logs=true
    local reset_storage_flag=false
    local clean_backups=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-backup)
                backup_logs=false
                shift
                ;;
            --reset-storage)
                reset_storage_flag=true
                shift
                ;;
            --clean-backups)
                clean_backups=true
                shift
                ;;
            *)
                print_status "ERROR" "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Stop all brokers
    stop_all_brokers
    
    # Backup logs if requested
    if [ "$backup_logs" = true ]; then
        backup_logs
    fi
    
    # Clean logs
    clean_logs
    
    # Reset storage if requested
    if [ "$reset_storage_flag" = true ]; then
        reset_storage --reset-storage $([ "$clean_backups" = true ] && echo "--clean-backups")
    fi
    
    # Show summary
    show_summary
    
    print_status "INFO" "Cleanup completed successfully"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --no-backup      Skip backing up logs before cleanup"
    echo "  --reset-storage  Reset Kafka storage (delete all data)"
    echo "  --clean-backups  Also remove backup directories (use with --reset-storage)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Normal cleanup with backup"
    echo "  $0 --no-backup        # Cleanup without backup"
    echo "  $0 --reset-storage    # Reset storage and cleanup"
    echo "  $0 --reset-storage --clean-backups  # Reset everything including backups"
}

# Handle command line arguments
case "${1:-cleanup}" in
    "cleanup"|"")
        main "$@"
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        # Check if it's a valid option
        if [[ "$1" == --* ]]; then
            main "$@"
        else
            show_usage
            exit 1
        fi
        ;;
esac
