import React, { useState } from "react"
import { submitDeleteRequest } from "../services/deleteRequest"

const inputClass =
  "w-full bg-white/[0.03] border border-white/10 rounded-xl px-4 py-3.5 text-sm text-white placeholder-white/30 outline-none focus:border-primary/60 focus:bg-white/[0.05] transition-colors"

const DeleteAccountPage = () => {
  const [phone, setPhone] = useState("")
  const [email, setEmail] = useState("")
  const [reason, setReason] = useState("")
  const [status, setStatus] = useState("idle")
  const [error, setError] = useState("")

  const isSubmitting = status === "submitting"

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError("")

    const phoneOk = phone.trim().length >= 4
    const emailOk = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())
    if (!phoneOk && !emailOk) {
      setError("Please provide a phone number or an email address for the account.")
      setStatus("error")
      return
    }

    setStatus("submitting")
    try {
      await submitDeleteRequest({
        phone: phone.trim(),
        email: email.trim(),
        reason: reason.trim(),
      })
      setStatus("success")
    } catch (err) {
      setError("We could not submit your request right now. Please try again in a few minutes.")
      setStatus("error")
      console.error("Delete account submit error:", err)
    }
  }

  return (
    <section className="pt-32 lg:pt-40 pb-20 min-h-screen">
      <div className="container mx-auto px-5 lg:px-12">
        <div className="max-w-3xl mx-auto">
          <h1
            className="text-3xl lg:text-4xl font-bold font-space tracking-tight mb-4"
            style={{
              background: "linear-gradient(90deg, #FF6A00, #8B5CF6)",
              WebkitBackgroundClip: "text",
              WebkitTextFillColor: "transparent",
              backgroundClip: "text",
            }}
          >
            Multiverse City Account & Data Deletion
          </h1>
          <div className="h-px w-24 bg-primary mb-8" />

          <p className="text-white/60 text-sm leading-relaxed mb-8">
            If you would like to delete your Multiverse City account and the associated profile data,
            submit a request below. We will review it and take action according to the applicable
            retention requirements.
          </p>

          {status === "success" ? (
            <div className="glass-card p-8 text-center">
              <div className="mx-auto mb-4 h-16 w-16 rounded-full bg-primary/15 border border-primary/30 flex items-center justify-center">
                <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#FF6A00" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M20 6 9 17l-5-5" />
                </svg>
              </div>
              <h2 className="text-xl font-bold text-white mb-2">Request Submitted</h2>
              <p className="text-white/60 text-sm leading-relaxed max-w-md mx-auto">
                Your account deletion request has been received. Your account and profile data will be
                deleted according to the applicable retention requirements. We will contact you if
                additional verification is required.
              </p>
              <a href="/" className="inline-block mt-6 text-sm font-semibold text-primary hover:underline">
                &larr; Back to Home
              </a>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="glass-card p-6 lg:p-8" noValidate>
              <div className="space-y-5">
                <div>
                  <label htmlFor="delete-phone" className="block text-sm font-semibold text-white mb-2">
                    Phone Number <span className="text-white/40 font-normal">(used for the account)</span>
                  </label>
                  <input
                    id="delete-phone"
                    type="tel"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    placeholder="e.g. +91 98765 43210"
                    className={inputClass}
                    autoComplete="tel"
                  />
                </div>

                <div>
                  <label htmlFor="delete-email" className="block text-sm font-semibold text-white mb-2">
                    Email <span className="text-white/40 font-normal">(used for the account)</span>
                  </label>
                  <input
                    id="delete-email"
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="e.g. you@example.com"
                    className={inputClass}
                    autoComplete="email"
                  />
                </div>

                <div>
                  <label htmlFor="delete-reason" className="block text-sm font-semibold text-white mb-2">
                    Reason for Deletion <span className="text-white/40 font-normal">(optional)</span>
                  </label>
                  <textarea
                    id="delete-reason"
                    value={reason}
                    onChange={(e) => setReason(e.target.value)}
                    placeholder="Tell us why you are leaving, so we can improve."
                    rows={4}
                    maxLength={1000}
                    className={`${inputClass} resize-none`}
                  />
                </div>

                <p className="text-xs text-white/40 leading-relaxed">
                  Please provide the phone number <span className="text-white/60">or</span> email used to
                  create your account. We will contact you if additional verification is required.
                </p>

                {status === "error" && error && (
                  <div className="rounded-xl border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-300">
                    {error}
                  </div>
                )}

                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="btn-primary w-full disabled:opacity-50 disabled:hover:scale-100 disabled:cursor-not-allowed"
                >
                  {isSubmitting ? "Submitting…" : "Submit Delete Account Request"}
                </button>
              </div>
            </form>
          )}

          <div className="mt-10 glass-card p-6 lg:p-8">
            <h2 className="text-lg font-bold text-white mb-4">What happens next?</h2>
            <ul className="space-y-3 text-sm text-white/60 leading-relaxed">
              <li className="flex gap-3">
                <span className="text-primary font-bold">•</span>
                <span>
                  Your account and profile data will be deleted according to the applicable retention
                  requirements.
                </span>
              </li>
              <li className="flex gap-3">
                <span className="text-primary font-bold">•</span>
                <span>
                  Some information may be retained where legally required, such as transaction, payment,
                  tax, fraud-prevention, or accounting records.
                </span>
              </li>
              <li className="flex gap-3">
                <span className="text-primary font-bold">•</span>
                <span>
                  You will be contacted if additional verification is required before we process the
                  deletion.
                </span>
              </li>
            </ul>
          </div>

          <div className="mt-8">
            <a href="/" className="inline-flex items-center gap-2 text-sm font-semibold text-primary hover:underline">
              <span aria-hidden="true">&larr;</span> Back to Home
            </a>
          </div>
        </div>
      </div>
    </section>
  )
}

export default DeleteAccountPage
