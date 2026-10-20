package orders

import (
	"context"
	"errors"
	"fmt"
)

// ErrCreditLimitExceeded is returned when an order would take a customer over their limit.
var ErrCreditLimitExceeded = errors.New("order exceeds customer credit limit")

// LimitStore reads and writes the per-customer credit limit and open balance.
type LimitStore interface {
	Limit(ctx context.Context, customerID string) (int64, error)
	SetLimit(ctx context.Context, customerID string, cents int64, changedBy string) error
	OpenBalance(ctx context.Context, customerID string) (int64, error)
}

// @gloss implements .CreditCheck
// CreditService enforces the credit limit on every new order.
type CreditService struct {
	store LimitStore
}

func NewCreditService(store LimitStore) *CreditService {
	return &CreditService{store: store}
}

// Check refuses an order whose amount would take the open balance over the limit.
func (s *CreditService) Check(ctx context.Context, customerID string, orderCents int64) error {
	limit, err := s.store.Limit(ctx, customerID)
	if err != nil {
		return fmt.Errorf("read limit: %w", err)
	}
	balance, err := s.store.OpenBalance(ctx, customerID)
	if err != nil {
		return fmt.Errorf("read balance: %w", err)
	}
	if balance+orderCents > limit {
		return ErrCreditLimitExceeded
	}
	return nil
}

// SetLimit stores a new limit. The admin console calls it through PUT /internal/credit-limits/{id}.
func (s *CreditService) SetLimit(ctx context.Context, customerID string, cents int64, changedBy string) error {
	if cents < 0 {
		return fmt.Errorf("credit limit must not be negative: %d", cents)
	}
	return s.store.SetLimit(ctx, customerID, cents, changedBy)
}
