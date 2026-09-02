import React from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { X } from 'lucide-react'

const PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=com.ayush.multiverse.multiverses"

const DownloadModal = ({ isOpen, onClose, title, message }) => {
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

            <div className="flex flex-col items-center gap-3 justify-center mb-6">
              <a
                href={PLAY_STORE_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="hover:scale-105 transition-transform"
                title="Get it on Google Play"
              >
                <img
                  src="https://upload.wikimedia.org/wikipedia/commons/7/78/Google_Play_Store_badge_EN.svg"
                  className="h-12"
                  alt="Get it on Google Play"
                />
              </a>
              <span className="relative flex flex-col items-center cursor-not-allowed select-none" title="App Store — Coming Soon">
                <img
                  src="https://upload.wikimedia.org/wikipedia/commons/3/3c/Download_on_the_App_Store_Badge.svg"
                  className="h-12 opacity-40 grayscale"
                  alt="Download on the App Store"
                />
                <span className="mt-1 text-[10px] px-2 py-0.5 rounded-full border border-white/15 text-white/50 font-bold uppercase tracking-wide">Coming Soon</span>
              </span>
            </div>

            <button
              onClick={onClose}
              className="text-xs text-white/30 hover:text-white/60 transition-colors"
            >
              Maybe Later
            </button>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  )
}

export default DownloadModal
