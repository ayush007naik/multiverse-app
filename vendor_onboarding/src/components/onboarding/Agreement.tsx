"use client";

import { OnboardingData } from "@/types/onboarding";
import { useRef, useState } from "react";
import SignatureCanvas from "react-signature-canvas";
import { FileText, ShieldAlert, RotateCcw, CheckCircle, Download, Loader2 } from "lucide-react";
import jsPDF from "jspdf";
import html2canvas from "html2canvas";
import { uploadSignature } from "@/lib/storage";

interface Props {
  data: Partial<OnboardingData>;
  updateData: (data: Partial<OnboardingData>) => void;
  onNext: () => void;
  onBack: () => void;
}

export default function Agreement({ data, updateData, onNext, onBack }: Props) {
  const sigCanvas = useRef<SignatureCanvas>(null);
  const agreementRef = useRef<HTMLDivElement>(null);
  const [signed, setSigned] = useState(false);
  const [generating, setGenerating] = useState(false);

  const clear = () => {
    sigCanvas.current?.clear();
    setSigned(false);
    updateData({ signatureUrl: undefined, agreementSigned: false });
  };

  const handleSign = async () => {
    if (sigCanvas.current?.isEmpty()) return;
    setGenerating(true);
    try {
      const base64 = sigCanvas.current?.getTrimmedCanvas().toDataURL("image/png");
      const url = await uploadSignature(base64, `sig_${data.id || Date.now()}`);
      updateData({ signatureUrl: url, agreementSigned: true });
      setSigned(true);
    } catch (error) {
      console.error("Signature upload failed:", error);
    } finally {
      setGenerating(false);
    }
  };

  const downloadPDF = async () => {
    if (!agreementRef.current || !signed) return;
    setGenerating(true);
    try {
      const canvas = await html2canvas(agreementRef.current, {
        backgroundColor: "#050505",
        scale: 2,
      });
      const imgData = canvas.toDataURL("image/png");
      const pdf = new jsPDF("p", "mm", "a4");
      const imgProps = pdf.getImageProperties(imgData);
      const pdfWidth = pdf.internal.pageSize.getWidth();
      const pdfHeight = (imgProps.height * pdfWidth) / imgProps.width;

      pdf.addImage(imgData, "PNG", 0, 0, pdfWidth, pdfHeight);

      // Add Signature
      if (data.signatureUrl) {
        pdf.addPage();
        pdf.setTextColor(255, 122, 26);
        pdf.text("DIGITAL SIGNATURE VERIFIED", 20, 20);
        pdf.addImage(data.signatureUrl, "PNG", 20, 40, 50, 25);
        pdf.setTextColor(100, 100, 100);
        pdf.text(`Signed by: ${data.fullName || "Vendor"}`, 20, 75);
        pdf.text(`Date: ${new Date().toLocaleDateString()}`, 20, 85);
        pdf.text(`Email: ${data.email}`, 20, 95);
      }

      pdf.save(`Multiverse_Agreement_${data.fullName?.replace(/\s+/g, '_')}.pdf`);
    } catch (error) {
      console.error("PDF Generation Error:", error);
    } finally {
      setGenerating(false);
    }
  };

  return (
    <div className="space-y-6">
      <div ref={agreementRef} className="bg-zinc-900/50 border border-zinc-800 p-6 h-64 overflow-y-auto text-xs text-zinc-400 leading-relaxed space-y-4">
        <h3 className="text-[#00ffff] font-bold uppercase tracking-widest text-sm">Terms of Protocol Engagement</h3>
        <p>1. VENDOR AUTHENTICATION: The vendor agrees to provide valid identity parameters for protocol verification.</p>
        <p>2. MARKETPLACE CONDUCT: All transactions must adhere to the Multiverse City Security Guidelines. Any breach of protocol will result in immediate node deactivation.</p>
        <p>3. DATA ENCRYPTION: User data must be handled with end-to-end cryptographic standards as defined in the technical specification.</p>
        <p>4. REVENUE SHARING: A protocol fee of 5% will be automatically deducted from each transaction to maintain the Multiverse infrastructure.</p>
        <p>5. TERMINATION: Either party may terminate the connection with 24-hour notice, provided all pending packets are delivered.</p>
      </div>

      <div className="space-y-4">
        <label className="text-xs uppercase tracking-widest text-zinc-500 font-bold flex items-center gap-2">
          <ShieldAlert className="w-3 h-3 text-[#bf00ff]" /> Digital Signature
        </label>
        <div className="border border-dashed border-zinc-800 bg-black relative">
          <SignatureCanvas
            ref={sigCanvas}
            penColor="#00ffff"
            canvasProps={{
              className: "w-full h-40",
            }}
            onEnd={handleSign}
          />
          {!signed && (
            <div className="absolute inset-0 flex items-center justify-center pointer-events-none text-zinc-800 uppercase text-[10px] tracking-[0.4em] font-black">
              Sign Within Protocol Bounds
            </div>
          )}
        </div>
        <div className="flex justify-between items-center">
          <div className="flex gap-4">
            <button
              onClick={clear}
              className="text-zinc-500 hover:text-white flex items-center gap-2 text-[10px] uppercase font-bold tracking-widest transition-colors"
            >
              <RotateCcw className="w-3 h-3" /> Clear Buffer
            </button>
            {signed && (
              <button
                onClick={downloadPDF}
                disabled={generating}
                className="text-[#00ffff] hover:text-[#33ffff] flex items-center gap-2 text-[10px] uppercase font-bold tracking-widest transition-colors"
              >
                {generating ? <Loader2 className="w-3 h-3 animate-spin" /> : <Download className="w-3 h-3" />}
                Download Signed Protocol
              </button>
            )}
          </div>
          {signed && (
            <div className="text-[#00ffff] flex items-center gap-2 text-[10px] uppercase font-bold tracking-widest">
              <CheckCircle className="w-3 h-3" /> Signature Encrypted
            </div>
          )}
        </div>
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
          disabled={!signed}
          className="flex-1 bg-[#ff7a1a] hover:bg-[#ff8a33] text-black font-black uppercase py-4 tracking-widest flex items-center justify-center gap-2 transition-all shadow-[0_0_20px_rgba(255,122,26,0.3)] disabled:opacity-50"
        >
          Finalize Protocol
        </button>
      </div>
    </div>
  );
}
