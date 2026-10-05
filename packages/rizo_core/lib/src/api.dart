import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'config.dart';

/// An error from the API (or from reaching it). [status] is 0 when the server could not be reached.
class ApiException implements Exception {
  ApiException(this.status, this.message, {this.code = 'generic', this.details, this.cause});

  final int status;
  final String message;
  final String code;
  final Map<String, dynamic>? details;

  /// What went wrong underneath (for logs and tests).
  final Object? cause;

  /// The request never got an answer: offline, DNS, timeout. Safe to retry later.
  bool get isNetwork => status == 0;

  /// Worth trying again later: no connection, or the server is waking up / overloaded (Render free tier sleeps).
  bool get isRetryable => isNetwork || status == 502 || status == 503 || status == 504;

  /// The session is no longer valid.
  bool get isAuth => status == 401 && const {'invalidSession', 'accountGone', 'required'}.contains(code);

  @override
  String toString() => 'ApiException($status, $code, $message${cause == null ? '' : ', cause: $cause'})';
}

class UploadFile {
  UploadFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

typedef TokenProvider = String? Function();

/// A thin JSON client for the RIZO Service API (the same endpoints the website uses).
class ApiClient {
  ApiClient({this.tokenProvider, this.onUnauthorized, http.Client? client}) : _client = client ?? http.Client();

  final TokenProvider? tokenProvider;
  final void Function()? onUnauthorized;
  final http.Client _client;

  static const _timeout = Duration(seconds: 25);
  static const _uploadTimeout = Duration(seconds: 120);

  Map<String, String> _headers({bool json = true}) {
    final token = tokenProvider?.call();
    return {
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, Map<String, dynamic>? query) {
    final base = Uri.parse(AppConfig.url(path));
    if (query == null || query.isEmpty) return base;
    final params = <String, String>{
      ...base.queryParameters,
      for (final entry in query.entries)
        if (entry.value != null && entry.value.toString().isNotEmpty) entry.key: entry.value.toString(),
    };
    return base.replace(queryParameters: params);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _client.get(_uri(path, query), headers: _headers()), _timeout);

  Future<dynamic> post(String path, {Object? body}) =>
      _send(() => _client.post(_uri(path, null), headers: _headers(), body: body == null ? null : jsonEncode(body)), _timeout);

  Future<dynamic> put(String path, {Object? body}) =>
      _send(() => _client.put(_uri(path, null), headers: _headers(), body: body == null ? null : jsonEncode(body)), _timeout);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() => _client.patch(_uri(path, null), headers: _headers(), body: body == null ? null : jsonEncode(body)), _timeout);

  Future<dynamic> delete(String path) => _send(() => _client.delete(_uri(path, null), headers: _headers()), _timeout);

  /// Sends photos as multipart form data (field "photos"), like the website does.
  Future<dynamic> upload(String path, List<UploadFile> files, {String field = 'photos'}) {
    return _send(() async {
      final request = http.MultipartRequest('POST', _uri(path, null))..headers.addAll(_headers(json: false));
      for (final file in files) {
        request.files.add(http.MultipartFile.fromBytes(field, file.bytes, filename: file.name));
      }
      return http.Response.fromStream(await _client.send(request));
    }, _uploadTimeout);
  }

  Future<dynamic> _send(Future<http.Response> Function() call, Duration timeout) async {
    http.Response response;
    try {
      response = await call().timeout(timeout);
    } on TimeoutException {
      throw ApiException(0, 'The request timed out', code: 'network');
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(0, 'Could not reach the server', code: 'network', cause: error);
    }
    dynamic data;
    if (response.bodyBytes.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        data = null;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    final map = data is Map ? data : const {};
    final error = ApiException(
      response.statusCode,
      map['error']?.toString() ?? 'Request failed',
      code: map['code']?.toString() ?? 'generic',
      details: map['details'] is Map ? Map<String, dynamic>.from(map['details'] as Map) : null,
    );
    if (error.isAuth) onUnauthorized?.call();
    throw error;
  }

  void close() => _client.close();
}
