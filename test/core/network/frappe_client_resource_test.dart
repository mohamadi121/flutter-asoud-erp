import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Dio dio;
  late List<RequestOptions> requests;
  late FrappeClient client;

  setUp(() {
    requests = [];
    dio = Dio(BaseOptions(baseUrl: 'https://erp.example.test'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      handler.resolve(Response<Map<String, dynamic>>(
        requestOptions: options,
        statusCode: 200,
        data: const {
          'data': <String, dynamic>{},
          'message': <String, dynamic>{}
        },
      ));
    }));
    client = FrappeClient(dio: dio, baseUrl: 'https://erp.example.test');
  });

  tearDown(() => client.close());

  test('callMethod از endpoint استاندارد متد Frappe استفاده می‌کند', () async {
    await client
        .callMethod('frappe.client.get_list', data: {'doctype': 'Account'});
    expect(requests.single.method, 'POST');
    expect(requests.single.path, '/api/method/frappe.client.get_list');
    expect(requests.single.data, {'doctype': 'Account'});
  });

  test('createResource از endpoint استاندارد resource استفاده می‌کند',
      () async {
    await client.createResource('Company', {'company_name': 'آسود'});
    expect(requests.single.method, 'POST');
    expect(requests.single.path, '/api/resource/Company');
  });

  test('updateResource نام سند را در مسیر امن قرار می‌دهد', () async {
    await client
        .updateResource('Company', 'آسود ایران', {'company_name': 'آسود'});
    expect(requests.single.method, 'PUT');
    expect(requests.single.path,
        '/api/resource/Company/%D8%A2%D8%B3%D9%88%D8%AF%20%D8%A7%DB%8C%D8%B1%D8%A7%D9%86');
  });
}
