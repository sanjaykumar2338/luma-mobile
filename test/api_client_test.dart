import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma_mobile/core/api_client.dart';

void main() {
  test('decodes a successful API envelope and forwards query parameters',
      () async {
    Uri? requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(
          jsonEncode({
            'data': {'id': 4}
          }),
          200);
    });
    final api = ApiClient(client: client);

    final result = await api.request('/user', query: {'page': '2'});

    expect(result['data'], {'id': 4});
    expect(requested?.queryParameters['page'], '2');
  });

  test('turns server validation errors into ApiException', () async {
    final api = ApiClient(
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'message': 'Invalid input',
                'errors': {
                  'email': ['Invalid email']
                }
              }),
              422,
            )));

    expect(
        () => api
            .request('/user/profile', method: 'PATCH', body: {'email': 'bad'}),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Invalid input')));
  });
}
