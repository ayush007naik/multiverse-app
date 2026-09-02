import React from "react"
import { Mail, MapPin, Phone } from "lucide-react"

const Footer = ({
  onOpenTerms,
  onOpenBlog,
  onOpenCookie,
  onOpenAbout,
  onOpenRefund,
  onOpenCancellation,
  onOpenDelivery,
}) => {
  return (
    <footer className="py-16 lg:py-20 border-t border-white/5 bg-background">
      <div className="container mx-auto px-5 lg:px-12">
        <div className="grid sm:grid-cols-2 lg:grid-cols-5 gap-10 lg:gap-8 mb-16">
          <div className="lg:col-span-2">
            <div className="flex items-center gap-3 mb-6">
              <img src="/assets/logo.png" className="h-9" alt="Multiverse City" />
              <span className="text-xl font-bold font-space tracking-tight">MULTIVERSE CITY</span>
            </div>
            <p className="text-white/40 text-sm leading-relaxed max-w-sm mb-6">
              The world's first true super-app city ecosystem. Empowering citizens through unified digital infrastructure — from Mandi to the world.
            </p>
            <div className="space-y-3 text-sm text-white/40">
              <div className="flex items-center gap-3"><Mail size={14} className="text-primary" /> support@multiversecity.com</div>
              <div className="flex items-center gap-3"><Phone size={14} className="text-primary" /> +91 7018741456</div>
              <div className="flex items-center gap-3"><MapPin size={14} className="text-primary" /> Mandi, Himachal Pradesh, India</div>
            </div>
          </div>

          <div>
            <h4 className="font-bold uppercase tracking-widest text-xs mb-6 text-primary">Product</h4>
            <ul className="space-y-3 text-sm text-white/40">
              <li><a href="#features" className="hover:text-white transition-colors">Features</a></li>
              <li><a href="#categories" className="hover:text-white transition-colors">Categories</a></li>
              <li><a href="#services" className="hover:text-white transition-colors">Services</a></li>
              <li><a href="https://play.google.com/store/apps/details?id=com.ayush.multiverse.multiverses" target="_blank" rel="noopener noreferrer" className="hover:text-white transition-colors">Download App</a></li>
            </ul>
          </div>

          <div>
            <h4 className="font-bold uppercase tracking-widest text-xs mb-6 text-primary">Company</h4>
            <ul className="space-y-3 text-sm text-white/40">
              <li><button onClick={onOpenAbout} className="hover:text-white transition-colors text-left">About Us</button></li>
              <li><a href="#contact" className="hover:text-white transition-colors">Contact</a></li>
              <li><a href="#contact" className="hover:text-white transition-colors">Careers</a></li>
              <li><button onClick={onOpenBlog} className="hover:text-white transition-colors text-left">Blog</button></li>
            </ul>
          </div>

          <div>
            <h4 className="font-bold uppercase tracking-widest text-xs mb-6 text-primary">Legal</h4>
            <ul className="space-y-3 text-sm text-white/40">
              <li><a href="/privacy-customer.html" className="hover:text-white transition-colors">Customer App Privacy</a></li>
              <li><a href="/privacy-vendor.html" className="hover:text-white transition-colors">Vendor App Privacy</a></li>
              <li><a href="/privacy-delivery.html" className="hover:text-white transition-colors">Delivery Partner Privacy</a></li>
              <li><a href="/privacy-theatre.html" className="hover:text-white transition-colors">Theatre Scanner Privacy</a></li>
              <li><a href="/privacy-appointment.html" className="hover:text-white transition-colors">Appointment App Privacy</a></li>
              <li><a href="/delete-account" className="hover:text-white transition-colors">Delete Account</a></li>
              <li><button onClick={onOpenTerms} className="hover:text-white transition-colors text-left">Terms & Conditions</button></li>
              <li><button onClick={onOpenRefund} className="hover:text-white transition-colors text-left">Refund Policy</button></li>
              <li><button onClick={onOpenCancellation} className="hover:text-white transition-colors text-left">Cancellation Policy</button></li>
              <li><button onClick={onOpenDelivery} className="hover:text-white transition-colors text-left">Delivery Policy</button></li>
              <li><button onClick={onOpenCookie} className="hover:text-white transition-colors text-left">Cookie Policy</button></li>
            </ul>
          </div>
        </div>

        <div className="pt-8 border-t border-white/5 flex flex-col sm:flex-row justify-between items-center gap-4 text-white/20 text-xs">
          <p>&copy; 2026 Multiverse City. All Rights Reserved.</p>
          <div className="flex gap-6">
            <a href="https://wa.me/message/VQTSMLOHIWCXB1" target="_blank" rel="noopener noreferrer" className="hover:text-white/50 transition-colors">WhatsApp</a>
            <a href="https://www.instagram.com/multiverse.city?igsh=OHUzYzl1dm9uNWdq&utm_source=qr" target="_blank" rel="noopener noreferrer" className="hover:text-white/50 transition-colors">Instagram</a>
            <a href="https://www.linkedin.com/company/multiverse-city/" target="_blank" rel="noopener noreferrer" className="hover:text-white/50 transition-colors">LinkedIn</a>
            <a href="https://youtube.com/@multiverse.city.official?si=9A_6H_XlGdjGYiD7" target="_blank" rel="noopener noreferrer" className="hover:text-white/50 transition-colors">YouTube</a>
          </div>
        </div>
      </div>
    </footer>
  )
}

export default Footer
