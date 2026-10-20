import { readFileSync } from "node:fs";
import { ApolloServer } from "@apollo/server";
import { startStandaloneServer } from "@apollo/server/standalone";
import { buildContext } from "./context";
import { resolvers } from "./resolvers";

const typeDefs = readFileSync(new URL("../schema.graphql", import.meta.url), "utf8");

// @gloss hosts hp:OrderPlacement
export async function start(port = Number(process.env.PORT ?? 4000)) {
  const server = new ApolloServer({ typeDefs, resolvers, introspection: process.env.NODE_ENV !== "production" });
  const { url } = await startStandaloneServer(server, { listen: { port }, context: buildContext });
  return url;
}
