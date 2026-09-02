import React, { useEffect, useRef } from "react"
import { motion, useInView, useMotionValue, useTransform, animate } from "framer-motion"
import { gsap } from "gsap"
import { ScrollTrigger } from "gsap/ScrollTrigger"
import { LayoutList, Store, Film, UserPlus, Home } from "lucide-react"

gsap.registerPlugin(ScrollTrigger)

const stats = [
  { icon: LayoutList, val: 20, suffix: "+", label: "Categories" },
  { icon: Store, val: 500, suffix: "+", label: "Vendors" },
  { icon: Film, val: 2, suffix: "+", label: "Theatres" },
  { icon: UserPlus, val: 50, suffix: "+", label: "Appointment Partners" },
  { icon: Home, val: 100, suffix: "+", label: "Real Estate Properties" },
]

const Counter = ({ to, suffix }) => {
  const ref = useRef(null)
  const inView = useInView(ref, { once: true })
  const mv = useMotionValue(0)
  const text = useTransform(mv, (v) => Math.round(v).toLocaleString())

  useEffect(() => {
    if (inView) {
      const controls = animate(mv, to, { duration: 2, ease: "easeOut" })
      return controls.stop
    }
  }, [inView, to, mv])

  return (
    <h3 ref={ref} className="text-3xl lg:text-5xl font-black font-space text-gradient-fire mb-2">
      <motion.span>{text}</motion.span>
      {suffix}
    </h3>
  )
}

const Statistics = () => {
  const sectionRef = useRef(null)
  const bgRef = useRef(null)

  // Subtle scroll-scrubbed parallax on the background (GSAP), independent
  // of Framer's per-card counters so the two never compete.
  useEffect(() => {
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    if (reduced || !sectionRef.current) return
    const tween = gsap.fromTo(
      bgRef.current,
      { yPercent: -12 },
      {
        yPercent: 12,
        ease: "none",
        scrollTrigger: {
          trigger: sectionRef.current,
          start: "top bottom",
          end: "bottom top",
          scrub: 1,
        },
      }
    )
    return () => {
      tween.scrollTrigger && tween.scrollTrigger.kill()
      tween.kill()
    }
  }, [])

  return (
    <section ref={sectionRef} className="py-16 lg:py-24 border-y border-white/5 relative overflow-hidden">
      <div ref={bgRef} className="absolute inset-y-0 inset-x-0 scale-y-125">
        <div className="absolute inset-0 bg-gradient-to-r from-primary/5 via-transparent to-secondary/5" />
        <div className="absolute inset-0 cyber-grid opacity-40" />
      </div>
      <div className="container mx-auto px-5 lg:px-12 relative z-10">
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-8 lg:gap-12">
          {stats.map((s, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, scale: 0.5 }}
              whileInView={{ opacity: 1, scale: 1 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.1, type: "spring" }}
              className="text-center"
            >
              <div className="w-14 h-14 mx-auto mb-4 rounded-2xl bg-gradient-to-br from-primary/20 to-secondary/10 border border-primary/20 flex items-center justify-center">
                <s.icon className="text-primary animate-float" size={24} />
              </div>
              <Counter to={s.val} suffix={s.suffix} />
              <p className="text-white/40 font-bold uppercase tracking-widest text-[10px] lg:text-xs">{s.label}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  )
}

export default Statistics
