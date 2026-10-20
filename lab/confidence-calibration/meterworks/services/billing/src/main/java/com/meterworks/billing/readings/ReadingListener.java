package com.meterworks.billing.readings;

import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

import com.google.protobuf.InvalidProtocolBufferException;
import com.meterworks.readings.v1.ReadingReceived;

/** Stores every accepted meter reading the ingest service publishes. */
@Component
public class ReadingListener {
    private final ReadingStore store;

    public ReadingListener(ReadingStore store) {
        this.store = store;
    }

    @KafkaListener(topics = "meter.readings.v1", groupId = "billing")
    public void onReading(byte[] payload) throws InvalidProtocolBufferException {
        ReadingReceived event = ReadingReceived.parseFrom(payload);
        store.append(event.getMeterSerial(), event.getRegister().name(), event.getReadAtUnix(), event.getCumulativeWh());
    }
}
