import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vendor_dashboard/services/excel_import_service.dart';

void main() {
  Uint8List csv(String value) => Uint8List.fromList(value.codeUnits);

  group('ExcelImportService flexible parser', () {
    test('maps reordered common vendor headers', () {
      final sheet = ExcelImportService.parseFile(
        csv(
          'Qty,Item Name,Rate (Rs.),Tax %,Item Code\n'
          '12,Masala Chips,25.50,5%,CHIPS-01',
        ),
        'vendor-stock.csv',
      );

      expect(sheet.columns.detected, isTrue);
      expect(sheet.rows, hasLength(1));
      expect(
        ExcelImportService.validateRow(sheet.rows.single, sheet.columns),
        isNull,
      );

      final row = ExcelImportService.rowFromCells(
        sheet.rows.single,
        sheet.columns,
      );
      expect(row.productName, 'Masala Chips');
      expect(row.mrp, 25.5);
      expect(row.stock, 12);
      expect(row.gst, 5);
      expect(row.sku, 'CHIPS-01');
    });

    test('accepts semicolon-delimited files and uses safe defaults', () {
      final sheet = ExcelImportService.parseFile(
        csv('Product;Selling Price\nSoap;Rs.40'),
        'products.txt',
      );

      expect(sheet.columns.detected, isTrue);
      expect(
        ExcelImportService.validateRow(sheet.rows.single, sheet.columns),
        isNull,
      );

      final row = ExcelImportService.rowFromCells(
        sheet.rows.single,
        sheet.columns,
      );
      expect(row.category, ExcelImportService.defaultCategory);
      expect(row.stock, 0);
      expect(row.gst, 0);
      expect(row.mrp, 40);
      expect(row.sellingPrice, 40);
    });
  });
}
