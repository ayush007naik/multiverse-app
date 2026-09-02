import React, { useEffect, useState } from "react"
import { getCmsPage } from "../services/cms"
import { renderCmsContent } from "../utils/cmsRender"

const fallbackContent = (
  <div className="space-y-6 text-white/60 text-sm leading-relaxed">
    <div className="bg-primary/10 p-3 rounded-lg border border-primary/20 text-primary font-bold text-xs">Effective Date: May 2026</div>
    <p>Welcome to Multiverse City. Your privacy is important to us. This Privacy Policy explains how we collect, use, store, and protect your information.</p>

    {[
      { t: "1. Information We Collect", c: "Personal Information: Full name, phone, email, delivery address, profile photo, payment info (processed via third-party gateways). Device Information: Device model, OS, app version, IP, crash logs. Location: Real-time GPS with your permission for delivery tracking." },
      { t: "2. How We Use Your Information", c: "To process orders, enable tracking, improve UX, manage wallet/payments, provide support, send notifications, prevent fraud, and improve performance." },
      { t: "3. Payments & Wallet", c: "Payments via Razorpay, UPI, Google Pay, PhonePe, Paytm. We do not store card/banking details. Wallet balances are securely stored with transaction records." },
      { t: "4. Data Sharing", c: "We do not sell personal information. Limited data shared with delivery partners, vendors, payment providers, and legal authorities if required." },
      { t: "5. Data Security", c: "Industry-standard security: encrypted communication, access control, secure cloud storage. No digital platform can guarantee absolute security." },
      { t: "6. Third-Party Services", c: "We use Firebase, Google Maps, Razorpay, and analytics providers. These services have their own privacy policies." },
      { t: "7. Your Rights", c: "You may update your profile, request account deletion, manage permissions, and contact support regarding your data." },
      { t: "8. Contact Us", c: "Questions about this policy? Email: support@multiversecity.com. By using Multiverse City, you agree to this Privacy Policy." },
    ].map((s, idx) => (
      <section key={idx}>
        <h3 className="text-lg font-bold text-white mb-2">{s.t}</h3>
        <p>{s.c}</p>
      </section>
    ))}
  </div>
)

const PrivacyPolicyPage = () => {
  const [page, setPage] = useState(null)
  const [ready, setReady] = useState(false)

  useEffect(() => {
    let active = true
    getCmsPage("privacy_policy").then((p) => {
      if (!active) return
      setPage(p)
      setReady(true)
    })
    return () => {
      active = false
    }
  }, [])

  const hasCms = ready && page && page.published && page.content && page.content.trim()

  return (
    <section className="pt-32 lg:pt-40 pb-20 min-h-screen">
      <div className="container mx-auto px-5 lg:px-12">
        <div className="max-w-3xl mx-auto">
          <h1 className="text-3xl lg:text-4xl font-bold font-space tracking-tight mb-4">Privacy Policy</h1>
          <div className="h-px w-24 bg-primary mb-10" />
          {hasCms ? renderCmsContent(page.content) : fallbackContent}
          <div className="mt-12">
            <a href="/" className="inline-flex items-center gap-2 text-sm font-semibold text-primary hover:underline">
              <span aria-hidden="true">&larr;</span> Back to Home
            </a>
          </div>
        </div>
      </div>
    </section>
  )
}

export default PrivacyPolicyPage
