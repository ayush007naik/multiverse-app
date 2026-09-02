export interface OnboardingData {
  // Basic Info
  fullName: string;
  email: string;
  phone: string;
  password?: string;

  // Business Details
  shopName: string;
  category: string;
  streetAddress: string;
  city: string;
  state: string;
  pincode: string;
  latitude?: number;
  longitude?: number;
  gstNumber?: string;
  deliveryRadius: number;

  // Documents
  aadhaarUrl?: string;
  passportPhotoUrl?: string;
  businessLicenseUrl?: string;

  // Agreement
  agreementSigned: boolean;
  signatureUrl?: string;

  // Status
  otpVerified: boolean;
  currentStep: number;
}

export const CATEGORIES = [
  'Grocery',
  'Pharmacy',
  'Electronics',
  'Beauty',
  'Fashion',
  'Furniture',
  'Baby and Kids',
  'Books',
  'Hardware',
  'Materials',
  'Other',
];
