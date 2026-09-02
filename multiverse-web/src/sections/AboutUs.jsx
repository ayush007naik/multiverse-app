import React from "react"
import { motion } from "framer-motion"
import { CheckCircle2, Target, Eye, Rocket } from "lucide-react"

const capabilities = [
  "Multi-category shopping — Grocery, Pharmacy, Electronics & more",
  "Movie ticket booking with seat selection & history",
  "Appointment booking — Doctors, Dentists, Salons, Labs",
  "Real Estate marketplace — Buy, Sell, Rent with virtual tours",
  "Location-based smart search with voice support",
  "Secure payments via UPI, Cards & Digital Wallet",
  "Real-time order tracking with live GPS updates",
  "Cross-city delivery support across Himachal Pradesh",
  "Personalized recommendations powered by AI",
  "Cashback offers and referral rewards program",
]

const AboutUs = () => {
  return (
    <section id="about" className="py-20 lg:py-32 relative overflow-hidden">
      <div className="absolute top-10 right-[-8%] w-[360px] h-[360px] aurora-orb bg-primary/10" />
      <div className="container mx-auto px-5 lg:px-12 relative z-10">
        <div className="flex flex-col lg:grid lg:grid-cols-2 gap-12 lg:gap-20 items-center">
          <motion.div
            initial={{ opacity: 0, x: -30 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
          >
            <motion.span
              initial={{ opacity: 0, y: 10 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              className="inline-block text-primary font-bold tracking-[0.3em] uppercase text-xs mb-4"
            >
              About Us
            </motion.span>
            <h2 className="text-4xl sm:text-5xl lg:text-6xl font-black font-space mb-6 lg:mb-8 leading-tight">
              Built for <span className="text-gradient-fire">Millions</span>,<br />Designed for <span className="text-gradient-fire">You.</span>
            </h2>
            <div className="space-y-4 text-white/50 text-base lg:text-lg leading-relaxed mb-8">
              <p>
                Multiverse City is an all-in-one digital platform built to simplify everyday life. We bring shopping, entertainment, healthcare, and real estate into a single, seamless application — so you never need to switch between apps again.
              </p>
              <p>
                Starting from Mandi, Himachal Pradesh, our mission is to digitize local commerce and empower businesses and citizens alike with world-class technology.
              </p>
            </div>

            <div className="space-y-3">
              {capabilities.map((f, i) => (
                <div key={i} className="flex items-start gap-3 text-sm font-medium text-white/70">
                  <CheckCircle2 className="text-primary flex-shrink-0 mt-0.5" size={16} />
                  {f}
                </div>
              ))}
            </div>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, x: 30 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            className="space-y-6"
          >
            <div className="glass-card glass-shine p-8 lg:p-10 relative group overflow-hidden">
              <div className="absolute top-0 right-0 p-8 opacity-[0.05] group-hover:scale-110 transition-transform duration-500">
                <Target size={80} />
              </div>
              <div className="flex items-center gap-4 mb-5">
                <div className="w-11 h-11 rounded-2xl bg-primary/20 flex items-center justify-center text-primary">
                  <Rocket size={20} />
                </div>
                <h3 className="text-2xl font-black font-space">Our Mission</h3>
              </div>
              <p className="text-white/50 leading-relaxed">
                To empower local businesses and provide customers with a unified digital platform where they can shop, book services, discover opportunities, and manage everyday needs efficiently — all from a single app.
              </p>
            </div>

            <div className="glass-card glass-shine p-8 lg:p-10 relative group overflow-hidden">
              <div className="absolute top-0 right-0 p-8 opacity-[0.05] group-hover:scale-110 transition-transform duration-500">
                <Eye size={80} />
              </div>
              <div className="flex items-center gap-4 mb-5">
                <div className="w-11 h-11 rounded-2xl bg-secondary/20 flex items-center justify-center text-secondary">
                  <Eye size={20} />
                </div>
                <h3 className="text-2xl font-black font-space">Our Vision</h3>
              </div>
              <p className="text-white/50 leading-relaxed">
                To become the leading digital ecosystem connecting people with products, services, entertainment, healthcare, and real estate — while promoting local commerce and delivering a world-class customer experience.
              </p>
            </div>

            <div className="glass-card glass-shine p-8 lg:p-10 relative group overflow-hidden">
              <div className="flex items-center gap-4 mb-5">
                <div className="w-11 h-11 rounded-2xl bg-green-500/20 flex items-center justify-center text-green-500">
                  <CheckCircle2 size={20} />
                </div>
                <h3 className="text-2xl font-black font-space">Why Multiverse City?</h3>
              </div>
              <p className="text-white/50 leading-relaxed">
                Because switching between 10 different apps for daily needs is outdated. Multiverse City brings everything together — from ordering groceries to finding your dream home — in one powerful, beautifully designed ecosystem.
              </p>
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  )
}

export default AboutUs
