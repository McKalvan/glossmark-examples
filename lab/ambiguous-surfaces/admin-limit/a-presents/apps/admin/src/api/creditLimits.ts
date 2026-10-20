export interface CreditLimit {
  customerId: string;
  customerName: string;
  limitCents: number;
  openBalanceCents: number;
  updatedBy: string;
  updatedAt: string;
}

const BASE = "/internal/credit-limits";

export async function fetchCreditLimit(customerId: string): Promise<CreditLimit> {
  const res = await fetch(`${BASE}/${encodeURIComponent(customerId)}`, { credentials: "include" });
  if (!res.ok) throw new Error(`credit limit ${customerId}: ${res.status}`);
  return res.json();
}

export async function updateCreditLimit(customerId: string, limitCents: number, reason: string): Promise<CreditLimit> {
  const res = await fetch(`${BASE}/${encodeURIComponent(customerId)}`, {
    method: "PUT",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ limitCents, reason }),
  });
  if (!res.ok) throw new Error(`update credit limit ${customerId}: ${res.status}`);
  return res.json();
}
