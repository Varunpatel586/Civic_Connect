import 'package:civic_connect/models/issue.dart';
import 'package:civic_connect/utils/complaint_reference.dart';
import 'package:flutter_test/flutter_test.dart';

Issue _issue({required String id, String? address, DateTime? createdAt}) {
  final filed = createdAt ?? DateTime(2026, 3, 4);
  return Issue(
    id: id,
    userId: 'u1',
    title: 'Test complaint',
    imageUrl: 'http://example.test/a.jpg',
    latitude: 23.03,
    longitude: 72.58,
    timestamp: filed,
    createdAt: filed,
    address: address,
  );
}

void main() {
  group('format', () {
    test('builds a reference from year, state and record id', () {
      final issue = _issue(
        id: '66bc2e2a0f8b1c4d4b123457',
        address: 'Ring Road, Ahmedabad, 380015, Gujarat, India',
      );

      expect(ComplaintReference.format(issue), 'CC-2026-GJ-93047');
    });

    test('is stable — the same issue always yields the same reference', () {
      final issue = _issue(id: '66bc2e2a0f8b1c4d4b123458');

      expect(
        ComplaintReference.format(issue),
        ComplaintReference.format(issue),
      );
    });

    test('distinct records yield distinct references', () {
      final a = _issue(id: '66bc2e2a0f8b1c4d4b123457');
      final b = _issue(id: '66bc2e2a0f8b1c4d4b123458');

      expect(
        ComplaintReference.format(a),
        isNot(ComplaintReference.format(b)),
      );
    });

    test('takes the year from the filing date', () {
      final issue = _issue(
        id: '66bc2e2a0f8b1c4d4b123457',
        createdAt: DateTime(2024, 12, 31),
      );

      expect(ComplaintReference.format(issue), startsWith('CC-2024-'));
    });

    test('handles a non-hex id without throwing', () {
      final issue = _issue(id: 'a1b2c3d4-dead-beef-zzzz-gggggg');

      expect(ComplaintReference.format(issue), matches(r'^CC-2026-IN-\d{5}$'));
    });

    test('handles an empty id', () {
      expect(ComplaintReference.format(_issue(id: '')), 'CC-2026-IN-00000');
    });
  });

  group('stateCode', () {
    test('reads the state out of an address', () {
      expect(ComplaintReference.stateCode('MG Road, Bengaluru, Karnataka'), 'KA');
      expect(ComplaintReference.stateCode('Andheri, Mumbai, Maharashtra'), 'MH');
    });

    test('matching ignores case', () {
      expect(ComplaintReference.stateCode('SECTOR 17, CHANDIGARH'), 'CH');
    });

    test('falls back to IN when no state is named', () {
      expect(ComplaintReference.stateCode('Amphitheatre Pkwy, CA'), 'IN');
      expect(ComplaintReference.stateCode(null), 'IN');
      expect(ComplaintReference.stateCode(''), 'IN');
    });
  });

  group('locality', () {
    test('pulls the locality out of a geocoded address', () {
      expect(
        ComplaintReference.locality('Ring Road, Ahmedabad, 380015, India'),
        'Ahmedabad',
      );
    });

    test('returns null when the address has no locality component', () {
      expect(ComplaintReference.locality('Ring Road'), isNull);
      expect(ComplaintReference.locality(null), isNull);
      expect(ComplaintReference.locality(''), isNull);
    });

    test('skips the literal "null" the geocoder emits for missing fields', () {
      expect(ComplaintReference.locality('null, null'), isNull);
    });
  });
}
