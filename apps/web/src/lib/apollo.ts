import { ApolloClient, ApolloLink, HttpLink, InMemoryCache } from "@apollo/client";
import { getCsrfToken } from "./api";

const csrfLink = new ApolloLink((operation, forward) => {
  const token = getCsrfToken();
  operation.setContext(({ headers = {} }: { headers?: Record<string, string> }) => ({
    headers: token ? { ...headers, "x-csrf-token": token } : headers,
  }));
  return forward(operation);
});

export function createApolloClient() {
  return new ApolloClient({
    link: ApolloLink.from([csrfLink, new HttpLink({ uri: "/graphql", credentials: "same-origin" })]),
    cache: new InMemoryCache({
      typePolicies: {
        Transaction: { keyFields: ["id"] },
        NodeStatus: { keyFields: false },
        Overview: { keyFields: false },
        ChainOverview: { keyFields: false },
        Portfolio: { keyFields: false },
        Balance: { keyFields: false },
        LedgerInvariants: { keyFields: false },
        OperationTimeline: { keyFields: false },
      },
    }),
    defaultOptions: {
      watchQuery: { fetchPolicy: "cache-and-network" },
    },
  });
}
