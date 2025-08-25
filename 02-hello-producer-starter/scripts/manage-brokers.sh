#!/bin/bash

# Kafka Broker Management Script
# This script starts all Kafka brokers, monitors their status, and restarts failed ones

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
MAX_RESTART_ATTEMPTS=3

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

# Function to get broker port by ID
get_broker_port() {
    local broker_id=$1
    local index=$((broker_id - 1))
    echo "${BROKER_PORTS[$index]}"
}

# Function to get controller port by ID
get_controller_port() {
    local broker_id=$1
    local index=$((broker_id - 1))
    echo "${CONTROLLER_PORTS[$index]}"
}

# Function to check if a broker is running
check_broker_status() {
    local broker_id=$1
    local config_file=$(get_broker_config $broker_id)
    local broker_port=$(get_broker_port $broker_id)
    
    # Check if process is running
    if pgrep -f "kafka.Kafka.*$config_file" > /dev/null; then
        # Check if port is listening
        if lsof -i :$broker_port > /dev/null 2>&1; then
            return 0  # Broker is running
        fi
    fi
    return 1  # Broker is not running
}

# Function to start a single broker
start_broker() {
    local broker_id=$1
    local config_file=$(get_broker_config $broker_id)
    
    print_status "INFO" "Starting broker $broker_id with config $config_file..."
    
    # Start broker in background
    nohup $KAFKA_HOME/bin/kafka-server-start $KAFKA_HOME/etc/kafka/$config_file > /dev/null 2>&1 &
    
    # Wait a bit for startup
    sleep 5
    
    # Check if started successfully
    if check_broker_status $broker_id; then
        print_status "SUCCESS" "Broker $broker_id started successfully"
        return 0
    else
        print_status "ERROR" "Failed to start broker $broker_id"
        return 1
    fi
}

# Function to restart a broker
restart_broker() {
    local broker_id=$1
    local config_file=$(get_broker_config $broker_id)
    
    print_status "WARNING" "Restarting broker $broker_id..."
    
    # Kill existing process
    pkill -f "kafka.Kafka.*$config_file" > /dev/null 2>&1 || true
    sleep 2
    
    # Start again
    start_broker $broker_id
}

# Function to start all brokers
start_all_brokers() {
    print_status "INFO" "Starting all Kafka brokers..."
    
    # Check if storage is formatted
    if [ ! -f "$LOG_DIR/kraft-combined-logs-1/meta.properties" ]; then
        print_status "WARNING" "Storage not formatted. Running storage format script..."
        ./scripts/format-storage.sh
    fi
    
    # Start brokers in sequence
    for broker_id in "${BROKER_IDS[@]}"; do
        if ! start_broker $broker_id; then
            print_status "ERROR" "Failed to start broker $broker_id after initial attempt"
        fi
    done
    
    # Wait for all brokers to stabilize
    print_status "INFO" "Waiting for brokers to stabilize..."
    sleep 10
}

# Function to check all broker statuses
check_all_brokers() {
    print_status "INFO" "Checking broker statuses..."
    
    local all_healthy=true
    
    for broker_id in "${BROKER_IDS[@]}"; do
        local config_file=$(get_broker_config $broker_id)
        local broker_port=$(get_broker_port $broker_id)
        
        if check_broker_status $broker_id; then
            print_status "SUCCESS" "Broker $broker_id: RUNNING (Port: $broker_port)"
        else
            print_status "ERROR" "Broker $broker_id: NOT RUNNING (Port: $broker_port)"
            all_healthy=false
        fi
    done
    
    return $([ "$all_healthy" = true ] && echo 0 || echo 1)
}

# Function to restart failed brokers
restart_failed_brokers() {
    print_status "INFO" "Checking for failed brokers and restarting..."
    
    local restart_count=0
    
    for broker_id in "${BROKER_IDS[@]}"; do
        local config_file=$(get_broker_config $broker_id)
        
        if ! check_broker_status $broker_id; then
            print_status "WARNING" "Broker $broker_id is not running, attempting restart..."
            
            if restart_broker $broker_id; then
                print_status "SUCCESS" "Broker $broker_id restarted successfully"
            else
                print_status "ERROR" "Failed to restart broker $broker_id"
                restart_count=$((restart_count + 1))
            fi
        fi
    done
    
    if [ $restart_count -gt 0 ]; then
        print_status "WARNING" "$restart_count broker(s) failed to restart"
        return 1
    fi
    
    return 0
}

# Function to wait for cluster health
wait_for_cluster_health() {
    print_status "INFO" "Waiting for cluster to become healthy..."
    
    local max_wait=60
    local wait_time=0
    
    while [ $wait_time -lt $max_wait ]; do
        if check_all_brokers > /dev/null 2>&1; then
            print_status "SUCCESS" "All brokers are healthy!"
            return 0
        fi
        
        print_status "INFO" "Waiting for cluster health... ($((max_wait - wait_time))s remaining)"
        sleep 5
        wait_time=$((wait_time + 5))
    done
    
    print_status "ERROR" "Cluster did not become healthy within $max_wait seconds"
    return 1
}

# Function to test cluster connectivity
test_cluster() {
    print_status "INFO" "Testing cluster connectivity..."
    
    # Try to create a test topic
    if $KAFKA_HOME/bin/kafka-topics --create --bootstrap-server localhost:9092 --topic test-connectivity --partitions 1 --replication-factor 1 --if-not-exists > /dev/null 2>&1; then
        print_status "SUCCESS" "Cluster connectivity test passed"
        # Clean up test topic
        $KAFKA_HOME/bin/kafka-topics --delete --bootstrap-server localhost:9092 --topic test-connectivity > /dev/null 2>&1 || true
        return 0
    else
        print_status "ERROR" "Cluster connectivity test failed"
        return 1
    fi
}

# Main execution
main() {
    print_status "INFO" "Kafka Broker Management Script Started"
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
    
    # Start all brokers
    start_all_brokers
    
    # Wait for cluster health
    if wait_for_cluster_health; then
        print_status "SUCCESS" "All brokers started successfully!"
        
        # Test cluster connectivity
        if test_cluster; then
            print_status "SUCCESS" "Kafka cluster is fully operational!"
        else
            print_status "WARNING" "Cluster started but connectivity test failed"
        fi
    else
        print_status "ERROR" "Failed to start all brokers successfully"
        exit 1
    fi
    
    print_status "INFO" "Broker management completed"
}

# Handle command line arguments
case "${1:-start}" in
    "start")
        main
        ;;
    "status")
        check_all_brokers
        ;;
    "restart")
        restart_failed_brokers
        ;;
    "health")
        wait_for_cluster_health
        ;;
    "test")
        test_cluster
        ;;
    *)
        echo "Usage: $0 {start|status|restart|health|test}"
        echo "  start   - Start all brokers (default)"
        echo "  status  - Check status of all brokers"
        echo "  restart - Restart failed brokers"
        echo "  health  - Wait for cluster health"
        echo "  test    - Test cluster connectivity"
        exit 1
        ;;
esac
