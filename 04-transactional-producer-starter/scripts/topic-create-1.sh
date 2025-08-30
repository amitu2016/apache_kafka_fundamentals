#!/bin/bash
# Confluent 8.0.0 uses KRaft mode - no Zookeeper needed
$KAFKA_HOME/bin/kafka-topics --create --bootstrap-server localhost:9092 --topic hello-producer-1 --partitions 5 --replication-factor 3 --config min.insync.replicas=2
