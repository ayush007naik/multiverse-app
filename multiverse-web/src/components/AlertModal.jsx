import React from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { X } from 'lucide-react'

const AlertModal = ({ isOpen, onClose, title, message }) => {
  if (!isOpen) return null

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-[3000] flex items-center justify-center p-6">
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          onClick={onClose}
          className="absolute inset-0 bg-black/80 backdrop-blur-sm"
        />
        <motion.div
          initial={{ opacity: 0, scale: 0.9, y: 20 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.9, y: 20 }}
          className="relative w-full max-w-md bg-[#0D0D0D] border border-white/10 rounded-3xl overflow-hidden shadow-[0_0_60px_rgba(255,106,0,0.15)]"
        >
          <div className="relative p-8 text-center">
            <button
              onClick={onClose}
              className="absolute top-4 right-4 p-2 hover:bg-white/5 rounded-full transition-colors text-white/30 hover:text-white"
            >
              <X size={18} />
            </button>

            <div className="w-16 h-16 bg-primary/10 rounded-2xl flex items-center justify-center mx-auto mb-6 border border-primary/20 overflow-hidden">
              <img src="/assets/logo.png" alt="Multiverse City" className="w-10 h-10 object-contain" />
            </div>

            <h3 className="text-xl font-bold font-space mb-3">{title}</h3>
            <p className="text-white/50 text-sm leading-relaxed mb-8">{message}</p>

            <div className="flex flex-col sm:flex-row gap-3 justify-center">
              <button
                onClick={onClose}
                className="flex items-center justify-center gap-2 bg-primary text-white font-bold py-3 px-6 rounded-full shadow-[0_0_20px_rgba(255,106,0,0.3)] hover:scale-105 transition-all text-sm"
              >
                Coming Soon
              </button>
              <button
                onClick={onClose}
                className="flex items-center justify-center gap-2 border border-white/10 text-white/70 font-bold py-3 px-6 rounded-full hover:bg-white/5 transition-all text-sm"
              >
                Maybe Later
              </button>
            </div>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  )
}

export default AlertModal
