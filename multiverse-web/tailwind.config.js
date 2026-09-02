/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        background: "#050505",
        primary: "#FF6A00",
        secondary: "#FF9000",
        surface: "#0A0A0A",
        border: "rgba(255, 255, 255, 0.08)",
      },
      fontFamily: {
        display: ["Sora", "Inter", "sans-serif"],
        sans: ["Inter", "-apple-system", "sans-serif"],
        // legacy alias: existing sections use `font-space` — now served by Sora
        space: ["Sora", "Inter", "sans-serif"],
      },
      boxShadow: {
        'glow': '0 0 40px -8px rgba(255, 106, 0, 0.45)',
        'glow-sm': '0 0 24px -8px rgba(255, 106, 0, 0.4)',
      },
      backgroundImage: {
        'noise': "url(\"data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.85' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='0.5'/%3E%3C/svg%3E\")",
      },
      animation: {
        'pulse-slow': 'pulse 4s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'float': 'float 6s ease-in-out infinite',
        'float-slow': 'float 9s ease-in-out infinite',
        'marquee': 'marquee 40s linear infinite',
        'spin-slow': 'spin 24s linear infinite',
        'gradient-x': 'gradient-x 8s ease infinite',
        'aurora': 'aurora 16s ease-in-out infinite alternate',
        'shine': 'shine 3.5s ease-in-out infinite',
        'blob': 'blob 18s ease-in-out infinite',
      },
      keyframes: {
        float: {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-20px)' },
        },
        marquee: {
          '0%': { transform: 'translateX(0)' },
          '100%': { transform: 'translateX(-50%)' },
        },
        'gradient-x': {
          '0%, 100%': { backgroundPosition: '0% 50%' },
          '50%': { backgroundPosition: '100% 50%' },
        },
        aurora: {
          '0%': { transform: 'translate(0,0) scale(1)', opacity: '0.6' },
          '50%': { transform: 'translate(30px,-40px) scale(1.15)', opacity: '0.9' },
          '100%': { transform: 'translate(-25px,30px) scale(1.05)', opacity: '0.7' },
        },
        shine: {
          '0%': { transform: 'translateX(-120%)' },
          '60%, 100%': { transform: 'translateX(220%)' },
        },
        blob: {
          '0%, 100%': { borderRadius: '60% 40% 55% 45% / 55% 45% 60% 40%' },
          '50%': { borderRadius: '45% 55% 40% 60% / 50% 60% 45% 55%' },
        },
      },
    },
  },
  plugins: [],
}
