"use client";

import { OnboardingData, CATEGORIES } from "@/types/onboarding";
import { Store, MapPin, Navigation, Map } from "lucide-react";

interface Props {
  data: Partial<OnboardingData>;
  updateData: (data: Partial<OnboardingData>) => void;
  onNext: () => void;
  onBack: () => void;
}

export default function BusinessDetails({ data, updateData, onNext, onBack }: Props) {
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onNext();
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <div className="space-y-4">
        <div className="space-y-2">
          <label className="text-xs uppercase tracking-widest text-zinc-500 font-bold flex items-center gap-2">
            <Store className="w-3 h-3 text-[#00ffff]" /> Shop Name
          </label>
          <input
            required
            type="text"
            value={data.shopName || ""}
            onChange={(e) => updateData({ shopName: e.target.value })}
            className="w-full bg-zinc-900/50 border border-zinc-800 p-4 focus:outline-none focus:border-[#00ffff] transition-colors text-white"
            placeholder="ENTER SHOP IDENTITY"
          />
        </div>

        <div className="space-y-2">
          <label className="text-xs uppercase tracking-widest text-zinc-500 font-bold flex items-center gap-2">
            <Store className="w-3 h-3 text-[#00ffff]" /> Category
          </label>
          <select
            required
            value={data.category || ""}
            onChange={(e) => updateData({ category: e.target.value })}
            className="w-full bg-zinc-900/50 border border-zinc-800 p-4 focus:outline-none focus:border-[#00ffff] transition-colors text-white appearance-none"
          >
            <option value="" disabled>SELECT SECTOR</option>
            {CATEGORIES.map((cat) => (
              <option key={cat} value={cat}>{cat.toUpperCase()}</option>
            ))}
          </select>
        </div>

        <div className="space-y-2">
          <label className="text-xs uppercase tracking-widest text-zinc-500 font-bold flex items-center gap-2">
            <MapPin className="w-3 h-3 text-[#00ffff]" /> Street Address
          </label>
          <textarea
            required
            value={data.streetAddress || ""}
            onChange={(e) => updateData({ streetAddress: e.target.value })}
            className="w-full bg-zinc-900/50 border border-zinc-800 p-4 focus:outline-none focus:border-[#00ffff] transition-colors text-white h-24"
            placeholder="LOCATION PARAMETERS"
          />
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div className="space-y-2">
            <label className="text-xs uppercase tracking-widest text-zinc-500 font-bold flex items-center gap-2">
              <Navigation className="w-3 h-3 text-[#00ffff]" /> City
            </label>
            <input
              required
              type="text"
              value={data.city || ""}
              onChange={(e) => updateData({ city: e.target.value })}
              className="w-full bg-zinc-900/50 border border-zinc-800 p-4 focus:outline-none focus:border-[#00ffff] transition-colors text-white"
              placeholder="NODE CITY"
            />
          </div>
          <div className="space-y-2">
            <label className="text-xs uppercase tracking-widest text-zinc-500 font-bold flex items-center gap-2">
              <Map className="w-3 h-3 text-[#00ffff]" /> Pincode
            </label>
            <input
              required
              type="text"
              value={data.pincode || ""}
              onChange={(e) => updateData({ pincode: e.target.value })}
              className="w-full bg-zinc-900/50 border border-zinc-800 p-4 focus:outline-none focus:border-[#00ffff] transition-colors text-white"
              placeholder="ZONE CODE"
            />
          </div>
        </div>
      </div>

      <div className="flex gap-4">
        <button
          type="button"
          onClick={onBack}
          className="w-1/3 border border-zinc-800 hover:border-zinc-600 text-zinc-400 font-bold uppercase py-4 tracking-widest transition-all"
        >
          Previous
        </button>
        <button
          type="submit"
          className="flex-1 bg-[#00ffff] hover:bg-[#33ffff] text-black font-black uppercase py-4 tracking-widest flex items-center justify-center gap-2 transition-all shadow-[0_0_20px_rgba(0,255,255,0.3)]"
        >
          Next Sector
        </button>
      </div>
    </form>
  );
}
