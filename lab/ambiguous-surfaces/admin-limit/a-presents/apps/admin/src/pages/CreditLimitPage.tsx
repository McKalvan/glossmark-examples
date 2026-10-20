import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { CreditLimit, fetchCreditLimit, updateCreditLimit } from "../api/creditLimits";

const dollars = (cents: number) => (cents / 100).toLocaleString("en-US", { style: "currency", currency: "USD" });

// @gloss presents hp:CreditLimit
export default function CreditLimitPage() {
  const { customerId = "" } = useParams();
  const [current, setCurrent] = useState<CreditLimit | null>(null);
  const [draft, setDraft] = useState("");
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchCreditLimit(customerId).then((cl) => {
      setCurrent(cl);
      setDraft(String(cl.limitCents / 100));
    }, (e) => setError(String(e)));
  }, [customerId]);

  async function save() {
    const cents = Math.round(Number(draft) * 100);
    if (!Number.isFinite(cents) || cents < 0) {
      setError("Enter a limit of zero or more.");
      return;
    }
    if (current && cents < current.openBalanceCents && !window.confirm("The new limit is below the open balance. New orders will be refused. Continue?")) {
      return;
    }
    setCurrent(await updateCreditLimit(customerId, cents, reason));
    setError(null);
  }

  if (!current) return <p>{error ?? "Loading…"}</p>;
  return (
    <form onSubmit={(e) => { e.preventDefault(); void save(); }}>
      <h1>Credit limit: {current.customerName}</h1>
      <p>Open balance {dollars(current.openBalanceCents)}. Last changed by {current.updatedBy} on {current.updatedAt}.</p>
      <label>
        Limit (USD)
        <input name="limit" inputMode="decimal" value={draft} onChange={(e) => setDraft(e.target.value)} />
      </label>
      <label>
        Reason
        <input name="reason" required value={reason} onChange={(e) => setReason(e.target.value)} />
      </label>
      {error && <p role="alert">{error}</p>}
      <button type="submit">Save limit</button>
    </form>
  );
}
