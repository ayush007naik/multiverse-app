import { ref, uploadBytes, getDownloadURL } from "firebase/storage";
import { storage } from "./firebase";

export const uploadDocument = async (file: File, path: string) => {
  const storageRef = ref(storage, `vendor-documents/${path}`);
  const snapshot = await uploadBytes(storageRef, file);
  const publicUrl = await getDownloadURL(snapshot.ref);
  return publicUrl;
};

export const uploadSignature = async (base64Data: string, fileName: string) => {
  // Convert base64 to Blob
  const base64 = base64Data.split(',')[1];
  const blob = await fetch(`data:image/png;base64,${base64}`).then(res => res.blob());

  const storageRef = ref(storage, `vendor-signatures/${fileName}.png`);
  const snapshot = await uploadBytes(storageRef, blob);
  const publicUrl = await getDownloadURL(snapshot.ref);
  return publicUrl;
};
