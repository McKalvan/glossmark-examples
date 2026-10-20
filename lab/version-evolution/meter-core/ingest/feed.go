package ingest

import "time"

// @gloss implements mc:ReadingFeed
// Reading is one normalised register value, as published on the readings topic.
type Reading struct {
	MeterID   string    `json:"meter_id"`
	Register  string    `json:"register"`
	ValueKWh  float64   `json:"value_kwh"`
	TakenAt   time.Time `json:"taken_at"`
	Estimated bool      `json:"estimated"`
}
