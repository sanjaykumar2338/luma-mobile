import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma_mobile/core/api_client.dart';

void main() {
  test('parses Bible chapters, verses, ranges, and books with spaces', () {
    expect(parseBibleReaderReference('Nehemiah 1'), {
      'translation': 'WEB',
      'book': 'Nehemiah',
      'chapter': 1,
    });
    expect(parseBibleReaderReference('KJV: 1 Corinthians 13:4-7'), {
      'translation': 'KJV',
      'book': '1 Corinthians',
      'chapter': 13,
      'verse_start': 4,
      'verse_end': 7,
    });
  });
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

  test('reports malformed successful responses as an API error', () async {
    final api = ApiClient(
        client: MockClient((_) async => http.Response('not-json', 200)));

    expect(
        () => api.request('/user'),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', contains('invalid response'))));
  });

  test('sends JSON bodies with DELETE requests', () async {
    String? body;
    final api = ApiClient(client: MockClient((request) async {
      body = request.body;
      return http.Response(
          jsonEncode({'message': 'Account permanently deleted.'}), 200);
    }));

    await api
        .request('/user', method: 'DELETE', body: {'confirmation': 'DELETE'});
    expect(body, jsonEncode({'confirmation': 'DELETE'}));
  });

  test('maps sermon questions to the Laravel conversation contract', () async {
    Map<String, dynamic>? payload;
    final api = ApiClient(client: MockClient((request) async {
      payload = jsonDecode(request.body).cast<String, dynamic>();
      return http.Response(jsonEncode({'data': {}}), 201);
    }));

    await api.request('/sermons/7/conversation/messages',
        method: 'POST', body: {'content': 'What is this sermon about?'});

    expect(payload?['question'], 'What is this sermon about?');
    expect(payload?['content'], 'What is this sermon about?');
    expect(payload?['client_request_id'], matches(RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4000-8000-[0-9a-f]{12}$')));
  });
}
