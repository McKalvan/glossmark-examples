import { Router } from "express";
import { account, lastOrder } from "../clients";

export interface ReorderCard {
  orderId: string;
  placedAt: string;
  lines: { sku: string; name: string; cases: number; priceCents: number }[];
  totalCents: number;
  canReorder: boolean;
  reason?: string;
}

// Mirrors the order service's credit check so the app can grey out the button before the user taps it.
export function canReorder(openBalanceCents: number, limitCents: number, onHold: boolean, totalCents: number): { ok: boolean; reason?: string } {
  if (onHold) return { ok: false, reason: "Account on hold. Call your account manager." };
  if (openBalanceCents + totalCents > limitCents) return { ok: false, reason: "This order would exceed your credit limit." };
  return { ok: true };
}

export const reorderRouter = Router();

// @gloss hosts hp:OrderPlacement
reorderRouter.get("/mobile/v1/reorder-card", async (req, res, next) => {
  try {
    const { customerId, token } = res.locals.session;
    const [order, acct] = await Promise.all([lastOrder(customerId, token), account(customerId, token)]);
    const lines = order.lines.map((l) => ({ sku: l.sku, name: l.name, cases: l.cases, priceCents: l.unitCents }));
    const totalCents = lines.reduce((sum, l) => sum + l.cases * l.priceCents, 0);
    const check = canReorder(acct.openBalanceCents, acct.limitCents, acct.onHold, totalCents);
    const card: ReorderCard = { orderId: order.id, placedAt: order.placedAt, lines, totalCents, canReorder: check.ok, reason: check.reason };
    res.json(card);
  } catch (err) {
    next(err);
  }
});
