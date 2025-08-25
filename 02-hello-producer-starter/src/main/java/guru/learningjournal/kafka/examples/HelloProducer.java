package guru.learningjournal.kafka.examples;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Properties;

public class HelloProducer {

    private static final Logger logger = LoggerFactory.getLogger(HelloProducer.class);

    public static void main(String[] args) {
        logger.info("Creating Kafka Producer...");
        Properties props = new Properties();
        props.put(ProducerConfig.CLIENT_ID_CONFIG, AppConfigs.applicationID);
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, AppConfigs.bootstrapServers);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.IntegerSerializer");
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer");
        logger.info("Kafka Producer properties: {}", props);

        KafkaProducer<Integer, String> producer = new KafkaProducer<>(props);
        logger.info("Kafka Producer created");

        logger.info("Creating ProducerRecord...");
        for (int i = 0; i < AppConfigs.numEvents; i++) {
           producer.send(new ProducerRecord<>(AppConfigs.topicName, i, "Hello " + i));
        }
        logger.info("ProducerRecord sent");

        producer.close();
        logger.info("Exiting...");
    }
}
