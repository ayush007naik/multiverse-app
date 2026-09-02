// Determines 3D rendering quality tier based on device capabilities,
// motion preferences and network conditions. Used to keep the 3D
// showcase fast on low-end/mobile hardware.

export function detectWebGL() {
  try {
    const canvas = document.createElement("canvas")
    return !!(canvas.getContext("webgl2") || canvas.getContext("webgl"))
  } catch {
    return false
  }
}

export function getDeviceTier() {
  if (typeof navigator === "undefined") return "high"
  const cores = navigator.hardwareConcurrency || 4
  const mem = navigator.deviceMemory || 4
  const ua = navigator.userAgent || ""
  const isMobile = /Mobile|Android|iPhone|iPad/i.test(ua)

  if (!isMobile && cores >= 8 && mem >= 8) return "high"
  if (isMobile && (cores <= 4 || mem <= 2)) return "low"
  return "medium"
}

export function prefersReducedMotion() {
  return (
    typeof window !== "undefined" &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches
  )
}

export function isSlowConnection() {
  if (typeof navigator === "undefined" || !navigator.connection) return false
  const c = navigator.connection
  return c.saveData === true || (c.effectiveType && c.effectiveType === "2g")
}
