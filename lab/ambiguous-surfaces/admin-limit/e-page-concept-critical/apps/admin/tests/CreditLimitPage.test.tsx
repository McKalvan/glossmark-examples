import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { vi, test, expect } from "vitest";
import CreditLimitPage from "../src/pages/CreditLimitPage";
import * as api from "../src/api/creditLimits";

// @gloss verifies hpx:CreditLimitEditor
test("saves a new limit with a reason", async () => {
  const row = { customerId: "c1", customerName: "Bistro Nord", limitCents: 500_000, openBalanceCents: 120_000, updatedBy: "finance", updatedAt: "2026-10-01" };
  vi.spyOn(api, "fetchCreditLimit").mockResolvedValue(row);
  const put = vi.spyOn(api, "updateCreditLimit").mockResolvedValue({ ...row, limitCents: 750_000 });
  render(<MemoryRouter initialEntries={["/credit/c1"]}><Routes><Route path="/credit/:customerId" element={<CreditLimitPage />} /></Routes></MemoryRouter>);
  fireEvent.change(await screen.findByRole("textbox", { name: /limit/i }), { target: { value: "7500" } });
  fireEvent.change(screen.getByRole("textbox", { name: /reason/i }), { target: { value: "new contract" } });
  fireEvent.click(screen.getByRole("button", { name: /save/i }));
  await waitFor(() => expect(put).toHaveBeenCalledWith("c1", 750_000, "new contract"));
});
