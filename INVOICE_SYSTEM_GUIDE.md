# 📄 Invoice System - Upgrade Guide

## ✅ New Features Implemented

### 1. **Company Logo in PDF Invoice**
- Automatically loads logo from `assets/logo.png`
- Recommended size: 200x200 pixels
- If logo not found, invoice still generates without it

**Setup:**
```
1. Create your company logo (PNG format, 200x200px recommended)
2. Save it as: assets/logo.png
3. Update pubspec.yaml to include assets:

flutter:
  assets:
    - assets/logo.png
```

### 2. **Unique Invoice Number Generation**
- Auto-generated format: `INV-YY/XXXXXX`
- Example: `INV-25/000001`
- Sequential numbering with year prefix
- Stored in Firestore for tracking

### 3. **Email Invoice Functionality**
- Send invoices directly via email
- Opens device email client with pre-filled:
  - Subject line
  - Email body with invoice details
  - PDF attachment option
- Fallback to sharing if email not available

**Usage:**
```dart
await InvoiceGeneratorService.sendInvoiceByEmail(
  orderId,
  'customer@email.com',
);
```

### 4. **Monthly Report System**
- Complete commission & GST breakdown
- Filter by any month/year
- Summary includes:
  - Total Revenue
  - Total Commission (10%)
  - Total GST (18% on commission)
  - Net Amount
  - Invoice count
- Detailed invoice list with all transactions
- Export as PDF

**Access:**
```
Navigate to: /monthly-report
Or use: Navigator.pushNamed(context, '/monthly-report');
```

### 5. **Professional UI**
- Clean, modern dark theme
- Color-coded summary cards
- Responsive layout
- Easy navigation

---

## 📱 New Screens

### Invoice List Screen (`/invoices`)
- View all generated invoices
- Real-time updates from Firestore
- Actions per invoice:
  - **View**: Preview PDF
  - **Share**: Share via any app
  - **Email**: Send to customer email

### Monthly Report Screen (`/monthly-report`)
- Month/Year selector
- Financial summary cards
- Detailed invoice breakdown
- Download as PDF

---

## 🔧 Service Methods

### InvoiceGeneratorService

```dart
// Generate invoice for order
final invoiceData = await InvoiceGeneratorService.generateAndSaveInvoice(orderId);

// Share invoice
await InvoiceGeneratorService.shareInvoice(orderId);

// Email invoice
await InvoiceGeneratorService.sendInvoiceByEmail(orderId, email);

// View invoice
await InvoiceGeneratorService.viewInvoice(orderId);

// Generate monthly report
final report = await InvoiceGeneratorService.generateMonthlyReport(
  year: 2025,
  month: 4,
);

// Generate report PDF
final pdf = await InvoiceGeneratorService.generateMonthlyReportPDF(report);
```

---

## 📊 Firestore Collections

### `invoices` Collection
Each invoice document contains:
```javascript
{
  invoiceNumber: "INV-25/000001",    // Unique invoice number
  orderId: "order123",               // Reference to order
  invoiceId: "auto-generated",       // Firestore document ID
  customerName: "John Doe",
  customerEmail: "john@email.com",
  vendorName: "Shop Name",
  vendorEmail: "shop@email.com",
  totalAmount: 1000.00,
  commission: 100.00,                // 10% of total
  gstOnCommission: 18.00,           // 18% of commission
  netAmount: 882.00,                 // total - commission - gst
  createdAt: Timestamp,
  orderDate: Timestamp,
  items: [...],                      // Order items
  generatedAt: Timestamp,
  generatedBy: "user-uid",
  status: "generated"
}
```

---

## 🎨 Invoice PDF Features

### Header Section
- Company logo (if available)
- Company name: MULTIVERSES MANDI
- Invoice number
- Date of generation

### Company Details
- Company name & address
- GSTIN number
- Contact information

### Bill To Section
- Customer name
- Customer email

### Order Information
- Order ID
- Order date
- Vendor name
- Vendor email

### Items Table
- Item name
- Quantity
- Price per unit
- Total per item

### Amount Breakdown
- Subtotal
- Platform Commission (10%)
- GST on Commission (18%)
- **Net Amount to Vendor** (highlighted)

### Terms & Conditions
- Computer-generated notice
- GST applicability note
- Contact information
- Payment terms

### Footer
- Thank you message
- Company branding

---

## 📈 Monthly Report PDF Features

### Header
- Company name
- Report title
- Month & Year

### Summary Section
- Total Invoices count
- Total Revenue
- Total Commission
- Total GST Collected
- **Net Amount** (highlighted)

### Invoice Details Table
- Invoice number
- Customer name
- Total amount
- Commission
- GST

### Footer
- Report generation date

---

## 🚀 Quick Start

### 1. Add Logo (Optional)
```bash
# Create assets folder
mkdir -p assets

# Add your logo.png file
# Recommended: 200x200 pixels, transparent background
```

### 2. Update pubspec.yaml
```yaml
flutter:
  assets:
    - assets/logo.png
```

### 3. Navigate to Invoices
```dart
Navigator.pushNamed(context, '/invoices');
```

### 4. Access Monthly Reports
```dart
Navigator.pushNamed(context, '/monthly-report');
```

---

## 💡 Tips

1. **Invoice Numbers**: Automatically sequential, no manual input needed
2. **Email**: Customer email is optional but recommended
3. **Reports**: Generate reports for any past month
4. **PDF Export**: Both invoices and reports can be saved/shared as PDF
5. **Real-time**: Invoice list updates automatically with Firestore

---

## 🐛 Troubleshooting

### Logo Not Showing
- Check file path: `assets/logo.png`
- Verify pubspec.yaml includes the asset
- Run: `flutter clean && flutter pub get`

### Email Not Opening
- Ensure email client is configured on device
- Check internet connection
- Fallback sharing will work if email fails

### Monthly Report Empty
- Verify invoices exist for selected month
- Check Firestore timestamps are correct
- Ensure proper date filtering

---

## 📝 Notes

- All calculations are done server-side for accuracy
- GST is only applied on platform commission (not total amount)
- Invoice numbers are permanent once generated
- Reports can be regenerated for any period
- All data is stored in Firestore for audit trail

---

## 🎯 Future Enhancements

Potential additions:
- Bulk email invoices
- Automated monthly report generation
- Export to Excel/CSV
- Payment status tracking
- Multi-currency support
- Custom invoice templates
- Digital signatures

---

**Last Updated**: April 2025
**Version**: 2.0
