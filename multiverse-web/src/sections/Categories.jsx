import React from "react"
import { motion } from "framer-motion"
import { ArrowRight, ShoppingCart, Film, UserPlus, Home } from "lucide-react"

const cats = [
  {
    icon: ShoppingCart,
    title: "Marketplace",
    desc: "From daily groceries to premium electronics — shop thousands of products with hyper-local delivery. Compare prices, read reviews, and get doorstep delivery in minutes.",
    img: "screen1.webp",
    color: "from-green-500/20",
    border: "border-green-500/20",
    stats: "1K+ Products",
  },
  {
    icon: Film,
    title: "Movies",
    desc: "Book tickets for the latest blockbusters at your favorite theaters. Choose your seats, grab combo deals, and enjoy a premium cinema experience — all from your phone.",
    img: "screen2.webp",
    color: "from-red-500/20",
    border: "border-red-500/20",
    stats: "2+ Theaters",
  },
  {
    icon: UserPlus,
    title: "Appointments",
    desc: "Connect with verified doctors, dentists, salons, and home-service professionals. View real-time availability, book instantly, and get reminders before your session.",
    img: "screen3.webp",
    color: "from-primary/20",
    border: "border-primary/20",
    stats: "50+ Professionals",
  },
  {
    icon: Home,
    title: "Real Estate",
    desc: "Discover your dream property — buy, sell, or rent. Browse verified listings with virtual tours, detailed floor plans, and direct builder/agent connectivity.",
    img: "screen4.webp",
    color: "from-blue-500/20",
    border: "border-blue-500/20",
    stats: "100+ Listings",
  },
]

const Categories = ({ onOpenDownload }) => {
  return (
    <section id="categories" className="py-20 lg:py-32 relative overflow-hidden">
      <div className="absolute top-40 right-[-10%] w-[380px] h-[380px] aurora-orb bg-primary/10" />
      <div className="container mx-auto px-5 lg:px-12 relative z-10">
        <div className="text-center mb-16 lg:mb-24">
          <motion.span
            initial={{ opacity: 0, y: 10 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="inline-block text-primary font-bold tracking-[0.3em] uppercase text-xs mb-4"
          >
            Core Pillars
          </motion.span>
          <motion.h2
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="text-4xl sm:text-5xl lg:text-7xl font-black font-space mb-6"
          >
            Explore <span className="text-gradient-fire">Categories</span>
          </motion.h2>
          <p className="text-white/40 text-base lg:text-xl max-w-2xl mx-auto">
            Four powerful verticals, one seamless experience. Each category is designed to deliver best-in-class service.
          </p>
        </div>

        <div className="grid sm:grid-cols-2 gap-6 lg:gap-8 perspective-2000">
          {cats.map((c, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, scale: 0.95, rotateY: i % 2 === 0 ? -3 : 3 }}
              whileInView={{ opacity: 1, scale: 1, rotateY: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.1 }}
              whileHover={{ y: -8 }}
              onClick={() => {
                if (onOpenDownload) onOpenDownload(
                  "Explore " + c.title,
                  "Tap to download Multiverse City app and explore " + c.title + "."
                )
              }}
              className="glass-card glass-shine relative overflow-hidden group cursor-pointer preserve-3d"
            >
              <div className={`absolute inset-0 bg-gradient-to-br ${c.color} to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-700`} />

              <div className="relative z-10 p-8 lg:p-12 flex flex-col lg:flex-row gap-8 items-center">
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-4">
                    <div className={`w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center`}>
                      <c.icon className="text-primary" size={20} />
                    </div>
                    <span className={`text-[10px] font-bold tracking-widest uppercase ${c.border} border px-3 py-1 rounded-full text-white/50`}>
                      {c.stats}
                    </span>
                  </div>
                  <h3 className="text-2xl lg:text-3xl font-black font-space mb-3">{c.title}</h3>
                  <p className="text-white/40 text-sm lg:text-base leading-relaxed mb-6">{c.desc}</p>
                  <button onClick={(e) => {
                    e.stopPropagation()
                    const msgs = {
                      Marketplace: "Tap to download Multiverse City and start shopping — thousands of products with hyper-local delivery!",
                      Movies: "Tap to download Multiverse City and book tickets for the latest blockbusters at your favorite theaters!",
                      Appointments: "Tap to download Multiverse City and book verified doctors, dentists & more with instant availability!",
                      "Real Estate": "Tap to download Multiverse City and explore verified properties with virtual tours!"
                    };
                    if (onOpenDownload) onOpenDownload("Explore " + c.title, msgs[c.title] || "This feature is available in the Multiverse City app. Download now to explore!");
                  }} className="flex items-center gap-2 text-primary font-bold text-sm hover:gap-4 transition-all group/btn">
                    Explore {c.title} <ArrowRight size={16} className="group-hover/btn:translate-x-1 transition-transform" />
                  </button>
                </div>

                <div className="relative w-[200px] lg:w-[230px] aspect-[941/1672] flex-shrink-0 preserve-3d">
                  <motion.div
                    className="w-full h-full bg-black border-8 border-white/10 rounded-[36px] shadow-2xl overflow-hidden"
                    whileHover={{ y: -14, rotateY: i % 2 === 0 ? -8 : 8, rotateX: 4, scale: 1.03 }}
                    initial={{ rotate: i % 2 === 0 ? -4 : 4 }}
                    transition={{ type: "spring", stiffness: 200, damping: 15 }}
                  >
                    <img src={"/assets/app_screens/" + c.img} className="w-full h-full object-cover" alt={c.title} loading="lazy" decoding="async" />
                  </motion.div>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  )
}

export default Categories
