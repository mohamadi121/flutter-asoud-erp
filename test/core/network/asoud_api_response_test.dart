import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/asoud_api_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses successful ASOUD API response', () {
    final response = AsoudApiResponse<Map<String, dynamic>>.parse(
      {
        'ok': true,
        'data': {'account_number': '1101'},
        'meta': {'api_version': 'v1'},
      },
      (value) => Map<String, dynamic>.from(value! as Map),
    );

    expect(response.data['account_number'], '1101');
    expect(response.apiVersion, 'v1');
  });

  test('turns backend failure into ApiException', () {
    expect(
      () => AsoudApiResponse<Object?>.parse(
        {
          'ok': false,
          'error': {'code': 'VALIDATION_ERROR', 'message': 'invalid'},
          'meta': {'api_version': 'v1'},
        },
        (value) => value,
      ),
      throwsA(isA<ApiException>()),
    );
  });
}
