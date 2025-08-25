package guru.learningjournal.kafka.examples;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.File;
import java.util.Scanner;

public class Dispatcher implements Runnable {

    private static final Logger logger = LogManager.getLogger(Dispatcher.class);

    private final String fileLocation;
    private final String topicName;
    private final KafkaProducer<Integer, String> producer;

    public Dispatcher(KafkaProducer<Integer, String> producer, String topicName, String fileLocation) {
        this.fileLocation = fileLocation;
        this.topicName = topicName;
        this.producer = producer;
    }

    @Override
    public void run() {
        logger.info("Start Processing file: {}", fileLocation);
        File file = new File(fileLocation);
        Scanner scanner = null;
        int count = 0;

        try {
            scanner = new Scanner(file);
            while (scanner.hasNextLine()) {
                String line = scanner.nextLine();
                producer.send(new ProducerRecord<Integer, String>(topicName, null, line));
                count++;
            }
        } catch (Exception e) {
            logger.error("Error processing file: {}", fileLocation, e);
        } finally {
            if (scanner != null) {
                scanner.close();
            }
            // Don't close the producer here - let the main thread handle it
        }
        logger.info("Completed processing file: {}, total records: {}", fileLocation, count);
    }
}