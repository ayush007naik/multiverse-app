import React, { useEffect, useRef } from "react"

// Custom cursor — only active on precise-pointer desktop devices and
// never under prefers-reduced-motion. Adds a subtle trailing dot + glow ring.
export default function Cursor() {
  const dotRef = useRef(null)
  const ringRef = useRef(null)

  useEffect(() => {
    // Skip entirely on coarse-pointer (touch) or reduced-motion setups
    const media = window.matchMedia("(pointer: fine)")
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)")
    if (reduced.matches || !media.matches) return

    document.body.classList.add("custom-cursor-enabled")

    const dot = dotRef.current
    const ring = ringRef.current
    let raf = 0
    let targetX = window.innerWidth / 2
    let targetY = window.innerHeight / 2
    let x = targetX
    let y = targetY
    let ringX = x
    let ringY = y
    let visible = false
    let hovering = false

    const lerp = (a, b, n) => a + (b - a) * n

    const loop = () => {
      ringX = lerp(ringX, targetX, 0.16)
      ringY = lerp(ringY, targetY, 0.16)
      if (ring) {
        const s = hovering ? 1.8 : 1
        ring.style.transform = `translate3d(${ringX - 20}px, ${ringY - 20}px, 0) scale(${s})`
      }
      if (dot) {
        dot.style.transform = `translate3d(${x}px, ${y}px, 0) translate(-50%, -50%)`
      }
      raf = requestAnimationFrame(loop)
    }

    const onMove = (e) => {
      targetX = e.clientX
      targetY = e.clientY
      x = e.clientX
      y = e.clientY
      if (!visible) {
        visible = true
        ring.style.opacity = "1"
        dot.style.opacity = "1"
      }
    }

    const onOver = (e) => {
      hovering = !!e.target.closest("a, button, [data-cursor]")
    }

    const onLeave = () => {
      visible = false
      ring.style.opacity = "0"
      dot.style.opacity = "0"
    }

    window.addEventListener("mousemove", onMove, { passive: true })
    window.addEventListener("mouseover", onOver, { passive: true })
    document.addEventListener("mouseleave", onLeave)
    raf = requestAnimationFrame(loop)

    return () => {
      cancelAnimationFrame(raf)
      window.removeEventListener("mousemove", onMove)
      window.removeEventListener("mouseover", onOver)
      document.removeEventListener("mouseleave", onLeave)
      document.body.classList.remove("custom-cursor-enabled")
    }
  }, [])

  return (
    <>
      <div
        ref={ringRef}
        aria-hidden
        className="pointer-events-none fixed left-0 top-0 z-[100] h-10 w-10 rounded-full border border-primary/60 opacity-0 transition-opacity duration-300"
        style={{ willChange: "transform" }}
      />
      <div
        ref={dotRef}
        aria-hidden
        className="pointer-events-none fixed left-0 top-0 z-[100] h-1.5 w-1.5 rounded-full bg-primary opacity-0 transition-opacity duration-300"
        style={{ willChange: "transform" }}
      />
    </>
  )
}
