/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      // A restrained, Mercury-adjacent palette: deep ink, a single confident
      // accent, and soft neutrals. Kept small on purpose so the UI stays calm.
      colors: {
        ink: "#0b0f19",
        surface: "#ffffff",
        muted: "#f5f6f8",
        border: "#e6e8ee",
        subtle: "#6b7280",
        accent: "#5b5bd6",
        "accent-soft": "#ececfb",
        positive: "#0f9d58",
        warning: "#d97706",
        danger: "#dc2626",
      },
      fontFamily: {
        sans: [
          "Inter",
          "ui-sans-serif",
          "system-ui",
          "-apple-system",
          "Segoe UI",
          "sans-serif",
        ],
      },
      boxShadow: {
        card: "0 1px 2px rgba(11, 15, 25, 0.04), 0 4px 16px rgba(11, 15, 25, 0.04)",
      },
    },
  },
  plugins: [],
};
