import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  ApiService({required this.token});
  final String? token;
  static const baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://10.0.2.2:3000');
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token'
      };
  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);
  Future<Map<String, dynamic>> _json(http.Response response) async {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException((body['error'] as String?) ??
          'Request failed (${response.statusCode}).');
    }
    return body;
  }

  Future<Map<String, dynamic>> register(
          String name, String email, String password) async =>
      _json(await http.post(_uri('/api/auth/register'),
          headers: _headers,
          body: jsonEncode(
              {'name': name, 'email': email, 'password': password})));
  Future<Map<String, dynamic>> login(String email, String password) async =>
      _json(await http.post(_uri('/api/auth/login'),
          headers: _headers,
          body: jsonEncode({'email': email, 'password': password})));
  Future<Map<String, dynamic>> dashboard() async =>
      _json(await http.get(_uri('/api/dashboard'), headers: _headers));
  Future<List<Map<String, dynamic>>> calls(
      {String query = '',
      String type = 'all',
      String? from,
      String? to}) async {
    final data = await _json(await http.get(
        _uri('/api/calls', {
          'query': query,
          'type': type,
          if (from != null) 'from': from,
          if (to != null) 'to': to
        }),
        headers: _headers));
    return List<Map<String, dynamic>>.from(data['calls'] as List);
  }

  Future<void> addCall(Map<String, dynamic> call) async => _json(await http
      .post(_uri('/api/calls'), headers: _headers, body: jsonEncode(call)));
  Future<void> deleteCall(String id) async =>
      _json(await http.delete(_uri('/api/calls/$id'), headers: _headers));
  Future<List<Map<String, dynamic>>> contacts([String query = '']) async {
    final data = await _json(await http
        .get(_uri('/api/contacts', {'query': query}), headers: _headers));
    return List<Map<String, dynamic>>.from(data['contacts'] as List);
  }

  Future<void> addContact(String name, String phone, String tag) async =>
      _json(await http.post(_uri('/api/contacts'),
          headers: _headers,
          body: jsonEncode({'name': name, 'phone': phone, 'tag': tag})));
  Future<void> deleteContact(String id) async =>
      _json(await http.delete(_uri('/api/contacts/$id'), headers: _headers));
  Future<Map<String, dynamic>> analytics({String? from, String? to}) async =>
      _json(await http.get(
          _uri('/api/analytics',
              {if (from != null) 'from': from, if (to != null) 'to': to}),
          headers: _headers));
  Future<List<Map<String, dynamic>>> recordings() async {
    final data =
        await _json(await http.get(_uri('/api/recordings'), headers: _headers));
    return List<Map<String, dynamic>>.from(data['recordings'] as List);
  }

  Future<void> uploadRecording(
      {required File file,
      required String callId,
      required String name}) async {
    final request = http.MultipartRequest('POST', _uri('/api/recordings'))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields.addAll({'callId': callId, 'name': name, 'consent': 'true'})
      ..files.add(await http.MultipartFile.fromPath('recording', file.path));
    final response = await request.send();
    await _json(await http.Response.fromStream(response));
  }
}
