package orders

import (
	"context"
	"errors"
	"testing"
)

type fakeStore struct {
	limit, balance int64
}

func (f *fakeStore) Limit(context.Context, string) (int64, error)       { return f.limit, nil }
func (f *fakeStore) OpenBalance(context.Context, string) (int64, error) { return f.balance, nil }
func (f *fakeStore) SetLimit(_ context.Context, _ string, cents int64, _ string) error {
	f.limit = cents
	return nil
}

// @gloss verifies hp:CreditLimit
func TestCheckRefusesOrderOverLimit(t *testing.T) {
	svc := NewCreditService(&fakeStore{limit: 500_000, balance: 450_000})
	if err := svc.Check(context.Background(), "cust-1", 60_000); !errors.Is(err, ErrCreditLimitExceeded) {
		t.Fatalf("want ErrCreditLimitExceeded, got %v", err)
	}
	if err := svc.Check(context.Background(), "cust-1", 50_000); err != nil {
		t.Fatalf("order at the limit should pass, got %v", err)
	}
}
