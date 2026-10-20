package com.meterworks.billing.estimate;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

import org.springframework.stereotype.Component;

import com.meterworks.billing.readings.ReadingStore;

/**
 * Estimates consumption for a period with no actual read: the service point's
 * average daily use over the same period last year, or the regional profile
 * when there is no history.
 */
@Component
public class ReadingEstimator {
    static final long REGIONAL_PROFILE_WH_PER_DAY = 7_900;

    private final ReadingStore readings;

    public ReadingEstimator(ReadingStore readings) {
        this.readings = readings;
    }

    public long estimate(UUID servicePointId, LocalDate start, LocalDate end) {
        long days = ChronoUnit.DAYS.between(start, end) + 1;
        return readings.consumptionBetween(servicePointId, start.minusYears(1), end.minusYears(1))
                .map(lastYear -> lastYear.wh() * days / (ChronoUnit.DAYS.between(start.minusYears(1), end.minusYears(1)) + 1))
                .orElse(REGIONAL_PROFILE_WH_PER_DAY * days);
    }
}
