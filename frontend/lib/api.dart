import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  final String message;
  final int? status;

  const ApiException(this.message, {this.status});

  @override
  String toString() => message;
}

String defaultApiBase() {
  const env = String.fromEnvironment('API_BASE');
  if (env.isNotEmpty) return env;
  if (kIsWeb) return '';
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080';
  }
  return 'http://localhost:8080';
}

class ApiClient {
  String baseUrl;
  final http.Client _client;

  ApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Uri _uri(String path) {
    final base = baseUrl.trim();
    if (base.isEmpty) {
      if (kIsWeb) return Uri.base.resolve(path);
      return Uri.parse('http://localhost:8080$path');
    }
    final clean = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return Uri.parse('$clean$path');
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final uri = _uri(path);
    const headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    http.Response response;
    try {
      if (method == 'GET') {
        response = await _client.get(uri, headers: headers).timeout(timeout);
      } else if (method == 'POST') {
        response = await _client
            .post(uri, headers: headers, body: body == null ? null : jsonEncode(body))
            .timeout(timeout);
      } else if (method == 'DELETE') {
        response = await _client.delete(uri, headers: headers).timeout(timeout);
      } else {
        throw const ApiException('Unsupported request method.');
      }
    } on TimeoutException {
      throw const ApiException('The server took too long to answer. Try again.');
    } catch (_) {
      throw ApiException(
        'Could not reach the ScamGym server at ${uri.origin.isEmpty ? uri.toString() : uri.origin}. '
        'Check the server address.',
      );
    }

    if (response.statusCode == 204) return null;

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Request failed (${response.statusCode}).';
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String) {
          message = detail;
        } else if (detail is List) {
          final parts = detail
              .whereType<Map<String, dynamic>>()
              .map((item) => item['msg'])
              .whereType<String>()
              .toList();
          if (parts.isNotEmpty) message = parts.join('; ');
        }
      }
      throw ApiException(message, status: response.statusCode);
    }
    return decoded;
  }

  Future<Health> health() async {
    final data = await _request('GET', '/api/health');
    return Health.fromJson(data is Map<String, dynamic> ? data : const {});
  }

  Future<List<Scenario>> scenarios() async {
    final data = await _request('GET', '/api/scenarios');
    if (data is Map<String, dynamic> && data['scenarios'] is List) {
      return (data['scenarios'] as List)
          .whereType<Map<String, dynamic>>()
          .map(Scenario.fromJson)
          .toList(growable: false);
    }
    return const [];
  }

  Future<RoundStart> startRound(String scenarioId) async {
    final data = await _request(
      'POST',
      '/api/rounds',
      body: {'scenario_id': scenarioId},
    );
    return RoundStart.fromJson(data is Map<String, dynamic> ? data : const {});
  }

  Future<SendResult> sendMessage(String roundId, String text) async {
    final data = await _request(
      'POST',
      '/api/rounds/$roundId/messages',
      body: {'text': text},
      timeout: const Duration(seconds: 80),
    );
    return SendResult.fromJson(data is Map<String, dynamic> ? data : const {});
  }

  Future<void> recordLinkClick(String roundId, String url) async {
    await _request(
      'POST',
      '/api/rounds/$roundId/events',
      body: {'kind': 'link_clicked', 'url': url},
    );
  }

  Future<WeighIn> scoreRound(String roundId) async {
    final data = await _request(
      'POST',
      '/api/rounds/$roundId/score',
      timeout: const Duration(seconds: 30),
    );
    return WeighIn.fromJson(data is Map<String, dynamic> ? data : const {});
  }

  Future<LinkReport> checkLink(String url) async {
    final data = await _request(
      'POST',
      '/api/check/link',
      body: {'url': url},
      timeout: const Duration(seconds: 45),
    );
    return LinkReport.fromJson(data is Map<String, dynamic> ? data : const {});
  }

  Future<MessageReport> checkMessage(String text) async {
    final data = await _request(
      'POST',
      '/api/check/message',
      body: {'text': text},
      timeout: const Duration(seconds: 45),
    );
    return MessageReport.fromJson(data is Map<String, dynamic> ? data : const {});
  }
}
