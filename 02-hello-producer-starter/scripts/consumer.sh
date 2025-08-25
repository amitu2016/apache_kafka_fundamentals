#!/bin/bash

# Usage: ./consumer.sh [bootstrap-server]
TOPIC="hello-producer-topic"
BOOTSTRAP_SERVER=${1:-localhost:9092}
echo "Consuming messages from topic '$TOPIC' on broker '$BOOTSTRAP_SERVER'..."

$KAFKA_HOME/bin/kafka-console-consumer \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --topic "$TOPIC" \
  --from-beginning