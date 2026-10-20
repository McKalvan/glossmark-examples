package ingest

import (
	"context"
	"fmt"
	"time"
)

// HeadEnd is the vendor system that talks to meters over the air.
type HeadEnd interface {
	Poll(ctx context.Context, since time.Time) ([]RawRead, error)
}

// RawRead is a register value as the head-end reports it, before normalisation.
type RawRead struct {
	Serial   string
	Channel  int
	WattHour int64
	At       time.Time
}

// Publisher sends normalised readings to subscribers.
type Publisher interface {
	Publish(ctx context.Context, r Reading) error
}

// @gloss implements mc:ReadingIngestor
// Ingestor polls one head-end and publishes every reading it has not seen.
type Ingestor struct {
	head HeadEnd
	pub  Publisher
	last time.Time
}

func NewIngestor(head HeadEnd, pub Publisher, since time.Time) *Ingestor {
	return &Ingestor{head: head, pub: pub, last: since}
}

// Run polls once and returns the number of readings published.
func (i *Ingestor) Run(ctx context.Context) (int, error) {
	raws, err := i.head.Poll(ctx, i.last)
	if err != nil {
		return 0, fmt.Errorf("poll head-end: %w", err)
	}
	n := 0
	for _, r := range raws {
		reading := Reading{
			MeterID:  r.Serial,
			Register: fmt.Sprintf("R%d", r.Channel),
			ValueKWh: float64(r.WattHour) / 1000,
			TakenAt:  r.At.UTC(),
		}
		if err := i.pub.Publish(ctx, reading); err != nil {
			return n, fmt.Errorf("publish %s: %w", r.Serial, err)
		}
		if r.At.After(i.last) {
			i.last = r.At
		}
		n++
	}
	return n, nil
}
