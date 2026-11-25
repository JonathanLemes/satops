import type { CodegenConfig } from "@graphql-codegen/cli";

const config: CodegenConfig = {
  schema: "../../packages/graphql-types/schema.graphql",
  documents: ["src/**/*.{ts,tsx}", "!src/gql/**/*"],
  ignoreNoDocuments: true,
  generates: {
    "src/gql/": {
      preset: "client",
      presetConfig: { fragmentMasking: false },
      config: {
        scalars: { JSON: "any", Sats: "number", DateTime: "string", ID: "string" },
        enumsAsTypes: true,
        useTypeImports: true,
      },
    },
  },
};

export default config;
