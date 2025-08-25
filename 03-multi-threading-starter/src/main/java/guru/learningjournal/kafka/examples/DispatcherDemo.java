package guru.learningjournal.kafka.examples;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.serialization.StringSerializer;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Properties;

public class DispatcherDemo {

    private static final Logger logger = LogManager.getLogger();

    public static void main(String[] args) {
        Properties props = new Properties();
        try{
            InputStream inputStream = Files.newInputStream(Paths.get(AppConfigs.kafkaConfigFileLocation));
            props.load(inputStream);
            props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, AppConfigs.bootstrapServers);
            props.put(ProducerConfig.CLIENT_ID_CONFIG, AppConfigs.applicationID);
            props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
            props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());

            logger.info("Producer configuration created successfully");
            logger.info("Bootstrap servers: {}", AppConfigs.bootstrapServers);
            logger.info("Application ID: {}", AppConfigs.applicationID);
        }catch (Exception e){
            throw new RuntimeException(e);
        }

        KafkaProducer<Integer, String> producer = new KafkaProducer<>(props);
        
        // Create dispatcher threads
        Thread thread1 = new Thread(new Dispatcher(producer, AppConfigs.topicName, "src/main/resources/data/nse_eod_01.csv"));
        Thread thread2 = new Thread(new Dispatcher(producer, AppConfigs.topicName, "src/main/resources/data/nse_eod_02.csv"));
        
        logger.info("Starting both dispatcher threads...");
        thread1.start();
        thread2.start();
        
        try {
            // Wait for both threads to complete
            logger.info("Waiting for thread 1 to complete...");
            thread1.join();
            logger.info("Thread 1 completed");
            
            logger.info("Waiting for thread 2 to complete...");
            thread2.join();
            logger.info("Thread 2 completed");
            
            logger.info("All files processed successfully");
            
        } catch (InterruptedException e) {
            logger.error("Error in thread join - interrupting threads", e);
            thread1.interrupt();
            thread2.interrupt();
            Thread.currentThread().interrupt();
        } finally {
            // Only close the producer after all threads have completed
            logger.info("Flushing producer to ensure all messages are sent...");
            producer.flush();
            logger.info("Closing producer...");
            producer.close();
            logger.info("Producer closed successfully");
        }
    }
}