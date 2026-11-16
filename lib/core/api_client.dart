import 'dart:io';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.fields = const {}});
  final String message;
  final int? statusCode;
  final Map<String, dynamic> fields;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  Future<Map<String, dynamic>> uploadSermon(String filePath, {String? title}) async {
    final request = http.MultipartRequest('POST', Uri.parse('${AppConfig.apiBaseUrl}/sermons'));
    request.headers['Accept'] = 'application/json';
    final token = await _storage.read(key: 'luma_access_token');
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields['source_type'] = 'upload';
    request.fields['auto_process'] = 'true';
    if (title != null && title.trim().isNotEmpty) request.fields['title'] = title.trim();
    request.files.add(await http.MultipartFile.fromPath('media', filePath));
    final response = await request.send();
    final payload = response.statusCode == 204 ? <String, dynamic>{} : jsonDecode(await response.stream.bytesToString());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final map = payload is Map ? payload.cast<String, dynamic>() : <String, dynamic>{};
      throw ApiException(map['message'] as String? ?? 'Upload failed. Please try again.', statusCode: response.statusCode, fields: (map['errors'] as Map?)?.cast<String, dynamic>() ?? {});
    }
    return payload is Map ? payload.cast<String, dynamic>() : <String, dynamic>{'data': payload};
  }

  Future<dynamic> requestAny(String path, {String method = 'GET', Map<String, dynamic>? body, bool auth = false, Map<String, String>? query, String? idempotencyKey}) async {
    if (path.contains('/conversation/messages') && body != null && body['content'] != null) {
      body = {...body, 'question': body['content'], 'client_request_id': '00000000-0000-4000-8000-000000000001'};
    }
    if (path == '/bible-studies' && method == 'POST' && body != null) {
      body = {...body};
      final reference = body['reader_reference'];
      if (reference is String) {
        final match = RegExp(r'^(.+?)\s+(\d+)').firstMatch(reference.trim());
        if (match != null) {
          body['reader_reference'] = {'translation': 'WEB', 'book': match.group(1), 'chapter': int.parse(match.group(2)!)};
        } else {
          body.remove('reader_reference');
        }
      }
      body['depth'] = body['depth'] == 'quick' ? 'quick_read' : body['depth'] == 'deep' ? 'go_deeper' : body['depth'];
    }
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path').replace(queryParameters: query);
    final headers = <String, String>{'Accept': 'application/json', 'Content-Type': 'application/json'};
    if (idempotencyKey != null) headers['Idempotency-Key'] = idempotencyKey;
    if (auth) {
      final token = await _storage.read(key: 'luma_access_token');
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    final response = await switch (method) {
      'POST' => http.post(uri, headers: headers, body: body == null ? null : jsonEncode(body)),
      'PATCH' => http.patch(uri, headers: headers, body: body == null ? null : jsonEncode(body)),
      'PUT' => http.put(uri, headers: headers, body: body == null ? null : jsonEncode(body)),
      'DELETE' => http.delete(uri, headers: headers),
      _ => http.get(uri, headers: headers),
    };
    final payload = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final map = payload is Map ? payload.cast<String, dynamic>() : <String, dynamic>{};
      throw ApiException(map['message'] as String? ?? 'Something went wrong. Please try again.', statusCode: response.statusCode, fields: (map['errors'] as Map?)?.cast<String, dynamic>() ?? {});
    }
    return payload;
  }

  Future<Map<String, dynamic>> request(String path, {String method = 'GET', Map<String, dynamic>? body, bool auth = false, Map<String, String>? query, String? idempotencyKey}) async {
    final result = await requestAny(path, method: method, body: body, auth: auth, query: query, idempotencyKey: idempotencyKey);
    return result is Map ? result.cast<String, dynamic>() : <String, dynamic>{'data': result};
  }
}
