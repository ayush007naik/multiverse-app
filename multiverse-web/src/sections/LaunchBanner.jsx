import React, { useLayoutEffect, useRef } from "react"
import { gsap } from "gsap"

// Cinematic infinite ticker strip (GSAP-driven). Preserves the original
// launch copy while giving the strip an editorial, premium marquee motion.
const MSG = "Launching in Mandi — First time in Himachal Pradesh"

const LaunchBanner = () => {
  const trackRef = useRef(null)

  useLayoutEffect(() => {
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    if (reduced) return
    const el = trackRef.current
    if (!el) return
    const tween = gsap.fromTo(
      el,
      { x: 0 },
      { x: "-50%", duration: 28, ease: "none", repeat: -1 }
    )
    return () => tween.kill()
  }, [])

  return (
    <section
      className="relative py-3 overflow-hidden border-y border-white/5 bg-gradient-to-r from-primary/5 via-primary/10 to-primary/5"
      aria-hidden
    >
      <div className="flex w-max">
        <div ref={trackRef} className="flex items-center gap-12 pr-12">
          {Array.from({ length: 4 }).map((_, i) => (
            <span key={i} className="flex items-center gap-12 whitespace-nowrap text-white/60 text-xs lg:text-sm font-semibold tracking-[0.18em] uppercase">
              {MSG}
              <span className="text-primary">●</span>
            </span>
          ))}
        </div>
      </div>
    </section>
  )
}

export default LaunchBanner
