# Storage Demo - Kafka Producer Example

This project demonstrates a Kafka producer that sends messages to demonstrate storage capabilities. The project has been modernized to support Java 21 and Confluent 8.0.0.

## Prerequisites

- Java 21 (OpenJDK or Oracle JDK)
- Maven 3.6+
- Confluent Platform 8.0.0 (or Apache Kafka 3.6+)

## Project Structure

- **Java Version**: Updated from Java 8 to Java 21
- **Kafka Version**: Updated to 3.6.1 (compatible with Confluent 8.0.0)
- **Build Tool**: Maven with updated compiler plugin

## Setup

1. **Set KAFKA_HOME environment variable**:
   ```bash
   export KAFKA_HOME=/path/to/confluent-8.0.0
   ```

2. **Build the project**:
   ```bash
   mvn clean compile
   ```

## Running the Demo

### Option 1: Automated Broker Management (Recommended)

Use the comprehensive broker management script:

```bash
# Start all brokers with monitoring and auto-restart
./scripts/manage-brokers.sh

# Check broker status
./scripts/manage-brokers.sh status

# Restart failed brokers
./scripts/manage-brokers.sh restart

# Test cluster connectivity
./scripts/manage-brokers.sh test
```

### Option 2: Manual Broker Management

#### 1. Start Kafka Servers (KRaft Mode)

Since Confluent 8.0.0 uses KRaft mode (no Zookeeper needed), start the Kafka servers directly:

```bash
# Terminal 1 - Start first Kafka server
./scripts/0-kafka-server-start.sh

# Terminal 2 - Start second Kafka server  
./scripts/1-kafka-server-start.sh

# Terminal 3 - Start third Kafka server
./scripts/2-kafka-server-start.sh
```

#### 2. Create Topic

```bash
./scripts/topic-create.sh
```

#### 3. Run the Storage Demo

```bash
mvn exec:java -Dexec.mainClass="guru.learningjournal.kafka.examples.StorageDemo"
```

#### 4. Describe Topic (Optional)

```bash
./scripts/describe-topic.sh
```

## Scripts

### Broker Management Scripts

- **`manage-brokers.sh`** - Comprehensive broker management script
  - `./scripts/manage-brokers.sh` - Start all brokers with monitoring
  - `./scripts/manage-brokers.sh status` - Check broker status
  - `./scripts/manage-brokers.sh restart` - Restart failed brokers
  - `./scripts/manage-brokers.sh health` - Wait for cluster health
  - `./scripts/manage-brokers.sh test` - Test cluster connectivity

- **`cleanup-brokers.sh`** - Stop brokers and clean up logs
  - `./scripts/cleanup-brokers.sh` - Normal cleanup with backup
  - `./scripts/cleanup-brokers.sh --no-backup` - Cleanup without backup
  - `./scripts/cleanup-brokers.sh --reset-storage` - Reset storage and cleanup
  - `./scripts/cleanup-brokers.sh --reset-storage --clean-backups` - Reset everything

### Individual Scripts

- `zookeeper-start.sh` - Not needed in KRaft mode (kept for reference)
- `0-kafka-server-start.sh` - Starts first Kafka server
- `1-kafka-server-start.sh` - Starts second Kafka server  
- `2-kafka-server-start.sh` - Starts third Kafka server
- `topic-create.sh` - Creates the invoice topic
- `describe-topic.sh` - Describes the invoice topic
- `format-storage.sh` - Formats Kafka storage for KRaft mode

## Configuration

The application configuration is in `AppConfigs.java`:
- Bootstrap servers: `localhost:9092,localhost:9093`
- Topic: `invoice`
- Number of events: 500,000

## Log Management

- **Project Logs**: Stored in `logs/` directory (local to project)
- **Confluent Logs**: Stored in `$KAFKA_HOME/logs/` directory
- **Backup**: Logs are automatically backed up before cleanup
- **Cleanup**: Use `cleanup-brokers.sh` to stop brokers and clean logs

## Notes

- **KRaft Mode**: Confluent 8.0.0 uses KRaft consensus instead of Zookeeper
- **No Zookeeper**: The zookeeper-start script is not needed
- **Bootstrap Servers**: Use `--bootstrap-server` instead of `--zookeeper` in commands
- **Java 21**: The project now supports modern Java features and performance improvements
- **Auto-Recovery**: The management script automatically detects and restarts failed brokers
- **Log Analysis**: Logs are stored locally for easy analysis and debugging
