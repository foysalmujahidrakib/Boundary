import { defineConfig } from "vite";
import tailwindcss from "@tailwindcss/vite";
import { resolve } from "node:path";

export default defineConfig({
  plugins: [
    tailwindcss(),
  ],
  // This is a multi-page static site. Vercel deploys Vite's `dist` directory,
  // so each HTML entry point must be included here rather than only index.html.
  build: {
    rollupOptions: {
      input: {
        home: resolve(__dirname, "index.html"),
        dashboard: resolve(__dirname, "dashboard.html"),
        club: resolve(__dirname, "club.html"),
        matches: resolve(__dirname, "matches.html"),
        tournaments: resolve(__dirname, "tournaments.html"),
        scoring: resolve(__dirname, "scoring.html"),
        scorecard: resolve(__dirname, "scorecard.html"),
        publicScorecard: resolve(__dirname, "public-scorecard.html"),
        liveMatches: resolve(__dirname, "Livematches.html"),
      },
    },
  },
});
