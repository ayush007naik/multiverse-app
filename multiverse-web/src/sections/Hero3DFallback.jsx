import React from "react"
import { motion } from "framer-motion"

// Elegant 2D fallback shown when WebGL is unavailable or 3D is not
// appropriate for the device/motion preference. Uses the existing
// web2.png hero presentation + refined cinematic treatment.
export default function Hero3DFallback() {
  return (
    <div className="relative flex justify-center lg:justify-end items-center w-full h-full">
      {/* Glow behind */}
      <div className="absolute w-[300px] h-[300px] lg:w-[480px] lg:h-[480px] bg-primary/20 rounded-full blur-[100px]" />

      {/* Orbiting accent ring (subtle, respects reduced-motion via CSS) */}
      <div className="absolute w-[320px] h-[320px] lg:w-[520px] lg:h-[520px] rounded-full border border-white/5" />
      <div className="absolute w-[360px] h-[360px] lg:w-[560px] lg:h-[560px] rounded-full border border-primary/10" style={{ animationDelay: "-3s" }} />

      <motion.div
        initial={{ opacity: 0, y: 40, scale: 0.92 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        transition={{ duration: 1, ease: [0.22, 1, 0.36, 1] }}
        className="relative w-full max-w-[380px] lg:max-w-[560px] z-10"
      >
        <img
          src="/assets/app_screens/web2.webp"
          className="w-full h-auto object-contain drop-shadow-[0_30px_60px_rgba(255,106,0,0.25)]"
          alt="Multiverse City App"
          width={1024}
          height={1536}
          fetchpriority="high"
          loading="eager"
          decoding="async"
        />
      </motion.div>

      {/* Soft ground reflection hint */}
      <div className="absolute -bottom-6 left-1/2 -translate-x-1/2 w-2/3 h-10 bg-primary/10 blur-2xl rounded-full" />
    </div>
  )
}
