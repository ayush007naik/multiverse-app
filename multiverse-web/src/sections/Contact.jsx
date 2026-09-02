import React from "react"
import { motion } from "framer-motion"
import { Mail, MapPin, Phone, Clock, MessageCircle } from "lucide-react"

const Contact = () => {
  return (
    <section id="contact" className="py-20 lg:py-32 relative overflow-hidden">
      <div className="absolute bottom-[-10%] right-[-8%] w-[360px] h-[360px] aurora-orb bg-primary/10" />
      <div className="container mx-auto px-5 lg:px-12 relative z-10">
        <div className="text-center mb-16 lg:mb-20">
          <motion.span
            initial={{ opacity: 0, y: 10 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="inline-block text-primary font-bold tracking-[0.3em] uppercase text-xs mb-4"
          >
            Get In Touch
          </motion.span>
          <motion.h2
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="text-4xl sm:text-5xl lg:text-7xl font-black font-space mb-6"
          >
            Connect With <span className="text-gradient-fire">Us</span>
          </motion.h2>
          <p className="text-white/40 text-base lg:text-xl max-w-2xl mx-auto">
            Have questions, feedback, or partnership inquiries? We would love to hear from you.
          </p>
        </div>

        <div className="max-w-4xl mx-auto">
          <div className="grid sm:grid-cols-2 gap-6">
            {[
              { icon: Mail, label: "Email Us", value: "support@multiversecity.com", sub: "We reply within 24 hours" },
              { icon: Phone, label: "Call Us", value: "+91 7018741456", sub: "Mon - Sat, 10AM to 7PM" },
              { icon: MapPin, label: "Headquarters", value: "Mandi, Himachal Pradesh, India", sub: "Visit us anytime" },
              { icon: Clock, label: "Support Hours", value: "24/7 Available", sub: "Always here for you" },
              { icon: MessageCircle, label: "WhatsApp", value: "Chat with us", sub: "Quick support on WhatsApp", link: "https://wa.me/message/VQTSMLOHIWCXB1" },
            ].map((item, i) => (
              <motion.div
                key={i}
                initial={{ opacity: 0, y: 15 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: i * 0.08 }}
              >
                {item.link ? (
                  <a href={item.link} target="_blank" rel="noopener noreferrer" className="glass-card glass-shine p-6 flex gap-4 items-start hover:border-primary/25 transition-all block">
                    <div className="w-12 h-12 bg-primary/10 rounded-xl flex items-center justify-center flex-shrink-0">
                      <item.icon className="text-primary" size={20} />
                    </div>
                    <div>
                      <p className="text-xs font-bold uppercase tracking-widest text-white/30 mb-1">{item.label}</p>
                      <p className="font-bold text-sm lg:text-base">{item.value}</p>
                      <p className="text-xs text-white/30 mt-0.5">{item.sub}</p>
                    </div>
                  </a>
                ) : (
                  <div className="glass-card glass-shine p-6 flex gap-4 items-start hover:border-primary/25 transition-all">
                    <div className="w-12 h-12 bg-primary/10 rounded-xl flex items-center justify-center flex-shrink-0">
                      <item.icon className="text-primary" size={20} />
                    </div>
                    <div>
                      <p className="text-xs font-bold uppercase tracking-widest text-white/30 mb-1">{item.label}</p>
                      <p className="font-bold text-sm lg:text-base">{item.value}</p>
                      <p className="text-xs text-white/30 mt-0.5">{item.sub}</p>
                    </div>
                  </div>
                )}
              </motion.div>
            ))}
          </div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="mt-8 glass-card glass-shine p-8 text-center relative overflow-hidden"
          >
            <p className="text-white/40 text-sm mb-2">Reach us directly</p>
            <a href="tel:+917018741456" className="text-2xl lg:text-3xl font-black font-space text-primary hover:underline">
              +91 7018741456
            </a>
            <p className="text-white/30 text-xs mt-3">Tap to call now</p>
          </motion.div>
        </div>
      </div>
    </section>
  )
}

export default Contact
