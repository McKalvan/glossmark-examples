import { describe, expect, it, vi } from "vitest";
import { resolvers } from "../src/resolvers";

const ctx = (roles: string[]) => ({
  user: { customerId: "c1", roles },
  orders: { place: vi.fn().mockResolvedValue({ id: "o1" }), get: vi.fn() },
  catalog: { price: vi.fn().mockResolvedValue([{ sku: "OIL-5L", cases: 2, unitCents: 4200 }]) },
  accounts: { get: vi.fn() },
});

// @gloss verifies hp:OrderPlacement
describe("Mutation.placeOrder", () => {
  it("prices the lines and forwards them to the order service", async () => {
    const c = ctx(["buyer"]);
    await resolvers.Mutation.placeOrder({}, { input: { lines: [{ sku: "OIL-5L", cases: 2 }] } }, c as never);
    expect(c.orders.place).toHaveBeenCalledWith("c1", [{ sku: "OIL-5L", cases: 2, unitCents: 4200 }]);
  });
  it("refuses a viewer", async () => {
    await expect(resolvers.Mutation.placeOrder({}, { input: { lines: [] } }, ctx(["viewer"]) as never)).rejects.toThrow("forbidden");
  });
});
