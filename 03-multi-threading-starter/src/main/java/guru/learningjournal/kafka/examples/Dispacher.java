package guru.learningjournal.kafka.examples;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.File;
import java.util.Scanner;

public class Dispacher implements Runnable {

    private static final Logger logger = LogManager.getLogger(Dispacher.class);

    private String fileLocation;
    private final String topicName;
    private KafkaProducer<String, String> producer;

    public Dispacher(KafkaProducer<String, String> producer, String topicName, String fileLocation) {
        this.fileLocation = fileLocation;
        this.topicName = topicName;
        this.producer = producer;
    }

    @Override
    public void run() {
        logger.info("Start Processing file: " + fileLocation);
        File file = new File(fileLocation);
        Scanner scanner = null;
        int count = 0;

        try {
            scanner = new Scanner(file);
            while (scanner.hasNextLine()) {
                String line = scanner.nextLine();
                producer.send(new ProducerRecord<String, String>(topicName, null, line));
                count++;
            }
        } catch (Exception e) {
            logger.error("Error processing file: " + fileLocation, e);
        } finally {
            if (scanner != null) {
                scanner.close();
            }
            producer.close();
        }
        logger.info("Completed processing file: " + fileLocation + ", total records: " + count);
    }
}