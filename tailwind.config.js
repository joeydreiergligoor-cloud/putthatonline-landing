/** @type {import('tailwindcss').Config} */
function withOpacity(variable) {
  return ({ opacityValue }) =>
    opacityValue !== undefined
      ? `rgb(var(${variable}) / ${opacityValue})`
      : `rgb(var(${variable}))`;
}

export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        bg: withOpacity("--color-bg"),
        panel: withOpacity("--color-panel"),
        "panel-hover": withOpacity("--color-panel-hover"),
        border: withOpacity("--color-border"),
        text: withOpacity("--color-text"),
        muted: withOpacity("--color-muted"),
        accent: withOpacity("--color-accent"),
        "accent-dim": withOpacity("--color-accent-dim"),
        online: withOpacity("--color-status-online"),
        soon: withOpacity("--color-status-soon"),
        offline: withOpacity("--color-status-offline"),
      },
      fontFamily: {
        display: ["var(--font-display)"],
        body: ["var(--font-body)"],
        mono: ["var(--font-mono)"],
      },
      borderRadius: {
        card: "var(--radius-card)",
        pill: "var(--radius-pill)",
      },
      transitionTimingFunction: {
        theme: "var(--motion-ease)",
      },
      transitionDuration: {
        fast: "var(--motion-fast)",
        medium: "var(--motion-medium)",
        slow: "var(--motion-slow)",
      },
    },
  },
  plugins: [],
};
