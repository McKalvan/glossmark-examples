// @gloss verifies mc:ReadingIngestor
package ingest

import (
	"context"
	"testing"
	"time"
)

type fakeHead struct{ reads []RawRead }

func (f fakeHead) Poll(context.Context, time.Time) ([]RawRead, error) { return f.reads, nil }

type capture struct{ got []Reading }

func (c *capture) Publish(_ context.Context, r Reading) error {
	c.got = append(c.got, r)
	return nil
}

func TestRunNormalisesWattHours(t *testing.T) {
	at := time.Date(2026, 3, 1, 0, 30, 0, 0, time.UTC)
	pub := &capture{}
	ing := NewIngestor(fakeHead{reads: []RawRead{{Serial: "M-1", Channel: 1, WattHour: 12500, At: at}}}, pub, at.Add(-time.Hour))

	n, err := ing.Run(context.Background())
	if err != nil || n != 1 {
		t.Fatalf("Run() = %d, %v", n, err)
	}
	if got := pub.got[0].ValueKWh; got != 12.5 {
		t.Errorf("ValueKWh = %v, want 12.5", got)
	}
}
