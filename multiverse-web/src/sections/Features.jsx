import React from "react"
import { motion } from "framer-motion"
import { Search, CalendarCheck, ShieldCheck, MapPin, Lock, Zap } from "lucide-react"

const features = [
  {
    icon: Search,
    title: "AI Powered Search",
    desc: "Our intelligent search engine understands your intent and delivers hyper-relevant results across all categories — groceries, doctors, movies, or properties — in milliseconds.",
    tag: "Smart Discovery",
  },
  {
    icon: Zap,
    title: "Lightning Fast",
    desc: "Optimized for speed at every level. From app launch to checkout, Multiverse City delivers a blazing-fast experience with zero lag.",
    tag: "Performance",
  },
  {
    icon: CalendarCheck,
    title: "Real-time Booking",
    desc: "Book movie tickets, doctor consultations, salon appointments, or property visits instantly. Live slot availability, instant confirmations, and zero wait times.",
    tag: "Instant Scheduling",
  },
  {
    icon: ShieldCheck,
    title: "Verified Businesses",
    desc: "Every business on Multiverse City undergoes rigorous verification. From document checks to quality audits — only trusted, certified partners make it to the platform.",
    tag: "Trust & Safety",
  },
  {
    icon: MapPin,
    title: "Live Tracking",
    desc: "Track your deliveries, service professionals, and ride partners in real-time with satellite-grade GPS precision. Know exactly when your order arrives.",
    tag: "Real-time GPS",
  },
  {
    icon: Lock,
    title: "Secure Payments",
    desc: "Bank-grade 256-bit encryption protects every transaction. PCI DSS compliant, Razorpay-powered processing ensures your financial data stays safe.",
    tag: "Enterprise Security",
  },
]

const Features = () => {
  return (
    <section id="features" className="py-20 lg:py-32 relative overflow-hidden">
      <div className="absolute top-40 left-[-10%] w-[360px] h-[360px] aurora-orb bg-primary/10" />
      <div className="absolute bottom-0 right-[-10%] w-[360px] h-[360px] aurora-orb bg-secondary/10" style={{ animationDelay: "-8s" }} />
      <div className="container mx-auto px-5 lg:px-12 relative z-10">
        <div className="text-center mb-16 lg:mb-24">
          <motion.span
            initial={{ opacity: 0, y: 10 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="inline-block text-primary font-bold tracking-[0.3em] uppercase text-xs mb-4"
          >
            Why Choose Us
          </motion.span>
          <motion.h2
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="text-4xl sm:text-5xl lg:text-7xl font-black font-space mb-6"
          >
            Powerful <span className="text-gradient-fire">Features</span>
          </motion.h2>
          <p className="text-white/40 text-base lg:text-xl max-w-2xl mx-auto">
            Engineered for the future of digital commerce. Every feature is built to simplify your life and amplify your productivity.
          </p>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-6 lg:gap-8 perspective-2000">
          {features.map((f, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.1 }}
              whileHover={{ y: -8, rotateX: 4, rotateY: i % 2 === 0 ? 2 : -2, scale: 1.02 }}
              className="glass-card glass-shine p-8 lg:p-10 group hover:border-primary/40 transition-all duration-500 preserve-3d relative"
            >
              <div className="absolute -top-8 -right-8 w-24 h-24 bg-primary/10 rounded-full blur-2xl group-hover:bg-primary/20 transition-all" />
              <div className="flex items-center justify-between mb-6">
                <div className="w-14 h-14 lg:w-16 lg:h-16 bg-gradient-to-br from-primary/25 to-secondary/15 rounded-2xl flex items-center justify-center group-hover:scale-110 group-hover:shadow-[0_0_30px_rgba(255,106,0,0.4)] transition-all">
                  <f.icon className="text-primary" size={28} />
                </div>
                <span className="text-[10px] lg:text-xs font-bold tracking-widest uppercase text-primary/60 bg-primary/5 px-3 py-1.5 rounded-full border border-primary/10">
                  {f.tag}
                </span>
              </div>
              <h3 className="text-xl lg:text-2xl font-bold mb-3 group-hover:text-primary transition-colors">{f.title}</h3>
              <p className="text-white/40 leading-relaxed text-sm lg:text-base">{f.desc}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  )
}

export default Features
