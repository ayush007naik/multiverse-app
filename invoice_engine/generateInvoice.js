/**
 * ═══════════════════════════════════════════════════════════════
 *  MULTIVERSE — Invoice PDF Generator
 *  Uses: Node.js + Puppeteer
 *
 *  Usage:
 *    node generateInvoice.js
 *    node generateInvoice.js --data='{"invoice":{"number":"INV-2024-0099"},...}'
 *    node generateInvoice.js --out=./invoices/
 *
 *  Install:
 *    npm install puppeteer
 * ═══════════════════════════════════════════════════════════════
 */

'use strict';

const puppeteer = require('puppeteer');
const path      = require('path');
const fs        = require('fs');

// ─────────────────────────────────────────────────────────────
//  SAMPLE INVOICE DATA  (override via --data='...' CLI arg)
// ─────────────────────────────────────────────────────────────

const DEFAULT_INVOICE_DATA = {
  invoice: {
    number:        "INV-2024-00042",
    orderId:       "ORD-8842991",
    dateTime:      "12 Jan '25, 7:42 PM",
    paymentMethod: "UPI / GPay",
    paymentStatus: "PAID",          // "PAID" | "COD" | "PENDING"
  },
  customer: {
    name:    "Arjun Mehta",
    phone:   "+91 98765 43210",
    address: "Flat 4B, Rosewood Apartments,<br>Koramangala, Bengaluru — 560034",
  },
  store: {
    name:    "Multiverse Dark Store #12",
    gstin:   "29AABCU9603R1ZX",
    phone:   "Support: 1800-XXX-XXXX",
    address: "Plot 7, Sector 4, Industrial Area,<br>HSR Layout, Bengaluru — 560102",
  },
  items: [
    { emoji: "🥤", name: "Tropicana Orange Juice",  desc: "1L Pack",          qty: 2, unitPrice: 99  },
    { emoji: "🍫", name: "Dairy Milk Silk",          desc: "145g — Oreo",      qty: 3, unitPrice: 75  },
    { emoji: "🌾", name: "Aashirvaad Atta",          desc: "5kg — Select",     qty: 1, unitPrice: 285 },
    { emoji: "🧴", name: "Dove Body Lotion",         desc: "400ml — Intensive",qty: 1, unitPrice: 199 },
  ],
  billing: {
    deliveryFee:     29,
    platformFee:     5,
    taxRate:         0.05,
    couponCode:      "NEWUSER50",
    couponDiscount:  50,
  },
  rider: {
    name:    "Ravi Kumar",
    rating:  "4.8",
    vehicle: "KA 05 AB 1234",
    phone:   "+919876543211",
  },
  orderStatus: "out_for_delivery",
};

// ─────────────────────────────────────────────────────────────
//  PARSE CLI ARGUMENTS
// ─────────────────────────────────────────────────────────────

function parseArgs() {
  const args = process.argv.slice(2);
  const result = { data: null, out: './', open: false };

  for (const arg of args) {
    if (arg.startsWith('--data=')) {
      try { result.data = JSON.parse(arg.slice(7)); }
      catch (e) { console.error('⚠️  Invalid --data JSON:', e.message); }
    } else if (arg.startsWith('--out=')) {
      result.out = arg.slice(6);
    } else if (arg === '--open') {
      result.open = true;
    }
  }

  return result;
}

// ─────────────────────────────────────────────────────────────
//  BUILD INVOICE FILENAME
// ─────────────────────────────────────────────────────────────

function buildFilename(invoiceData) {
  const invNum   = invoiceData.invoice.number.replace(/[^a-zA-Z0-9-]/g, '-');
  const customer = invoiceData.customer.name.replace(/\s+/g, '-').toLowerCase();
  const now      = new Date();
  const ts       = `${now.getFullYear()}${String(now.getMonth()+1).padStart(2,'0')}${String(now.getDate()).padStart(2,'0')}`;
  return `multiverse-invoice-${invNum}-${customer}-${ts}.pdf`;
}

// ─────────────────────────────────────────────────────────────
//  GENERATE PDF — MAIN FUNCTION
// ─────────────────────────────────────────────────────────────

async function generateInvoicePDF(invoiceData = DEFAULT_INVOICE_DATA, options = {}) {
  const {
    outputDir  = './',
    filename   = buildFilename(invoiceData),
    htmlPath   = path.join(__dirname, 'invoice.html'),
    openAfter  = false,
  } = options;

  // Ensure output directory exists
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  const outputPath = path.join(outputDir, filename);
  const fileUrl    = `file://${path.resolve(htmlPath)}`;

  console.log('\n🌌 Multiverse Invoice Generator');
  console.log('─'.repeat(44));
  console.log(`📄  Invoice   : #${invoiceData.invoice.number}`);
  console.log(`👤  Customer  : ${invoiceData.customer.name}`);
  console.log(`💰  Status    : ${invoiceData.invoice.paymentStatus}`);
  console.log(`📁  Output    : ${outputPath}`);
  console.log('─'.repeat(44));

  // ── Launch Puppeteer ──────────────────────
  const browser = await puppeteer.launch({
    headless: 'new',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--font-render-hinting=none',
    ],
  });

  try {
    const page = await browser.newPage();

    // High-DPI viewport for crisp rendering
    await page.setViewport({ width: 1200, height: 1754, deviceScaleFactor: 2 });

    // ── Load the HTML invoice ──
    console.log('⏳  Loading invoice template…');
    await page.goto(fileUrl, {
      waitUntil: 'networkidle0',
      timeout: 30_000,
    });

    // ── Inject custom invoice data ──
    console.log('💉  Injecting invoice data…');
    await page.evaluate((data) => {
      window.INVOICE_DATA = data;
      if (typeof window.renderInvoice === 'function') {
        window.renderInvoice(data);
      }
    }, invoiceData);

    // Wait for QR code canvas to render
    await page.waitForTimeout(800);

    // Wait for Google Fonts to load
    await page.evaluate(() =>
      document.fonts.ready
    );

    // ── Hide action buttons for PDF ──
    await page.evaluate(() => {
      const el = document.querySelector('.invoice-actions');
      if (el) el.style.display = 'none';
    });

    // ── Capture full page height ──
    const bodyHeight = await page.evaluate(() => {
      const body = document.body;
      const html = document.documentElement;
      return Math.max(
        body.scrollHeight, body.offsetHeight,
        html.clientHeight, html.scrollHeight, html.offsetHeight
      );
    });

    console.log(`📐  Page height: ${bodyHeight}px`);

    // ── Generate PDF ──
    console.log('🖨️   Rendering PDF…');
    await page.pdf({
      path: outputPath,
      format: 'A4',
      printBackground: true,
      scale: 1,
      preferCSSPageSize: false,
      displayHeaderFooter: false,
      margin: {
        top:    '0mm',
        right:  '0mm',
        bottom: '0mm',
        left:   '0mm',
      },
    });

    const stats   = fs.statSync(outputPath);
    const sizeKB  = (stats.size / 1024).toFixed(1);

    console.log(`✅  PDF generated! (${sizeKB} KB)`);
    console.log(`📂  Saved to: ${outputPath}`);

    // ── Optional: open after generation ──
    if (openAfter) {
      const openCmd = process.platform === 'darwin' ? 'open'
                    : process.platform === 'win32'  ? 'start'
                    : 'xdg-open';
      require('child_process').exec(`${openCmd} "${outputPath}"`);
    }

    return { success: true, path: outputPath, size: sizeKB };

  } catch (err) {
    console.error('❌  Error generating PDF:', err.message);
    throw err;
  } finally {
    await browser.close();
  }
}

// ─────────────────────────────────────────────────────────────
//  BATCH GENERATION
//  Pass an array of invoice data objects to generate multiple
// ─────────────────────────────────────────────────────────────

async function generateBatch(invoicesArray, outputDir = './invoices') {
  console.log(`\n📦 Batch mode: generating ${invoicesArray.length} invoices…\n`);
  const results = [];

  for (let i = 0; i < invoicesArray.length; i++) {
    const data = invoicesArray[i];
    console.log(`[${i + 1}/${invoicesArray.length}] Processing ${data.invoice.number}…`);
    try {
      const result = await generateInvoicePDF(data, { outputDir });
      results.push({ ...result, invoice: data.invoice.number });
    } catch (err) {
      results.push({ success: false, invoice: data.invoice.number, error: err.message });
    }
  }

  console.log('\n📊 Batch Summary:');
  results.forEach(r => {
    const icon = r.success ? '✅' : '❌';
    console.log(`  ${icon}  ${r.invoice}${r.success ? ` → ${r.path}` : ` → ${r.error}`}`);
  });

  return results;
}

// ─────────────────────────────────────────────────────────────
//  CLI ENTRY POINT
// ─────────────────────────────────────────────────────────────

if (require.main === module) {
  const args = parseArgs();

  const invoiceData = args.data
    ? { ...DEFAULT_INVOICE_DATA, ...args.data }
    : DEFAULT_INVOICE_DATA;

  generateInvoicePDF(invoiceData, {
    outputDir: args.out,
    openAfter: args.open,
  })
  .then(result => {
    console.log('\n🎉  Done!');
    process.exit(0);
  })
  .catch(err => {
    console.error('\n💥  Fatal error:', err);
    process.exit(1);
  });
}

// ─────────────────────────────────────────────────────────────
//  EXPORTS (for programmatic use)
// ─────────────────────────────────────────────────────────────

module.exports = {
  generateInvoicePDF,
  generateBatch,
  DEFAULT_INVOICE_DATA,
  buildFilename,
};

/*
 * ═══════════════════════════════════════════════════════════════
 *  USAGE EXAMPLES
 * ═══════════════════════════════════════════════════════════════
 *
 *  ── CLI ────────────────────────────────────────────────────────
 *
 *  # Generate with default sample data
 *  node generateInvoice.js
 *
 *  # Generate with custom data JSON
 *  node generateInvoice.js --data='{"invoice":{"number":"INV-99","paymentStatus":"COD"}}'
 *
 *  # Save to specific folder & auto-open
 *  node generateInvoice.js --out=./invoices/ --open
 *
 *
 *  ── Programmatic ────────────────────────────────────────────────
 *
 *  const { generateInvoicePDF } = require('./generateInvoice');
 *
 *  await generateInvoicePDF({
 *    invoice: { number: "INV-2024-99", paymentStatus: "PAID", ... },
 *    customer: { name: "Priya Singh", ... },
 *    items: [{ emoji:"🍕", name:"Pizza", qty:2, unitPrice:299 }],
 *    ...
 *  }, { outputDir: './invoices', openAfter: true });
 *
 *
 *  ── Batch ────────────────────────────────────────────────────────
 *
 *  const { generateBatch } = require('./generateInvoice');
 *
 *  await generateBatch([
 *    { invoice: { number: "INV-001", ... }, ... },
 *    { invoice: { number: "INV-002", ... }, ... },
 *  ], './invoices');
 *
 * ═══════════════════════════════════════════════════════════════
 */
