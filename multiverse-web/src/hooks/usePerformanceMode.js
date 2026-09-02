import { useState } from "react"
import {
  detectWebGL,
  getDeviceTier,
  prefersReducedMotion,
  isSlowConnection,
} from "../utils/perf"

// Lazily computes a 3D quality profile. Defaults to "off" until measured
// so we never block first paint.
export function usePerformanceMode() {
  const [profile] = useState(() => {
    const webgl = detectWebGL()
    const tier = getDeviceTier()
    const reduced = prefersReducedMotion()
    const slowNet = isSlowConnection()

    if (!webgl) {
      return { enabled: false, mode: "2d", reason: "no-webgl" }
    }
    if (reduced) {
      return { enabled: true, mode: "static", tier, reason: "reduced-motion" }
    }
    if (tier === "low") {
      return { enabled: true, mode: "static", tier, reason: "low-end" }
    }
    if (slowNet) {
      return { enabled: false, mode: "2d", tier, reason: "slow-connection" }
    }
    return { enabled: true, mode: "full", tier, reason: "full" }
  })

  return profile
}
