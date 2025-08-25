#!/bin/bash
# Confluent 8.0.0 uses KRaft mode - no Zookeeper needed
$KAFKA_HOME/bin/kafka-topics --create --bootstrap-server localhost:9092 --topic invoice --partitions 5 --replication-factor 3 --config segment.bytes=1000000
