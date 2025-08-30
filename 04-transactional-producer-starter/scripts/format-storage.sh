#!/bin/bash
# Format Kafka storage directories for KRaft mode
echo "Formatting Kafka storage directories for KRaft mode..."

# Create log directories in project folder
echo "Creating log directories in project folder..."
mkdir -p logs/kraft-combined-logs-1
mkdir -p logs/kraft-combined-logs-2
mkdir -p logs/kraft-combined-logs-3

# Update server properties to use local log directories
echo "Updating server properties to use local log directories..."

# Update server-1.properties
sed -i.bak 's|log.dirs=/tmp/kraft-combined-logs-1|log.dirs=logs/kraft-combined-logs-1|' $KAFKA_HOME/etc/kafka/server-1.properties

# Update server-2.properties
sed -i.bak 's|log.dirs=/tmp/kraft-combined-logs-2|log.dirs=logs/kraft-combined-logs-2|' $KAFKA_HOME/etc/kafka/server-2.properties

# Update server-3.properties
sed -i.bak 's|log.dirs=/tmp/kraft-combined-logs-3|log.dirs=logs/kraft-combined-logs-3|' $KAFKA_HOME/etc/kafka/server-3.properties

# Check if we have an existing formatted directory
if [ -f "logs/kraft-combined-logs-1/meta.properties" ]; then
    # Get the cluster ID from the existing formatted directory
    echo "Getting cluster ID from existing formatted directory..."
    CLUSTER_ID=$(find logs/kraft-combined-logs-1 -name "meta.properties" -exec grep "cluster.id" {} \; | cut -d'=' -f2)
    
    if [ -z "$CLUSTER_ID" ]; then
        echo "Error: Could not get cluster ID from existing directory"
        exit 1
    fi
    
    echo "Cluster ID: $CLUSTER_ID"
    
    # Format storage for node 2 (non-controller)
    echo "Formatting storage for node 2..."
    $KAFKA_HOME/bin/kafka-storage format -t 2 -c $KAFKA_HOME/etc/kafka/server-2.properties --cluster-id $CLUSTER_ID --no-initial-controllers
    
    # Format storage for node 3 (non-controller)
    echo "Formatting storage for node 3..."
    $KAFKA_HOME/bin/kafka-storage format -t 3 -c $KAFKA_HOME/etc/kafka/server-3.properties --cluster-id $CLUSTER_ID --no-initial-controllers
else
    # No existing formatted directory, format all nodes from scratch
    echo "No existing formatted directory found. Formatting all nodes from scratch..."
    
    # Format storage for node 1 (controller)
    echo "Formatting storage for node 1..."
    $KAFKA_HOME/bin/kafka-storage format -t 1 -c $KAFKA_HOME/etc/kafka/server-1.properties
    
    # Get the cluster ID from the newly formatted directory
    echo "Getting cluster ID from newly formatted directory..."
    sleep 2  # Wait a bit for the file to be written
    
    CLUSTER_ID=$(find logs/kraft-combined-logs-1 -name "meta.properties" -exec grep "cluster.id" {} \; | cut -d'=' -f2)
    
    if [ -z "$CLUSTER_ID" ]; then
        echo "Error: Could not get cluster ID from newly formatted directory"
        exit 1
    fi
    
    echo "Cluster ID: $CLUSTER_ID"
    
    # Format storage for node 2 (non-controller)
    echo "Formatting storage for node 2..."
    $KAFKA_HOME/bin/kafka-storage format -t 2 -c $KAFKA_HOME/etc/kafka/server-2.properties --cluster-id $CLUSTER_ID --no-initial-controllers
    
    # Format storage for node 3 (non-controller)
    echo "Formatting storage for node 3..."
    $KAFKA_HOME/bin/kafka-storage format -t 3 -c $KAFKA_HOME/etc/kafka/server-3.properties --cluster-id $CLUSTER_ID --no-initial-controllers
fi

echo "Storage formatting complete!"
echo "Log directories created in: $(pwd)/logs/"
