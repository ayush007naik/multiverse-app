import React, { useLayoutEffect, useRef } from "react"
import { gsap } from "gsap"
import { ScrollTrigger } from "gsap/ScrollTrigger"

// Thin cinematic scroll-progress bar fixed under the navbar (GSAP-driven).
gsap.registerPlugin(ScrollTrigger)

export default function ScrollProgress() {
  const barRef = useRef(null)

  useLayoutEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    const tween = gsap.fromTo(
      barRef.current,
      { scaleX: 0 },
      {
        scaleX: 1,
        ease: "none",
        scrollTrigger: {
          start: 0,
          end: "max",
          scrub: 0.3,
        },
      }
    )
    return () => {
      tween.scrollTrigger && tween.scrollTrigger.kill()
      tween.kill()
    }
  }, [])

  return (
    <div
      aria-hidden
      className="fixed left-0 top-0 z-[1001] h-[2px] w-full"
      style={{ pointerEvents: "none" }}
    >
      <div
        ref={barRef}
        className="h-full w-full origin-left bg-gradient-to-r from-primary via-secondary to-primary"
        style={{ scaleX: 0 }}
      />
    </div>
  )
}
