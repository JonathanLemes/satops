import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { fileURLToPath, URL } from "node:url";

const api = process.env.SATOPS_API_URL ?? "http://127.0.0.1:4000";

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: { alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) } },
  server: {
    proxy: {
      "/api": api,
      "/graphql": api,
      "/socket": { target: api.replace("http", "ws"), ws: true },
    },
  },
  build: {
    target: "es2022",
    chunkSizeWarningLimit: 4000,
  },
});
