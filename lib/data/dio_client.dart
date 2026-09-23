import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:parley_android/data/api_config.dart';
import 'package:parley_android/data/api_exceptions.dart';
import 'package:parley_android/data/mock/mock_routes.dart';
import 'package:parley_android/data/mock/mock_store.dart';

/// Wraps a Dio call and converts [DioException]s into the app's domain
/// exceptions from [api_exceptions.dart], so callers can keep using
/// `try / on NotFoundException` style.
Future<T> dioCall<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on DioException catch (err) {
    throw _mapDioError(err);
  }
}

ApiException _mapDioError(DioException err) {
  switch (err.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const NetworkException(
        'Connection failed. Please check your network and try again.',
      );
    case DioExceptionType.badResponse:
      final status = err.response?.statusCode ?? 0;
      final message = _extractMessage(err.response?.data) ?? 'Request failed';
      switch (status) {
        case 400:
        case 422:
          return ValidationException(message);
        case 401:
          return const ApiException('Unauthorized', statusCode: 401);
        case 404:
          return NotFoundException(message);
        case >= 500:
          return ServerException(message);
        default:
          return ApiException(message, statusCode: status);
      }
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return NetworkException(err.message ?? 'Network error');
  }
}

String? _extractMessage(dynamic data) {
  if (data is Map<String, dynamic>) {
    return (data['message'] as String?) ?? (data['error'] as String?);
  }
  return null;
}

/// Builds a configured [Dio]. When [mock] is true, a [DioAdapter] is
/// attached and pre-populated with routes that resolve against the
/// in-memory [MockStore], so the app runs without a real backend.
Dio buildDio({required bool mock}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      contentType: 'application/json',
      responseType: ResponseType.json,
      headers: const {'Accept': 'application/json'},
    ),
  );

  if (mock) {
    final adapter = DioAdapter(dio: dio);
    registerMockRoutes(adapter, MockStore.instance);
  }

  return dio;
}
