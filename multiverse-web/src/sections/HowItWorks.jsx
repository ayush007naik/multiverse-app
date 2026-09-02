import React from "react"
import { motion } from "framer-motion"
import { Download, LayoutGrid, ShoppingCart, CreditCard, Smile } from "lucide-react"

const steps = [
  { icon: Download, num: "01", title: "Download App", desc: "Get Multiverse City from Play Store or App Store. Quick signup with your phone number." },
  { icon: LayoutGrid, num: "02", title: "Choose Category", desc: "Browse 16+ categories — from groceries to real estate. Find exactly what you need." },
  { icon: ShoppingCart, num: "03", title: "Book or Buy", desc: "Select products, book appointments, or reserve tickets. Everything in a few taps." },
  { icon: CreditCard, num: "04", title: "Pay Securely", desc: "UPI, cards, wallet — pay however you want. Bank-grade encryption on every transaction." },
  { icon: Smile, num: "05", title: "Enjoy Service", desc: "Track your order in real-time. Sit back and enjoy a seamless experience." },
]

const HowItWorks = () => {
  return (
    <section className="py-20 lg:py-32 relative overflow-hidden">
      <div className="absolute top-0 right-[-10%] w-[360px] h-[360px] aurora-orb bg-primary/10" />
      <div className="container mx-auto px-5 lg:px-12 relative z-10">
        <div className="text-center mb-16 lg:mb-24">
          <motion.span
            initial={{ opacity: 0, y: 10 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="inline-block text-primary font-bold tracking-[0.3em] uppercase text-xs mb-4"
          >
            Simple Process
          </motion.span>
          <motion.h2
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="text-4xl sm:text-5xl lg:text-7xl font-black font-space mb-6"
          >
            How It <span className="text-gradient-fire">Works</span>
          </motion.h2>
        </div>

        <div className="relative">
          <div className="absolute top-10 left-[10%] w-[80%] h-[2px] bg-white/5 hidden lg:block" />
          <motion.div
            initial={{ scaleX: 0 }}
            whileInView={{ scaleX: 1 }}
            viewport={{ once: true }}
            transition={{ duration: 2, ease: "easeInOut" }}
            className="absolute top-10 left-[10%] w-[80%] h-[2px] bg-gradient-to-r from-primary to-secondary origin-left hidden lg:block"
          />

          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-8 lg:gap-12">
            {steps.map((s, i) => (
              <motion.div
                key={i}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: i * 0.15 }}
                whileHover={{ y: -10 }}
                className="relative z-10 text-center group"
              >
                <div className="relative w-20 h-20 lg:w-24 lg:h-24 bg-black border-2 border-primary rounded-full flex items-center justify-center mx-auto mb-6 lg:mb-10 shadow-[0_0_30px_rgba(255,106,0,0.2)] group-hover:shadow-[0_0_50px_rgba(255,106,0,0.45)] group-hover:-translate-y-1 transition-all">
                  <span className="absolute inset-0 rounded-full border-2 border-primary/20 animate-ping opacity-40" />
                  <s.icon className="text-primary group-hover:scale-125 transition-transform" size={28} />
                  <span className="absolute -top-3 -right-1 text-[10px] font-black font-space text-gradient-fire">{s.num}</span>
                </div>
                <h4 className="text-lg lg:text-xl font-bold mb-2">{s.title}</h4>
                <p className="text-white/40 text-sm leading-relaxed">{s.desc}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}

export default HowItWorks
