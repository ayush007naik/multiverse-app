import React from "react"
import { motion } from "framer-motion"
import { CheckCircle2 } from "lucide-react"

const points = [
  { title: "One Unified Platform", desc: "No more juggling 10 apps. Shopping, movies, healthcare, real estate — all under one roof." },
  { title: "AI Driven Insights", desc: "Personalized recommendations powered by machine learning that understand your preferences." },
  { title: "Save Time & Money", desc: "Compare prices, book instantly, and unlock exclusive app-only deals and cashback offers." },
  { title: "Bank-Grade Security", desc: "256-bit encryption, PCI compliance, and multi-factor authentication protect every transaction." },
  { title: "100% Verified Partners", desc: "Rigorous background checks and quality audits ensure only trusted businesses serve you." },
  { title: "Real-time Intelligence", desc: "Live order tracking, instant notifications, and dynamic ETA updates for complete visibility." },
  { title: "Cross-City Delivery", desc: "Send packages across cities with reliable logistics partners and real-time tracking." },
  { title: "24/7 Core Support", desc: "Dedicated customer support via chat, call, and email — always ready to help you." },
]

const WhyMultiverse = () => {
  return (
    <section className="py-20 lg:py-32 relative overflow-hidden">
      <div className="absolute top-0 left-[-10%] w-[380px] h-[380px] aurora-orb bg-primary/10" />
      <div className="container mx-auto px-5 lg:px-12 relative z-10">
        <div className="flex flex-col lg:grid lg:grid-cols-2 gap-12 lg:gap-24 items-center">
          <div>
            <motion.h2
              initial={{ opacity: 0, x: -30 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true }}
              className="text-4xl sm:text-5xl lg:text-7xl font-black font-space mb-10 lg:mb-12 leading-[0.9]"
            >
              Everything You Need,<br />
              <span className="text-gradient-fire">In One Place.</span>
            </motion.h2>

            <div className="space-y-5">
              {points.map((p, i) => (
                <motion.div
                  key={i}
                  initial={{ opacity: 0, x: -20 }}
                  whileInView={{ opacity: 1, x: 0 }}
                  viewport={{ once: true }}
                  transition={{ delay: i * 0.08 }}
                  whileHover={{ x: 6 }}
                  className="flex gap-4 group glass-card px-4 py-3 rounded-2xl border-white/5 hover:border-primary/20 transition-all preserve-3d"
                >
                  <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-primary/25 to-secondary/10 flex items-center justify-center flex-shrink-0 group-hover:shadow-[0_0_20px_rgba(255,106,0,0.4)] transition-all">
                    <CheckCircle2 className="text-primary group-hover:scale-125 transition-transform" size={18} />
                  </div>
                  <div>
                    <span className="font-bold text-white/90">{p.title}</span>
                    <p className="text-white/40 text-sm mt-0.5">{p.desc}</p>
                  </div>
                </motion.div>
              ))}
            </div>
          </div>

          <div className="relative flex justify-center perspective-2000">
            <div className="absolute w-[350px] h-[350px] lg:w-[500px] lg:h-[500px] bg-primary/15 blur-[120px] rounded-full blob animate-pulse-slow" />
            <motion.div
              initial={{ rotateY: -20, y: 50 }}
              whileInView={{ rotateY: 0, y: 0 }}
              whileHover={{ rotateY: 12, rotateX: 6, scale: 1.02 }}
              animate={{ y: [0, -15, 0] }}
              transition={{ y: { duration: 6, repeat: Infinity, ease: "easeInOut" }, rotateY: { duration: 1.5 } }}
              className="relative w-[240px] lg:w-[290px] aspect-[941/1672] bg-black border-[10px] lg:border-[12px] border-white/10 rounded-[50px] lg:rounded-[60px] shadow-[0_50px_100px_rgba(0,0,0,0.8)] overflow-hidden z-10"
            >
              <img src="/assets/app_screens/screen6.webp" className="w-full h-full object-cover" alt="Multiverse City App" loading="lazy" decoding="async" />
              <div className="absolute inset-0 bg-gradient-to-t from-primary/20 to-transparent pointer-events-none" />
            </motion.div>
          </div>
        </div>
      </div>
    </section>
  )
}

export default WhyMultiverse
