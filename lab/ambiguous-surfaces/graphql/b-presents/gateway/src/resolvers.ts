import { GraphQLError } from "graphql";
import type { Context } from "./context";

function requireRole(ctx: Context, role: "buyer" | "viewer") {
  if (!ctx.user || !ctx.user.roles.includes(role)) {
    throw new GraphQLError("forbidden", { extensions: { code: "FORBIDDEN" } });
  }
}

// @gloss presents hp:OrderPlacement
export const resolvers = {
  Query: {
    me: (_: unknown, __: unknown, ctx: Context) => ctx.accounts.get(ctx.user.customerId),
    order: async (_: unknown, { id }: { id: string }, ctx: Context) => {
      const order = await ctx.orders.get(id);
      return order && order.customerId === ctx.user.customerId ? order : null;
    },
  },
  Customer: {
    availableCreditCents: (c: { limitCents: number; openBalanceCents: number }) => Math.max(0, c.limitCents - c.openBalanceCents),
  },
  Mutation: {
    placeOrder: async (_: unknown, { input }: { input: { lines: { sku: string; cases: number }[] } }, ctx: Context) => {
      requireRole(ctx, "buyer");
      const priced = await ctx.catalog.price(ctx.user.customerId, input.lines);
      return ctx.orders.place(ctx.user.customerId, priced);
    },
  },
};
