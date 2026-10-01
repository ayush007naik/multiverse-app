import 'package:flutter_test/flutter_test.dart';
import 'package:vendor_dashboard/services/excel_import_service.dart';

/// The tally exists so a run that found nothing can say whether the products
/// genuinely have no photo online or the lookup never worked. The wording is
/// what the vendor reads, so it is asserted rather than assumed.
void main() {
  test('no lookups at all says nothing', () {
    // Photo lookup off, or a sheet where every row already had a URL.
    final s = ImageLookupStats();
    expect(s.headline, isNull);
    expect(s.serviceBroken, isFalse);
  });

  test('all found, none missed: no complaint', () {
    final s = ImageLookupStats()..found = 12;
    expect(s.headline, isNull);
    expect(s.serviceBroken, isFalse);
  });

  test('some misses are reported as misses, not as an error', () {
    final s = ImageLookupStats()
      ..found = 8
      ..noMatch = 4;
    expect(s.serviceBroken, isFalse);
    expect(s.headline, contains('8 of 12'));
    expect(s.headline, contains('no match on the internet'));
  });

  test('an expired session is called out with the fix', () {
    final s = ImageLookupStats()
      ..found = 0
      ..unauthorized = 12;
    expect(s.serviceBroken, isTrue);
    expect(s.headline, contains('sign out and back in'));
  });

  test('an unreachable service is called out separately', () {
    final s = ImageLookupStats()
      ..found = 3
      ..noMatch = 1
      ..unreachable = 8;
    expect(s.serviceBroken, isTrue);
    expect(s.headline, contains('service unreachable'));
    expect(s.failures, 8);
  });

  test('a mix of failures names each cause separately', () {
    final s = ImageLookupStats()
      ..unauthorized = 2
      ..unreachable = 1;
    final h = s.headline!;
    expect(h, contains('3 times'));
    expect(h, contains('session expired'));
    expect(h, contains('service unreachable'));
  });

  // A misconfigured service tells the vendor to hand this to a developer.
  // Suggesting they sign in again, or retry, would be actively wrong.
  test('a service fault is not blamed on the vendor', () {
    final s = ImageLookupStats()..error = 4;
    final h = s.headline!;
    expect(h, contains('needs a developer'));
    expect(h, isNot(contains('sign out')));
    expect(h, isNot(contains('retry')));
  });

  test('pluralisation is right for one failure', () {
    final s = ImageLookupStats()..unreachable = 1;
    expect(s.headline, contains('failed 1 time '));
  });

  test('nothing found and nothing failed is a miss, not silence', () {
    // Every row a miss: the vendor should still be told photos were looked for.
    final s = ImageLookupStats()..noMatch = 5;
    expect(s.headline, contains('0 of 5'));
    expect(s.serviceBroken, isFalse);
  });
}
