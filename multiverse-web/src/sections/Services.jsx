import React from "react"
import { motion } from "framer-motion"
import {
  ShoppingCart, Pill, Laptop, Shirt, UtensilsCrossed, Film,
  UserCog, Smile, Scissors, Microscope, Car, Home, Plus
} from "lucide-react"

const services = [
  { icon: ShoppingCart, name: "Grocery", desc: "Daily essentials delivered fast" },
  { icon: Pill, name: "Pharmacy", desc: "Medicines at your doorstep" },
  { icon: Laptop, name: "Electronics", desc: "Gadgets & accessories" },
  { icon: Shirt, name: "Fashion", desc: "Trending styles & brands" },
  { icon: UtensilsCrossed, name: "Food", desc: "Local & restaurant food" },
  { icon: Film, name: "Movies", desc: "Instant ticket booking" },
  { icon: UserCog, name: "Doctors", desc: "Expert consultations" },
  { icon: Smile, name: "Dentists", desc: "Dental care booking" },
  { icon: Scissors, name: "Salon", desc: "Beauty & grooming" },
  { icon: Microscope, name: "Labs", desc: "Diagnostic tests" },
  { icon: Car, name: "Car Service", desc: "Maintenance & repair" },
  { icon: Home, name: "Real Estate", desc: "Buy, sell & rent" },
]

const Services = () => {
  return (
    <section id="services" className="py-20 lg:py-32 bg-white/[0.01] relative overflow-hidden">
      <div className="absolute -bottom-20 left-1/4 w-[380px] h-[380px] aurora-orb bg-secondary/10" />
      <div className="container mx-auto px-5 lg:px-12 relative z-10">
        <div className="text-center mb-16 lg:mb-24">
          <motion.span
            initial={{ opacity: 0, y: 10 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="inline-block text-primary font-bold tracking-[0.3em] uppercase text-xs mb-4"
          >
            Everything You Need
          </motion.span>
          <motion.h2
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="text-4xl sm:text-5xl lg:text-7xl font-black font-space mb-6"
          >
            World-Class <span className="text-gradient-fire">Services</span>
          </motion.h2>
          <p className="text-white/40 text-base lg:text-xl max-w-2xl mx-auto">
            12+ service categories and growing. From daily needs to special occasions — Multiverse City has you covered.
          </p>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3 lg:gap-4 perspective-2000">
          {services.map((s, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.03 }}
              whileHover={{ y: -8, scale: 1.03 }}
              className="glass-card glass-shine p-5 lg:p-6 group hover:bg-primary/10 hover:border-primary/40 transition-all cursor-pointer text-center"
            >
              <s.icon className="mx-auto text-primary mb-3 group-hover:scale-125 group-hover:drop-shadow-[0_0_12px_rgba(255,106,0,0.7)] transition-transform" size={24} />
              <span className="text-xs lg:text-sm font-bold uppercase tracking-wider block">{s.name}</span>
              <span className="text-[10px] lg:text-xs text-white/30 mt-1 block">{s.desc}</span>
            </motion.div>
          ))}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            whileHover={{ y: -8, scale: 1.03 }}
            className="glass-card glass-shine p-5 lg:p-6 group bg-primary hover:bg-primary/80 transition-all cursor-pointer border-none text-center"
          >
            <Plus className="mx-auto text-white mb-3 group-hover:scale-125 transition-transform" size={24} />
            <span className="text-xs lg:text-sm font-bold uppercase tracking-wider">Coming Soon</span>
            <span className="text-[10px] text-white/50 mt-1 block">More categories</span>
          </motion.div>
        </div>
      </div>
    </section>
  )
}

export default Services
