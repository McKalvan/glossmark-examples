export interface OrderSummary { id: string; placedAt: string; lines: { sku: string; name: string; cases: number; unitCents: number; costCents: number }[] }
export interface Account { customerId: string; name: string; openBalanceCents: number; limitCents: number; onHold: boolean }

const ORDERS = process.env.ORDERS_URL ?? "http://orders.internal";
const ACCOUNTS = process.env.ACCOUNTS_URL ?? "http://accounts.internal";

async function get<T>(url: string, token: string): Promise<T> {
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (!res.ok) throw new Error(`${url}: ${res.status}`);
  return res.json() as Promise<T>;
}

export const lastOrder = (customerId: string, token: string) => get<OrderSummary>(`${ORDERS}/customers/${customerId}/orders/latest`, token);
export const account = (customerId: string, token: string) => get<Account>(`${ACCOUNTS}/accounts/${customerId}`, token);
