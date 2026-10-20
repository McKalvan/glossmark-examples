import { describe, expect, it } from "vitest";
import { canReorder } from "../src/routes/reorder";

// @gloss verifies hp:CreditLimit
describe("canReorder", () => {
  it("allows an order inside the limit", () => {
    expect(canReorder(50_000, 100_000, false, 40_000)).toEqual({ ok: true });
  });
  it("refuses an order that would exceed the limit", () => {
    expect(canReorder(95_000, 100_000, false, 8_400).ok).toBe(false);
  });
  it("refuses any order on a held account", () => {
    expect(canReorder(0, 100_000, true, 100).reason).toMatch(/hold/);
  });
});
