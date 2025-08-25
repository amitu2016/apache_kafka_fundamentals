#!/bin/bash
# Confluent 8.0.0 uses KRaft mode - no Zookeeper needed
$KAFKA_HOME/bin/kafka-topics --describe --bootstrap-server localhost:9092 --topic nse-eod-topic
