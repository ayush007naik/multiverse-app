import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:xml/xml.dart';

import 'global_catalog_service.dart';
import 'vendor_product_service.dart';
import 'product_image_search_service.dart';

class ExcelParseException implements Exception {
  final String message;
  const ExcelParseException(this.message);
  @override
  String toString() => message;
}

enum _FileKind { csv, xlsx, legacyXls }

/// Canonical field keys used by the flexible column mapper.
class ImportField {
  static const productName = 'productName';
  static const subcategory = 'subcategory';
  static const category = 'category';
  static const brand = 'brand';
  static const variant = 'variant';
  static const unit = 'unit';
  static const sku = 'sku';
  static const barcode = 'barcode';
  static const description = 'description';
  static const stock = 'stock';
  static const gst = 'gst';
  static const price = 'price';
  static const sellingPrice = 'sellingPrice';
  static const imageUrl = 'imageUrl';

  /// Human labels for the mapping summary shown after an upload.
  static const Map<String, String> labels = {
    productName: 'Product Name',
    brand: 'Brand',
    category: 'Category',
    subcategory: 'Subcategory',
    variant: 'Variant',
    unit: 'Unit',
    sku: 'SKU',
    barcode: 'Barcode',
    price: 'MRP',
    sellingPrice: 'Selling Price',
    imageUrl: 'Image URL',
    stock: 'Stock',
    gst: 'GST',
    description: 'Description',
  };
}

/// Maps the columns of an uploaded sheet to canonical product fields.
///
/// A sheet can use any column order, any header spelling and may contain extra
/// columns that are simply ignored. When no header row can be recognised the
/// map falls back to the template's positional order so header-less exports
/// still import.
class ColumnMap {
  /// field key -> column index
  final Map<String, int> _index;

  /// The header cells the mapping was built from (empty in positional mode).
  final List<String> headers;

  /// True when the mapping came from a recognised header row.
  final bool detected;

  /// 1-based number of the first data row inside the file (for error messages).
  final int firstDataRowNumber;

  const ColumnMap({
    required Map<String, int> index,
    required this.headers,
    required this.detected,
    required this.firstDataRowNumber,
  }) : _index = index;

  /// Template column order, used when no header row is recognised.
  factory ColumnMap.positional(
    List<String> headers, {
    required int firstDataRowNumber,
  }) {
    final index = <String, int>{};
    for (
      var i = 0;
      i < headers.length && i < ExcelImportService.sampleHeaders.length;
      i++
    ) {
      index[ExcelImportService.sampleHeaders[i]] = i;
    }
    return ColumnMap(
      index: index,
      headers: const [],
      detected: false,
      firstDataRowNumber: firstDataRowNumber,
    );
  }

  bool has(String field) => _index.containsKey(field);

  int? indexOf(String field) => _index[field];

  /// Reads (and trims) a field out of a raw row. Missing columns read as ''.
  String cell(List<String> cells, String field) {
    final i = _index[field];
    if (i == null || i < 0 || i >= cells.length) return '';
    return cells[i].trim();
  }

  /// Number of recognised fields — used to score header-row candidates.
  int get matchedCount => _index.length;

  Map<String, int> get mapping => Map<String, int>.unmodifiable(_index);

  /// "Product Name → 'Item Name', MRP → 'Rate'" style summary.
  List<String> describe() {
    final parts = <String>[];
    const order = [
      ImportField.productName,
      ImportField.brand,
      ImportField.category,
      ImportField.subcategory,
      ImportField.variant,
      ImportField.unit,
      ImportField.price,
      ImportField.sellingPrice,
      ImportField.stock,
      ImportField.gst,
      ImportField.sku,
      ImportField.barcode,
      ImportField.description,
    ];
    for (final field in order) {
      final i = _index[field];
      if (i == null) continue;
      final header = (i < headers.length ? headers[i] : '').trim();
      parts.add(
        header.isEmpty ||
                header.toLowerCase() == ImportField.labels[field]!.toLowerCase()
            ? ImportField.labels[field]!
            : '${ImportField.labels[field]} → "$header"',
      );
    }
    return parts;
  }
}

/// A parsed sheet: data rows plus the column mapping to read them with.
class ParsedSheet {
  final List<List<String>> rows;
  final ColumnMap columns;
  const ParsedSheet({required this.rows, required this.columns});

  bool get isEmpty => rows.isEmpty;
}

/// One parsed, validated row from an Excel/CSV file.
class ImportRow {
  final String productName;
  final String brand;
  final String category;
  final String subcategory;
  final String variant;
  final String unit;
  final double mrp;
  final int stock;
  final double gst;
  final String description;
  final String sku;
  final String barcode;
  final double sellingPrice;
  final String imageUrl;

  const ImportRow({
    required this.productName,
    required this.brand,
    required this.category,
    required this.subcategory,
    required this.variant,
    required this.unit,
    required this.mrp,
    required this.stock,
    required this.gst,
    required this.description,
    this.sku = '',
    this.barcode = '',
    this.sellingPrice = 0,
    this.imageUrl = '',
  });
}

/// Tally of image lookups across one import, so the summary can say
/// "12 products imported, photos: 8 found, 4 not found" instead of leaving the
/// vendor to guess whether photos were ever tried.
class ImageLookupStats {
  int found = 0;
  int noMatch = 0;
  int unauthorized = 0;
  int unreachable = 0;
  int error = 0;

  int get failures => unauthorized + unreachable + error;

  /// True when the lookups never ran, or ran and all of them failed. That is
  /// the case worth shouting about: the vendor asked for photos and got none
  /// for a reason that is not the product's fault.
  bool get serviceBroken => failures > 0;

  /// True when no lookup ran at all: photo lookup was off, or every row already
  /// carried a URL. Distinguished from "every lookup found nothing", which does
  /// run and is worth reporting.
  int get attempted => found + noMatch + failures;

  String? get headline {
    if (attempted == 0) return null;
    if (failures > 0) {
      // The causes need different actions, so they are named separately rather
      // than collapsed into one "failed" line. `error` is deliberately given no
      // vendor-facing advice: it means the service itself is misconfigured, and
      // telling the vendor to retry would just be wrong.
      final causes = <String>[
        if (unauthorized > 0) 'session expired — sign out and back in',
        if (unreachable > 0) 'service unreachable',
        if (error > 0) 'service rejected this sign-in — needs a developer',
      ];
      return 'Photo lookup failed $failures time${failures == 1 ? '' : 's'} '
          '(${causes.join('; ')}).';
    }
    if (noMatch == 0) return null;
    return 'Photos found for $found of ${found + noMatch} products. '
        '$noMatch had no match on the internet — add a photo URL to the sheet '
        'for those, or find one from the product page.';
  }
}

/// Per-row outcome of an import.
class ImportResultRow {
  final int rowNumber;
  final bool success;
  final String? error;
  final String? productId;
  final bool linked; // true when it matched an existing global product

  /// False for rows rejected by validation (retrying them cannot help until the
  /// source file is fixed), true for rows that failed while writing.
  final bool retryable;
  final ImportRow? row;
  const ImportResultRow({
    required this.rowNumber,
    required this.success,
    this.error,
    this.productId,
    this.linked = false,
    this.retryable = true,
    this.row,
  });
}

/// Live progress of an import run.
class ImportProgress {
  final int total;
  final int processed;
  final int imported;
  final int skipped;
  final int failed;
  final Duration elapsed;
  final Duration? estimatedRemaining;
  final bool finished;

  /// What the importer is doing right now. Photos are found before any product
  /// is written, so without this the progress bar sits at "0 imported" for a
  /// long time and looks stuck.
  final String? phase;

  const ImportProgress({
    required this.total,
    required this.processed,
    required this.imported,
    required this.skipped,
    required this.failed,
    required this.elapsed,
    this.estimatedRemaining,
    this.finished = false,
    this.phase,
  });

  double get fraction => total == 0 ? 0 : (processed / total).clamp(0.0, 1.0);

  factory ImportProgress.initial(int total) => ImportProgress(
    total: total,
    processed: 0,
    imported: 0,
    skipped: 0,
    failed: 0,
    elapsed: Duration.zero,
  );
}

class ExcelImportService {
  final GlobalCatalogService _catalog = GlobalCatalogService();
  final VendorProductService _products = VendorProductService();
  final ProductImageSearchService _imageSearch = ProductImageSearchService();

  /// How many image lookups run at once.
  ///
  /// Each lookup already fans out across several search providers, so this is
  /// deliberately modest: a larger number mostly buys rate limiting from the
  /// free providers, which costs more accuracy than it saves time.
  static const int _imageLookupConcurrency = 4;

  // ---------------------------------------------------------------
  // Template generation
  // ---------------------------------------------------------------

  /// Recommended column order. Sku / Barcode / Selling Price are optional —
  /// they are used only when the uploaded file has such a column.
  static const List<String> sampleHeaders = [
    'Product Name',
    'Brand',
    'Category',
    'Subcategory',
    'Variant',
    'Unit',
    'MRP',
    'Stock',
    'GST',
    'Description',
    'SKU',
    'Barcode',
    'Selling Price',
  ];

  static const Map<int, double> _columnWidths = {
    0: 22,
    1: 14,
    2: 14,
    3: 18,
    4: 12,
    5: 12,
    6: 10,
    7: 10,
    8: 8,
    9: 30,
    10: 12,
    11: 14,
    12: 14,
  };

  /// Sample XLSX template bytes (styled header + example rows + instructions).
  static Uint8List generateSampleExcel() {
    final excel = excel_pkg.Excel.createExcel();
    final sheet = excel['Products'];

    final headerStyle = excel_pkg.CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: excel_pkg.ExcelColor.white,
      backgroundColorHex: excel_pkg.ExcelColor.fromHexString('FFFF5F00'),
    );

    sheet.appendRow(
      sampleHeaders.map((h) => excel_pkg.TextCellValue(h)).toList(),
    );
    for (var c = 0; c < sampleHeaders.length; c++) {
      sheet
              .cell(
                excel_pkg.CellIndex.indexByColumnRow(
                  columnIndex: c,
                  rowIndex: 0,
                ),
              )
              .cellStyle =
          headerStyle;
    }

    _appendSampleRows(sheet);
    _columnWidths.forEach((col, width) => sheet.setColumnWidth(col, width));

    _addInstructionsSheet(excel);
    if (excel.tables.containsKey('Sheet1')) excel.delete('Sheet1');
    excel.setDefaultSheet('Products');
    return Uint8List.fromList(excel.encode() ?? []);
  }

  static void _appendSampleRows(excel_pkg.Sheet sheet) {
    sheet.appendRow([
      excel_pkg.TextCellValue('Maggi 70g'),
      excel_pkg.TextCellValue('Nestle'),
      excel_pkg.TextCellValue('Grocery'),
      excel_pkg.TextCellValue('Instant Noodles'),
      excel_pkg.TextCellValue('70g'),
      excel_pkg.TextCellValue('Pack'),
      const excel_pkg.IntCellValue(15),
      const excel_pkg.IntCellValue(250),
      const excel_pkg.IntCellValue(5),
      excel_pkg.TextCellValue('Instant noodles'),
      excel_pkg.TextCellValue('MAGGI-70'),
      excel_pkg.TextCellValue('8901058000000'),
      const excel_pkg.IntCellValue(14),
    ]);
    sheet.appendRow([
      excel_pkg.TextCellValue('Amul Butter 500g'),
      excel_pkg.TextCellValue('Amul'),
      excel_pkg.TextCellValue('Grocery'),
      excel_pkg.TextCellValue('Dairy'),
      excel_pkg.TextCellValue('500g'),
      excel_pkg.TextCellValue('Pack'),
      const excel_pkg.IntCellValue(290),
      const excel_pkg.IntCellValue(120),
      const excel_pkg.IntCellValue(0),
      excel_pkg.TextCellValue(''),
      excel_pkg.TextCellValue(''),
      excel_pkg.TextCellValue(''),
      const excel_pkg.IntCellValue(280),
    ]);
  }

  static void _addInstructionsSheet(excel_pkg.Excel excel) {
    final info = excel['How to fill'];
    const lines = [
      'HOW TO FILL THE PRODUCT TEMPLATE',
      '',
      'This template is only a RECOMMENDED format. You can upload any',
      'spreadsheet: columns can be in any order, headers can be named',
      'differently (Name / Item Name / Product Title all work), extra',
      'columns are ignored, and comma, semicolon or tab separated files',
      'are accepted.',
      '',
      '1. Required: a product name column and a price column (MRP / Price).',
      '2. Everything else is optional. Missing Brand, Variant, GST, Stock',
      '   or Category columns fall back to sensible defaults (GST 0%,',
      '   Stock 0, Category Grocery).',
      '3. Prices may be written as 15, 15.00, Rs.15 or Rs 1,299.00.',
      '   GST may be 18, 18%, or 0.18.',
      '4. This "How to fill" sheet is only for guidance — the app picks the',
      '   sheet that looks most like a product list.',
    ];
    for (var r = 0; r < lines.length; r++) {
      info.appendRow([excel_pkg.TextCellValue(lines[r])]);
      info.merge(
        excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r),
        excel_pkg.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: r),
      );
    }
    info.setColumnWidth(0, 70);
  }

  /// Sample CSV template string (UTF-8 BOM so Excel opens it correctly).
  static String generateSampleCsv() {
    final rows = <List<dynamic>>[
      sampleHeaders,
      [
        'Maggi 70g',
        'Nestle',
        'Grocery',
        'Instant Noodles',
        '70g',
        'Pack',
        15,
        250,
        5,
        'Instant noodles',
        'MAGGI-70',
        '8901058000000',
        14,
      ],
      [
        'Amul Butter 500g',
        'Amul',
        'Grocery',
        'Dairy',
        '500g',
        'Pack',
        290,
        120,
        0,
        '',
        '',
        '',
        280,
      ],
    ];
    return '\uFEFF${const ListToCsvConverter().convert(rows)}';
  }

  // ---------------------------------------------------------------
  // Column mapping
  // ---------------------------------------------------------------

  /// Header spellings matched exactly (after normalisation). Order matters:
  /// more specific fields are resolved before broader ones.
  static const Map<String, List<String>> _strictAliases = {
    ImportField.productName: [
      'product name',
      'productname',
      'name',
      'product',
      'item name',
      'item',
      'product title',
      'item title',
      'title',
      'productnm',
      'name of product',
      'product label',
      'item',
    ],
    ImportField.subcategory: [
      'subcategory',
      'sub category',
      'subcat',
      'sub cat',
      'subcategory name',
      'sub category name',
      'sub cat name',
      'secondary category',
      'sub type',
      'subcategoryname',
      'sub',
    ],
    ImportField.category: [
      'category',
      'categories',
      'cat',
      'category name',
      'main category',
      'product category',
      'categoryname',
      'section',
      'group',
      'type',
      'vertical',
      'department',
    ],
    ImportField.brand: [
      'brand',
      'brand name',
      'brandname',
      'make',
      'manufacturer',
      'manufacturer name',
      'company',
      'company name',
      'brand nm',
      'supplier',
    ],
    ImportField.variant: [
      'variant',
      'variants',
      'variant name',
      'variantname',
      'size',
      'pack size',
      'size variant',
      'flavour',
      'flavor',
      'flavour name',
      'flavor name',
      'weight',
      'net weight',
      'net qty',
      'net quantity',
      'pack',
      'model',
      'volume',
      'net weight g',
      'net weight kg',
    ],
    ImportField.unit: [
      'unit',
      'units',
      'uom',
      'unit of measure',
      'unit name',
      'unit measure',
      'packaging',
      'packaging unit',
      'pack type',
      'uom name',
      'packaging type',
    ],
    ImportField.sku: [
      'sku',
      'sku code',
      'sku id',
      'sku no',
      'sku number',
      'product code',
      'item code',
      'article code',
      'article no',
      'model no',
      'code',
    ],
    ImportField.barcode: [
      'barcode',
      'bar code',
      'ean',
      'ean code',
      'upc',
      'upc code',
      'gtin',
      'isbn',
      'scan code',
      'bar code no',
    ],
    ImportField.description: [
      'description',
      'product description',
      'item description',
      'desc',
      'details',
      'product details',
      'remarks',
      'remarks notes',
      'notes',
      'comment',
      'comments',
      'about',
      'information',
      'info',
      'specification',
      'specs',
    ],
    ImportField.stock: [
      'stock',
      'stock qty',
      'stock quantity',
      'quantity',
      'qty',
      'available stock',
      'inventory',
      'inventory qty',
      'current stock',
      'stock in hand',
      'qty in stock',
      'instock',
      'stock available',
      'units in stock',
      'available quantity',
      'stock level',
      'on hand',
    ],
    ImportField.gst: [
      'gst',
      'gst rate',
      'gst percentage',
      'gst percent',
      'gst slab',
      'gst applicable',
      'gst amount',
      'gst percent rate',
      'tax',
      'tax rate',
      'tax percentage',
      'taxable',
      'gstin rate',
    ],
    ImportField.price: [
      'mrp',
      'm r p',
      'marked price',
      'list price',
      'l price',
      'retail price',
      'maximum retail price',
      'mrp price',
      'price mrp',
      'product mrp',
      'mrp amount',
      'm r p rs',
      'price',
      'product price',
      'unit price',
      'price per unit',
      'rate',
      'amount',
      'product rate',
      'rate per unit',
    ],
    ImportField.sellingPrice: [
      'selling price',
      'sellingprice',
      'sale price',
      'vendor price',
      'our price',
      'your price',
      'offer price',
      'net price',
      'invoice price',
      'discounted price',
      'dealer price',
      'selling rate',
      'sp',
      'price to sell',
    ],
    ImportField.imageUrl: [
      'image url',
      'image link',
      'photo url',
      'product image',
      'image',
    ],
  };

  /// Second-choice spellings, tried after every strict alias is resolved.
  static const Map<String, List<String>> _looseAliases = {
    ImportField.productName: ['item description name', 'product description'],
    ImportField.subcategory: ['sub category type', 'subcategoryname'],
    ImportField.category: ['product sub type', 'cat name', 'category type'],
    ImportField.brand: ['brand nm name', 'make name'],
    ImportField.variant: [
      'weight in kg',
      'weight grams',
      'pack variant',
      'size value',
    ],
    ImportField.unit: ['unit of units', 'uom text'],
    ImportField.sku: [
      'sku number text',
      'seller code',
      'vendor code',
      'item code text',
    ],
    ImportField.barcode: ['barcode no', 'barcode number', 'scan barcode'],
    ImportField.description: [
      'item name remarks',
      'long description',
      'product remark',
    ],
    ImportField.stock: [
      'stock count',
      'quantity available',
      'stock units',
      'opening stock',
    ],
    ImportField.gst: [
      'gst percentage value',
      'gst percent value',
      'tax percent',
    ],
    ImportField.price: [
      'price rs',
      'rate rs',
      'mrp value',
      'price amount',
      'unit rate',
    ],
    ImportField.sellingPrice: [
      'selling',
      'sale',
      'offer',
      'deal price',
      'discount price',
    ],
    ImportField.imageUrl: ['image address', 'picture url', 'photo link'],
  };

  /// Very generic words: matched exactly, never fuzzily (so "Name" never
  /// steals a "Category Name" column and "Code" never steals "HSN Code").
  static const Set<String> _weakAliases = {
    'name',
    'product',
    'item',
    'title',
    'make',
    'company',
    'supplier',
    'type',
    'group',
    'section',
    'cat',
    'code',
    'tax',
    'taxable',
    'info',
    'about',
    'comments',
    'note',
    'notes',
    'sp',
    'rate',
    'amount',
    'sell',
    'sale',
    'offer',
    'packaging',
    'variant',
    'sub',
    'vertical',
    'department',
    'remarks',
    'desc',
    'details',
    'specs',
    'specification',
    'offer price',
    'price',
  };

  /// Resolution order — specific before generic so "Sub Category" is not read
  /// as "Category" and "Selling Price" is not read as "Price".
  static const List<String> _fieldOrder = [
    ImportField.productName,
    ImportField.subcategory,
    ImportField.category,
    ImportField.brand,
    ImportField.variant,
    ImportField.unit,
    ImportField.sku,
    ImportField.barcode,
    ImportField.description,
    ImportField.stock,
    ImportField.gst,
    ImportField.price,
    ImportField.sellingPrice,
    ImportField.imageUrl,
  ];

  /// Lowercases, strips currency/decorative noise and collapses separators so
  /// "MRP (Rs.)", "m.r.p" and "Product_Name" all normalise to comparable text.
  static String normalizeHeader(String raw) {
    var s = raw.toLowerCase();
    s = s.replaceAll(RegExp('[\uFEFF\u200B-\u200D\u00A0]'), ' ');
    s = s.replaceAll(RegExp(r'[^a-z0-9%]+'), ' ');
    s = s.replaceAll(RegExp(r'\b(rupees|ruppee|rs|inr|only|amt)\b'), ' ');
    s = s.replaceAll('%', ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// Builds a mapping from a candidate header row. Returns an empty map when
  /// the row does not look like a header at all.
  static Map<String, int> _mapHeader(List<String> cells) {
    final normalized = <int, String>{};
    for (var i = 0; i < cells.length; i++) {
      final n = normalizeHeader(cells[i]);
      if (n.isNotEmpty) normalized[i] = n;
    }
    if (normalized.isEmpty) return const {};

    final index = <String, int>{};
    final used = <int>{};

    void assign(String field, int column) {
      if (index.containsKey(field) || used.contains(column)) return;
      index[field] = column;
      used.add(column);
    }

    // Pass 1 — exact matches, strict spellings.
    for (final field in _fieldOrder) {
      final aliases = _strictAliases[field] ?? const <String>[];
      for (final entry in normalized.entries) {
        if (used.contains(entry.key)) continue;
        if (aliases.contains(entry.value)) {
          assign(field, entry.key);
          break;
        }
      }
    }

    // Pass 2 — exact matches, alternate spellings.
    for (final field in _fieldOrder) {
      if (index.containsKey(field)) continue;
      final aliases = _looseAliases[field] ?? const <String>[];
      for (final entry in normalized.entries) {
        if (used.contains(entry.key)) continue;
        if (aliases.contains(entry.value)) {
          assign(field, entry.key);
          break;
        }
      }
    }

    // Pass 3 — fuzzy: "Item Name (English)", "Available Qty (Nos.)",
    // "MRP INR" and similar decorated headers.
    for (final field in _fieldOrder) {
      if (index.containsKey(field)) continue;
      final aliases = <String>[
        ...?_strictAliases[field],
        ...?_looseAliases[field],
      ];
      double? bestScore;
      int? bestColumn;
      for (final entry in normalized.entries) {
        if (used.contains(entry.key)) continue;
        final score = _bestAliasScore(entry.value, aliases);
        if (score == null) continue;
        if (bestScore == null || score > bestScore) {
          bestScore = score;
          bestColumn = entry.key;
        }
      }
      if (bestColumn != null && bestScore! >= 0.6) {
        assign(field, bestColumn);
      }
    }

    return index;
  }

  /// Highest fuzzy score of a header against a list of aliases, or null when
  /// nothing is close enough. Generic single words never fuzzy-match.
  static double? _bestAliasScore(String header, List<String> aliases) {
    final headerTokens = header.split(' ').where((t) => t.isNotEmpty).toSet();
    double? best;
    for (final raw in aliases) {
      final alias = normalizeHeader(raw);
      if (alias.isEmpty || _weakAliases.contains(alias)) continue;
      if (header == alias) return 1;
      final padded = ' $header ';
      if (padded.contains(' $alias ')) {
        best = (best ?? 0) < 0.9 ? 0.9 : best;
        continue;
      }
      final aliasTokens = alias.split(' ').where((t) => t.isNotEmpty).toSet();
      if (aliasTokens.isEmpty || headerTokens.isEmpty) continue;
      final shared = headerTokens.intersection(aliasTokens).length;
      if (shared == 0) continue;
      // Every alias token must be present, otherwise partial noise matches.
      if (shared < aliasTokens.length) continue;
      final score = shared / headerTokens.length;
      if (best == null || score > best) best = score;
    }
    return best;
  }

  // ---------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------

  /// Reads XLSX / CSV / TSV / TXT bytes into raw string rows plus a column
  /// mapping. The file kind is detected from the bytes first and the extension
  /// second, so a mis-named or mis-extracted file still imports.
  static ParsedSheet parseFile(Uint8List bytes, String fileName) {
    try {
      switch (_detectKind(bytes, fileName)) {
        case _FileKind.csv:
          return _parseDelimited(bytes);
        case _FileKind.legacyXls:
          throw const ExcelParseException(
            'This is an older .xls workbook, which cannot be read directly. '
            'Open it and use "Save As" → .xlsx (Excel 2007+) or .csv, then '
            'upload it again.',
          );
        case _FileKind.xlsx:
          return _parseXlsx(bytes);
      }
    } on ExcelParseException {
      rethrow;
    } catch (e) {
      throw ExcelParseException(
        'Could not read "$fileName". Supported formats: .xlsx (Excel 2007+), '
        '.csv, .tsv and .txt — separated by comma, semicolon, tab or pipe. '
        '($e)',
      );
    }
  }

  /// Content sniffing first (PK zip → xlsx, OLE2 header → legacy .xls),
  /// extension as a fallback.
  static _FileKind _detectKind(Uint8List bytes, String fileName) {
    final ext = fileName.toLowerCase();
    if (bytes.length >= 4) {
      final magic = bytes.sublist(0, 4);
      // ZIP: every xlsx starts with "PK\x03\x04"
      if (magic[0] == 0x50 && magic[1] == 0x4B) return _FileKind.xlsx;
      // OLE2 compound document: legacy .xls / .doc
      if (magic[0] == 0xD0 &&
          magic[1] == 0xCF &&
          magic[2] == 0x11 &&
          magic[3] == 0xE0) {
        return _FileKind.legacyXls;
      }
    }
    if (ext.endsWith('.xls')) return _FileKind.legacyXls;
    if (ext.endsWith('.xlsx') || ext.endsWith('.xlsm')) return _FileKind.xlsx;
    return _FileKind.csv;
  }

  /// Parses any delimited text file, auto-detecting the separator.
  static ParsedSheet _parseDelimited(Uint8List bytes) {
    final text = utf8
        .decode(bytes, allowMalformed: true)
        .replaceFirst(RegExp('^\uFEFF'), '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final delimiter = sniffDelimiter(text);
    // csv's converter ignores the final record when a text export does not
    // end in a line break. Many inventory systems produce files that way.
    final parseText = text.endsWith('\n') || text.endsWith('\r')
        ? text
        : '$text\n';
    List<List<dynamic>> parsed;
    try {
      parsed = CsvToListConverter(
        fieldDelimiter: delimiter,
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(parseText);
    } catch (_) {
      parsed = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(parseText);
    }
    final rows = parsed
        .map((r) => r.map((c) => c?.toString().trim() ?? '').toList())
        .toList();
    return _buildSheet(rows);
  }

  /// Picks the delimiter used by most of the first lines. Handles comma,
  /// semicolon, tab and pipe separated exports (e.g. European CSVs use ";").
  static String sniffDelimiter(String text) {
    final lines = text
        .split(RegExp(r'\r\n|\r|\n'))
        .where((l) => l.trim().isNotEmpty)
        .take(8)
        .toList();
    if (lines.isEmpty) return ',';
    const candidates = [',', ';', '\t', '|'];
    String? best;
    var bestScore = 0;
    for (final d in candidates) {
      var total = 0;
      for (final line in lines) {
        // Ignore separators inside quoted sections.
        total += _countOutsideQuotes(line, d);
      }
      if (total > bestScore) {
        bestScore = total;
        best = d;
      }
    }
    return best ?? ',';
  }

  static int _countOutsideQuotes(String line, String delimiter) {
    var count = 0;
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
        continue;
      }
      if (!inQuotes && ch == delimiter) count++;
    }
    return count;
  }

  static ParsedSheet _parseXlsx(Uint8List bytes) {
    Object? lastError;

    try {
      return _bestSheetOf(excel_pkg.Excel.decodeBytes(bytes));
    } catch (e) {
      lastError = e;
    }

    // excel 4.x throws on any workbook that declares a built-in number format
    // id (41 = Accounting, for example) inside xl/styles.xml. Real Excel,
    // Google Sheets and LibreOffice all emit those, so retry once with the
    // ids lifted above the floor the package insists on.
    final remapped = _remapLowNumFmtIds(bytes);
    if (remapped != null) {
      try {
        return _bestSheetOf(excel_pkg.Excel.decodeBytes(remapped));
      } catch (e) {
        lastError = e;
      }
    }

    try {
      return _bestRawSheet(bytes);
    } catch (e) {
      lastError = e;
    }

    throw ExcelParseException(
      'This .xlsx file could not be read ($lastError). If it is an older .xls '
      'workbook, or the file is corrupt, save it as .xlsx or .csv and upload '
      'it again.',
    );
  }

  static ParsedSheet _bestSheetOf(excel_pkg.Excel excel) {
    if (excel.tables.isEmpty) {
      return const ParsedSheet(rows: [], columns: _emptyMap);
    }

    // Pick the sheet that looks most like a product list instead of trusting
    // the sheet name, so files with a cover/instructions sheet still work.
    ParsedSheet? best;
    var bestScore = -1;
    for (final name in excel.tables.keys) {
      final rows = excel.tables[name]!.rows
          .map((r) => r.map(_cellToString).toList())
          .toList();
      if (rows.isEmpty) continue;
      final sheet = _buildSheet(rows);
      final score = _sheetScore(sheet) + (_isPreferredSheetName(name) ? 1 : 0);
      if (score > bestScore) {
        best = sheet;
        bestScore = score;
      }
    }
    return best ?? const ParsedSheet(rows: [], columns: _emptyMap);
  }

  // ---------------------------------------------------------------
  // XLSX repair helpers (work around excel 4.x numFmtId validation)
  // ---------------------------------------------------------------

  /// Lifts every `<numFmt numFmtId="n">` below 164 to a free custom id and
  /// repacks the workbook. Returns null when there is nothing to fix.
  static Uint8List? _remapLowNumFmtIds(Uint8List bytes) {
    final Archive zip;
    try {
      zip = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      return null;
    }
    final styles = _zipEntry(zip, 'xl/styles.xml');
    if (styles == null) return null;

    final xml = _entryText(styles);
    final low = RegExp(r'<numFmt\b[^>]*\bnumFmtId="(\d+)"')
        .allMatches(xml)
        .map((m) => int.parse(m.group(1)!))
        .where((id) => id < 164)
        .toSet()
        .toList();
    if (low.isEmpty) return null;

    var next = 164;
    for (final m in RegExp(r'\bnumFmtId="(\d+)"').allMatches(xml)) {
      final id = int.parse(m.group(1)!);
      if (id >= next) next = id + 1;
    }

    var patched = xml;
    for (final old in low) {
      // The quotes keep "41" from also rewriting "410".
      patched = patched.replaceAll('numFmtId="$old"', 'numFmtId="$next"');
      next++;
    }
    if (patched == xml) return null;

    final out = Archive();
    for (final entry in zip.files) {
      if (!entry.isFile) continue;
      final isStyles = entry.name.toLowerCase() == 'xl/styles.xml';
      final content = isStyles
          ? Uint8List.fromList(utf8.encode(patched))
          : _entryBytes(entry);
      out.addFile(ArchiveFile(entry.name, content.length, content));
    }
    final encoded = ZipEncoder().encode(out);
    return encoded == null ? null : Uint8List.fromList(encoded);
  }

  /// Last-resort reader: pulls cell text straight out of the OOXML parts so a
  /// valid workbook still imports even when the package rejects it.
  static ParsedSheet _bestRawSheet(Uint8List bytes) {
    final zip = ZipDecoder().decodeBytes(bytes);
    final shared = _rawSharedStrings(zip);
    final sheets = zip.files
        .where((f) {
          final n = f.name.toLowerCase();
          return f.isFile &&
              n.startsWith('xl/worksheets/') &&
              n.endsWith('.xml');
        })
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (sheets.isEmpty) {
      throw const ExcelParseException('the workbook has no worksheets');
    }

    ParsedSheet? best;
    var bestScore = -1;
    for (final file in sheets) {
      final rows = _rawSheetRows(_entryText(file), shared);
      if (rows.isEmpty) continue;
      final sheet = _buildSheet(rows);
      final name = file.name.split('/').last.replaceAll('.xml', '');
      final score = _sheetScore(sheet) + (_isPreferredSheetName(name) ? 1 : 0);
      if (score > bestScore) {
        best = sheet;
        bestScore = score;
      }
    }
    return best ?? const ParsedSheet(rows: [], columns: _emptyMap);
  }

  static List<String> _rawSharedStrings(Archive zip) {
    final file = _zipEntry(zip, 'xl/sharedstrings.xml');
    if (file == null) return const [];
    final doc = XmlDocument.parse(_entryText(file));
    return doc
        .findAllElements('si')
        .map((si) => si.findAllElements('t').map((t) => t.innerText).join())
        .toList();
  }

  static List<List<String>> _rawSheetRows(String xml, List<String> shared) {
    final blocks = XmlDocument.parse(xml).findAllElements('sheetData');
    if (blocks.isEmpty) return const [];
    final rows = <List<String>>[];
    for (final row in blocks.first.findElements('row')) {
      final cells = <int, String>{};
      var maxCol = -1;
      for (final cell in row.findElements('c')) {
        final ref = cell.getAttribute('r');
        final col = ref == null ? maxCol + 1 : _columnIndexOf(ref);
        if (col > maxCol) maxCol = col;
        cells[col] = _rawCellText(cell, shared);
      }
      if (cells.isEmpty) continue;
      final list = List<String>.filled(maxCol + 1, '');
      cells.forEach((i, v) => list[i] = v);
      rows.add(list);
    }
    return rows;
  }

  static String _rawCellText(XmlElement cell, List<String> shared) {
    if (cell.getAttribute('t') == 'inlineStr') {
      return cell
          .findElements('is')
          .expand((e) => e.findElements('t'))
          .map((t) => t.innerText)
          .join();
    }
    final raw = cell.getElement('v')?.innerText ?? '';
    if (cell.getAttribute('t') != 's') return raw;
    final i = int.tryParse(raw);
    return (i != null && i >= 0 && i < shared.length) ? shared[i] : '';
  }

  /// "BC12" -> 54
  static int _columnIndexOf(String ref) {
    var col = 0;
    for (var i = 0; i < ref.length; i++) {
      final code = ref.codeUnitAt(i);
      if (code < 0x41 || code > 0x5A) break;
      col = col * 26 + (code - 0x40);
    }
    return col - 1;
  }

  static ArchiveFile? _zipEntry(Archive zip, String name) {
    for (final f in zip.files) {
      if (f.isFile && f.name.toLowerCase() == name) return f;
    }
    return null;
  }

  static Uint8List _entryBytes(ArchiveFile file) {
    final c = file.content;
    if (c is Uint8List) return c;
    if (c is List<int>) return Uint8List.fromList(c);
    if (c is String) return Uint8List.fromList(utf8.encode(c));
    return Uint8List(0);
  }

  static String _entryText(ArchiveFile file) =>
      utf8.decode(_entryBytes(file), allowMalformed: true);

  /// Prefers sheets with a recognised header and real data rows.
  static int _sheetScore(ParsedSheet sheet) {
    if (sheet.rows.isEmpty) return 0;
    if (!sheet.columns.detected) return 1;
    return 1000 + sheet.columns.matchedCount * 10;
  }

  /// Common names vendors give their product sheet.
  static bool _isPreferredSheetName(String name) {
    const names = {
      'products',
      'product',
      'product list',
      'inventory',
      'items',
      'stock',
      'stock list',
      'catalogue',
      'catalog',
      'sheet1',
    };
    return names.contains(name.trim().toLowerCase());
  }

  static const ColumnMap _emptyMap = ColumnMap(
    index: <String, int>{},
    headers: <String>[],
    detected: false,
    firstDataRowNumber: 1,
  );

  /// Finds the header row (up to the 8th row, so a title/company row above the
  /// header is fine), maps the columns and returns the data rows that follow.
  static ParsedSheet _buildSheet(List<List<String>> rawRows) {
    final rows = <List<String>>[];
    for (final r in rawRows) {
      rows.add(r.map((c) => c.trim()).toList());
    }
    // Drop fully empty rows anywhere in the sheet.
    rows.removeWhere((r) => r.every((c) => c.trim().isEmpty));
    if (rows.isEmpty) return const ParsedSheet(rows: [], columns: _emptyMap);

    final maxScan = rows.length < 8 ? rows.length : 8;
    Map<String, int>? bestIndex;
    var bestRow = -1;
    for (var i = 0; i < maxScan; i++) {
      final index = _mapHeader(rows[i]);
      if (index.length < 2) continue;
      if (!index.containsKey(ImportField.productName) &&
          !index.containsKey(ImportField.price)) {
        continue;
      }
      // The first valid header is the actual table header in normal exports.
      // Continuing to scan can let a data row whose values resemble aliases
      // replace it (for example a product named "Sale Pack").
      bestIndex = index;
      bestRow = i;
      break;
    }

    if (bestIndex != null && bestRow >= 0) {
      final headerCells = rows[bestRow];
      final columns = ColumnMap(
        index: bestIndex,
        headers: headerCells,
        detected: true,
        firstDataRowNumber: bestRow + 2, // 1-based, header occupies bestRow
      );
      final data = <List<String>>[];
      for (var i = bestRow + 1; i < rows.length; i++) {
        // Skip repeated headers (exports that repeat them on every page).
        if (_isRepeatedHeader(rows[i], headerCells, bestIndex)) continue;
        data.add(rows[i]);
      }
      return ParsedSheet(rows: data, columns: columns);
    }

    // No header recognised — fall back to the template's column order and skip
    // leading title / note rows.
    var start = 0;
    while (start < rows.length) {
      final filled = rows[start].where((c) => c.trim().isNotEmpty).length;
      if (filled == 0 || filled <= 2) {
        start++;
        continue;
      }
      break;
    }
    final data = start >= rows.length ? <List<String>>[] : rows.sublist(start);
    return ParsedSheet(
      rows: data,
      columns: ColumnMap.positional(
        data.isEmpty ? const [] : data.first,
        firstDataRowNumber: start + 1,
      ),
    );
  }

  /// A repeated header must contain the same header text in the same mapped
  /// columns. Re-mapping a data row alone is unsafe: a product like "Sale"
  /// or "Pack" can resemble an alias and would otherwise be discarded.
  static bool _isRepeatedHeader(
    List<String> candidate,
    List<String> header,
    Map<String, int> mapping,
  ) {
    if (mapping.length < 2) return false;
    for (final column in mapping.values) {
      if (column >= candidate.length || column >= header.length) return false;
      final candidateValue = normalizeHeader(candidate[column]);
      final headerValue = normalizeHeader(header[column]);
      if (candidateValue.isEmpty || candidateValue != headerValue) return false;
    }
    return true;
  }

  static String _cellToString(excel_pkg.Data? cell) {
    if (cell == null) return '';
    final v = cell.value;
    if (v is excel_pkg.TextCellValue) return v.value.toString().trim();
    if (v is excel_pkg.IntCellValue) return v.value.toString();
    if (v is excel_pkg.DoubleCellValue) return v.value.toString();
    if (v is excel_pkg.BoolCellValue) return v.value ? 'TRUE' : 'FALSE';
    if (v is excel_pkg.DateCellValue) {
      return v.asDateTimeLocal().toIso8601String();
    }
    return v.toString().trim();
  }

  // ---------------------------------------------------------------
  // Value parsing / validation
  // ---------------------------------------------------------------

  /// Parses a GST cell, tolerating "18%", "18 %", "18.0" and the fraction
  /// Excel produces when a user types "5%": 0.05 is treated as 5%.
  static double? _parseGst(String raw) {
    var v = raw.trim();
    if (v.endsWith('%')) v = v.substring(0, v.length - 1).trim();
    v = v.replaceAll(',', '');
    final val = double.tryParse(v);
    if (val == null) return null;
    if (val > 0 && val < 1) return val * 100;
    return val;
  }

  /// Parses an amount, stripping currency symbols, commas and whitespace.
  static double? _parseAmount(String raw) {
    var v = raw.trim().replaceAll(',', '');
    v = v.replaceAll(RegExp(r'[₹$€£]|Rs\.?', caseSensitive: false), '').trim();
    v = v.replaceAll(RegExp(r'\bINR\b', caseSensitive: false), '').trim();
    return double.tryParse(v);
  }

  /// Parses an integer, tolerating decimals, thousands separators and trailing
  /// words like "250 pcs".
  static int? _parseStock(String raw) {
    var v = raw.trim().replaceAll(',', '');
    v = v.replaceAll(RegExp(r'[₹$€£]|Rs\.?', caseSensitive: false), '').trim();
    final match = RegExp(r'-?\d+(\.\d+)?').firstMatch(v);
    if (match == null) return null;
    return double.parse(match.group(0)!).round();
  }

  /// Reads the product name, brand and price columns, falling back to the
  /// Selling Price column when the file has no MRP-like column.
  static String? _validate(List<String> cells, ColumnMap columns) {
    final name = columns.cell(cells, ImportField.productName);
    if (name.isEmpty) {
      return columns.has(ImportField.productName)
          ? 'Product Name is empty'
          : 'No product name column found (looked for Name / Product Name / '
                'Item Name / Title)';
    }

    final hasPriceColumn =
        columns.has(ImportField.price) || columns.has(ImportField.sellingPrice);
    if (!hasPriceColumn) {
      return 'No price column found (looked for MRP / Price / Rate / Amount)';
    }
    final priceCell = columns.cell(cells, ImportField.price).isNotEmpty
        ? columns.cell(cells, ImportField.price)
        : columns.cell(cells, ImportField.sellingPrice);
    final priceVal = _parseAmount(priceCell);
    if (priceVal == null || priceVal <= 0) {
      return 'MRP/Price is invalid ("$priceCell") — use a number like 15, '
          '15.00 or Rs.15';
    }
    return null;
  }

  /// Returns an error string, or null when the row is valid.
  static String? validateRow(List<String> cells, [ColumnMap? columns]) {
    final map =
        columns ?? ColumnMap.positional(const [], firstDataRowNumber: 1);
    final error = _validate(cells, map);
    if (error != null) return error;

    if (map.has(ImportField.stock)) {
      final stockCell = map.cell(cells, ImportField.stock);
      if (stockCell.isNotEmpty) {
        final stockVal = _parseStock(stockCell);
        if (stockVal == null) return 'Stock is not a number ("$stockCell")';
        if (stockVal < 0) return 'Stock must be >= 0';
      }
    }

    if (map.has(ImportField.gst)) {
      final gstCell = map.cell(cells, ImportField.gst);
      if (gstCell.isNotEmpty) {
        final gstVal = _parseGst(gstCell);
        if (gstVal == null || gstVal < 0) {
          return 'GST is invalid ("$gstCell") — use 0, 5, 12, 18 or 28%';
        }
        if (gstVal > 100) {
          return 'GST looks wrong (got "$gstCell"). It must be a percentage '
              'between 0 and 100.';
        }
      }
    }

    return null;
  }

  /// Builds an import row, applying defaults for columns the file doesn't have.
  static ImportRow rowFromCells(List<String> cells, [ColumnMap? columns]) {
    final map =
        columns ?? ColumnMap.positional(const [], firstDataRowNumber: 1);

    var priceCell = map.cell(cells, ImportField.price);
    if (priceCell.isEmpty) {
      priceCell = map.cell(cells, ImportField.sellingPrice);
    }
    final mrp = _parseAmount(priceCell) ?? 0;

    final sellingCell = map.cell(cells, ImportField.sellingPrice);
    final selling = _parseAmount(sellingCell) ?? 0;

    final stockCell = map.cell(cells, ImportField.stock);
    final gstCell = map.cell(cells, ImportField.gst);

    return ImportRow(
      productName: _clean(map.cell(cells, ImportField.productName)),
      brand: _clean(map.cell(cells, ImportField.brand)),
      category: _clean(map.cell(cells, ImportField.category)).isEmpty
          ? defaultCategory
          : _clean(map.cell(cells, ImportField.category)),
      subcategory: _clean(map.cell(cells, ImportField.subcategory)),
      variant: _clean(map.cell(cells, ImportField.variant)),
      unit: _clean(map.cell(cells, ImportField.unit)),
      mrp: mrp,
      stock: stockCell.isEmpty ? 0 : (_parseStock(stockCell) ?? 0),
      gst: gstCell.isEmpty ? 0 : (_parseGst(gstCell) ?? 0),
      description: _clean(map.cell(cells, ImportField.description)),
      sku: _clean(map.cell(cells, ImportField.sku)),
      barcode: _clean(map.cell(cells, ImportField.barcode)),
      sellingPrice: selling > 0 ? selling : mrp,
      imageUrl: _clean(map.cell(cells, ImportField.imageUrl)),
    );
  }

  /// Category used when the uploaded file has no category column.
  static const String defaultCategory = 'Grocery';

  /// Collapses internal whitespace and trims stray punctuation/quotes.
  static String _clean(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r"""^['"]+|['"]+$"""), '')
        .trim();
  }

  // ---------------------------------------------------------------
  // Import run
  // ---------------------------------------------------------------

  /// Runs an import. Yields progress via [onProgress] and returns per-row
  /// results. Invalid rows are skipped; the valid ones are imported
  /// immediately (no admin approval). Global products are deduplicated.
  Future<List<ImportResultRow>> import({
    required Uint8List bytes,
    required String fileName,
    required String vendorId,
    bool forceGstZero = false,
    bool autoFindImages = false,
    String? shopId,
    void Function(ImportProgress progress)? onProgress,
    bool Function()? isCancelled,
    void Function(ParsedSheet sheet)? onParsed,

    /// Receives the live lookup tally. Passed in by the caller rather than
    /// returned so the running counts can be read while the import is still
    /// going, not only after it finishes.
    ImageLookupStats? onImageStats,
  }) async {
    final sheet = parseFile(bytes, fileName);
    onParsed?.call(sheet);

    if (sheet.rows.isEmpty) {
      throw const ExcelParseException(
        'No product rows found in the file. Check that the sheet has a header '
        'row and at least one product under it.',
      );
    }

    final rawRows = sheet.rows;
    final columns = sheet.columns;
    final firstDataRowNumber = columns.firstDataRowNumber;
    final total = rawRows.length;
    final started = DateTime.now();
    final results = <ImportResultRow>[];
    var imported = 0;
    var skipped = 0;
    var failed = 0;

    onProgress?.call(ImportProgress.initial(total));

    // Photos are resolved for every usable row up front, so the wait happens
    // once, in parallel, instead of once per row inside the write loop. Rows
    // that already carry a URL in the sheet are skipped: the vendor supplied
    // that one deliberately.
    Map<int, String> prefetchedImages = const {};
    final imageStats = onImageStats ?? ImageLookupStats();
    if (autoFindImages) {
      // Positions in the sheet that need a lookup, in ascending order, paired
      // with the row to look up.
      final positions = <int>[];
      final rowsNeedingImage = <ImportRow>[];
      for (var i = 0; i < rawRows.length; i++) {
        if (validateRow(rawRows[i], columns) != null) continue;
        final row = rowFromCells(rawRows[i], columns);
        if (row.imageUrl.startsWith('http')) continue;
        positions.add(i);
        rowsNeedingImage.add(row);
      }
      if (rowsNeedingImage.isNotEmpty) {
        final urls = await _prefetchImages(
          rowsNeedingImage,
          onProgress: onProgress,
          isCancelled: isCancelled,
          stats: imageStats,
        );
        prefetchedImages = {
          for (var n = 0; n < urls.length; n++)
            if (urls[n] != null) positions[n]: urls[n]!,
        };
        // Surfaced on the progress line while the import runs, so a run where
        // every lookup is being rejected does not look like a run that is merely
        // slow. The vendor sees "0 found, 12 rejected" instead of "finding
        // photos" forever and then a result with no photos in it.
        if (imageStats.serviceBroken) {
          onProgress?.call(
            ImportProgress(
              total: total,
              processed: 0,
              imported: 0,
              skipped: 0,
              failed: 0,
              elapsed: DateTime.now().difference(started),
              phase: 'Photo lookup is failing — photos will be left blank',
            ),
          );
        }
      }
    }

    for (var i = 0; i < rawRows.length; i++) {
      if (isCancelled?.call() ?? false) break;
      final rowNumber = firstDataRowNumber + i;

      final error = validateRow(rawRows[i], columns);
      if (error != null) {
        skipped++;
        results.add(
          ImportResultRow(
            rowNumber: rowNumber,
            success: false,
            error: error,
            linked: false,
            retryable: false,
            // Keep the partially parsed row so the results list and the error
            // report show which product failed instead of "(invalid row)".
            row: rowFromCells(rawRows[i], columns),
          ),
        );
      } else {
        final row = rowFromCells(rawRows[i], columns);
        try {
          final outcome = await _importOne(
            row: row,
            vendorId: vendorId,
            shopId: shopId,
            forceGstZero: forceGstZero,
            autoFindImage: autoFindImages,
            prefetchedImage: prefetchedImages[i],
          );
          imported++;
          results.add(
            ImportResultRow(
              rowNumber: rowNumber,
              success: true,
              productId: outcome.productId,
              linked: outcome.linked,
              row: row,
            ),
          );
        } catch (e) {
          failed++;
          results.add(
            ImportResultRow(
              rowNumber: rowNumber,
              success: false,
              error: 'Import failed: $e',
              row: row,
            ),
          );
        }
      }

      final elapsed = DateTime.now().difference(started);
      final processed = i + 1;
      final remaining = processed > 0 && processed < total
          ? elapsed * ((total - processed) / processed)
          : null;
      onProgress?.call(
        ImportProgress(
          total: total,
          processed: processed,
          imported: imported,
          skipped: skipped,
          failed: failed,
          elapsed: elapsed,
          estimatedRemaining: remaining,
        ),
      );
    }

    onProgress?.call(
      ImportProgress(
        total: total,
        processed: total,
        imported: imported,
        skipped: skipped,
        failed: failed,
        elapsed: DateTime.now().difference(started),
        finished: true,
      ),
    );

    return results;
  }

  /// Looks up an image for every row, a few at a time, before any writes.
  ///
  /// Image lookup is a network round trip of one to several seconds per row,
  /// so doing it inside the write loop made a 200-row sheet take many minutes
  /// with the app apparently idle. Fetching them up front overlaps that waiting
  /// while keeping the database writes serial — the catalog de-duplication in
  /// [GlobalCatalogService.getOrCreateGlobal] is a read-then-write and must not
  /// run concurrently with itself.
  ///
  /// Returns a list the same length as [rows], holding the image URL for each
  /// row or null where the service was not confident. A row with no match is
  /// simply left without a photo, and its product is still imported.
Future<List<String?>> _prefetchImages(
    List<ImportRow> rows, {
    void Function(ImportProgress progress)? onProgress,
    bool Function()? isCancelled,
    ImageLookupStats? stats,
  }) async {
    final found = List<String?>.filled(rows.length, null);
    final total = rows.length;
    var next = 0;
    var done = 0;
    final started = DateTime.now();

    Future<void> worker() async {
      while (true) {
        if (isCancelled?.call() ?? false) return;
        final index = next++;
        if (index >= total) return;
        found[index] = await _lookupImage(rows[index], stats);
        done++;
        final elapsed = DateTime.now().difference(started);
        // Once anything has failed, the running count is the more useful thing
        // to show than a generic "finding photos": a vendor can act on "3
        // rejected" and cannot act on "finding photos".
        final phase = (stats?.failures ?? 0) > 0
            ? 'Photo lookup failing: ${stats!.failures} of $done — photos left blank'
            : 'Finding photos from the internet';
        onProgress?.call(
          ImportProgress(
            total: total,
            processed: done,
            imported: 0,
            skipped: 0,
            failed: 0,
            elapsed: elapsed,
            estimatedRemaining: done > 0
                ? elapsed * ((total - done) / done)
                : null,
            phase: phase,
          ),
        );
      }
    }

    await Future.wait([
      for (var i = 0; i < _imageLookupConcurrency; i++) worker(),
    ]);
    return found;
  }

  /// The single best photo for a row, or null when the service is not confident.
  ///
  /// Never throws: a failed lookup must never fail an otherwise valid import.
  Future<String?> _lookupImage(ImportRow row, [ImageLookupStats? stats]) async {
    final outcome = await _imageSearch.lookupImage(
      name: row.productName,
      brand: row.brand,
      variant: row.variant,
      category: row.category,
      barcode: row.barcode,
    );
    if (stats != null) {
      switch (outcome.reason) {
        case ImageLookupFailure.none:
          if (outcome.url != null) {
            stats.found++;
          } else {
            stats.noMatch++;
          }
        case ImageLookupFailure.unauthorized:
          stats.unauthorized++;
        case ImageLookupFailure.unreachable:
          stats.unreachable++;
        case ImageLookupFailure.error:
          stats.error++;
      }
    }
    return outcome.url;
  }

  Future<({String productId, bool linked})> _importOne({
    required ImportRow row,
    required String vendorId,
    String? shopId,
    bool forceGstZero = false,
    bool autoFindImage = false,
    String? prefetchedImage,
  }) async {
    final gst = forceGstZero ? 0.0 : row.gst;
    final (globalId, match) = await _catalog.getOrCreateGlobal(
      name: row.productName,
      brand: row.brand,
      category: row.category,
      subcategory: row.subcategory,
      variant: row.variant,
      unit: row.unit,
      mrp: row.mrp,
      gst: gst,
      description: row.description,
      createdBy: vendorId,
    );

    final images = <String>[];
    if (row.imageUrl.startsWith('http')) {
      // A photo supplied in the sheet always wins: the vendor chose it.
      images.add(row.imageUrl);
    } else if (prefetchedImage != null) {
      images.add(prefetchedImage);
    } else if (autoFindImage) {
      final url = await _lookupImage(row);
      if (url != null) images.add(url);
    }
    final productId = await _products.addLinkedProduct(
      vendorId: vendorId,
      shopId: shopId,
      globalProductId: globalId,
      title: row.productName,
      description: row.description,
      category: row.category,
      subcategory: row.subcategory,
      brand: row.brand,
      variant: row.variant,
      unit: row.unit,
      mrp: row.mrp,
      gst: gst,
      sku: row.sku,
      barcode: row.barcode,
      price: row.sellingPrice > 0 ? row.sellingPrice : row.mrp,
      stock: row.stock,
      images: images,
    );

    return (productId: productId, linked: match.globalProduct != null);
  }

  /// Retries only the rows that failed during a previous run (rows rejected by
  /// validation are not retried — the source file must be fixed instead).
  Future<List<ImportResultRow>> retryFailed({
    required List<ImportResultRow> previous,
    required String vendorId,
    bool forceGstZero = false,
    bool autoFindImages = false,
    String? shopId,
    void Function(ImportProgress progress)? onProgress,
    ImageLookupStats? onImageStats,
  }) async {
    final failedRows = previous
        .where((r) => !r.success && r.retryable && r.row != null)
        .toList();

    // Same two-phase approach as [import]: look the images up in parallel
    // first, then write. Passing autoFindImage through here too — a retry that
    // silently dropped it left retried products permanently imageless.
    Map<int, String> prefetchedImages = const {};
    final imageStats = onImageStats ?? ImageLookupStats();
    if (autoFindImages && failedRows.isNotEmpty) {
      final positions = <int>[];
      final rowsNeedingImage = <ImportRow>[];
      for (var i = 0; i < failedRows.length; i++) {
        final row = failedRows[i].row!;
        if (row.imageUrl.startsWith('http')) continue;
        positions.add(i);
        rowsNeedingImage.add(row);
      }
      if (rowsNeedingImage.isNotEmpty) {
        final urls = await _prefetchImages(
          rowsNeedingImage,
          onProgress: onProgress,
          stats: imageStats,
        );
        prefetchedImages = {
          for (var n = 0; n < urls.length; n++)
            if (urls[n] != null) positions[n]: urls[n]!,
        };
      }
    }

    final results = <ImportResultRow>[];
    var ok = 0;
    var failed = 0;

    for (var i = 0; i < failedRows.length; i++) {
      final r = failedRows[i];
      try {
        final outcome = await _importOne(
          row: r.row!,
          vendorId: vendorId,
          shopId: shopId,
          forceGstZero: forceGstZero,
          autoFindImage: autoFindImages,
          prefetchedImage: prefetchedImages[i],
        );
        ok++;
        results.add(
          ImportResultRow(
            rowNumber: r.rowNumber,
            success: true,
            productId: outcome.productId,
            linked: outcome.linked,
            row: r.row,
          ),
        );
      } catch (e) {
        failed++;
        results.add(
          ImportResultRow(
            rowNumber: r.rowNumber,
            success: false,
            error: 'Import failed: $e',
            row: r.row,
          ),
        );
      }
      onProgress?.call(
        ImportProgress(
          total: failedRows.length,
          processed: i + 1,
          imported: ok,
          skipped: 0,
          failed: failed,
          elapsed: Duration.zero,
        ),
      );
    }

    onProgress?.call(
      ImportProgress(
        total: failedRows.length,
        processed: failedRows.length,
        imported: ok,
        skipped: 0,
        failed: failed,
        elapsed: Duration.zero,
        finished: true,
      ),
    );

    return results;
  }

  // ---------------------------------------------------------------
  // Error report
  // ---------------------------------------------------------------

  /// Generates a CSV error report of the failed/skipped rows.
  static Uint8List generateErrorReport(List<ImportResultRow> results) {
    final rows = <List<dynamic>>[
      ['Row Number', 'Product Name', 'Status', 'Error'],
    ];
    for (final r in results.where((r) => !r.success)) {
      rows.add([
        r.rowNumber,
        r.row?.productName ?? '',
        r.retryable ? 'Failed' : 'Needs Fix',
        r.error ?? '',
      ]);
    }
    final csv = '\uFEFF${const ListToCsvConverter().convert(rows)}';
    return Uint8List.fromList(utf8.encode(csv));
  }
}
