"use client";

import { OnboardingData } from "@/types/onboarding";
import { User, Mail, Phone, Lock, Loader2 } from "lucide-react";
import { useState } from "react";
import { auth, db } from "@/lib/firebase";
import { createUserWithEmailAndPassword, updateProfile } from "firebase/auth";
import { doc, setDoc } from "firebase/firestore";

interface Props {
  data: Partial<OnboardingData>;
  updateData: (data: Partial<OnboardingData>) => void;
  onNext: () => void;
}

export default function BasicInfo({ data, updateData, onNext }: Props) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!data.email || !data.password || !data.fullName) return;

    setLoading(true);
    setError(null);

    try {
      // 1. Create Firebase Auth user
      const userCredential = await createUserWithEmailAndPassword(auth, data.email, data.password);
      const user = userCredential.user;

      // 2. Update profile with name
      await updateProfile(user, { displayName: data.fullName });

      // 3. Create vendor document in Firestore
      await setDoc(doc(db, "vendors", user.uid), {
        id: user.uid,
        fullName: data.fullName,
        email: data.email,
        phone: data.phone,
        currentStep: 2,
        updated_at: new Date().toISOString()
      }, { merge: true });

      onNext();
    } catch (err: any) {
      console.error("Auth Error:", err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {error && (
        <div className="p-3 bg-red-500/10 border border-red-500/50 text-red-500 text-[10px] uppercase font-bold tracking-widest">
          {error}
        </div>
      )}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="space-y-2">
          <label className="text-xs uppercase tracking-widest text-zinc-500 font-bold flex items-center gap-2">
            <User className="w-3 h-3 text-[#ff7a1a]" /> Full Name
          </label>
          <input
            required
            type="text"
            value={data.fullName || ""}
            onChange={(e) => updateData({ fullName: e.target.value })}
            className="w-full bg-zinc-900/50 border border-zinc-800 p-4 focus:outline-none focus:border-[#ff7a1a] transition-colors text-white"
            placeholder="ENTER LEGAL NAME"
          />
        </div>
        <div className="space-y-2">
          <label className="text-xs uppercase tracking-widest text-zinc-500 font-bold flex items-center gap-2">
            <Mail className="w-3 h-3 text-[#ff7a1a]" /> Access Email
          </label>
          <input
            required
            type="email"
            value={data.email || ""}
            onChange={(e) => updateData({ email: e.target.value })}
            className="w-full bg-zinc-900/50 border border-zinc-800 p-4 focus:outline-none focus:border-[#ff7a1a] transition-colors text-white"
            placeholder="PROTOCOL@DOMAIN.COM"
          />
        </div>
        <div className="space-y-2">
          <label className="text-xs uppercase tracking-widest text-zinc-500 font-bold flex items-center gap-2">
            <Phone className="w-3 h-3 text-[#ff7a1a]" /> Primary Phone
          </label>
          <input
            required
            type="tel"
            value={data.phone || ""}
            onChange={(e) => updateData({ phone: e.target.value })}
            className="w-full bg-zinc-900/50 border border-zinc-800 p-4 focus:outline-none focus:border-[#ff7a1a] transition-colors text-white"
            placeholder="+91 XXXXX XXXXX"
          />
        </div>
        <div className="space-y-2">
          <label className="text-xs uppercase tracking-widest text-zinc-500 font-bold flex items-center gap-2">
            <Lock className="w-3 h-3 text-[#ff7a1a]" /> Secure Password
          </label>
          <input
            required
            type="password"
            value={data.password || ""}
            onChange={(e) => updateData({ password: e.target.value })}
            className="w-full bg-zinc-900/50 border border-zinc-800 p-4 focus:outline-none focus:border-[#ff7a1a] transition-colors text-white"
            placeholder="••••••••"
          />
        </div>
      </div>

      <button
        type="submit"
        disabled={loading}
        className="mt-8 w-full bg-[#ff7a1a] hover:bg-[#ff8a33] text-black font-black uppercase py-4 tracking-widest flex items-center justify-center gap-2 transition-all group shadow-[0_0_20px_rgba(255,122,26,0.3)] disabled:opacity-50"
      >
        {loading ? (
          <>
            <Loader2 className="w-5 h-5 animate-spin" />
            SYNCHRONIZING...
          </>
        ) : (
          "Initialize Next Phase"
        )}
      </button>
    </form>
  );
}
