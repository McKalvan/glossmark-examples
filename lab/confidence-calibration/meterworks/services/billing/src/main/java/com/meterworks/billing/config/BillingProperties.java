package com.meterworks.billing.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Settings under {@code billing.*} in application.yml.
 *
 * @param paymentTermsDays days a customer has to pay an invoice before dunning starts
 * @param estimateAfterDays days without an actual read before a period is billed on an estimate
 */
@ConfigurationProperties(prefix = "billing")
public record BillingProperties(int paymentTermsDays, int estimateAfterDays) {
    public BillingProperties {
        if (paymentTermsDays <= 0) {
            paymentTermsDays = 14;
        }
        if (estimateAfterDays <= 0) {
            estimateAfterDays = 35;
        }
    }
}
