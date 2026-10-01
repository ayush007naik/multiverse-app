import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter_test/flutter_test.dart';
import 'package:vendor_dashboard/services/excel_import_service.dart';

/// Builds a minimal but valid workbook whose styles.xml declares a built-in
/// number format id (41 = Accounting). Real Excel, Google Sheets and
/// LibreOffice all emit these, and excel 4.x throws on them.
Uint8List buildWorkbook({required List<String> strings, bool withStyles = true}) {
  final s = strings.map((v) => _esc(v)).toList();
  final cellRefs = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M'];
  final row1 = cellRefs
      .map((c) => '<c r="${c}1" t="s"><v>${cellRefs.indexOf(c)}</v></c>')
      .join();
  final row2 = cellRefs
      .map((c) => '<c r="${c}2" t="s"><v>13</v></c>')
      .join();

  final files = <String, String>{
    '[Content_Types].xml':
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>'
        '</Types>',
    '_rels/.rels':
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>',
    'xl/workbook.xml':
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets><sheet name="Products" sheetId="1" r:id="rId1"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels':
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>'
        '</Relationships>',
    'xl/sharedStrings.xml':
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="${s.length}" uniqueCount="${s.length}">'
        '${s.map((v) => '<si><t>$v</t></si>').join()}</sst>',
    'xl/worksheets/sheet1.xml':
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<sheetData><row r="1">$row1</row><row r="2">$row2</row></sheetData></worksheet>',
  };

  if (withStyles) {
    files['xl/styles.xml'] =
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<numFmts count="1">'
        '<numFmt numFmtId="41" formatCode="_(&quot;\$&quot;* #,##0.00_);_(&quot;\$&quot;* (#,##0.00);_(&quot;\$&quot;* &quot;-&quot;??_);_(@_)"/>'
        '</numFmts>'
        '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>'
        '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>'
        '<borders count="1"><border/></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0"/></cellStyleXfs>'
        '<cellXfs count="1"><xf numFmtId="41" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>'
        '</styleSheet>';
  }

  final out = Archive();
  files.forEach((name, body) {
    final bytes = Uint8List.fromList(utf8.encode(body));
    out.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return Uint8List.fromList(ZipEncoder().encode(out)!);
}

String _esc(String v) =>
    v.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

void main() {
  final headers = ExcelImportService.sampleHeaders;
  final strings = [...headers, 'Amul Butter 500g'];

  group('excel 4.x numFmtId regression', () {
    test('the excel package really does reject a built-in format id', () {
      expect(
        () => excel_pkg.Excel.decodeBytes(buildWorkbook(strings: strings)),
        throwsA(anything),
      );
    });

    test('import still works for a workbook using an Accounting format', () {
      final sheet = ExcelImportService.parseFile(
        buildWorkbook(strings: strings),
        'vendor-products.xlsx',
      );

      expect(sheet.columns.detected, isTrue);
      expect(sheet.rows, hasLength(1));

      final row = ExcelImportService.rowFromCells(
        sheet.rows.single,
        sheet.columns,
      );
      expect(row.productName, 'Amul Butter 500g');
    });

    test('falls back to raw OOXML when styles.xml is unusable', () {
      final sheet = ExcelImportService.parseFile(
        buildWorkbook(strings: strings, withStyles: false),
        'vendor-products.xlsx',
      );

      expect(sheet.columns.detected, isTrue);
      expect(sheet.rows, hasLength(1));
      expect(sheet.rows.single.first, 'Amul Butter 500g');
    });

    test('a genuinely broken file reports the real reason, not a guess', () {
      expect(
        () => ExcelImportService.parseFile(
          Uint8List.fromList(utf8.encode('PK\x03\x04 this is not a zip')),
          'broken.xlsx',
        ),
        throwsA(
          isA<ExcelParseException>().having(
            (e) => e.message,
            'message',
            contains('End of Central Directory'),
          ),
        ),
      );
    });
  });
}
