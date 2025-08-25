package guru.learningjournal.kafka.examples;

public class AppConfigs {
    final static String applicationID = "Multi-Threaded-Producer";
    final static String topicName = "nse-eod-topic";
    final static String bootstrapServers = "localhost:9092,localhost:9093,localhost:9094";
    public static String kafkaConfigFileLocation = "src/main/resources/kafka.properties";
}
