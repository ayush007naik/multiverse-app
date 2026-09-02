import React, { useState } from "react"
import Navbar from "./sections/Navbar"
import Hero from "./sections/Hero"
import Features from "./sections/Features"
import Categories from "./sections/Categories"
import Services from "./sections/Services"
import WhyMultiverse from "./sections/WhyMultiverse"
import HowItWorks from "./sections/HowItWorks"
import AppShowcase from "./sections/AppShowcase"
import Statistics from "./sections/Statistics"
import Testimonials from "./sections/Testimonials"
import AboutUs from "./sections/AboutUs"
import Contact from "./sections/Contact"
import Footer from "./sections/Footer"
import LaunchBanner from "./sections/LaunchBanner"
import PrivacyPolicyPage from "./pages/PrivacyPolicy"
import DeleteAccountPage from "./pages/DeleteAccount"
import Modal from "./components/Modal"
import AlertModal from "./components/AlertModal"
import DownloadModal from "./components/DownloadModal"
import CmsModal from "./components/CmsModal"
import BlogModal from "./components/BlogModal"
import Cursor from "./components/Cursor"
import Preloader from "./components/Preloader"
import ScrollProgress from "./components/ScrollProgress"

function App() {
  const [modalContent, setModalContent] = useState(null)
  const [cmsPage, setCmsPage] = useState(null)
  const [blogOpen, setBlogOpen] = useState(false)
  const [alertData, setAlertData] = useState({ open: false, title: "", message: "" })
  const [downloadData, setDownloadData] = useState({ open: false, title: "", message: "" })

  const showAlert = (title, message) => setAlertData({ open: true, title, message })
  const closeAlert = () => setAlertData({ open: false, title: "", message: "" })

  const openDownload = (title, message) => setDownloadData({ open: true, title, message })
  const closeDownload = () => setDownloadData({ open: false, title: "", message: "" })

  const openCms = (slug, title, fallback) => setCmsPage({ slug, title, fallback })

  const openTerms = () => {
    openCms("terms_conditions", "Terms & Conditions", (
        <div className="space-y-6 text-white/60 text-sm leading-relaxed">
          <p className="bg-white/5 p-4 rounded-xl border border-white/10 italic">Last Updated: May 2026</p>
          <p>Welcome to Multiverse City. These Terms & Conditions govern your access to and use of the Multiverse City application, website, and related services. By using Multiverse City, you agree to these Terms.</p>

          {[
            { t: "1. About Multiverse City", c: "Multiverse City is a multi-service digital platform connecting users with local businesses, products, services, and delivery solutions across Mandi District, including Mandi, Nerchowk, Sundernagar, and surrounding areas. Services include grocery delivery, pharmacy, electronics, fashion, furniture, property listings, movie tickets, and more." },
            { t: "2. Eligibility", c: "You must be legally capable of entering binding agreements. Information provided must be accurate. Users under 18 must use the platform under parental supervision." },
            { t: "3. User Accounts", c: "You are responsible for maintaining confidentiality of your account and all activities under it. Multiverse City may suspend accounts involved in suspicious or unlawful activities." },
            { t: "4. Orders & Bookings", c: "All orders are subject to availability. Delivery times are approximate. Multiverse City reserves the right to cancel orders in exceptional circumstances." },
            { t: "5. Payments", c: "Payments are processed through authorized third-party gateways. Prices may change without notice. Failed transactions by banks are outside our control." },
            { t: "6. Refunds & Cancellations", c: "Refund eligibility depends on order status and merchant policies. Refunds may take several business days. Misuse may result in denied refund requests." },
            { t: "7. Prohibited Activities", c: "Users must not use the platform fraudulently, abuse offers, upload false information, or interfere with platform security. Violations may result in suspension and legal action." },
            { t: "8. Intellectual Property", c: "All platform content — logos, branding, graphics, designs, text, software — are the intellectual property of Multiverse City and protected under applicable laws." },
            { t: "9. Limitation of Liability", c: "Multiverse City shall not be liable for indirect damages, delivery delays, third-party interruptions, technical downtime, or force majeure events." },
            { t: "10. Governing Law", c: "These Terms are governed by the laws of India. Disputes fall under the jurisdiction of courts in Himachal Pradesh, India." },
            { t: "11. Contact", c: "For support or inquiries: Multiverse City Support Team, Mandi District, Himachal Pradesh, India. Email: support@multiversecity.com" },
          ].map((s, idx) => (
            <section key={idx}>
              <h3 className="text-lg font-bold text-white mb-2">{s.t}</h3>
              <p>{s.c}</p>
            </section>
          ))}
        </div>
      ))
  }

  const openBlog = () => {
    setBlogOpen(true)
  }

  const openAbout = () => {
    openCms("about_us", "About Us", (
      <div className="space-y-6 text-white/60 text-sm leading-relaxed">
        <p>Multiverse City is a multi-service digital platform connecting users with local businesses, products, services, and delivery solutions across Mandi District, including Mandi, Nerchowk, Sundernagar, and surrounding areas.</p>
        <p>We empower local businesses with digital storefronts and give citizens a single super-app for groceries, pharmacy, electronics, fashion, furniture, property, movie tickets, and more.</p>
      </div>
    ))
  }

  const openRefund = () => {
    openCms("refund_policy", "Refund Policy", (
      <div className="space-y-6 text-white/60 text-sm leading-relaxed">
        <p>Refund eligibility depends on the order status and the merchant's policy. Approved refunds are credited back to the original payment method or wallet and may take a few business days to reflect.</p>
      </div>
    ))
  }

  const openCancellation = () => {
    openCms("cancellation_policy", "Cancellation Policy", (
      <div className="space-y-6 text-white/60 text-sm leading-relaxed">
        <p>Orders may be cancelled before they are prepared or dispatched by the merchant. Once cancelled, eligible amounts are refunded as per our refund policy.</p>
      </div>
    ))
  }

  const openDelivery = () => {
    openCms("delivery_policy", "Delivery Policy", (
      <div className="space-y-6 text-white/60 text-sm leading-relaxed">
        <p>Delivery times are approximate and depend on the merchant's location and current load. Live tracking is available in the app for supported orders.</p>
      </div>
    ))
  }

  const openCookie = () => {
    setModalContent({
      title: "Cookie Policy",
      content: (
        <div className="space-y-6 text-white/60 text-sm leading-relaxed">
          <div className="bg-primary/10 p-3 rounded-lg border border-primary/20 text-primary font-bold text-xs">Effective Date: May 2026</div>
          <p>This Cookie Policy explains how Multiverse City uses cookies and similar technologies when you visit our website or use our application.</p>

          {[
            { t: "1. What Are Cookies?", c: "Cookies are small text files stored on your device when you visit a website. They help us recognize your browser, remember your preferences, and improve your overall experience." },
            { t: "2. How We Use Cookies", c: "We use cookies to: Remember your login session and preferences. Analyze website traffic and user behavior using analytics tools. Provide personalized content and recommendations. Ensure security and prevent fraudulent activity. Measure the effectiveness of our marketing campaigns." },
            { t: "3. Types of Cookies We Use", c: "Essential Cookies: Required for the website to function properly (login, cart, security). Performance Cookies: Help us understand how visitors interact with our site (Google Analytics). Functionality Cookies: Remember your preferences like language and region. Marketing Cookies: Used to deliver relevant ads and track campaign performance." },
            { t: "4. Third-Party Cookies", c: "We may allow third-party services such as Google Analytics, Firebase, and advertising partners to place cookies on your device. These parties have their own privacy policies governing how they use cookie data." },
            { t: "5. Managing Cookies", c: "You can control cookies through your browser settings. You may choose to block all cookies, accept all cookies, or receive a notification when a cookie is set. Note: Disabling essential cookies may affect website functionality." },
            { t: "6. Updates to This Policy", c: "We may update this Cookie Policy from time to time. Any changes will be posted on this page with an updated effective date. We encourage you to review this policy periodically." },
            { t: "7. Contact Us", c: "If you have questions about our use of cookies, please contact us at: support@multiversecity.com" },
          ].map((s, idx) => (
            <section key={idx}>
              <h3 className="text-lg font-bold text-white mb-2">{s.t}</h3>
              <p>{s.c}</p>
            </section>
          ))}
        </div>
      ),
    })
  }

  const isPrivacyRoute = window.location.pathname.startsWith("/privacy-policy")
  const isDeleteRoute = window.location.pathname.startsWith("/delete-account")

  return (
    <div className="relative grain">
      <Cursor />
      <Preloader />
      <ScrollProgress />
      <Navbar onShowAlert={showAlert} />
      {isPrivacyRoute ? (
        <PrivacyPolicyPage />
      ) : isDeleteRoute ? (
        <DeleteAccountPage />
      ) : (
        <>
          <Hero onShowAlert={showAlert} onOpenDownload={openDownload} />
          <LaunchBanner />
          <Features />
          <Categories onShowAlert={showAlert} onOpenDownload={openDownload} />
          <Services />
          <WhyMultiverse />
          <HowItWorks />
          <AppShowcase />
          <Statistics />
          <Testimonials />
          <AboutUs />
          <Contact />
        </>
      )}
      <Footer
        onOpenTerms={openTerms}
        onOpenBlog={openBlog}
        onOpenCookie={openCookie}
        onOpenAbout={openAbout}
        onOpenRefund={openRefund}
        onOpenCancellation={openCancellation}
        onOpenDelivery={openDelivery}
      />
      {modalContent && (
        <Modal title={modalContent.title} onClose={() => setModalContent(null)}>
          {modalContent.content}
        </Modal>
      )}
      {cmsPage && (
        <CmsModal
          slug={cmsPage.slug}
          title={cmsPage.title}
          fallback={cmsPage.fallback}
          onClose={() => setCmsPage(null)}
        />
      )}
      {blogOpen && <BlogModal onClose={() => setBlogOpen(false)} />}
      <AlertModal isOpen={alertData.open} onClose={closeAlert} title={alertData.title} message={alertData.message} />
      <DownloadModal isOpen={downloadData.open} onClose={closeDownload} title={downloadData.title} message={downloadData.message} />
    </div>
  )
}

export default App
