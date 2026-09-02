import React, { lazy, Suspense, useEffect, useRef, useState } from "react"
import { motion } from "framer-motion"
import { Sparkles } from "lucide-react"
import { usePerformanceMode } from "../hooks/usePerformanceMode"
import Hero3DFallback from "./Hero3DFallback"

// Lazy-load the entire 3D experience — its (~hundreds of KB) chunk is fetched
// only when the hero is in view AND the device supports it.
const PhoneShowcase3D = lazy(() =>
  import("./PhoneShowcase3D").then((m) => ({ default: m.default }))
)

const PLAY_URL = "https://play.google.com/store/apps/details?id=com.ayush.multiverse.multiverses"

function useInView(ref, margin = "0px") {
  const [inView, setInView] = useState(false)
  useEffect(() => {
    const el = ref.current
    if (!el) return
    const obs = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting) {
          setInView(true)
          obs.disconnect()
        }
      },
      { rootMargin: margin }
    )
    obs.observe(el)
    return () => obs.disconnect()
  }, [ref, margin])
  return inView
}

const Hero = ({ onShowAlert, onOpenDownload }) => {
  const containerRef = useRef(null)
  const inView = useInView(containerRef, "200px 0px")
  const quality = usePerformanceMode()
  const [hydrated, setHydrated] = useState(false)

  // Resolve on client so deferred/lazy 3D never flashes SSR-style fallback wrongly
  useEffect(() => setHydrated(true), [])

  const show3D = hydrated && inView && quality.enabled

  return (
    <section id="home" className="relative min-h-screen pt-28 pb-16 lg:pt-32 lg:pb-20 overflow-hidden flex items-center">
      {/* Aurora orbs */}
      <div className="absolute -top-24 -left-24 w-[420px] h-[420px] aurora-orb bg-primary/25" />
      <div className="absolute top-1/3 right-[-10%] w-[460px] h-[460px] aurora-orb bg-secondary/15" style={{ animationDelay: "-6s" }} />
      <div className="absolute bottom-[-15%] left-1/3 w-[420px] h-[420px] aurora-orb bg-[#FF7A1A]/20" style={{ animationDelay: "-11s" }} />

      {/* Cyber grid */}
      <div className="absolute inset-0 cyber-grid" />

      {/* Expanding rings */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-full h-full flex justify-center items-center pointer-events-none opacity-40">
        <div className="absolute w-[600px] h-[600px] lg:w-[900px] lg:h-[900px] border border-primary/20 rounded-full animate-pulse-slow" />
        <div className="absolute w-[400px] h-[400px] lg:w-[680px] lg:h-[680px] border border-primary/10 rounded-full animate-pulse-slow" style={{ animationDelay: "2s" }} />
        <div className="absolute w-[220px] h-[220px] lg:w-[400px] lg:h-[400px] border border-white/10 rounded-full animate-pulse-slow" style={{ animationDelay: "3s" }} />
      </div>

      <div ref={containerRef} className="container mx-auto px-5 lg:px-12 relative z-10">
        <div className="flex flex-col lg:grid lg:grid-cols-2 gap-14 lg:gap-8 items-center">
          {/* Left: copy */}
          <motion.div
            initial={{ opacity: 0, x: -50 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.9, ease: "easeOut" }}
            className="text-center lg:text-left"
          >
            <motion.span
              initial={{ opacity: 0, y: -10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2 }}
              className="inline-flex items-center gap-2 glass-card rounded-full px-5 py-2 text-xs lg:text-sm font-bold tracking-[0.2em] uppercase text-primary mb-6 border-primary/20"
            >
              <Sparkles size={14} className="animate-pulse" /> All-In-One Super App
            </motion.span>

            <h1 className="text-6xl sm:text-7xl lg:text-[7.5rem] font-black font-space leading-[0.85] tracking-tighter mb-8">
              <motion.span
                initial={{ opacity: 0, y: 40 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.3, duration: 0.7, ease: "easeOut" }}
                className="block"
              >One App.</motion.span>
              <motion.span
                initial={{ opacity: 0, y: 40 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.45, duration: 0.7, ease: "easeOut" }}
                className="block text-gradient-fire drop-shadow-[0_0_30px_rgba(255,106,0,0.4)]"
              >Unlimited</motion.span>
              <motion.span
                initial={{ opacity: 0, y: 40 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.6, duration: 0.7, ease: "easeOut" }}
                className="block text-4xl sm:text-5xl lg:text-[6rem] text-white/90"
              >Possibilities.</motion.span>
            </h1>

            <motion.p
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.75 }}
              className="text-base lg:text-xl text-white/50 max-w-lg mb-8 lg:mb-12 leading-relaxed mx-auto lg:mx-0"
            >
              Marketplace. Movie Tickets. Appointments. Real Estate. Everything you need, orchestrated inside one powerful ecosystem.
            </motion.p>

            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.9 }}
              className="flex flex-col sm:flex-row gap-4 lg:gap-6 items-center lg:items-start"
            >
              <a href={PLAY_URL} target="_blank" rel="noopener noreferrer" className="btn-primary w-full sm:w-auto text-center">
                Download App
              </a>
              <a href="#categories" className="btn-outline w-full sm:w-auto text-center">
                Explore Categories
              </a>
            </motion.div>

            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 1.1 }}
              className="flex flex-wrap gap-4 mt-10 lg:mt-12 justify-center lg:justify-start items-center"
            >
              <a
                href={PLAY_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="hover:scale-105 transition-transform"
                title="Get it on Google Play"
              >
                <img src="https://upload.wikimedia.org/wikipedia/commons/7/78/Google_Play_Store_badge_EN.svg" className="h-10 lg:h-11" alt="Get it on Google Play" />
              </a>
              <span
                className="relative inline-flex flex-col items-center cursor-not-allowed select-none"
                title="App Store — Coming Soon"
              >
                <img
                  src="https://upload.wikimedia.org/wikipedia/commons/3/3c/Download_on_the_App_Store_Badge.svg"
                  className="h-10 lg:h-11 opacity-40 grayscale"
                  alt="Download on the App Store"
                />
                <span className="mt-1 text-[9px] px-2 py-0.5 rounded-full border border-white/20 text-white/50 font-bold uppercase tracking-wide">Coming Soon</span>
              </span>
            </motion.div>
          </motion.div>

          {/* Right: interactive 3D ecosystem showcase (lazy) w/ 2D fallback */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 1, delay: 0.3 }}
            className="relative h-[440px] sm:h-[500px] lg:h-[600px] flex items-center justify-center"
          >
            {show3D ? (
              <Suspense
                fallback={<Hero3DFallback />}
              >
                <PhoneShowcase3D quality={quality} />
              </Suspense>
            ) : (
              <Hero3DFallback />
            )}
          </motion.div>
        </div>
      </div>
    </section>
  )
}

export default Hero
