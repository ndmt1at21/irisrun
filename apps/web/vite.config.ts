import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    // `pnpm dev` talks to the device of a running `irisrun start`.
    proxy: { "/device": { target: "ws://127.0.0.1:7777", ws: true } },
  },
});
