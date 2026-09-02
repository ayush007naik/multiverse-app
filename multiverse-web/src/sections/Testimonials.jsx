import React from "react"
import { motion } from "framer-motion"
import { Star } from "lucide-react"

const reviews = [
  {
    name: "Priya Sharma",
    role: "Daily User, Mandi",
    txt: "Multiverse City has completely changed how I manage my daily life. I order groceries, book doctor appointments, and even buy movie tickets — all from one app. The UI is smooth and the delivery is always on time.",
    avatar: "PS",
  },
  {
    name: "Rahul Verma",
    role: "Business Owner",
    txt: "As a local business owner, Multiverse City gave my store the digital visibility it desperately needed. The verification process gives customers confidence, and the analytics dashboard helps me track sales in real-time.",
    avatar: "RV",
  },
  {
    name: "Anjali Gupta",
    role: "Real Estate Client",
    txt: "Finding a property was always stressful until I tried Multiverse City. The verified listings, virtual tours, and direct agent connectivity made the entire process seamless. Found my dream home in just 2 weeks!",
    avatar: "AG",
  },
]

const Testimonials = () => {
  return (
    <section className="py-20 lg:py-32 relative overflow-hidden">
      <div className="absolute bottom-0 left-[-10%] w-[360px] h-[360px] aurora-orb bg-secondary/10" />
      <div className="container mx-auto px-5 lg:px-12 relative z-10">
        <div className="text-center mb-16 lg:mb-24">
          <motion.span
            initial={{ opacity: 0, y: 10 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="inline-block text-primary font-bold tracking-[0.3em] uppercase text-xs mb-4"
          >
            Testimonials
          </motion.span>
          <motion.h2
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="text-4xl sm:text-5xl lg:text-7xl font-black font-space mb-6"
          >
            What Our <span className="text-gradient-fire">Users Say</span>
          </motion.h2>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-6 lg:gap-8 perspective-2000">
          {reviews.map((r, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.1 }}
              whileHover={{ y: -8 }}
              className="glass-card glass-shine p-8 lg:p-10 group hover:border-primary/25 transition-all"
            >
              <div className="flex gap-1 mb-6">
                {[1, 2, 3, 4, 5].map((s) => (
                  <Star key={s} size={14} className="fill-primary text-primary animate-pulse" style={{ animationDelay: `${s * 0.2}s` }} />
                ))}
              </div>
              <p className="text-white/60 leading-relaxed mb-8 text-sm lg:text-base">"{r.txt}"</p>
              <div className="flex items-center gap-4 pt-6 border-t border-white/5">
                <div className="w-11 h-11 rounded-full bg-gradient-to-br from-primary to-secondary flex items-center justify-center text-white text-sm font-bold">
                  {r.avatar}
                </div>
                <div>
                  <h4 className="font-bold text-sm">{r.name}</h4>
                  <p className="text-xs text-white/30">{r.role}</p>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  )
}

export default Testimonials
