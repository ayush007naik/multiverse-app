import React, { useState, useEffect, useRef } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { Menu, X, Download } from "lucide-react"

const navItems = [
  { label: "Home", href: "#home" },
  { label: "Features", href: "#features" },
  { label: "Categories", href: "#categories" },
  { label: "Services", href: "#services" },
  { label: "About", href: "#about" },
  { label: "Contact", href: "#contact" },
]

const PLAY_URL = "https://play.google.com/store/apps/details?id=com.ayush.multiverse.multiverses"

const Navbar = ({ onShowAlert }) => {
  const [scrolled, setScrolled] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)
  const [active, setActive] = useState("")

  const navRef = useRef(null)

  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 40)
    window.addEventListener("scroll", handleScroll, { passive: true })
    return () => window.removeEventListener("scroll", handleScroll)
  }, [])

  useEffect(() => {
    if (mobileOpen) document.body.style.overflow = "hidden"
    else document.body.style.overflow = ""
    return () => { document.body.style.overflow = "" }
  }, [mobileOpen])

  // Scrollspy — highlight the section currently in view
  useEffect(() => {
    const ids = navItems.map((i) => i.href.slice(1))
    const sections = ids
      .map((id) => document.getElementById(id))
      .filter(Boolean)
    if (!sections.length) return
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => {
          if (e.isIntersecting) setActive(`#${e.target.id}`)
        })
      },
      { rootMargin: "-45% 0px -50% 0px", threshold: 0 }
    )
    sections.forEach((s) => observer.observe(s))
    return () => observer.disconnect()
  }, [])

  return (
    <>
      <motion.nav
        initial={{ y: -100 }}
        animate={{ y: 0 }}
        transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1], delay: 0.15 }}
        ref={navRef}
        className={`fixed top-0 w-full z-[1000] transition-all duration-500 ${
          scrolled
            ? "bg-background/85 backdrop-blur-2xl py-3 border-b border-white/5"
            : "bg-transparent py-6"
        }`}
      >
        {/* Top accent line */}
        <div className="absolute left-0 top-0 h-[2px] w-full bg-gradient-to-r from-transparent via-primary/40 to-transparent" />

        <div className="container mx-auto px-5 lg:px-12 flex justify-between items-center">
          {/* Logo */}
          <a href="#home" className="flex items-center gap-3 group">
            <span className="relative">
              <img src="/assets/logo.png" alt="Multiverse City" className="h-9 w-9 object-contain" />
              <span className="absolute -inset-1 rounded-full bg-primary/0 blur group-hover:bg-primary/20 transition-all duration-500" />
            </span>
            <span className="text-xl lg:text-2xl font-display font-bold tracking-tight">
              MULTIVERSE <span className="text-gradient-fire">CITY</span>
            </span>
          </a>

          {/* Desktop links */}
          <div className="hidden lg:flex items-center gap-8">
            {navItems.map((item) => {
              const isActive = active === item.href
              return (
                <a
                  key={item.href}
                  href={item.href}
                  className={`group relative text-sm font-medium transition-colors duration-300 ${
                    isActive ? "text-white" : "text-white/50 hover:text-white/90"
                  }`}
                >
                  {item.label}
                  <span
                    className={`absolute -bottom-1.5 left-0 h-px bg-primary transition-all duration-500 ${
                      isActive ? "w-full" : "w-0 group-hover:w-full"
                    }`}
                  />
                </a>
              )
            })}
          </div>

          {/* Actions */}
          <div className="flex items-center gap-4">
            <a
              href={PLAY_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="hidden lg:inline-flex items-center gap-2 group relative overflow-hidden bg-primary text-white text-sm font-bold py-3 px-7 rounded-full shadow-glow-sm transition-all duration-300 hover:scale-105 active:scale-95"
            >
              <span className="absolute inset-0 bg-gradient-to-r from-primary to-secondary opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
              <Download size={16} className="relative z-10" />
              <span className="relative z-10">Download App</span>
            </a>
            <button
              onClick={() => setMobileOpen(!mobileOpen)}
              aria-label="Toggle menu"
              className="lg:hidden p-2 text-white/80 hover:text-white transition-colors"
            >
              {mobileOpen ? <X size={26} /> : <Menu size={26} />}
            </button>
          </div>
        </div>

        {/* Bottom hairline that fades in when scrolled */}
        <div
          className={`absolute left-0 bottom-0 h-px w-full bg-gradient-to-r from-transparent via-white/15 to-transparent transition-opacity duration-500 ${
            scrolled ? "opacity-100" : "opacity-0"
          }`}
        />
      </motion.nav>

      {/* Mobile menu */}
      <AnimatePresence>
        {mobileOpen && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.25 }}
            className="fixed inset-0 z-[999] lg:hidden"
          >
            <div className="absolute inset-0 bg-background/95 backdrop-blur-2xl" />
            <div className="absolute left-0 top-0 h-[2px] w-full bg-gradient-to-r from-primary via-secondary to-primary" />

            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 20 }}
              transition={{ delay: 0.05, duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
              className="relative flex flex-col justify-between h-full pt-28 px-8 pb-10"
            >
              <div className="flex flex-col gap-1">
                {navItems.map((item, i) => (
                  <motion.a
                    key={item.href}
                    href={item.href}
                    onClick={() => setMobileOpen(false)}
                    initial={{ opacity: 0, x: -24 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: 0.08 + i * 0.06, duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
                    className="group flex items-center justify-between text-3xl font-display font-bold py-4 border-b border-white/5 text-white/70 hover:text-white transition-colors"
                  >
                    <span>{item.label}</span>
                    <span className="text-primary opacity-0 group-hover:opacity-100 transition-opacity duration-300 text-xl">→</span>
                  </motion.a>
                ))}
              </div>

              <motion.a
                href={PLAY_URL}
                target="_blank"
                rel="noopener noreferrer"
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.35 }}
                onClick={() => setMobileOpen(false)}
                className="flex items-center justify-center gap-2 bg-primary text-white font-bold py-4 rounded-full shadow-glow text-lg"
              >
                <Download size={18} />
                Download App
              </motion.a>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  )
}

export default Navbar
