import React from "react"
import { motion } from "framer-motion"

const screens = [
  { img: "screen1.webp", label: "Marketplace" },
  { img: "screen2.webp", label: "Movies" },
  { img: "screen3.webp", label: "Appointments" },
  { img: "screen4.webp", label: "Real Estate" },
  { img: "screen5.webp", label: "Features" },
  { img: "screen6.webp", label: "Explore" },
]

const AppShowcase = () => {
  return (
    <section className="py-20 lg:py-32 overflow-hidden bg-white/[0.01] relative">
      <div className="absolute top-20 left-1/3 w-[300px] h-[300px] aurora-orb bg-primary/10" />
      <div className="container mx-auto px-5 lg:px-12 mb-12 lg:mb-20 text-center relative z-10">
        <motion.span
          initial={{ opacity: 0, y: 10 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="inline-block text-primary font-bold tracking-[0.3em] uppercase text-xs mb-4"
        >
          App Preview
        </motion.span>
        <motion.h2
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="text-4xl sm:text-5xl lg:text-7xl font-black font-space"
        >
          Explore the <span className="text-gradient-fire">Experience</span>
        </motion.h2>
      </div>

      <div className="relative overflow-hidden perspective-2000">
        <div className="absolute left-0 top-0 w-20 lg:w-40 h-full bg-gradient-to-r from-background to-transparent z-10" />
        <div className="absolute right-0 top-0 w-20 lg:w-40 h-full bg-gradient-to-l from-background to-transparent z-10" />

        <div className="flex gap-6 lg:gap-10 animate-marquee w-max">
          {[...screens, ...screens, ...screens, ...screens].map((s, i) => (
            <div key={i} className="flex flex-col items-center gap-4 flex-shrink-0">
              <div className="w-[230px] lg:w-[300px] aspect-[941/1672] bg-black border-6 lg:border-8 border-white/5 rounded-[36px] lg:rounded-[48px] overflow-hidden shadow-2xl hover:border-primary/40 transition-all duration-500">
                <motion.img
                  whileHover={{ scale: 1.06, rotateZ: i % 2 === 0 ? -2 : 2 }}
                  src={"/assets/app_screens/" + s.img}
                  className="w-full h-full object-cover"
                  alt={s.label}
                />
              </div>
              <span className="text-xs lg:text-sm font-bold uppercase tracking-widest text-white/30">{s.label}</span>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

export default AppShowcase
