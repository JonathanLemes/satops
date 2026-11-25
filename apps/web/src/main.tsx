import "@fontsource/rethink-sans/400.css";
import "@fontsource/rethink-sans/500.css";
import "@fontsource/rethink-sans/600.css";
import "@fontsource/rethink-sans/700.css";
import "./styles/globals.css";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./app/app";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
