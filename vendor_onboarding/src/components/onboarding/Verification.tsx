"use client";

import { OnboardingData } from "@/types/onboarding";
import { useState, useEffect } from "react";
import { ShieldCheck, Smartphone, CheckCircle2, ArrowRight, Loader2 } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import { auth } from "@/lib/firebase";
import { RecaptchaVerifier, signInWithPhoneNumber, ConfirmationResult } from "firebase/auth";

interface Props {
  data: Partial<OnboardingData>;
  onComplete: () => void;
}

export default function Verification({ data, onComplete }: Props) {
  const [otp, setOtp] = useState(["", "", "", "", "", ""]);
  const [verifying, setVerifying] = useState(false);
  const [verified, setVerified] = useState(false);
  const [confirmationResult, setConfirmationResult] = useState<ConfirmationResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!confirmationResult && data.phone) {
      setupRecaptcha();
    }
  }, [data.phone]);

  const setupRecaptcha = () => {
    try {
      if (!(window as any).recaptchaVerifier) {
        (window as any).recaptchaVerifier = new RecaptchaVerifier(auth, 'recaptcha-container', {
          'size': 'invisible',
          'callback': () => {
            console.log("Recaptcha verified");
          }
        });
      }
    } catch (err) {
      console.error("Recaptcha error:", err);
    }
  };

  const sendOtp = async () => {
    if (!data.phone) return;
    setVerifying(true);
    setError(null);
    try {
      const appVerifier = (window as any).recaptchaVerifier;
      const result = await signInWithPhoneNumber(auth, data.phone, appVerifier);
      setConfirmationResult(result);
    } catch (err: any) {
      setError(err.message);
      console.error("SMS Error:", err);
    } finally {
      setVerifying(false);
    }
  };

  const handleVerify = async () => {
    if (!confirmationResult) return;
    setVerifying(true);
    setError(null);
    try {
      const code = otp.join("");
      await confirmationResult.confirm(code);
      setVerified(true);
    } catch (err: any) {
      setError("Invalid Protocol Key");
      console.error("Verification Error:", err);
    } finally {
      setVerifying(false);
    }
  };

  return (
    <div className="flex flex-col items-center justify-center space-y-8 py-4">
      <AnimatePresence mode="wait">
        {!verified ? (
          <motion.div
            key="otp-form"
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 1.1 }}
            className="w-full space-y-8 flex flex-col items-center"
          >
            <div className="w-20 h-20 rounded-full bg-zinc-900 border border-[#00ffff] flex items-center justify-center shadow-[0_0_30px_rgba(0,255,255,0.2)]">
              <Smartphone className="w-10 h-10 text-[#00ffff]" />
            </div>

            <div className="text-center space-y-2">
              <h3 className="text-xl font-bold uppercase tracking-tight text-white">Identity Verification</h3>
              <p className="text-zinc-500 text-xs uppercase tracking-widest">
                {confirmationResult
                  ? `Sent a 6-digit transmission to ${data.phone}`
                  : "Initialize identity transmission protocol"}
              </p>
            </div>

            <div id="recaptcha-container"></div>

            {error && (
              <p className="text-red-500 text-[10px] uppercase font-bold tracking-widest">{error}</p>
            )}

            {confirmationResult ? (
              <>
                <div className="flex gap-3">
                  {otp.map((digit, i) => (
                    <input
                      key={i}
                      id={`otp-${i}`}
                      type="text"
                      maxLength={1}
                      value={digit}
                      onChange={(e) => handleOtpChange(i, e.target.value)}
                      className="w-12 h-16 bg-zinc-900/50 border-2 border-zinc-800 text-center text-2xl font-black text-[#00ffff] focus:border-[#00ffff] focus:outline-none transition-all"
                      autoComplete="off"
                    />
                  ))}
                </div>

                <button
                  onClick={handleVerify}
                  disabled={otp.some(d => !d) || verifying}
                  className="w-full bg-[#00ffff] hover:bg-[#33ffff] text-black font-black uppercase py-4 tracking-widest flex items-center justify-center gap-2 transition-all shadow-[0_0_20px_rgba(0,255,255,0.3)] disabled:opacity-50"
                >
                  {verifying ? (
                    <>
                      <Loader2 className="w-5 h-5 animate-spin" />
                      Syncing Secure Keys
                    </>
                  ) : (
                    "Authorize Protocol"
                  )}
                </button>
              </>
            ) : (
              <button
                onClick={sendOtp}
                disabled={verifying || !data.phone}
                className="w-full bg-[#00ffff] hover:bg-[#33ffff] text-black font-black uppercase py-4 tracking-widest flex items-center justify-center gap-2 transition-all shadow-[0_0_20px_rgba(0,255,255,0.3)] disabled:opacity-50"
              >
                {verifying ? (
                  <>
                    <Loader2 className="w-5 h-5 animate-spin" />
                    Initializing Signal
                  </>
                ) : (
                  "Send Identity Transmission"
                )}
              </button>
            )}

            <button
              onClick={sendOtp}
              className="text-[10px] text-zinc-600 uppercase font-bold tracking-[0.2em] hover:text-zinc-400 transition-colors"
            >
              Request Signal Retransmission
            </button>
          </motion.div>
        ) : (
          <motion.div
            key="success"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="text-center space-y-8 w-full"
          >
            <div className="relative inline-block">
              <div className="w-24 h-24 rounded-full bg-zinc-900 border-2 border-[#ff7a1a] flex items-center justify-center shadow-[0_0_40px_rgba(255,122,26,0.4)]">
                <CheckCircle2 className="w-12 h-12 text-[#ff7a1a]" />
              </div>
              <motion.div
                initial={{ scale: 0 }}
                animate={{ scale: 1 }}
                transition={{ delay: 0.5, type: "spring" }}
                className="absolute -top-2 -right-2 bg-[#00ffff] text-black p-1 rounded-full"
              >
                <ShieldCheck className="w-6 h-6" />
              </motion.div>
            </div>

            <div className="space-y-3">
              <h2 className="text-3xl font-black uppercase tracking-tighter text-white italic">
                PROTOCOL <span className="text-[#ff7a1a]">ACTIVATED</span>
              </h2>
              <p className="text-zinc-500 text-sm uppercase tracking-[0.2em] max-w-xs mx-auto">
                Your vendor identity has been encrypted and added to the Multiverse Core.
              </p>
            </div>

            <div className="bg-zinc-900/50 border border-zinc-800 p-4 rounded-none text-left space-y-2">
              <div className="flex justify-between text-[10px] uppercase font-bold">
                <span className="text-zinc-600">Reference ID</span>
                <span className="text-[#00ffff]">MVC-VX-{Math.random().toString(36).substring(7).toUpperCase()}</span>
              </div>
              <div className="flex justify-between text-[10px] uppercase font-bold">
                <span className="text-zinc-600">Security Status</span>
                <span className="text-green-500">AWAITING ADMIN CLEARANCE</span>
              </div>
            </div>

            <button
              onClick={onComplete}
              className="w-full bg-[#ff7a1a] hover:bg-[#ff8a33] text-black font-black uppercase py-4 tracking-widest flex items-center justify-center gap-2 transition-all group shadow-[0_0_20px_rgba(255,122,26,0.3)]"
            >
              Enter Dashboard
              <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
            </button>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
