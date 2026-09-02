"use client";

import { OnboardingData } from "@/types/onboarding";
import { Upload, FileText, UserSquare, CheckCircle2, AlertCircle } from "lucide-react";
import { useState, useRef } from "react";
import { uploadDocument } from "@/lib/storage";

interface Props {
  data: Partial<OnboardingData>;
  updateData: (data: Partial<OnboardingData>) => void;
  onNext: () => void;
  onBack: () => void;
}

export default function DocumentUpload({ data, updateData, onNext, onBack }: Props) {
  const [uploading, setUploading] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [currentType, setCurrentType] = useState<keyof OnboardingData | null>(null);

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !currentType) return;

    setUploading(currentType as string);
    setError(null);

    try {
      const path = `vendors/docs/${Date.now()}_${file.name}`;
      const url = await uploadDocument(file, path);
      updateData({ [currentType]: url });
    } catch (err: any) {
      setError(`Failed to upload: ${err.message}`);
    } finally {
      setUploading(null);
      setCurrentType(null);
    }
  };

  const triggerUpload = (type: keyof OnboardingData) => {
    setCurrentType(type);
    fileInputRef.current?.click();
  };

  const docs = [
    { id: "aadhaarUrl", label: "Aadhaar Card (Front)", icon: <FileText className="w-6 h-6" />, color: "#ff7a1a" },
    { id: "passportPhotoUrl", label: "Passport Photo", icon: <UserSquare className="w-6 h-6" />, color: "#00ffff" },
    { id: "businessLicenseUrl", label: "Business License / GST", icon: <CheckCircle2 className="w-6 h-6" />, color: "#bf00ff" },
  ];

  return (
    <div className="space-y-8">
      {error && (
        <div className="p-3 bg-red-500/10 border border-red-500/50 text-red-500 text-[10px] uppercase font-bold tracking-widest flex items-center gap-2">
          <AlertCircle className="w-3 h-3" /> {error}
        </div>
      )}

      <input
        type="file"
        ref={fileInputRef}
        onChange={handleFileChange}
        className="hidden"
        accept="image/*,application/pdf"
      />

      <div className="grid grid-cols-1 gap-4">
        {docs.map((doc) => (
          <div key={doc.id} className="bg-zinc-900/30 border border-zinc-800 p-6 flex items-center justify-between group hover:border-zinc-700 transition-all">
            <div className="flex items-center gap-4">
              <div
                className="w-12 h-12 flex items-center justify-center border border-zinc-800"
                style={{ color: doc.color, boxShadow: `inset 0 0 10px ${doc.color}20` }}
              >
                {doc.icon}
              </div>
              <div>
                <p className="text-xs uppercase tracking-widest text-zinc-500 font-bold">{doc.label}</p>
                <p className="text-[10px] text-zinc-600 uppercase mt-1">Required for Protocol Verification</p>
              </div>
            </div>

            {data[doc.id as keyof OnboardingData] ? (
              <div className="text-[#00ffff] flex items-center gap-2 text-xs font-bold uppercase tracking-widest">
                <CheckCircle2 className="w-4 h-4" /> Uploaded
              </div>
            ) : (
              <button
                onClick={() => triggerUpload(doc.id as keyof OnboardingData)}
                disabled={uploading !== null}
                className="bg-zinc-800 hover:bg-zinc-700 text-white p-3 transition-colors"
              >
                {uploading === doc.id ? (
                  <div className="w-5 h-5 border-2 border-[#ff7a1a] border-t-transparent animate-spin rounded-full" />
                ) : (
                  <Upload className="w-5 h-5" />
                )}
              </button>
            )}
          </div>
        ))}
      </div>

      <div className="flex gap-4">
        <button
          onClick={onBack}
          className="w-1/3 border border-zinc-800 hover:border-zinc-600 text-zinc-400 font-bold uppercase py-4 tracking-widest transition-all"
        >
          Previous
        </button>
        <button
          onClick={onNext}
          disabled={!data.aadhaarUrl || !data.passportPhotoUrl}
          className="flex-1 bg-[#bf00ff] hover:bg-[#d433ff] text-white font-black uppercase py-4 tracking-widest flex items-center justify-center gap-2 transition-all shadow-[0_0_20px_rgba(191,0,255,0.3)] disabled:opacity-50 disabled:cursor-not-allowed"
        >
          Initialize Agreement
        </button>
      </div>
    </div>
  );
}
