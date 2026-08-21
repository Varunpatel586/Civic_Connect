import '../models/issue.dart';

/// Turns a database record into the reference a citizen would actually quote
/// down the phone: `CC-2026-GJ-04821`.
///
/// Nothing here is invented. The year comes from the filing date, the state
/// code is read out of the geocoded address, and the sequence is a stable
/// encoding of the record's own id — so the same complaint always produces the
/// same reference, on every device, without storing an extra field.
abstract final class ComplaintReference {
  /// Two-letter codes matching the state abbreviations already familiar from
  /// vehicle registrations, so the reference reads as native.
  static const Map<String, String> _stateCodes = {
    'andhra pradesh': 'AP',
    'arunachal pradesh': 'AR',
    'assam': 'AS',
    'bihar': 'BR',
    'chhattisgarh': 'CG',
    'goa': 'GA',
    'gujarat': 'GJ',
    'haryana': 'HR',
    'himachal pradesh': 'HP',
    'jharkhand': 'JH',
    'karnataka': 'KA',
    'kerala': 'KL',
    'madhya pradesh': 'MP',
    'maharashtra': 'MH',
    'manipur': 'MN',
    'meghalaya': 'ML',
    'mizoram': 'MZ',
    'nagaland': 'NL',
    'odisha': 'OD',
    'punjab': 'PB',
    'rajasthan': 'RJ',
    'sikkim': 'SK',
    'tamil nadu': 'TN',
    'telangana': 'TS',
    'tripura': 'TR',
    'uttar pradesh': 'UP',
    'uttarakhand': 'UK',
    'west bengal': 'WB',
    'delhi': 'DL',
    'jammu and kashmir': 'JK',
    'ladakh': 'LA',
    'puducherry': 'PY',
    'chandigarh': 'CH',
  };

  /// The full reference, e.g. `CC-2026-GJ-04821`.
  static String format(Issue issue) {
    final year = issue.createdAt.year;
    final state = stateCode(issue.address);
    final sequence = _sequence(issue.id);
    return 'CC-$year-$state-$sequence';
  }

  /// State code parsed out of the address, or `IN` when the address does not
  /// name a state we recognise.
  static String stateCode(String? address) {
    if (address == null || address.isEmpty) return 'IN';
    final haystack = address.toLowerCase();
    for (final entry in _stateCodes.entries) {
      if (haystack.contains(entry.key)) return entry.value;
    }
    return 'IN';
  }

  /// The locality the complaint sits in, pulled from the geocoded address.
  ///
  /// The address is built by [LocationService] as
  /// `street, locality, postalCode, country`, so the second component is the
  /// locality. Returns null rather than a guess when the shape does not match.
  static String? locality(String? address) {
    if (address == null || address.isEmpty) return null;
    final parts = address
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty && p != 'null')
        .toList();
    if (parts.length < 2) return null;
    return parts[1];
  }

  /// Five stable digits derived from the record id.
  ///
  /// Mongo ObjectIds end in a counter, so the trailing hex gives a short,
  /// well-distributed sequence. Ids that are not hex — the sample rows the feed
  /// falls back to — hash instead, which is equally stable.
  static String _sequence(String id) {
    if (id.isEmpty) return '00000';

    final tail = id.length >= 6 ? id.substring(id.length - 6) : id;
    final parsed = int.tryParse(tail, radix: 16);
    final value = parsed ?? id.hashCode.abs();

    return (value % 100000).toString().padLeft(5, '0');
  }
}
