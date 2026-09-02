import React, { useEffect, useState } from "react"

// Cinematic intro cover. Auto-dismisses after ~1.4s, respects
// prefers-reduced-motion (skips entirely) and only shows once per session.
export default function Preloader() {
  const [phase, setPhase] = useState("in")

  useEffect(() => {
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    if (reduced || sessionStorage.getItem("mc_preloader_done")) {
      setPhase("done")
      return
    }
    sessionStorage.setItem("mc_preloader_done", "1")
    const t1 = setTimeout(() => setPhase("out"), 1400)
    const t2 = setTimeout(() => setPhase("done"), 2000)
    return () => {
      clearTimeout(t1)
      clearTimeout(t2)
    }
  }, [])

  if (phase === "done") return null

  return (
    <div
      aria-hidden
      className={`fixed inset-0 z-[200] flex items-center justify-center bg-background transition-opacity duration-700 ${
        phase === "out" ? "opacity-0 pointer-events-none" : "opacity-100"
      }`}
    >
      <div className="flex flex-col items-center gap-6" style={{ willChange: "opacity, transform" }}>
        <div className="relative flex h-16 w-16 items-center justify-center">
          <span className="absolute inset-0 animate-ping rounded-full bg-primary/20" />
          <span className="relative rounded-full bg-primary/10 p-4">
            <span className="block h-4 w-4 rounded-full bg-primary shadow-glow-sm" />
          </span>
        </div>
        <div className="overflow-hidden">
          <p className="font-display text-xl font-semibold tracking-[0.3em] text-white">
            MULTIVERSE <span className="text-primary">CITY</span>
          </p>
        </div>
        <div className="h-px w-40 overflow-hidden rounded bg-white/10">
          <span className="preload-bar" />
        </div>
      </div>
    </div>
  )
}
