import 'dart:convert';
import 'dart:io';

/// JSON fixtures copied from the request-template contract
/// (`test/fixtures/requests/`).
dynamic requestFixture(String name) =>
    jsonDecode(File('test/fixtures/requests/$name.json').readAsStringSync());

/// A `{ok, data, meta}` fixture as the raw transport answers it:
/// `{message: envelope}`.
Map<String, dynamic> requestEnvelope(String name) =>
    {'message': Map<String, dynamic>.from(requestFixture(name) as Map)};

/// The `data` of an envelope fixture.
dynamic requestData(String name) => (requestFixture(name) as Map)['data'];

/// The three template field lists of the contract (§3.4 to §3.6).
Map<String, List<Map<String, dynamic>>> templateFieldFixtures() {
  final raw = requestFixture('template_fields') as Map;
  return {
    for (final entry in raw.entries)
      entry.key as String: [
        for (final field in entry.value as List)
          Map<String, dynamic>.from(field as Map)
      ]
  };
}

/// The three `request_options` rows (purchase, supply, leave).
List<Map<String, dynamic>> requestOptionFixtures() => [
      for (final row in requestFixture('request_options') as List)
        Map<String, dynamic>.from(row as Map)
    ];
